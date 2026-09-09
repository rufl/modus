#!/usr/bin/env bash
set -euo pipefail

logs_dir="${MODUS_MANUAL_EVIDENCE_DIR:-logs/manual_test_logs}"
report_path="docs/MANUAL_EVIDENCE_REPORT.md"
min_hours="40"
strict=0

usage() {
  cat <<'USAGE'
Usage: tools/validate_manual_evidence.sh [--logs DIR] [--report PATH] [--min-hours HOURS] [--strict]

Validates imported ManualTestTimer CSV logs and writes a manual evidence report.
This proves recorded manual evidence only; it does not execute gameplay.

Options:
  --logs DIR          Directory containing ManualTestTimer CSV logs. Default: logs/manual_test_logs
  --report PATH       Report output path. Default: docs/MANUAL_EVIDENCE_REPORT.md
  --min-hours HOURS   Minimum logged manual testing hours for PASS. Default: 40
  --strict            Exit nonzero for blocked or failed evidence status.

Environment:
  MODUS_MANUAL_EVIDENCE_DIR   Override the default logs directory.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --logs)
      logs_dir="${2:-}"
      if [[ -z "$logs_dir" ]]; then
        printf 'Missing value for --logs\n' >&2
        exit 64
      fi
      shift 2
      ;;
    --report)
      report_path="${2:-}"
      if [[ -z "$report_path" ]]; then
        printf 'Missing value for --report\n' >&2
        exit 64
      fi
      shift 2
      ;;
    --min-hours)
      min_hours="${2:-}"
      if ! [[ "$min_hours" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf 'Invalid --min-hours value: %s\n' "$min_hours" >&2
        exit 64
      fi
      shift 2
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

generated_date="$(date +%Y-%m-%d)"
manual_checklist="tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md"
manual_timing_doc="tests/docs/MANUAL_TEST_TIMING.md"
manual_timer="tests/manual/manual_test_timer.gd"
manual_overlay="tests/manual/manual_evidence_overlay.tscn"
manual_overlay_script="tests/manual/manual_evidence_overlay.gd"
manual_session_script="tests/manual/manual_showcase_session.gd"
manual_runner="tools/run_manual_showcase_session.sh"

required_files=(
  "$manual_checklist"
  "$manual_timing_doc"
  "$manual_timer"
  "$manual_overlay"
  "$manual_overlay_script"
  "$manual_session_script"
  "$manual_runner"
)

missing_files=()
for path in "${required_files[@]}"; do
  if [[ ! -e "$path" ]]; then
    missing_files+=("$path")
  fi
done

csv_files=()
if [[ -d "$logs_dir" ]]; then
  while IFS= read -r path; do
    csv_files+=("$path")
  done < <(find "$logs_dir" -type f -name '*.csv' | sort)
fi

total_session_duration="0"
validated_duration="0"
total_tests=0
passed=0
failed=0
skipped=0
incomplete=0
malformed=0
missing_metadata=0

add_float() {
  awk -v left="$1" -v right="$2" 'BEGIN { printf "%.2f", left + right }'
}

to_hours() {
  awk -v seconds="$1" 'BEGIN { printf "%.2f", seconds / 3600.0 }'
}

is_below_min_hours() {
  awk -v seconds="$1" -v hours="$2" 'BEGIN { exit !((seconds / 3600.0) < hours) }'
}

for file in "${csv_files[@]}"; do
  header="$(head -n 1 "$file" 2>/dev/null || true)"
  if [[ "$header" != "Timestamp,TestName,Duration,Result,Notes" ]]; then
    malformed=$((malformed + 1))
    continue
  fi

  file_test_duration="$(awk -F, '
    BEGIN { session_duration = -1; summary_test_time = -1 }
    /^# Session Summary/ { in_summary = 1; next }
    in_summary {
      if ($1 == "total_duration" && $2 ~ /^[0-9]+([.][0-9]+)?$/) session_duration = $2
      else if ($1 == "total_test_time" && $2 ~ /^[0-9]+([.][0-9]+)?$/) summary_test_time = $2
      else if ($1 ~ /^metadata_(tester|os|renderer|resolution|input_devices|scene|build_identity)$/ && length($2) > 0) metadata[$1] = 1
      next
    }
    NR == 1 || NF == 0 { next }
    NF < 4 { bad += 1; next }
    $3 !~ /^[0-9]+([.][0-9]+)?$/ { bad += 1; next }
    {
      sum += $3
      tests += 1
      if ($4 == "pass") passed += 1
      else if ($4 == "fail") failed += 1
      else if ($4 == "skip") skipped += 1
      else incomplete += 1
      if (($4 == "fail" || $4 == "skip") && length($5) == 0) bad += 1
    }
    END {
      printf "%.2f %d %d %d %d %d %d %.2f %.2f %d\n", sum, tests, passed, failed, skipped, incomplete, bad, session_duration, summary_test_time, length(metadata)
    }
  ' "$file")"

  read -r duration tests file_passed file_failed file_skipped file_incomplete file_bad session_duration summary_test_time metadata_count <<< "$file_test_duration"

  if awk -v value="$session_duration" 'BEGIN { exit !(value >= 0) }'; then
    total_session_duration="$(add_float "$total_session_duration" "$session_duration")"
  else
    total_session_duration="$(add_float "$total_session_duration" "$duration")"
    file_bad=$((file_bad + 1))
  fi
  validated_duration="$(add_float "$validated_duration" "$duration")"

  if ! awk -v rows="$duration" -v summary="$summary_test_time" 'BEGIN { delta = rows - summary; if (delta < 0) delta = -delta; exit !(summary >= 0 && delta <= 0.25) }'; then
    file_bad=$((file_bad + 1))
  fi
  if [[ "$metadata_count" -lt 7 ]]; then
    missing_metadata=$((missing_metadata + 7 - metadata_count))
  fi

  total_tests=$((total_tests + tests))
  passed=$((passed + file_passed))
  failed=$((failed + file_failed))
  skipped=$((skipped + file_skipped))
  incomplete=$((incomplete + file_incomplete))
  malformed=$((malformed + file_bad))
done

total_hours="$(to_hours "$validated_duration")"
session_hours="$(to_hours "$total_session_duration")"
status="BLOCKED"
status_note=""

if [[ "${#missing_files[@]}" -gt 0 ]]; then
  status="FAIL"
  status_note="Required manual evidence source files are missing."
elif [[ ! -d "$logs_dir" ]]; then
  status="BLOCKED"
  status_note="Manual evidence log directory does not exist."
elif [[ "${#csv_files[@]}" -eq 0 ]]; then
  status="BLOCKED"
  status_note="No ManualTestTimer CSV logs were found."
elif [[ "$malformed" -gt 0 ]]; then
  status="FAIL"
  status_note="One or more manual evidence logs are malformed."
elif [[ "$missing_metadata" -gt 0 ]]; then
  status="FAIL"
  status_note="One or more manual evidence logs are missing required session metadata."
elif [[ "$total_tests" -eq 0 ]]; then
  status="BLOCKED"
  status_note="Manual evidence logs contain no completed test rows."
elif [[ "$failed" -gt 0 ]]; then
  status="FAIL"
  status_note="Manual evidence logs contain failed test rows."
elif [[ "$incomplete" -gt 0 ]]; then
  status="FAIL"
  status_note="Manual evidence logs contain incomplete or unknown test results."
elif is_below_min_hours "$validated_duration" "$min_hours"; then
  status="BLOCKED"
  status_note="Logged manual testing hours are below the required threshold."
else
  status="PASS"
  status_note="Manual evidence logs meet the configured threshold and contain no failures."
fi

mkdir -p "$(dirname "$report_path")"
{
  printf '# MODUS Manual Evidence Report\n\n'
  printf '**Generated:** %s\n' "$generated_date"
  printf '**Overall Status:** %s\n' "$status"
  printf '**Logs Directory:** `%s`\n' "$logs_dir"
  printf '**Configured Minimum Hours:** %s\n\n' "$min_hours"

  printf '## Scope\n\n'
  printf 'This report validates imported `ManualTestTimer` CSV logs. It does not execute the game and does not replace direct runtime observation notes.\n\n'

  printf '## Result\n\n'
  printf '%s\n' "- Status: ${status}"
  printf '%s\n' "- Note: ${status_note}"
  printf '%s\n' "- CSV files scanned: ${#csv_files[@]}"
  printf '%s\n' "- Validated test hours: ${total_hours}"
  printf '%s\n' "- Validated test seconds: ${validated_duration}"
  printf '%s\n' "- Total session hours including recorder overhead: ${session_hours}"
  printf '%s\n' "- Total tests: ${total_tests}"
  printf '%s\n' "- Passed: ${passed}"
  printf '%s\n' "- Failed: ${failed}"
  printf '%s\n' "- Skipped: ${skipped}"
  printf '%s\n' "- Incomplete/other: ${incomplete}"
  printf '%s\n' "- Malformed rows/files: ${malformed}"
  printf '%s\n\n' "- Missing required metadata fields: ${missing_metadata}"

  printf '## Source-Audit Prerequisites\n\n'
  printf '| File | Status |\n'
  printf '| --- | --- |\n'
  for path in "${required_files[@]}"; do
    if [[ -e "$path" ]]; then
      printf '| `%s` | present |\n' "$path"
    else
      printf '| `%s` | missing |\n' "$path"
    fi
  done

  printf '\n## Evidence Files\n\n'
  if [[ "${#csv_files[@]}" -eq 0 ]]; then
    printf '%s\n' '- No evidence files found.'
  else
    for path in "${csv_files[@]}"; do
      printf '%s\n' "- \`${path}\`"
    done
  fi

  printf '\n## Follow-Up\n\n'
  printf '%s\n' '- Run `tools/run_manual_showcase_session.sh --tester NAME --input DEVICES` in a normal graphical session.'
  printf '%s\n' '- Review every row honestly; FAIL and SKIP require notes, and recorder overhead does not count toward the threshold.'
  printf '%s\n' '- Update `docs/CURRENT_STATUS.md` only after this report shows PASS and gameplay observations have been reviewed.'
} > "$report_path"

printf 'Manual evidence report written to %s\n' "$report_path"
printf 'Overall status: %s\n' "$status"

if [[ "$strict" -eq 1 && "$status" != "PASS" ]]; then
  if [[ "$status" == "BLOCKED" ]]; then
    exit 127
  fi
  exit 1
fi
