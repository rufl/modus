#!/usr/bin/env bash
set -euo pipefail

source tests/runners/headless_common.sh

report_path="docs/ENET_LOCAL_HOST_JOIN_SMOKE.md"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
status="BLOCKED"
note="Smoke did not start."
port="-"
server_exit="not run"
client_exit="not run"
server_pid=""
client_pid=""
cleanup_done=0
owns_run_dir=0

run_dir="${MODUS_ENET_SMOKE_RUN_DIR:-}"
if [[ -z "$run_dir" ]]; then
  run_dir="$(mktemp -d "${TMPDIR:-/tmp}/modus_enet_smoke.XXXXXX")"
  owns_run_dir=1
else
  mkdir -p "$run_dir"
fi

smoke_home="${MODUS_ENET_SMOKE_HOME:-$run_dir/home}"
smoke_cache="${MODUS_ENET_SMOKE_CACHE:-$run_dir/cache}"
smoke_config="${MODUS_ENET_SMOKE_CONFIG:-$run_dir/config}"
log_dir="${MODUS_ENET_SMOKE_LOG_DIR:-$run_dir/logs}"
server_log="$log_dir/server.log"
client_log="$log_dir/client.log"
mkdir -p "$smoke_home" "$smoke_cache" "$smoke_config" "$log_dir"

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
  stop_process "$client_pid"
  stop_process "$server_pid"
  if [[ "$owns_run_dir" -eq 1 ]]; then
    rm -rf -- "$run_dir"
  fi
}

on_signal() {
  local signal="$1"
  status="FAIL"
  note="Smoke interrupted by ${signal}; child processes were terminated."
  stop_process "$client_pid"
  stop_process "$server_pid"
  client_pid=""
  server_pid=""
  client_exit="interrupted"
  server_exit="interrupted"
  write_report
  exit 128
}

trap cleanup EXIT
trap 'on_signal SIGINT' INT
trap 'on_signal SIGTERM' TERM
trap 'on_signal SIGHUP' HUP

write_report() {
  mkdir -p "$(dirname "$report_path")"
  cat >"$report_path" <<EOF
# MODUS ENet Local Host/Join Smoke

**Generated:** $(date +%Y-%m-%d)
**Started:** $started_at
**Status:** $status
**Port:** $port

## Result

$note

The harness starts separate Godot server and client processes and proves only a
real localhost ENet connection. It does not verify gameplay or synchronization.

| Probe | Exit |
| --- | ---: |
| Server | $server_exit |
| Client | $client_exit |

Logs are disposable and are not retained by the repository cleanup workflow.
EOF
}

if ! godot_bin="$(modus_find_godot_bin 2>/dev/null)"; then
  note="Godot 4.7 executable not found. Install it or set GODOT_BIN."
elif ! command -v timeout >/dev/null 2>&1; then
  note="The timeout utility is unavailable; the smoke cannot safely manage child processes."
elif [[ -n "${MODUS_ENET_SMOKE_PORT:-}" ]]; then
  port="$MODUS_ENET_SMOKE_PORT"
  if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
    status="FAIL"
    note="MODUS_ENET_SMOKE_PORT must be an integer from 1 through 65535."
  fi
else
  if ! port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()' 2>/dev/null)"; then
    port="-"
    note="The environment denied ephemeral localhost port selection."
  fi
fi

if [[ "$status" == "BLOCKED" && "$port" != "-" && -n "$port" ]]; then
  probe_timeout="${MODUS_ENET_SMOKE_TIMEOUT:-8}"
  if ! [[ "$probe_timeout" =~ ^[0-9]+$ ]] || [[ "$probe_timeout" -lt 1 ]]; then
    status="FAIL"
    note="MODUS_ENET_SMOKE_TIMEOUT must be a positive integer number of seconds."
  else
    set +e
    timeout --kill-after=2s "${probe_timeout}s" \
      env HOME="$smoke_home" XDG_CACHE_HOME="$smoke_cache" XDG_CONFIG_HOME="$smoke_config" \
      "$godot_bin" --headless --path . --script res://tools/enet_loopback_probe.gd -- server "$port" \
      >"$server_log" 2>&1 &
    server_pid=$!
    sleep 0.5
    if kill -0 "$server_pid" 2>/dev/null; then
      timeout --kill-after=2s "${probe_timeout}s" \
        env HOME="$smoke_home" XDG_CACHE_HOME="$smoke_cache" XDG_CONFIG_HOME="$smoke_config" \
        "$godot_bin" --headless --path . --script res://tools/enet_loopback_probe.gd -- client "$port" \
        >"$client_log" 2>&1 &
      client_pid=$!
      if wait "$client_pid"; then
        client_exit=0
      else
        client_exit=$?
      fi
      client_pid=""
    else
      client_exit="not run"
    fi

    if [[ -n "$server_pid" ]]; then
      if wait "$server_pid"; then
        server_exit=0
      else
        server_exit=$?
      fi
      server_pid=""
    fi
    set -e

    if [[ "$client_exit" == "0" ]] &&
      rg -q "ENET_CLIENT_CONNECTED" "$client_log" 2>/dev/null &&
      [[ "$server_exit" == "0" ]] &&
      rg -q "ENET_SERVER_PEER_CONNECTED" "$server_log" 2>/dev/null; then
      status="PASS"
      note="Separate Godot server and client connected over localhost ENet."
    elif rg -q "ERR_CANT_CREATE|ERR_UNCONFIGURED|_sock == -1|socket|address already in use|permission denied" \
      "$server_log" "$client_log" 2>/dev/null; then
      status="BLOCKED"
      note="The environment denied localhost socket creation or binding."
    elif [[ "$client_exit" == "124" || "$client_exit" == "137" ||
      "$server_exit" == "124" || "$server_exit" == "137" ]]; then
      status="FAIL"
      note="Server or client probe timed out before a successful connection."
    else
      status="FAIL"
      note="Server/client probe failed before observing a successful connection."
    fi
  fi
fi

write_report

case "$status" in
  PASS)
    printf 'PASS: ENet local host/join smoke passed.\n'
    exit 0
    ;;
  BLOCKED)
    printf 'BLOCKED: ENet local host/join smoke was blocked by the environment. See %s.\n' "$report_path" >&2
    exit 127
    ;;
  *)
    printf 'FAIL: ENet local host/join smoke failed. See %s.\n' "$report_path" >&2
    exit 1
    ;;
esac
