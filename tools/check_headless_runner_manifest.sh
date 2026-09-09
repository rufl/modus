#!/usr/bin/env bash
set -euo pipefail

manifest="tests/runners/headless_gui_required_tests.txt"
failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    fail "missing file: $path"
  fi
}

require_text() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq -- "$needle" "$path"; then
    fail "$path is missing: $needle"
  fi
}

require_file "$manifest"
require_file "tests/runners/headless_common.sh"
require_file "tests/runners/run_all_tests_headless.sh"
require_file "tests/runners/run_tests_by_category.sh"

while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue

  if [[ "$line" != res://* ]]; then
    fail "manifest entry must use res:// path: $line"
    continue
  fi

  path="${line#res://}"
  require_file "$path"
done < "$manifest"

require_text "tests/runners/headless_common.sh" "MODUS_INCLUDE_GUI_REQUIRED"
require_text "tests/runners/headless_common.sh" "-gtest="
require_text "tests/runners/headless_common.sh" "-gconfig="
require_text "tests/runners/run_all_tests_headless.sh" "modus_collect_gut_tests tests/unit tests/integration tests/property"
require_text "tests/runners/run_tests_by_category.sh" "run_test_category \"Integration\" tests/integration"
require_text "tests/runners/run_tests_by_category.sh" "--report PATH"
require_text "tests/runners/run_tests_by_category.sh" "docs/AUTOMATED_TEST_LANES_REPORT.md"

if [[ $failures -gt 0 ]]; then
  printf '\nHeadless runner manifest check failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf 'Headless runner manifest check passed.\n'
