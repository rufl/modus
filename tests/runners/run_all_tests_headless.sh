#!/usr/bin/env bash
# MODUS Test Suite Runner - Headless Mode
# Uses GUT's command-line interface to run tests with proper autoload support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

source "$SCRIPT_DIR/headless_common.sh"
modus_parse_headless_args "$@"

echo "======================================================================"
echo "  MODUS TEST SUITE - Headless Execution"
echo "======================================================================"
echo ""

if ! godot_bin="$(modus_find_godot_bin)"; then
  exit 127
fi

modus_import_project "$godot_bin"

modus_collect_gut_tests tests/unit tests/integration tests/property
modus_print_headless_selection
echo ""

set +e
modus_run_godot "$godot_bin" --headless -s addons/gut/gut_cmdln.gd "${MODUS_GUT_TEST_ARGS[@]}"
exit_code=$?
set -e

echo ""
echo "======================================================================"
if [ $exit_code -eq 0 ]; then
  echo "  SUCCESS: All selected headless tests passed"
else
  echo "  FAILURE: Some selected headless tests failed (exit code: $exit_code)"
fi
echo "======================================================================"
echo ""

exit $exit_code
