#!/usr/bin/env bash
set -euo pipefail

# Usage: GODOT_SOURCE_DIR=/tmp/modus-godot-source-ed1daf0bf bash tools/godot/build.sh [--prepare-only]
# Requires Git, Python >= 3.9 with venv/pip, a C++17 compiler, pkg-config and
# wayland-scanner. All upstream audio drivers and codecs remain enabled.
# The source tree, Python environment, SDK and binary stay outside MODUS.
revision="ed1daf0bf001b61586d9930840f2f1394092c079"
release="4.7.2-stable"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source_dir="${GODOT_SOURCE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/modus/godot-$revision}"
venv_dir="${GODOT_BUILD_VENV:-$source_dir-build-venv}"
patch_file="$script_dir/audio-server-shutdown.patch"
jobs="${GODOT_BUILD_JOBS:-2}"
prepare_only=false
if [[ $# -eq 1 && "$1" == "--prepare-only" ]]; then
  prepare_only=true
elif [[ $# -ne 0 ]]; then
  printf 'Usage: bash %s [--prepare-only]\n' "$0" >&2
  exit 2
fi
if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
  printf 'GODOT_BUILD_JOBS must be a positive integer.\n' >&2
  exit 2
fi

if [[ ! -e "$source_dir" ]]; then
  mkdir -p -- "$(dirname -- "$source_dir")"
  git clone --depth 1 --branch "$release" https://github.com/godotengine/godot.git "$source_dir"
fi
if [[ "$(git -C "$source_dir" rev-parse HEAD)" != "$revision" ]]; then
  printf 'Refusing source tree not pinned to %s.\n' "$revision" >&2
  exit 2
fi
# Do not reset user changes. An exact already-applied patch permits incremental builds.
if git -C "$source_dir" diff --quiet HEAD --; then
  git -C "$source_dir" apply --check "$patch_file"
  git -C "$source_dir" apply "$patch_file"
elif ! cmp -s <(git -C "$source_dir" diff --no-color --no-ext-diff --binary --full-index HEAD --) "$patch_file"; then
  printf 'Refusing source changes other than audio-server-shutdown.patch.\n' >&2
  exit 2
fi
if [[ -n "$(git -C "$source_dir" ls-files --others --exclude-standard)" ]]; then
  printf 'Refusing untracked source files; use a dedicated engine checkout.\n' >&2
  exit 2
fi
if "$prepare_only"; then
  printf 'Prepared patched Godot source: %s\n' "$source_dir"
  exit 0
fi

python3 -m venv "$venv_dir"
"$venv_dir/bin/python" -m pip install --require-hashes -r "$script_dir/requirements.txt"
cd -- "$source_dir"
# Use the SDK version selected by the pinned upstream installer (0.22.3).
# Fix its destination independent of host LOCALAPPDATA configuration.
if [[ ! -f bin/build_deps/accesskit/lib/linux/x86_64/static/libaccesskit.a ]]; then
  env -u LOCALAPPDATA "$venv_dir/bin/python" misc/scripts/install_accesskit.py
fi
"$venv_dir/bin/scons" -j "$jobs" platform=linuxbsd arch=x86_64 target=editor \
  use_llvm=no lto=none debug_symbols=no extra_suffix=modus_audio_shutdown \
  accesskit_sdk_path="$source_dir/bin/build_deps/accesskit"
printf 'Patched engine: %s/bin/godot.linuxbsd.editor.x86_64.modus_audio_shutdown\n' "$source_dir"
