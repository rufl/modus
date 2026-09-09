#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/tests/runners/headless_common.sh"
if [[ $# -gt 1 ]]; then
  printf 'Usage: bash %s [export-preset-name]\n' "$0" >&2
  exit 2
fi
godot_bin="$(modus_find_godot_bin)"
preset="${1:-Windows Desktop}"
runtime="$(mktemp -d "${TMPDIR:-/tmp}/modus-export-notices.XXXXXX")"
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/data" "$runtime/cache" "$runtime/config" "$runtime/run"
chmod 700 "$runtime/run"
# Export resource payloads only: no platform templates or host display/session needed.
env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u XAUTHORITY \
  XDG_DATA_HOME="$runtime/data" XDG_CACHE_HOME="$runtime/cache" \
  XDG_CONFIG_HOME="$runtime/config" XDG_RUNTIME_DIR="$runtime/run" \
  timeout 180 "$godot_bin" --headless --path "$repo_root" \
  --export-pack "$preset" "$runtime/export.zip" > "$runtime/output.log" 2>&1 || {
    cat "$runtime/output.log"
    exit 1
  }
if grep -Eq 'ERROR:|Leaked instance:|ObjectDB instances.*leaked|resources still in use' "$runtime/output.log"; then
  cat "$runtime/output.log"
  printf 'Export reported runtime errors or retained resources.\n' >&2
  exit 1
fi
python3 "$repo_root/tests/runners/test_export_notices.py" "$runtime/export.zip"
printf 'Export notice smoke passed: %s (resource ZIP, not a platform executable).\n' "$preset"
