#!/usr/bin/env bash
set -euo pipefail

report_path="docs/PRODUCTION_READINESS_REPORT.md"
main_smoke_report="docs/MAIN_PLAYER_PATH_SMOKE.md"
automated_lanes_report="docs/AUTOMATED_TEST_LANES_REPORT.md"
manual_evidence_report="docs/MANUAL_EVIDENCE_REPORT.md"
performance_evidence_report="docs/PERFORMANCE_EVIDENCE_REPORT.md"
release_readiness_report="docs/RELEASE_READINESS_REPORT.md"
strict=0
run_godot_tests=0

checks=()
commands=()
notes=()

usage() {
  cat <<'USAGE'
Usage: tools/validate_production_readiness.sh [--report PATH] [--run-godot-tests] [--strict]

Generates a conservative production-readiness report. By default the script
exits 0 after writing the report, even when MODUS is not production ready.
Use --strict to return 1 when readiness blockers remain.

Options:
  --report PATH        Report output path. Default: docs/PRODUCTION_READINESS_REPORT.md
  --run-godot-tests    Run ./tests/runners/run_all_tests_headless.sh if Godot is available.
  --strict             Exit nonzero when production-readiness blockers remain.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report)
      report_path="${2:-}"
      if [[ -z "$report_path" ]]; then
        printf 'Missing value for --report\n' >&2
        exit 64
      fi
      shift 2
      ;;
    --run-godot-tests)
      run_godot_tests=1
      shift
      ;;
    --strict)
      strict=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 64
      ;;
  esac
done

add_check() {
  local status="$1"
  local name="$2"
  local command="$3"
  local note="$4"

  checks+=("${status}|${name}")
  commands+=("$command")
  notes+=("$note")
}

compact() {
  local text
  text="$(tr '\n' ' ' | sed 's/  */ /g' | sed 's/|/-/g')"
  if [[ "${#text}" -gt 600 ]]; then
    printf '%s...' "${text:0:600}"
  else
    printf '%s' "$text"
  fi
}

extract_report_status() {
  local path="$1"
  local line
  local status

  line="$(grep -E '^\*\*Overall Status:\*\* ' "$path" | head -n 1 || true)"
  status="${line#\*\*Overall Status:\*\* }"
  if [[ -z "$line" || "$status" == "$line" ]]; then
    printf 'UNKNOWN'
  else
    printf '%s' "$status"
  fi
}

print_markdown_section_body() {
  local path="$1"
  local start="$2"
  local end="$3"

  awk -v start="$start" -v end="$end" '
    $0 == start { printing = 1; next }
    $0 == end { printing = 0 }
    printing { print }
  ' "$path"
}

run_required_check() {
  local name="$1"
  shift
  local output

  if output="$("$@" 2>&1)"; then
    add_check "PASS" "$name" "$*" "$(printf '%s' "$output" | compact)"
  else
    add_check "FAIL" "$name" "$*" "$(printf '%s' "$output" | compact)"
  fi
}

run_godot_suite_check() {
  local exit_code=0
  local raw_log_path="${MODUS_GODOT_SUITE_LOG_PATH:-logs/full_godot_gut_latest.log}"
  local log_path="${raw_log_path}.gz"
  local summary
  local timeout_seconds="${MODUS_GODOT_SUITE_TIMEOUT_SECONDS:-2400}"
  local timeout_note=""

  if [[ ! "$timeout_seconds" =~ ^[1-9][0-9]*$ ]]; then
    add_check "FAIL" "Filtered Godot/GUT suite" \
      "./tests/runners/run_all_tests_headless.sh" \
      "MODUS_GODOT_SUITE_TIMEOUT_SECONDS must be a positive integer; got '${timeout_seconds}'."
    return
  fi

  mkdir -p "$(dirname "$raw_log_path")"
  timeout --kill-after=15s "${timeout_seconds}s" \
    ./tests/runners/run_all_tests_headless.sh > "$raw_log_path" 2>&1 || exit_code=$?
  summary="$(
    {
      sed -E $'s/\\x1B\\[[0-9;]*[[:alpha:]]//g' "$raw_log_path" \
        | grep -E '^(Scripts|Tests|Passing Tests|Failing Tests|Risky/Pending|Asserts|Orphans|Time)[[:space:]]' \
        || true
    } \
      | tail -n 8 \
      | compact
  )"
  if [[ -z "$summary" ]]; then
    summary="No complete GUT summary was emitted."
    if [[ "$exit_code" -eq 0 ]]; then
      exit_code=65
    fi
  fi
  if [[ "$exit_code" -eq 124 ]]; then
    timeout_note=" Timed out after ${timeout_seconds} seconds."
  fi
  gzip -f "$raw_log_path"

  if [[ "$exit_code" -eq 0 ]]; then
    add_check "PASS" "Filtered Godot/GUT suite" \
      "timeout ${timeout_seconds}s ./tests/runners/run_all_tests_headless.sh" \
      "${summary} Full log: \`${log_path}\`."
  else
    add_check "FAIL" "Filtered Godot/GUT suite" \
      "timeout ${timeout_seconds}s ./tests/runners/run_all_tests_headless.sh" \
      "${summary}${timeout_note} Full log: \`${log_path}\`. Exit code: ${exit_code}."
  fi
}

reuse_retained_godot_suite_check() {
  local raw_log_path="${MODUS_GODOT_SUITE_LOG_PATH:-logs/full_godot_gut_latest.log}"
  local log_path="${raw_log_path}.gz"
  local summary
  local failing_count

  if [[ ! -f "$log_path" ]]; then
    return 1
  fi

  summary="$(
    {
      gzip -cd -- "$log_path" \
        | sed -E $'s/\\x1B\\[[0-9;]*[[:alpha:]]//g' \
        | grep -E '^(Scripts|Tests|Passing Tests|Failing Tests|Risky/Pending|Asserts|Orphans|Time)[[:space:]]' \
        || true
    } \
      | tail -n 8 \
      | compact
  )"
  if [[ -z "$summary" || "$summary" != *"Tests "* || "$summary" != *"Passing Tests "* || "$summary" != *"Time "* ]]; then
    return 1
  fi

  failing_count="$(
    gzip -cd -- "$log_path" \
      | sed -E $'s/\\x1B\\[[0-9;]*[[:alpha:]]//g' \
      | awk '$1 == "Failing" && $2 == "Tests" { value = $3 } END { print value }'
  )"

  if [[ "$failing_count" =~ ^[1-9][0-9]*$ ]]; then
    add_check "FAIL" "Filtered Godot/GUT suite" \
      "retained ${log_path}" \
      "${summary} Full log: \`${log_path}\`. Complete retained summary; rerun with --run-godot-tests to replace it."
  elif gzip -cd -- "$log_path" | awk 'index($0, "---- All tests passed! ----") { found = 1 } END { exit !found }'; then
    add_check "PASS" "Filtered Godot/GUT suite" \
      "retained ${log_path}" \
      "${summary} Full log: \`${log_path}\`. Complete retained summary; rerun with --run-godot-tests to replace it."
  else
    return 1
  fi
}

find_godot_bin() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    if [[ -x "$GODOT_BIN" ]]; then
      printf '%s\n' "$GODOT_BIN"
      return 0
    fi
    if command -v "$GODOT_BIN" >/dev/null 2>&1; then
      command -v "$GODOT_BIN"
      return 0
    fi
    return 1
  fi

  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return 0
  fi

  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return 0
  fi

  return 1
}

count_tests() {
  local dirs=("$@")
  find "${dirs[@]}" -type f -name 'test_*.gd' | wc -l | tr -d ' '
}

count_manifest_entries() {
  grep -Ev '^[[:space:]]*(#|$)' tests/runners/headless_gui_required_tests.txt | wc -l | tr -d ' '
}

readiness_blockers=0
godot_suite_status=""
report_date="$(date +%Y-%m-%d)"

run_required_check "Project-control truth check" bash tools/check_project_truth.sh
run_required_check "Headless runner manifest check" bash tools/check_headless_runner_manifest.sh
run_required_check "Headless common shell syntax" bash -n tests/runners/headless_common.sh
run_required_check "Headless full-run shell syntax" bash -n tests/runners/run_all_tests_headless.sh
run_required_check "Headless batched-run shell syntax" bash -n tests/runners/run_tests_by_category.sh

total_selected="$(bash -c 'source tests/runners/headless_common.sh; modus_collect_gut_tests tests/unit tests/integration tests/property; printf "%s/%s" "$MODUS_HEADLESS_INCLUDED_COUNT" "$MODUS_HEADLESS_SKIPPED_COUNT"')"
add_check "PASS" "Headless selection calculation" "source tests/runners/headless_common.sh; modus_collect_gut_tests tests/unit tests/integration tests/property" "Selected/skipped files: ${total_selected}"

total_with_gui="$(bash -c 'source tests/runners/headless_common.sh; MODUS_INCLUDE_GUI_REQUIRED=1; modus_collect_gut_tests tests/unit tests/integration tests/property; printf "%s/%s" "$MODUS_HEADLESS_INCLUDED_COUNT" "$MODUS_HEADLESS_SKIPPED_COUNT"')"
add_check "PASS" "Legacy full selection calculation" "MODUS_INCLUDE_GUI_REQUIRED=1; modus_collect_gut_tests tests/unit tests/integration tests/property" "Selected/skipped files: ${total_with_gui}"

if [[ "$run_godot_tests" -eq 1 ]]; then
  if godot_bin="$(find_godot_bin)"; then
    run_godot_suite_check
    last_check="${checks[$((${#checks[@]} - 1))]%%|*}"
    godot_suite_status="$last_check"
    if [[ "$last_check" != "PASS" ]]; then
      readiness_blockers=$((readiness_blockers + 1))
    fi
  else
    godot_suite_status="BLOCKED"
    add_check "BLOCKED" "Filtered Godot/GUT suite" "./tests/runners/run_all_tests_headless.sh" "Godot executable not found. Install Godot 4.7 or set GODOT_BIN."
    readiness_blockers=$((readiness_blockers + 1))
  fi
elif reuse_retained_godot_suite_check; then
  last_check="${checks[$((${#checks[@]} - 1))]%%|*}"
  godot_suite_status="$last_check"
  if [[ "$last_check" != "PASS" ]]; then
    readiness_blockers=$((readiness_blockers + 1))
  fi
else
  godot_suite_status="BLOCKED"
  add_check "BLOCKED" "Filtered Godot/GUT suite" "./tests/runners/run_all_tests_headless.sh" "No complete retained suite log exists. Run with --run-godot-tests when Godot 4.7 is available."
  readiness_blockers=$((readiness_blockers + 1))
fi

main_smoke_status="MISSING"
if [[ -f "$main_smoke_report" ]]; then
  main_smoke_status="$(extract_report_status "$main_smoke_report")"
fi

case "$main_smoke_status" in
  PASS)
    add_check "PASS" "Main player path smoke" "$main_smoke_report" "Latest report status is PASS."
    ;;
  FAIL)
    add_check "FAIL" "Main player path smoke" "tools/run_main_player_path_smoke.sh --strict" "Latest report status is FAIL."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  BLOCKED)
    add_check "BLOCKED" "Main player path smoke" "tools/run_main_player_path_smoke.sh --strict" "Latest report status is BLOCKED."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  MISSING)
    add_check "BLOCKED" "Main player path smoke" "tools/run_main_player_path_smoke.sh --strict" "No main player path smoke report exists."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  *)
    add_check "BLOCKED" "Main player path smoke" "tools/run_main_player_path_smoke.sh --strict" "Latest report status could not be read: ${main_smoke_status}."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
esac

automated_lanes_status="MISSING"
if [[ -f "$automated_lanes_report" ]]; then
  automated_lanes_status="$(extract_report_status "$automated_lanes_report")"
  add_check "PASS" "Automated lane report" "$automated_lanes_report" "Latest report status is ${automated_lanes_status}; this triage report does not replace the full-suite readiness gate."
else
  add_check "BLOCKED" "Automated lane report" "tests/runners/run_tests_by_category.sh --report ${automated_lanes_report}" "No automated lane report exists."
fi

manual_evidence_status="MISSING"
if [[ -f "$manual_evidence_report" ]]; then
  manual_evidence_status="$(extract_report_status "$manual_evidence_report")"
fi

case "$manual_evidence_status" in
  PASS)
    if grep -Fq "Manual Testing Hours | 0" docs/CURRENT_STATUS.md || grep -Fq "Manual testing: 0 hours" README.md; then
      add_check "BLOCKED" "Manual gameplay validation" "$manual_evidence_report + docs source audit" "Manual evidence is PASS, but current docs still record 0 manual testing hours."
      readiness_blockers=$((readiness_blockers + 1))
    else
      add_check "PASS" "Manual gameplay validation" "$manual_evidence_report" "Manual evidence report status is PASS."
    fi
    ;;
  FAIL)
    add_check "FAIL" "Manual gameplay validation" "tools/validate_manual_evidence.sh --strict" "Manual evidence report status is FAIL."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  BLOCKED)
    add_check "BLOCKED" "Manual gameplay validation" "tools/validate_manual_evidence.sh --strict" "Manual evidence report status is BLOCKED."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  MISSING)
    add_check "BLOCKED" "Manual gameplay validation" "tools/validate_manual_evidence.sh --strict" "No manual evidence report exists."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  *)
    add_check "BLOCKED" "Manual gameplay validation" "tools/validate_manual_evidence.sh --strict" "Manual evidence report status could not be read: ${manual_evidence_status}."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
esac

performance_evidence_status="MISSING"
if [[ -f "$performance_evidence_report" ]]; then
  performance_evidence_status="$(extract_report_status "$performance_evidence_report")"
fi

case "$performance_evidence_status" in
  PASS)
    if grep -Fq "ZERO benchmarks" docs/CURRENT_STATUS.md || grep -Fq "ZERO performance benchmarks" README.md; then
      add_check "BLOCKED" "Performance benchmark validation" "$performance_evidence_report + docs source audit" "Performance evidence is PASS, but current docs still record zero benchmarks."
      readiness_blockers=$((readiness_blockers + 1))
    else
      add_check "PASS" "Performance benchmark validation" "$performance_evidence_report" "Performance evidence report status is PASS."
    fi
    ;;
  FAIL)
    add_check "FAIL" "Performance benchmark validation" "tools/validate_performance_evidence.sh --strict" "Performance evidence report status is FAIL."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  BLOCKED)
    add_check "BLOCKED" "Performance benchmark validation" "tools/validate_performance_evidence.sh --strict" "Performance evidence report status is BLOCKED."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  MISSING)
    add_check "BLOCKED" "Performance benchmark validation" "tools/validate_performance_evidence.sh --strict" "No performance evidence report exists."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  *)
    add_check "BLOCKED" "Performance benchmark validation" "tools/validate_performance_evidence.sh --strict" "Performance evidence report status could not be read: ${performance_evidence_status}."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
esac

release_readiness_status="MISSING"
if [[ -f "$release_readiness_report" ]]; then
  release_readiness_status="$(extract_report_status "$release_readiness_report")"
fi

case "$release_readiness_status" in
  PASS)
    add_check "PASS" "Release-version readiness" "$release_readiness_report" "Release readiness report status is PASS."
    ;;
  FAIL)
    add_check "FAIL" "Release-version readiness" "tools/validate_release_readiness.sh --strict" "Release readiness report status is FAIL."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  BLOCKED)
    add_check "BLOCKED" "Release-version readiness" "tools/validate_release_readiness.sh --strict" "Release readiness report status is BLOCKED."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  MISSING)
    add_check "BLOCKED" "Release-version readiness" "tools/validate_release_readiness.sh --strict" "No release readiness report exists."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
  *)
    add_check "BLOCKED" "Release-version readiness" "tools/validate_release_readiness.sh --strict" "Release readiness report status could not be read: ${release_readiness_status}."
    readiness_blockers=$((readiness_blockers + 1))
    ;;
esac

unit_count="$(count_tests tests/unit)"
integration_count="$(count_tests tests/integration)"
property_count="$(count_tests tests/property)"
manifest_count="$(count_manifest_entries)"

if [[ "$readiness_blockers" -eq 0 ]]; then
  readiness_status="READY"
else
  readiness_status="NOT READY"
fi

mkdir -p "$(dirname "$report_path")"

{
  printf '# MODUS Production Readiness Report\n\n'
  printf '**Generated:** %s\n' "$report_date"
  printf '**Overall Status:** %s\n' "$readiness_status"
  printf '**Readiness Blockers:** %d\n\n' "$readiness_blockers"

  printf '## Scope\n\n'
  printf 'This report is a conservative technical source-audit and local-tooling validation. It does not count as runtime, manual gameplay, multiplayer, rendering, or performance proof unless those checks are explicitly run and recorded. Its blocker count covers only the gates below; it is not legal or distribution clearance, and `docs/ATTRIBUTION.md` currently records unresolved third-party provenance.\n\n'

  printf '## Test Inventory\n\n'
  printf '| Category | Count |\n'
  printf '| --- | ---: |\n'
  printf '| Unit test files | %s |\n' "$unit_count"
  printf '| Integration test files | %s |\n' "$integration_count"
  printf '| Property test files | %s |\n' "$property_count"
  printf '| GUI-required manifest entries | %s |\n\n' "$manifest_count"

  printf '## Latest Automated Lane Triage\n\n'
  if [[ -f "$automated_lanes_report" ]]; then
    printf 'Latest report: `%s` with status `%s`. This lane report provides category evidence without replacing the official production-readiness gate: the full filtered Godot/GUT suite must still pass.\n\n' "$automated_lanes_report" "$automated_lanes_status"
    print_markdown_section_body "$automated_lanes_report" "## Lane Summary" "## Triage Notes"
    printf '\n'
    printf '### Triage Notes\n\n'
    print_markdown_section_body "$automated_lanes_report" "## Triage Notes" "## Durable Failure Lanes"
    printf '\n'
  else
    printf 'No automated lane report exists yet. Run `tests/runners/run_tests_by_category.sh --report %s` to generate it.\n\n' "$automated_lanes_report"
  fi

  printf '## Validation Results\n\n'
  printf '| Status | Check | Command / Evidence | Notes |\n'
  printf '| --- | --- | --- | --- |\n'
  for i in "${!checks[@]}"; do
    status="${checks[$i]%%|*}"
    name="${checks[$i]#*|}"
    printf '| %s | %s | `%s` | %s |\n' "$status" "$name" "${commands[$i]}" "${notes[$i]}"
  done

  printf '\n## Required Follow-Up\n\n'
  if [[ "$readiness_blockers" -eq 0 ]]; then
    printf '%s\n' '- No readiness blockers were detected by this validator.'
  else
    if [[ "$godot_suite_status" == "FAIL" ]]; then
      printf '%s\n' '- Triage the failing Godot/GUT suite, then rerun `tools/validate_production_readiness.sh --run-godot-tests --strict`.'
    elif [[ "$run_godot_tests" -eq 0 ]]; then
      if find_godot_bin >/dev/null 2>&1; then
        printf '%s\n' '- Run `tools/validate_production_readiness.sh --run-godot-tests --strict` to refresh full Godot/GUT proof.'
      else
        printf '%s\n' '- Install Godot 4.7 or set `GODOT_BIN`, then run `tools/validate_production_readiness.sh --run-godot-tests --strict`.'
      fi
    fi
    if [[ "$main_smoke_status" != "PASS" ]]; then
      printf '%s\n' '- Run `tools/run_main_player_path_smoke.sh --strict` and record a PASS result.'
    fi
    if [[ "$manual_evidence_status" != "PASS" ]]; then
      printf '%s\n' '- Run `tools/validate_manual_evidence.sh --strict` after recording ManualTestTimer CSV evidence.'
    fi
    if [[ "$performance_evidence_status" != "PASS" ]]; then
      printf '%s\n' '- Run `tools/validate_performance_evidence.sh --strict` after recording PerformanceLogger CSV evidence.'
    fi
    if [[ "$release_readiness_status" != "PASS" ]]; then
      printf '%s\n' '- Run `tools/validate_release_readiness.sh --strict` only after release-version source truth is ready.'
    fi
  fi
  printf '%s\n' '- Complete the third-party provenance/license ledger in `docs/ATTRIBUTION.md`; this release-clearance gap is outside the validator blocker count.'
} > "$report_path"

printf 'Production readiness report written to %s\n' "$report_path"
printf 'Overall status: %s (%d blocker(s))\n' "$readiness_status" "$readiness_blockers"

if [[ "$strict" -eq 1 && "$readiness_blockers" -gt 0 ]]; then
  exit 1
fi
