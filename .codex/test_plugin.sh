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
# works the same way it would from the plugin directory. Options alone (a seed, a
# filter) still run the whole suite. The value of an option that takes one
# (`-e spec/foo`, `--out tmp/x_spec.rb`) is passed on as is, never as a path.
targets=()
has_path=0
value_next=0
for arg in "$@"; do
  if [ "$value_next" = 1 ]; then
    targets+=("$arg")
    value_next=0
    continue
  fi
  case "$arg" in
    -I|-r|--require|-O|--options|--order|--seed|--failure-exit-code|--error-exit-code|\
    --drb-port|-f|--format|-o|--out|--deprecation-out|-P|--pattern|--exclude-pattern|\
    -e|--example|-E|--example-matches|-t|--tag|--default-path)
      targets+=("$arg"); value_next=1 ;;
    -*) targets+=("$arg") ;;
    spec|spec/*) targets+=("plugins/$PLUGIN_NAME/$arg"); has_path=1 ;;
    *_spec.rb|*_spec.rb:*|*/spec|*/spec/*) targets+=("$arg"); has_path=1 ;;
    *) targets+=("$arg") ;;
  esac
done
[ "$has_path" = 1 ] || targets+=("$SPEC_ROOT")

RITL_JUNIT="${RITL_JUNIT:-$([ "${CI:-}" = "true" ] && echo 1 || echo 0)}"
formatters=(--format progress)
if [ "$RITL_JUNIT" = 1 ]; then
  mkdir -p "$REDMINE_DIR/tmp/test-results"
  formatters+=(--format RspecJunitFormatter --out "tmp/test-results/rspec-$PLUGIN_NAME.xml")
fi

run bundle exec rspec "${targets[@]}" "${formatters[@]}"
