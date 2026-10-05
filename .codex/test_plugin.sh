#!/usr/bin/env bash
#
# Runs the plugin's specs inside the Redmine checkout prepared by test_setup.sh.
# Any extra arguments are passed to rspec, so a single file or example works:
#
#   ./.codex/test_plugin.sh
#   ./.codex/test_plugin.sh spec/context_menu_spec.rb -e 'single issue'
#
# Environment:
#   REDMINE_DIR   checkout to run in (default: redmine)
#   RITL_JUNIT    1 to also write JUnit xml to tmp/test-results (default: 1 in CI)
#   RITL_RUBY     pin the Ruby version instead of deriving it
#   MISE_BIN      mise executable, used only when it is present
set -euo pipefail

# shellcheck source-path=SCRIPTDIR
# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SPEC_ROOT="plugins/$PLUGIN_NAME/spec"

[ -d "$REDMINE_DIR/$SPEC_ROOT" ] || {
  echo "ERROR: '$REDMINE_DIR/$SPEC_ROOT' not found. Run ./.codex/redmine_clone.sh first." >&2
  exit 1
}

ritl_select_ruby quiet

export RAILS_ENV=test

# Arguments are relative to the plugin, so ./.codex/test_plugin.sh spec/foo_spec.rb
# works the same way it would from the plugin directory.
targets=()
if [ "$#" -eq 0 ]; then
  targets=("$SPEC_ROOT")
else
  for arg in "$@"; do
    case "$arg" in
      -*) targets+=("$arg") ;;
      spec/*) targets+=("plugins/$PLUGIN_NAME/$arg") ;;
      *) targets+=("$arg") ;;
    esac
  done
fi

RITL_JUNIT="${RITL_JUNIT:-$([ "${CI:-}" = "true" ] && echo 1 || echo 0)}"
formatters=(--format progress)
if [ "$RITL_JUNIT" = 1 ]; then
  mkdir -p "$REDMINE_DIR/tmp/test-results"
  formatters+=(--format RspecJunitFormatter --out "tmp/test-results/rspec-$PLUGIN_NAME.xml")
fi

run bundle exec rspec "${targets[@]}" "${formatters[@]}"
