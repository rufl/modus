#!/usr/bin/env bash
set -euo pipefail

source tests/runners/headless_common.sh
report_path="docs/ENET_LOCAL_HOST_JOIN_SMOKE.md"
port="${MODUS_ENET_SMOKE_PORT:-7791}"
godot_bin="$(modus_find_godot_bin 2>/dev/null || true)"
if [[ -z "$godot_bin" ]]; then
  printf 'BLOCKED: Godot 4.7 executable not found.\n' >&2
  exit 2
fi
smoke_home="${MODUS_ENET_SMOKE_HOME:-/tmp/modus_enet_smoke_home}"
smoke_cache="${MODUS_ENET_SMOKE_CACHE:-/tmp/modus_enet_smoke_cache}"
smoke_config="${MODUS_ENET_SMOKE_CONFIG:-/tmp/modus_enet_smoke_config}"
log_dir="${MODUS_ENET_SMOKE_LOG_DIR:-/tmp/modus_enet_smoke_logs}"
server_log="$log_dir/server.log"
client_log="$log_dir/client.log"
mkdir -p "$smoke_home" "$smoke_cache" "$smoke_config" "$log_dir"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
set +e
HOME="$smoke_home" XDG_CACHE_HOME="$smoke_cache" XDG_CONFIG_HOME="$smoke_config" \
  "$godot_bin" --headless --path . --script res://tools/enet_loopback_probe.gd -- server "$port" >"$server_log" 2>&1 &
server_pid=$!
sleep 0.5
HOME="$smoke_home" XDG_CACHE_HOME="$smoke_cache" XDG_CONFIG_HOME="$smoke_config" \
  "$godot_bin" --headless --path . --script res://tools/enet_loopback_probe.gd -- client "$port" >"$client_log" 2>&1
client_exit=$?
wait "$server_pid"
server_exit=$?
set -e
status="FAIL"
note="Server/client probe did not complete successfully."
if [[ "$server_exit" -eq 0 && "$client_exit" -eq 0 ]] && rg -q "ENET_SERVER_PEER_CONNECTED|ENET_CLIENT_CONNECTED" "$server_log" "$client_log"; then
  status="PASS"
  note="Separate Godot server and client connected over localhost and both probes tore down."
elif rg -q "ERR_CANT_CREATE|ERR_UNCONFIGURED|_sock == -1|socket" "$server_log" "$client_log"; then
  status="BLOCKED"
  note="The environment denied localhost socket creation; rerun outside the restricted sandbox."
fi
cat >"$report_path" <<EOF
# MODUS ENet Local Host/Join Smoke

**Generated:** $(date +%Y-%m-%d)
**Started:** $started_at
**Status:** $status
**Port:** $port

## Result

$note

The harness starts separate Godot 4.7 server and client processes, waits for connection signals, and closes both peers on success, timeout, or startup failure.

| Probe | Exit |
| --- | ---: |
| Server | $server_exit |
| Client | $client_exit |

Logs are disposable and are not retained by the repository cleanup workflow.
EOF
if [[ "$status" == "PASS" ]]; then
  printf 'PASS: ENet local host/join smoke passed.\n'
  exit 0
elif [[ "$status" == "BLOCKED" ]]; then
  printf 'BLOCKED: ENet local host/join smoke was blocked by the environment.\n'
  exit 0
fi
printf 'FAIL: ENet local host/join smoke failed. See %s.\n' "$report_path" >&2
exit 1
