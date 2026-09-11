#!/usr/bin/env bash
set -euo pipefail

source tests/runners/headless_common.sh

tester=""
input_devices=""
session=""
renderer="gl_compatibility"
resolution="1280x720"
evidence_dir="logs/manual_test_logs"
telemetry_dir="logs/validation_telemetry"

usage() {
  cat <<'USAGE'
Usage: tools/run_manual_showcase_session.sh --tester NAME --input DEVICES [options]

Launches the normal MODUS main-menu route with an F8 manual-evidence recorder.
The recorder writes reviewed CSV rows directly into the configured evidence directory.
It does not generate passes or replace human observation.

Required:
  --tester NAME         Human tester or reviewer identity.
  --input DEVICES       Devices used, for example "keyboard_mouse,gamepad_xbox".

Options:
  --session NAME        Evidence filename/session name. Default: timestamped showcase session.
  --renderer METHOD     gl_compatibility, mobile, or forward_plus.
  --resolution WxH      Window resolution. Default: 1280x720.
  --evidence-dir DIR    CSV destination. Default: logs/manual_test_logs.
  --telemetry-dir DIR  JSONL telemetry destination. Default: logs/validation_telemetry.

Environment:
  GODOT_BIN             Godot 4.7 executable or absolute path.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tester)
      tester="${2:-}"
      shift 2
      ;;
    --input)
      input_devices="${2:-}"
      shift 2
      ;;
    --session)
      session="${2:-}"
      shift 2
      ;;
    --renderer)
      renderer="${2:-}"
      shift 2
      ;;
    --resolution)
      resolution="${2:-}"
      shift 2
      ;;
    --evidence-dir)
      evidence_dir="${2:-}"
      shift 2
      ;;
    --telemetry-dir)
      telemetry_dir="${2:-}"
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

[[ -n "$tester" ]] || { printf 'Missing required --tester NAME.\n' >&2; exit 64; }
[[ -n "$input_devices" ]] || { printf 'Missing required --input DEVICES.\n' >&2; exit 64; }
[[ "$renderer" =~ ^(gl_compatibility|mobile|forward_plus)$ ]] || {
  printf 'Invalid --renderer value: %s\n' "$renderer" >&2
  exit 64
}
[[ "$resolution" =~ ^[0-9]+x[0-9]+$ ]] || {
  printf 'Invalid --resolution value: %s\n' "$resolution" >&2
  exit 64
}
[[ -n "$telemetry_dir" ]] || { printf 'Invalid --telemetry-dir value.\n' >&2; exit 64; }

if [[ "$(uname -s)" == "Linux" && -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
  printf 'A normal graphical display is required for manual evidence.\n' >&2
  exit 127
fi

godot_bin="$(modus_find_godot_bin)"
if [[ ! -f .godot/global_script_class_cache.cfg ]]; then
  modus_import_project "$godot_bin"
fi
mkdir -p "$evidence_dir" "$telemetry_dir"
evidence_dir="$(realpath "$evidence_dir")"
telemetry_dir="$(realpath "$telemetry_dir")"
if [[ -z "$session" ]]; then
  session="showcase_manual_$(date +%Y%m%d_%H%M%S)"
fi

commit="$(git rev-parse --short HEAD 2>/dev/null || printf unknown)"
dirty=""
if [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]; then
  dirty="-dirty"
fi
build_identity="0.9.5-beta+${commit}${dirty}"

printf 'Launching manual evidence session: %s\n' "$session"
printf 'CSV destination: %s\n' "$evidence_dir"
printf 'Telemetry destination: %s\n' "$telemetry_dir"
printf 'Press F8 or Gamepad Back to switch between gameplay and result recording.\n'
env \
  MODUS_LOCAL_TELEMETRY=1 \
  MODUS_LOCAL_TELEMETRY_DIR="$telemetry_dir" \
  MODUS_MANUAL_TESTER="$tester" \
  MODUS_MANUAL_INPUTS="$input_devices" \
  MODUS_MANUAL_SESSION="$session" \
  MODUS_MANUAL_BUILD="$build_identity" \
  MODUS_MANUAL_EVIDENCE_DIR="$evidence_dir" \
  "$godot_bin" --path . --resolution "$resolution" --rendering-method "$renderer" \
  --script tests/manual/manual_showcase_session.gd
