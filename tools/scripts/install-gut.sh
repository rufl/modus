#!/usr/bin/env bash
# Install the CI-pinned GUT release from the project root.
set -euo pipefail

if [[ ! -f project.godot ]]; then
    printf 'Error: Run this script from the project root.\n' >&2
    exit 1
fi

gut_version="9.7.1"
work_dir=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/modus-gut.XXXXXX")
trap 'rm -rf -- "$work_dir"' EXIT

curl --fail --location --output "$work_dir/gut.tar.gz" \
    "https://github.com/bitwes/Gut/archive/refs/tags/v${gut_version}.tar.gz"
tar -xzf "$work_dir/gut.tar.gz" -C "$work_dir" --strip-components=1
# Check the extracted dependency before replacing any existing installation.
test -s "$work_dir/addons/gut/gut_cmdln.gd"
test -s "$work_dir/addons/gut/LICENSE.md"

# GUT 9.7.1 includes this unused legacy scene with a Resource assigned as its
# script and a metadata path to a missing gut_loader_the_scene.gd. No GUT caller
# references it; remove the orphan rather than export an invalid scene.
rm -- "$work_dir/addons/gut/gut_loader_the_scene.tscn"

mkdir -p addons
# Replace the bundle so repeats neither nest gut/gut nor retain older files.
rm -rf -- addons/gut
cp -a "$work_dir/addons/gut" addons/gut
test -s addons/gut/gut_cmdln.gd
test -s addons/gut/LICENSE.md
