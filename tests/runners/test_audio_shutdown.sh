#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$repo_root/tests/runners/headless_common.sh"
godot_bin="$(modus_find_godot_bin)"
runtime="$(mktemp -d "${TMPDIR:-/tmp}/modus-audio-shutdown.XXXXXX")"
trap 'rm -rf -- "$runtime"' EXIT
mkdir -p "$runtime/data" "$runtime/cache" "$runtime/config" "$runtime/run"
chmod 700 "$runtime/run"
printf '[application]\nconfig/name="Audio shutdown regression"\n' > "$runtime/project.godot"
# No MODUS autoloads, imported scenes, or host display/session sockets.
env -u DISPLAY -u WAYLAND_DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u XAUTHORITY \
  XDG_DATA_HOME="$runtime/data" XDG_CACHE_HOME="$runtime/cache" \
  XDG_CONFIG_HOME="$runtime/config" XDG_RUNTIME_DIR="$runtime/run" \
  timeout 30 "$godot_bin" --headless --verbose --path "$runtime" \
  --script "$repo_root/tests/engine/audio_shutdown.gd" -- \
  "$repo_root/game/art/audio/music/Imago.mp3" > "$runtime/output.log" 2>&1 || {
    cat "$runtime/output.log"
    exit 1
  }
cat "$runtime/output.log"
grep -Fq 'MP3_SHUTDOWN_SMOKE_READY' "$runtime/output.log"
if grep -Eq 'ERROR:|Leaked instance:|ObjectDB instances.*leaked|resources still in use' "$runtime/output.log"; then
  printf 'Audio shutdown regression failed. Use the patched engine from tools/godot/build.sh.\n' >&2
  exit 1
fi
printf 'Audio shutdown regression passed.\n'
