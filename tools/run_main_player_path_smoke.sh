#!/usr/bin/env bash
set -euo pipefail

report_path="docs/MAIN_PLAYER_PATH_SMOKE.md"
target="main-menu"
duration=20
headless=0
strict=0

usage() {
  cat <<'USAGE'
Usage: tools/run_main_player_path_smoke.sh [--target main-menu|world] [--duration SECONDS] [--headless] [--report PATH] [--strict]

Attempts a short Godot launch smoke for the main player path and writes a
report. This is launch proof only; it does not count as manual gameplay proof.

Options:
  --target main-menu|world  Launch the project main scene or game/scenes/world.tscn.
  --duration SECONDS        Seconds to keep Godot alive before timeout. Default: 20.
  --headless                Add --headless to the Godot command.
  --report PATH             Report output path. Default: docs/MAIN_PLAYER_PATH_SMOKE.md.
  --strict                  Exit nonzero for blocked or failed smoke status.

Environment:
  GODOT_BIN                 Godot executable or absolute path.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target)
      target="${2:-}"
      if [[ "$target" != "main-menu" && "$target" != "world" ]]; then
        printf 'Invalid --target value: %s\n' "$target" >&2
        exit 64
      fi
      shift 2
      ;;
    --duration)
      duration="${2:-}"
      if ! [[ "$duration" =~ ^[0-9]+$ ]] || [[ "$duration" -lt 1 ]]; then
        printf 'Invalid --duration value: %s\n' "$duration" >&2
        exit 64
      fi
      shift 2
      ;;
    --headless)
      headless=1
      shift
      ;;
    --report)
      report_path="${2:-}"
      if [[ -z "$report_path" ]]; then
        printf 'Missing value for --report\n' >&2
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

source tests/runners/headless_common.sh

generated_date="$(date +%Y-%m-%d)"
main_scene="shared/ui_core/screens/main_menu_screen.tscn"
world_scene="game/scenes/world.tscn"
manual_checklist="tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md"
manual_timer="tests/manual/manual_test_timer.gd"
log_path="logs/main_player_path_smoke_${target}_${generated_date}.log"

required_files=(
  "project.godot"
  "$main_scene"
  "$world_scene"
  "$manual_checklist"
  "$manual_timer"
)

missing_files=()
for path in "${required_files[@]}"; do
  if [[ ! -e "$path" ]]; then
    missing_files+=("$path")
  fi
done

status="BLOCKED"
status_note=""
launch_command=""
exit_code=""

if [[ "${#missing_files[@]}" -gt 0 ]]; then
  status="BLOCKED"
  status_note="Required files are missing."
elif ! godot_bin="$(modus_find_godot_bin 2>/dev/null)"; then
  status="BLOCKED"
  status_note="Godot executable not found. Install Godot 4.7 or set GODOT_BIN."
else
  command_parts=("$godot_bin")
  if [[ "$headless" -eq 1 ]]; then
    command_parts+=("--headless")
  fi
  command_parts+=("--path" ".")
  if [[ "$target" == "world" ]]; then
    command_parts+=("$world_scene")
  fi
  launch_command="${command_parts[*]}"

  # Keep the launch smoke independent from host-level Godot settings and
  # unwritable user log directories.  This also makes repeated CI/local
  # smoke runs deterministic without touching the developer's real profile.
  smoke_home="${MODUS_SMOKE_HOME:-/tmp/modus_smoke_home}"
  smoke_cache="${MODUS_SMOKE_CACHE:-/tmp/modus_smoke_cache}"
  smoke_config="${MODUS_SMOKE_CONFIG:-/tmp/modus_smoke_config}"
  mkdir -p "$smoke_home" "$smoke_cache" "$smoke_config"

  mkdir -p "$(dirname "$log_path")"
  set +e
  env HOME="$smoke_home" XDG_CACHE_HOME="$smoke_cache" XDG_CONFIG_HOME="$smoke_config" \
    timeout "${duration}"s "${command_parts[@]}" > "$log_path" 2>&1
  exit_code=$?
  set -e

  if [[ "$exit_code" -eq 124 ]]; then
    status="PASS"
    status_note="Godot stayed alive for ${duration}s and was stopped by timeout."
  elif [[ "$exit_code" -eq 0 ]]; then
    status="PASS"
    status_note="Godot exited cleanly before the ${duration}s timeout."
  else
    status="FAIL"
    status_note="Godot exited with code ${exit_code}; see ${log_path}."
  fi
fi

mkdir -p "$(dirname "$report_path")"
{
  printf '# MODUS Main Player Path Smoke Report\n\n'
  printf '**Generated:** %s\n' "$generated_date"
  printf '**Overall Status:** %s\n' "$status"
  printf '**Target:** %s\n' "$target"
  printf '**Duration:** %ss\n' "$duration"
  printf '**Headless:** %s\n\n' "$([[ "$headless" -eq 1 ]] && printf 'yes' || printf 'no')"

  printf '## Scope\n\n'
  printf 'This report records launch-path smoke evidence only. Passing this smoke does not prove movement, weapons, HUD, multiplayer, performance, or manual gameplay quality.\n\n'

  printf '## Launch Command\n\n'
  if [[ -n "$launch_command" ]]; then
    printf '`%s`\n\n' "$launch_command"
  elif [[ "$target" == "world" ]]; then
    printf '`godot --path . %s`\n\n' "$world_scene"
  else
    printf '`godot --path .`\n\n'
  fi

  printf '## Result\n\n'
  printf '%s\n' "- Status: ${status}"
  printf '%s\n' "- Note: ${status_note}"
  if [[ -n "$exit_code" ]]; then
    printf '%s\n' "- Exit code: ${exit_code}"
    printf '%s\n' "- Log: \`${log_path}\`"
  fi

  printf '\n## Source-Audit Prerequisites\n\n'
  printf '| File | Status |\n'
  printf '| --- | --- |\n'
  for path in "${required_files[@]}"; do
    if [[ -e "$path" ]]; then
      printf '| `%s` | present |\n' "$path"
    else
      printf '| `%s` | missing |\n' "$path"
    fi
  done

  printf '\n## Manual Follow-Up\n\n'
  printf '%s\n' '- Run through `tests/docs/MANUAL_PLAYER_EXPERIENCE_TESTS.md` in a normal Godot session.'
  printf '%s\n' '- Record manual test timing with `tests/manual/manual_test_timer.gd`.'
  printf '%s\n' '- Validate imported manual CSV evidence with `tools/validate_manual_evidence.sh --strict`.'
  printf '%s\n' '- Update `docs/CURRENT_STATUS.md` only after observed gameplay evidence is recorded.'
} > "$report_path"

printf 'Main player path smoke report written to %s\n' "$report_path"
printf 'Overall status: %s\n' "$status"

if [[ "$strict" -eq 1 && "$status" != "PASS" ]]; then
  if [[ "$status" == "BLOCKED" ]]; then
    exit 127
  fi
  exit 1
fi
