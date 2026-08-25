#!/usr/bin/env bash
set -euo pipefail

report_path="docs/GOLDEN_DEMO_SMOKE.md"
strict=0
headless=0
record_video=1

usage() {
  cat <<'USAGE'
Usage: tools/run_showcase_golden_demo_smoke.sh [--headless] [--no-video] [--report PATH] [--strict]

Runs the maintained showcase scene through an automated framework-loop smoke:
player spawn, movement input, weapon fire, enemy defeat, pickup collection,
save/load restoration, and bundled sample-mod loading.

This is automated runtime proof, not manual gameplay or release approval.

Environment:
  GODOT_BIN  Godot 4.7 executable or absolute path.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --headless)
      headless=1
      record_video=0
      shift
      ;;
    --no-video)
      record_video=0
      shift
      ;;
    --report)
      report_path="${2:-}"
      [[ -n "$report_path" ]] || { printf 'Missing value for --report\n' >&2; exit 64; }
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

source tests/runners/headless_common.sh

date_stamp="$(date +%Y-%m-%d)"
json_path="logs/showcase_golden_demo_${date_stamp}.json"
log_path="logs/showcase_golden_demo_${date_stamp}.log"
capture_path="docs/media/release/golden_demo_smoke_1280x720.png"
video_path="docs/media/release/golden_demo_smoke_1280x720.mp4"
runtime_data="/tmp/modus_golden_data"
runtime_cache="/tmp/modus_golden_cache"
runtime_config="/tmp/modus_golden_config"

mkdir -p logs docs/media/release "$(dirname "$report_path")"
rm -f "$json_path" "$capture_path"
if [[ "$record_video" -eq 1 ]]; then
  rm -f "$video_path"
fi
rm -rf "$runtime_data" "$runtime_cache" "$runtime_config"
mkdir -p "$runtime_data" "$runtime_cache" "$runtime_config"
trap 'rm -rf "$runtime_data" "$runtime_cache" "$runtime_config"' EXIT

status="BLOCKED"
note=""
launch_code=127

if ! godot_bin="$(modus_find_godot_bin 2>/dev/null)"; then
  note="Godot 4.7 executable not found. Install it or set GODOT_BIN."
elif [[ ! -f tools/showcase_golden_demo_smoke.gd ]]; then
  note="Golden-demo smoke script is missing."
else
  if [[ ! -f .godot/global_script_class_cache.cfg ]]; then
    MODUS_GODOT_DATA="$runtime_data" MODUS_GODOT_CACHE="$runtime_cache" \
      MODUS_GODOT_CONFIG="$runtime_config" modus_import_project "$godot_bin"
  fi

  command=(
    "$godot_bin"
    --path .
    --resolution 1280x720
    --rendering-method gl_compatibility
    --rendering-driver opengl3
    --audio-driver Dummy
    --script tools/showcase_golden_demo_smoke.gd
  )

  set +e
  if [[ "$headless" -eq 1 ]]; then
    env XDG_DATA_HOME="$runtime_data" XDG_CACHE_HOME="$runtime_cache" \
      XDG_CONFIG_HOME="$runtime_config" MODUS_GOLDEN_SMOKE_JSON="$json_path" \
      "${command[@]}" --headless >"$log_path" 2>&1
    launch_code=$?
  elif ! command -v xvfb-run >/dev/null 2>&1; then
    note="xvfb-run is required for the player-visible smoke; use --headless for diagnostic scope."
    launch_code=127
  elif [[ "$record_video" -eq 1 ]] && ! command -v ffmpeg >/dev/null 2>&1; then
    note="ffmpeg is required for the requested smoke video; use --no-video to skip recording."
    launch_code=127
  else
    xvfb-run -a -s "-screen 0 1280x720x24" bash -c '
      set -u
      godot_bin="$1"; json_path="$2"; log_path="$3"; capture_path="$4"; video_path="$5"
      runtime_data="$6"; runtime_cache="$7"; runtime_config="$8"; record_video="$9"
      shift 9
      ffmpeg_pid=""
      if [[ "$record_video" -eq 1 ]]; then
        ffmpeg -y -loglevel error -f x11grab -framerate 20 -video_size 1280x720 \
          -i "$DISPLAY" -c:v libx264 -preset veryfast -crf 28 -pix_fmt yuv420p \
          "$video_path" &
        ffmpeg_pid=$!
        sleep 0.5
      fi
      env XDG_DATA_HOME="$runtime_data" XDG_CACHE_HOME="$runtime_cache" \
        XDG_CONFIG_HOME="$runtime_config" MODUS_GOLDEN_SMOKE_JSON="$json_path" \
        MODUS_GOLDEN_SMOKE_CAPTURE="$capture_path" \
        "$godot_bin" --path . --resolution 1280x720 --position 0,0 \
        --rendering-method gl_compatibility --rendering-driver opengl3 \
        --audio-driver Dummy --script tools/showcase_golden_demo_smoke.gd \
        >"$log_path" 2>&1
      code=$?
      if [[ -n "$ffmpeg_pid" ]]; then
        kill -INT "$ffmpeg_pid" 2>/dev/null || true
        wait "$ffmpeg_pid" 2>/dev/null || true
      fi
      exit "$code"
    ' _ "$godot_bin" "$json_path" "$log_path" "$capture_path" "$video_path" \
      "$runtime_data" "$runtime_cache" "$runtime_config" "$record_video"
    launch_code=$?
  fi
  set -e

  if [[ -f "$json_path" ]]; then
    status="$(python3 - "$json_path" <<'PY'
import json, sys
print(json.load(open(sys.argv[1], encoding="utf-8")).get("status", "FAIL"))
PY
)"
    note="Godot exited with code ${launch_code}; see ${log_path}."
    if [[ "$status" == "PASS" ]] && grep -Eq 'SCRIPT ERROR:|Parse Error:' "$log_path"; then
      status="FAIL"
      note="Framework steps passed, but the runtime log contains script errors; see ${log_path}."
    fi
  elif [[ -z "$note" ]]; then
    status="FAIL"
    note="Godot exited with code ${launch_code} before writing the result JSON; see ${log_path}."
  fi
fi

python3 - "$report_path" "$json_path" "$status" "$note" "$log_path" "$capture_path" "$video_path" <<'PY'
import hashlib
import json
import pathlib
import sys
from datetime import date

report, result_path, status, note, log_path, capture_path, video_path = sys.argv[1:]
result = {"steps": []}
if pathlib.Path(result_path).exists():
    result = json.load(open(result_path, encoding="utf-8"))

def artifact(path):
    p = pathlib.Path(path)
    if not p.exists() or p.stat().st_size == 0:
        return "missing", "-"
    return f"{p.stat().st_size} bytes", hashlib.sha256(p.read_bytes()).hexdigest()

capture_size, capture_hash = artifact(capture_path)
video_size, video_hash = artifact(video_path)
lines = [
    "# MODUS Golden Demo Smoke",
    "",
    f"**Generated:** {date.today().isoformat()}",
    f"**Overall Status:** {status}",
    "**Boundary:** automated visible runtime smoke; not manual gameplay, multiplayer, performance, or release approval",
    "",
    "## Framework Loop",
    "",
    "| Step | Status | Observation |",
    "| --- | --- | --- |",
]
for step in result.get("steps", []):
    lines.append(f"| `{step.get('step', 'unknown')}` | **{step.get('status', 'FAIL')}** | {step.get('note', '')} |")
if not result.get("steps"):
    lines.append(f"| `launch` | **{status}** | {note} |")
lines += [
    "",
    "## Retained Artifacts",
    "",
    "| Artifact | Size | SHA-256 | Scope |",
    "| --- | ---: | --- | --- |",
    f"| `{result_path}` | {artifact(result_path)[0]} | `{artifact(result_path)[1]}` | Machine-readable step results |",
    f"| `{log_path}` | {artifact(log_path)[0]} | `{artifact(log_path)[1]}` | Godot runtime log |",
    f"| `{capture_path}` | {capture_size} | `{capture_hash}` | Final visible PASS/FAIL overlay at 1280×720 |",
    f"| `{video_path}` | {video_size} | `{video_hash}` | Automated smoke recording; not reviewed manual gameplay |",
    "",
    "## Approval Boundary",
    "",
    "A PASS proves that one controlled local run loaded the maintained showcase, spawned a player, accepted movement input, fired a weapon, defeated an enemy, collected a pickup, restored an encrypted save slot, and loaded the bundled SDK sample mod. It does not prove gameplay feel, long-session stability, real peers, Steam, manual hours, packaging, provenance clearance, or release approval.",
    "",
]
pathlib.Path(report).write_text("\n".join(lines), encoding="utf-8")
PY

printf 'Golden demo smoke report written to %s\n' "$report_path"
printf 'Overall status: %s\n' "$status"

if [[ "$strict" -eq 1 && "$status" != "PASS" ]]; then
  [[ "$status" == "BLOCKED" ]] && exit 127
  exit 1
fi
