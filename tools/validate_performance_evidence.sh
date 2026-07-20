#!/usr/bin/env bash
set -euo pipefail

logs_dir="${MODUS_PERFORMANCE_EVIDENCE_DIR:-logs/performance_logs}"
report_path="docs/PERFORMANCE_EVIDENCE_REPORT.md"
min_duration_seconds="60"
strict=0

usage() {
  cat <<'USAGE'
Usage: tools/validate_performance_evidence.sh [--logs DIR] [--report PATH] [--min-duration-seconds SECONDS] [--strict]

Validates imported PerformanceLogger CSV logs and writes a performance evidence
report. This proves recorded benchmark evidence only; it does not run Godot or
measure performance itself.

Options:
  --logs DIR                    Directory containing PerformanceLogger CSV logs. Default: logs/performance_logs
  --report PATH                 Report output path. Default: docs/PERFORMANCE_EVIDENCE_REPORT.md
  --min-duration-seconds SECONDS
                                Minimum aggregate logged benchmark duration for PASS. Default: 60
  --strict                      Exit nonzero for blocked or failed evidence status.

Environment:
  MODUS_PERFORMANCE_EVIDENCE_DIR  Override the default logs directory.
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
    --min-duration-seconds)
      min_duration_seconds="${2:-}"
      if ! [[ "$min_duration_seconds" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        printf 'Invalid --min-duration-seconds value: %s\n' "$min_duration_seconds" >&2
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
performance_logger="tests/manual/performance_logger.gd"
performance_benchmarks="tests/benchmarks/test_performance_benchmarks.gd"
performance_guide="docs/guides/performance_optimization.md"

required_files=(
  "$performance_logger"
  "$performance_benchmarks"
  "$performance_guide"
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

total_samples=0
total_duration="0"
weighted_fps_sum="0"
min_fps=""
max_fps=""
max_frame_time="0"
max_memory="0"
malformed=0

add_float() {
  awk -v left="$1" -v right="$2" 'BEGIN { printf "%.2f", left + right }'
}

is_less_than() {
  awk -v left="$1" -v right="$2" 'BEGIN { exit !(left < right) }'
}

for file in "${csv_files[@]}"; do
  header="$(head -n 1 "$file" 2>/dev/null || true)"
  if [[ "$header" != "Time,FPS,FrameTime,Memory,ActivePools,VisibleEnemies" ]]; then
    malformed=$((malformed + 1))
    continue
  fi

  parsed="$(awk -F, '
    /^# Statistics/ { in_stats = 1; next }
    in_stats {
      if ($1 == "duration" && $2 ~ /^[0-9]+([.][0-9]+)?$/) stats_duration = $2
      next
    }
    NR == 1 || NF == 0 { next }
    NF < 6 { bad += 1; next }
    $1 !~ /^[0-9]+([.][0-9]+)?$/ ||
    $2 !~ /^[0-9]+([.][0-9]+)?$/ ||
    $3 !~ /^[0-9]+([.][0-9]+)?$/ ||
    $4 !~ /^[0-9]+([.][0-9]+)?$/ ||
    $5 !~ /^[0-9]+$/ ||
    $6 !~ /^[0-9]+$/ { bad += 1; next }
    {
      samples += 1
      fps_sum += $2
      if (min_fps == "" || $2 < min_fps) min_fps = $2
      if (max_fps == "" || $2 > max_fps) max_fps = $2
      if ($3 > max_frame_time) max_frame_time = $3
      if ($4 > max_memory) max_memory = $4
      if ($1 > last_time) last_time = $1
    }
    END {
      duration = stats_duration
      if (duration == "") duration = last_time
      if (min_fps == "") min_fps = 0
      if (max_fps == "") max_fps = 0
      printf "%.2f %d %.2f %.2f %.2f %.2f %.2f %d\n", duration, samples, fps_sum, min_fps, max_fps, max_frame_time, max_memory, bad
    }
  ' "$file")"

  read -r file_duration file_samples file_fps_sum file_min_fps file_max_fps file_max_frame_time file_max_memory file_bad <<< "$parsed"

  total_duration="$(add_float "$total_duration" "$file_duration")"
  total_samples=$((total_samples + file_samples))
  weighted_fps_sum="$(add_float "$weighted_fps_sum" "$file_fps_sum")"
  malformed=$((malformed + file_bad))

  if [[ "$file_samples" -gt 0 ]]; then
    if [[ -z "$min_fps" ]] || is_less_than "$file_min_fps" "$min_fps"; then
      min_fps="$file_min_fps"
    fi
    if [[ -z "$max_fps" ]] || is_less_than "$max_fps" "$file_max_fps"; then
      max_fps="$file_max_fps"
    fi
    if is_less_than "$max_frame_time" "$file_max_frame_time"; then
      max_frame_time="$file_max_frame_time"
    fi
    if is_less_than "$max_memory" "$file_max_memory"; then
      max_memory="$file_max_memory"
    fi
  fi
done

avg_fps="0.00"
if [[ "$total_samples" -gt 0 ]]; then
  avg_fps="$(awk -v sum="$weighted_fps_sum" -v samples="$total_samples" 'BEGIN { printf "%.2f", sum / samples }')"
fi
if [[ -z "$min_fps" ]]; then
  min_fps="0.00"
fi
if [[ -z "$max_fps" ]]; then
  max_fps="0.00"
fi

status="BLOCKED"
status_note=""

if [[ "${#missing_files[@]}" -gt 0 ]]; then
  status="FAIL"
  status_note="Required performance evidence source files are missing."
elif [[ ! -d "$logs_dir" ]]; then
  status="BLOCKED"
  status_note="Performance evidence log directory does not exist."
elif [[ "${#csv_files[@]}" -eq 0 ]]; then
  status="BLOCKED"
  status_note="No PerformanceLogger CSV logs were found."
elif [[ "$malformed" -gt 0 ]]; then
  status="FAIL"
  status_note="One or more performance evidence logs are malformed."
elif [[ "$total_samples" -eq 0 ]]; then
  status="BLOCKED"
  status_note="Performance evidence logs contain no sample rows."
elif is_less_than "$total_duration" "$min_duration_seconds"; then
  status="BLOCKED"
  status_note="Logged benchmark duration is below the required threshold."
else
  status="PASS"
  status_note="Performance evidence logs meet the configured duration threshold."
fi

mkdir -p "$(dirname "$report_path")"
{
  printf '# MODUS Performance Evidence Report\n\n'
  printf '**Generated:** %s\n' "$generated_date"
  printf '**Overall Status:** %s\n' "$status"
  printf '**Logs Directory:** `%s`\n' "$logs_dir"
  printf '**Minimum Duration Required:** %ss\n\n' "$min_duration_seconds"

  printf '## Scope\n\n'
  printf 'This report validates imported `PerformanceLogger` CSV logs. It records measured benchmark evidence but does not run Godot, exercise gameplay, or prove performance quality by itself.\n\n'

  printf '## Result\n\n'
  printf '%s\n' "- Status: ${status}"
  printf '%s\n' "- Note: ${status_note}"
  printf '%s\n' "- CSV files scanned: ${#csv_files[@]}"
  printf '%s\n' "- Total duration: ${total_duration}s"
  printf '%s\n' "- Total samples: ${total_samples}"
  printf '%s\n' "- Average FPS: ${avg_fps}"
  printf '%s\n' "- Minimum FPS: ${min_fps}"
  printf '%s\n' "- Maximum FPS: ${max_fps}"
  printf '%s\n' "- Maximum frame time: ${max_frame_time}ms"
  printf '%s\n' "- Maximum memory: ${max_memory}MB"
  printf '%s\n\n' "- Malformed rows/files: ${malformed}"

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
  printf '%s\n' '- Run benchmark sessions with `tests/manual/performance_logger.gd` enabled.'
  printf '%s\n' '- Keep the exported CSV logs under the configured evidence directory before rerunning this validator.'
  printf '%s\n' '- Update performance claims only after this report shows PASS and the measured context has been reviewed.'
} > "$report_path"

printf 'Performance evidence report written to %s\n' "$report_path"
printf 'Overall status: %s\n' "$status"

if [[ "$strict" -eq 1 && "$status" != "PASS" ]]; then
  if [[ "$status" == "BLOCKED" ]]; then
    exit 127
  fi
  exit 1
fi
