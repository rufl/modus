#!/usr/bin/env bash
set -euo pipefail

source tests/runners/headless_common.sh

godot_bin="$(modus_find_godot_bin 2>/dev/null || true)"
if [[ -z "$godot_bin" ]]; then
  printf 'BLOCKED: Godot 4.7 executable not found.\n' >&2
  exit 2
fi

smoke_home="${MODUS_MULTIPLAYER_SMOKE_HOME:-/tmp/modus_multiplayer_profile_home}"
smoke_cache="${MODUS_MULTIPLAYER_SMOKE_CACHE:-/tmp/modus_multiplayer_profile_cache}"
smoke_config="${MODUS_MULTIPLAYER_SMOKE_CONFIG:-/tmp/modus_multiplayer_profile_config}"
log_path="${MODUS_MULTIPLAYER_SMOKE_LOG:-/tmp/modus_multiplayer_profile_smoke.log}"
mkdir -p "$smoke_home" "$smoke_cache" "$smoke_config"

set +e
HOME="$smoke_home" XDG_CACHE_HOME="$smoke_cache" XDG_CONFIG_HOME="$smoke_config" \
  MODUS_FEATURE_PROFILE=multiplayer_demo \
  "$godot_bin" --headless --path . --quit-after 3 >"$log_path" 2>&1
exit_code=$?
set -e

if rg -n "SCRIPT ERROR|Parse Error|service lookup failed|unknown feature|Active profile .* not found" "$log_path" >/dev/null; then
  printf 'FAIL: multiplayer_demo launch emitted profile/service errors. Log: %s\n' "$log_path" >&2
  exit 1
fi

if [[ "$exit_code" -ne 0 && "$exit_code" -ne 124 ]]; then
  printf 'FAIL: multiplayer_demo launch exited with %s. Log: %s\n' "$exit_code" "$log_path" >&2
  exit 1
fi

printf 'PASS: multiplayer_demo profile launch completed without profile/service errors.\n'
