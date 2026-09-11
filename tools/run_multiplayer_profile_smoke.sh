#!/usr/bin/env bash
set -euo pipefail

source tests/runners/headless_common.sh

status="BLOCKED"
note="Smoke did not start."
exit_code="not run"
child_pid=""
cleanup_done=0
owns_run_dir=0

run_dir="${MODUS_MULTIPLAYER_SMOKE_RUN_DIR:-}"
if [[ -z "$run_dir" ]]; then
  run_dir="$(mktemp -d "${TMPDIR:-/tmp}/modus_multiplayer_profile.XXXXXX")"
  owns_run_dir=1
else
  mkdir -p "$run_dir"
fi

smoke_home="${MODUS_MULTIPLAYER_SMOKE_HOME:-$run_dir/home}"
smoke_cache="${MODUS_MULTIPLAYER_SMOKE_CACHE:-$run_dir/cache}"
smoke_config="${MODUS_MULTIPLAYER_SMOKE_CONFIG:-$run_dir/config}"
log_path="${MODUS_MULTIPLAYER_SMOKE_LOG:-$run_dir/multiplayer_profile_smoke.log}"
mkdir -p "$smoke_home" "$smoke_cache" "$smoke_config" "$(dirname "$log_path")"

stop_process() {
  local pid="$1"
  [[ -n "$pid" ]] || return 0
  if kill -0 "$pid" 2>/dev/null; then
    kill -TERM "$pid" 2>/dev/null || true
    for _ in {1..20}; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$pid" 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null || true
}

cleanup() {
  [[ "$cleanup_done" -eq 0 ]] || return 0
  cleanup_done=1
  stop_process "$child_pid"
  if [[ "$owns_run_dir" -eq 1 ]]; then
    rm -rf -- "$run_dir"
  fi
}

on_signal() {
  stop_process "$child_pid"
  exit 128
}

trap cleanup EXIT
trap 'on_signal SIGINT' INT
trap 'on_signal SIGTERM' TERM
trap 'on_signal SIGHUP' HUP

if ! godot_bin="$(modus_find_godot_bin 2>/dev/null)"; then
  note="Godot 4.7 executable not found. Install it or set GODOT_BIN."
elif ! command -v timeout >/dev/null 2>&1; then
  note="The timeout utility is unavailable; the smoke cannot safely manage the child process."
else
  probe_timeout="${MODUS_MULTIPLAYER_SMOKE_TIMEOUT:-10}"
  if ! [[ "$probe_timeout" =~ ^[0-9]+$ ]] || [[ "$probe_timeout" -lt 1 ]]; then
    status="FAIL"
    note="MODUS_MULTIPLAYER_SMOKE_TIMEOUT must be a positive integer number of seconds."
  else
    smoke_env=(HOME="$smoke_home" XDG_CACHE_HOME="$smoke_cache" XDG_CONFIG_HOME="$smoke_config")
    if ! env "${smoke_env[@]}" "$godot_bin" --headless --path . --import >/dev/null 2>"$log_path"; then
      status="FAIL"
      note="multiplayer_demo import failed."
    else
      set +e
      env "${smoke_env[@]}" \
        MODUS_FEATURE_PROFILE=multiplayer_demo \
        timeout --kill-after=2s "${probe_timeout}s" \
        "$godot_bin" --headless --path . --quit-after 3 >"$log_path" 2>&1 &
      child_pid=$!
    if wait "$child_pid"; then
      exit_code=0
    else
      exit_code=$?
    fi
    child_pid=""
    set -e

    if rg -n "SCRIPT ERROR|Parse Error|service lookup failed|unknown feature|Active profile .* not found" \
      "$log_path" >/dev/null 2>&1; then
      status="FAIL"
      note="multiplayer_demo launch emitted profile or service errors."
    elif [[ "$exit_code" -eq 0 ]]; then
      status="PASS"
      note="multiplayer_demo profile launched without profile or service errors."
    elif [[ "$exit_code" -eq 124 || "$exit_code" -eq 137 ]]; then
      status="FAIL"
      note="multiplayer_demo launch timed out."
    else
      status="FAIL"
      note="multiplayer_demo launch exited with code $exit_code."
    fi
  fi
fi
fi

case "$status" in
  PASS)
    printf 'PASS: multiplayer_demo profile launch completed without profile/service errors.\n'
    exit 0
    ;;
  BLOCKED)
    printf 'BLOCKED: multiplayer_demo profile smoke was blocked by the environment. Log: %s\n' "$log_path" >&2
    exit 127
    ;;
  *)
    printf 'FAIL: multiplayer_demo profile smoke failed. Log: %s\n' "$log_path" >&2
    exit 1
    ;;
esac
