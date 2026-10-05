#!/usr/bin/env bash
#
# Shared helpers for the .codex scripts. Sourced, not executed.
#
# Environment:
#   REDMINE_DIR     checkout to work in (default: redmine)
#   MISE_BIN        mise executable, used only when it is present
#   RITL_RUBY       pin the Ruby version instead of deriving it from the Gemfile
#   RITL_RUBY_MAX   newest Ruby to pick (default: 3.4)

REDMINE_DIR="${REDMINE_DIR:-redmine}"
MISE_BIN="${MISE_BIN:-mise}"
RITL_RUBY_MAX="${RITL_RUBY_MAX:-3.4}"

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Used by the scripts that source this file, not here.
# shellcheck disable=SC2034
PLUGIN_NAME="$(basename "$PLUGIN_ROOT")"

# Compares two "major.minor" strings. Returns 0 when $1 <= $2.
ritl_version_le() {
  [ "$(printf '%s\n%s\n' "$1" "$2" | sort -t. -k1,1n -k2,2n | head -n 1)" = "$1" ]
}

# Redmine pins a range rather than a version, so derive one just below the upper
# bound: "< 3.5.0" means 3.4 is the newest Ruby the checkout accepts. Redmine 7
# allows "< 4.1.0", which would derive Ruby 4.0, so the result is clamped to
# RITL_RUBY_MAX and floored at the lower bound.
ritl_detect_ruby_version() {
  local gemfile="$REDMINE_DIR/Gemfile" line lower upper major minor candidate

  if [ -n "${RITL_RUBY:-}" ]; then
    echo "$RITL_RUBY"
    return 0
  fi

  [ -f "$gemfile" ] || return 0

  line="$(grep -E "^[[:space:]]*ruby[[:space:]]" "$gemfile" | head -n 1 || true)"
  [ -n "$line" ] || return 0

  lower="$(printf '%s' "$line" | sed -E -n "s/.*>=[[:space:]]*['\"]?([0-9]+\.[0-9]+).*/\1/p")"
  upper="$(printf '%s' "$line" | sed -E -n "s/.*<[[:space:]]*['\"]?([0-9]+)\.([0-9]+).*/\1.\2/p")"

  if [ -n "$upper" ]; then
    major="${upper%%.*}"
    minor="${upper##*.}"
    [ "$minor" -gt 0 ] && minor=$((minor - 1))
    candidate="${major}.${minor}"
  else
    candidate="$lower"
  fi

  [ -n "$candidate" ] || return 0

  # Never ask for a Ruby that has not been released.
  ritl_version_le "$candidate" "$RITL_RUBY_MAX" || candidate="$RITL_RUBY_MAX"
  # ...and never fall below what the checkout requires.
  if [ -n "$lower" ] && ! ritl_version_le "$lower" "$candidate"; then
    candidate="$lower"
  fi

  echo "$candidate"
}

# Sets RUBY_TARGET and USE_MISE. Pass "install" to let mise fetch the Ruby,
# anything else to select a Ruby that is expected to be there already.
ritl_select_ruby() {
  local mode="${1:-}"

  RUBY_TARGET="$(ritl_detect_ruby_version)"
  USE_MISE=0

  if [ -n "$RUBY_TARGET" ] && command -v "$MISE_BIN" >/dev/null 2>&1; then
    if [ "$mode" = install ]; then
      # Local, not global: a project script has no business repointing the machine.
      "$MISE_BIN" install "ruby@$RUBY_TARGET"
      echo "Using Ruby $RUBY_TARGET through mise."
    fi
    USE_MISE=1
  elif [ -n "$RUBY_TARGET" ] && [ "$mode" = install ]; then
    echo "mise not found; using the Ruby already on PATH ($(ruby -e 'print RUBY_VERSION' 2>/dev/null || echo 'none'))."
    echo "This checkout expects Ruby ~$RUBY_TARGET; bundler will complain if it does not fit."
  fi

  # Never let the function's status be the status of the last test it happened to
  # run: the callers use `set -e` and would stop silently.
  return 0
}

# Runs a command inside the Redmine checkout, through mise when it is in use.
run() {
  if [ "${USE_MISE:-0}" = 1 ]; then
    (cd "$REDMINE_DIR" && "$MISE_BIN" exec "ruby@$RUBY_TARGET" -- "$@")
  else
    (cd "$REDMINE_DIR" && "$@")
  fi
}
