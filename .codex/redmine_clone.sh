#!/usr/bin/env bash
#
# Clones (or updates) a Redmine checkout and installs this plugin into it.
#
#   ./.codex/redmine_clone.sh [5.0-stable|5.1-stable|6.0-stable|6.1-stable|7.0-stable|master]
#
# Environment:
#   REDMINE_DIR   where to put the checkout (default: redmine)
#   REDMINE_REPO  upstream to clone from (default: the official repository)
set -euo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

REDMINE_VERSION="${1:-6.1-stable}"
REDMINE_REPO="${REDMINE_REPO:-https://github.com/redmine/redmine.git}"

for tool in git rsync; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "ERROR: '$tool' is required but not installed." >&2
    exit 1
  }
done

if ! git ls-remote --heads "$REDMINE_REPO" "$REDMINE_VERSION" | grep -q "refs/heads/$REDMINE_VERSION\$"; then
  echo "ERROR: branch '$REDMINE_VERSION' not found on $REDMINE_REPO" >&2
  exit 1
fi

if [ ! -d "$REDMINE_DIR/.git" ]; then
  git clone --depth 1 --branch "$REDMINE_VERSION" "$REDMINE_REPO" "$REDMINE_DIR"
else
  git -C "$REDMINE_DIR" fetch --depth 1 origin "$REDMINE_VERSION:refs/remotes/origin/$REDMINE_VERSION"
  git -C "$REDMINE_DIR" checkout -B "$REDMINE_VERSION" "origin/$REDMINE_VERSION"
fi

# --delete so that a file removed from the plugin also disappears from the
# checkout. The Redmine directory itself is excluded in case it sits inside the
# plugin, and so is the plugin's own git metadata.
mkdir -p "$REDMINE_DIR/plugins/$PLUGIN_NAME"
rsync -a --delete \
  --exclude "/$REDMINE_DIR/" \
  --exclude '/.git/' \
  "$PLUGIN_ROOT/" "$REDMINE_DIR/plugins/$PLUGIN_NAME/"

echo "Installed $PLUGIN_NAME into $REDMINE_DIR at $REDMINE_VERSION"
