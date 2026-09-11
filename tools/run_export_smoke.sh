#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: tools/run_export_smoke.sh --platform PLATFORM --executable PATH [--log PATH]

Launches a native export without a display for a bounded interval. Linux exports
are executed; Windows exports are reported as unsupported on the Linux runner.
USAGE
}

platform=""
executable=""
log_path=""
timeout_seconds="${MODUS_EXPORT_SMOKE_TIMEOUT_SECONDS:-20}"
quit_after_frames="${MODUS_EXPORT_SMOKE_QUIT_AFTER_FRAMES:-10}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      platform="${2:-}"
      [[ -n "$platform" ]] || { printf 'Missing value for --platform\n' >&2; exit 64; }
      shift 2
      ;;
    --executable)
      executable="${2:-}"
      [[ -n "$executable" ]] || { printf 'Missing value for --executable\n' >&2; exit 64; }
      shift 2
      ;;
    --log)
      log_path="${2:-}"
      [[ -n "$log_path" ]] || { printf 'Missing value for --log\n' >&2; exit 64; }
      shift 2
      ;;
    --timeout-seconds)
      timeout_seconds="${2:-}"
      [[ -n "$timeout_seconds" ]] || { printf 'Missing value for --timeout-seconds\n' >&2; exit 64; }
      shift 2
      ;;
    --quit-after-frames)
      quit_after_frames="${2:-}"
      [[ -n "$quit_after_frames" ]] || { printf 'Missing value for --quit-after-frames\n' >&2; exit 64; }
      shift 2
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

if [[ -z "$platform" || -z "$executable" ]]; then
  printf 'Both --platform and --executable are required.\n\n' >&2
  usage >&2
  exit 64
fi

case "$platform" in
  linux)
    ;;
  windows|editor)
    printf 'SKIP: %s export cannot be launched on the Linux runner; artifact and export validation still ran.\n' "$platform"
    exit 0
    ;;
  *)
    printf 'Unsupported export platform: %s\n' "$platform" >&2
    exit 64
    ;;
esac

if [[ ! -s "$executable" ]]; then
  printf 'FAIL: export is missing or empty: %s\n' "$executable" >&2
  exit 1
fi
if [[ ! -x "$executable" ]]; then
  printf 'FAIL: Linux export is not executable: %s\n' "$executable" >&2
  exit 1
fi

if [[ -z "$log_path" ]]; then
  log_path="${executable}.launch.log"
fi
mkdir -p "$(dirname "$log_path")"

runtime_root="$(mktemp -d "${TMPDIR:-/tmp}/modus-export-smoke.XXXXXX")"
trap 'rm -rf "$runtime_root"' EXIT
mkdir -p "$runtime_root/home" "$runtime_root/data" "$runtime_root/cache" "$runtime_root/config"

set +e
HOME="$runtime_root/home" \
XDG_DATA_HOME="$runtime_root/data" \
XDG_CACHE_HOME="$runtime_root/cache" \
XDG_CONFIG_HOME="$runtime_root/config" \
  timeout --foreground --kill-after=5s "${timeout_seconds}s" \
  "$executable" --headless --rendering-method gl_compatibility \
  --rendering-driver opengl3 --quit-after "$quit_after_frames" >"$log_path" 2>&1
exit_code=$?
set -e

if grep -Eiq 'SCRIPT ERROR|Parse Error|ERROR:|FATAL|CRASH|Segmentation fault|Aborted|Failed to load|Could not load' "$log_path"; then
  printf 'FAIL: %s export emitted runtime, script, or parse errors. Log: %s\n' "$platform" "$log_path" >&2
  cat "$log_path" >&2
  exit 1
fi

if [[ "$exit_code" -ne 0 ]]; then
  if [[ "$exit_code" -eq 124 || "$exit_code" -eq 137 ]]; then
    printf 'FAIL: %s export exceeded the bounded %ss headless smoke timeout. Log: %s\n' \
      "$platform" "$timeout_seconds" "$log_path" >&2
  else
    printf 'FAIL: %s export exited with code %s during headless launch. Log: %s\n' \
      "$platform" "$exit_code" "$log_path" >&2
  fi
  cat "$log_path" >&2
  exit 1
fi

printf 'PASS: %s export launched and exited cleanly in headless mode. Log: %s\n' \
  "$platform" "$log_path"
