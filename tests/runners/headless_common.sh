#!/usr/bin/env bash

MODUS_HEADLESS_GUI_REQUIRED_MANIFEST="${MODUS_HEADLESS_GUI_REQUIRED_MANIFEST:-tests/runners/headless_gui_required_tests.txt}"
MODUS_INCLUDE_GUI_REQUIRED="${MODUS_INCLUDE_GUI_REQUIRED:-0}"
MODUS_GUT_TEST_ARGS=()
MODUS_HEADLESS_INCLUDED_COUNT=0
MODUS_HEADLESS_SKIPPED_COUNT=0

modus_headless_usage() {
  cat <<'USAGE'
Usage: runner [--include-gui-required]

Environment:
  GODOT_BIN                         Godot executable or absolute path.
  MODUS_INCLUDE_GUI_REQUIRED=1      Include GUI-required tests in the run.
  MODUS_HEADLESS_GUI_REQUIRED_MANIFEST
                                    Override the GUI-required test manifest.
  MODUS_GODOT_DATA / MODUS_GODOT_CACHE / MODUS_GODOT_CONFIG
                                    Override isolated writable Godot runtime directories.
  MODUS_GODOT_RUNTIME                 Override the isolated Godot runtime socket directory.
USAGE
}

# Keep all implicit Godot state under one private directory for this invocation.
# Explicit MODUS_GODOT_* paths remain caller-owned and are never removed.
MODUS_HEADLESS_RUNTIME_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/modus-godot.XXXXXX")"
MODUS_HEADLESS_RUNTIME_DATA="${MODUS_GODOT_DATA:-$MODUS_HEADLESS_RUNTIME_ROOT/data}"
MODUS_HEADLESS_RUNTIME_CACHE="${MODUS_GODOT_CACHE:-$MODUS_HEADLESS_RUNTIME_ROOT/cache}"
MODUS_HEADLESS_RUNTIME_CONFIG="${MODUS_GODOT_CONFIG:-$MODUS_HEADLESS_RUNTIME_ROOT/config}"
MODUS_HEADLESS_RUNTIME="${MODUS_GODOT_RUNTIME:-$MODUS_HEADLESS_RUNTIME_ROOT/runtime}"
mkdir -p "$MODUS_HEADLESS_RUNTIME_DATA" "$MODUS_HEADLESS_RUNTIME_CACHE" \
  "$MODUS_HEADLESS_RUNTIME_CONFIG" "$MODUS_HEADLESS_RUNTIME"
chmod 700 "$MODUS_HEADLESS_RUNTIME"

modus_cleanup_headless_runtime() {
  rm -rf -- "$MODUS_HEADLESS_RUNTIME_ROOT"
}

trap modus_cleanup_headless_runtime EXIT

modus_run_godot() {
  env XDG_DATA_HOME="$MODUS_HEADLESS_RUNTIME_DATA" \
    XDG_CACHE_HOME="$MODUS_HEADLESS_RUNTIME_CACHE" \
    XDG_CONFIG_HOME="$MODUS_HEADLESS_RUNTIME_CONFIG" \
    XDG_RUNTIME_DIR="$MODUS_HEADLESS_RUNTIME" "$@"
}

modus_import_project() {
  local godot_bin="$1"
  modus_run_godot "$godot_bin" --headless --editor --path . --quit \
    >"$MODUS_HEADLESS_RUNTIME_ROOT/import.log" 2>&1
}


modus_parse_headless_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --include-gui-required)
        MODUS_INCLUDE_GUI_REQUIRED=1
        shift
        ;;
      -h|--help)
        modus_headless_usage
        exit 0
        ;;
      *)
        printf 'Unknown argument: %s\n\n' "$1" >&2
        modus_headless_usage >&2
        exit 64
        ;;
    esac
  done
}

modus_find_godot_bin() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    if [[ -x "$GODOT_BIN" ]]; then
      printf '%s\n' "$GODOT_BIN"
      return 0
    fi

    if command -v "$GODOT_BIN" >/dev/null 2>&1; then
      command -v "$GODOT_BIN"
      return 0
    fi

    printf 'Godot executable from GODOT_BIN was not found or is not executable: %s\n' "$GODOT_BIN" >&2
    return 127
  fi

  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return 0
  fi

  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return 0
  fi

  printf 'Godot executable not found. Install Godot 4.7 or set GODOT_BIN=/path/to/godot.\n' >&2
  return 127
}

modus_is_gui_required_test() {
  local res_path="$1"

  if [[ ! -f "$MODUS_HEADLESS_GUI_REQUIRED_MANIFEST" ]]; then
    return 1
  fi

  grep -Fxq "$res_path" "$MODUS_HEADLESS_GUI_REQUIRED_MANIFEST"
}

modus_collect_gut_tests() {
  local dirs=("$@")
  local dir
  local file_path
  local res_path

  MODUS_GUT_TEST_ARGS=(-gconfig= -gprefix=test_ -gsuffix=.gd -gexit)
  MODUS_HEADLESS_INCLUDED_COUNT=0
  MODUS_HEADLESS_SKIPPED_COUNT=0

  for dir in "${dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      printf 'Test directory does not exist: %s\n' "$dir" >&2
      return 1
    fi
  done

  while IFS= read -r file_path; do
    res_path="res://${file_path#./}"

    if [[ "$MODUS_INCLUDE_GUI_REQUIRED" != "1" ]] && modus_is_gui_required_test "$res_path"; then
      MODUS_HEADLESS_SKIPPED_COUNT=$((MODUS_HEADLESS_SKIPPED_COUNT + 1))
      continue
    fi

    MODUS_GUT_TEST_ARGS+=("-gtest=${res_path}")
    MODUS_HEADLESS_INCLUDED_COUNT=$((MODUS_HEADLESS_INCLUDED_COUNT + 1))
  done < <(find "${dirs[@]}" -type f -name 'test_*.gd' | sort)

  if [[ "$MODUS_HEADLESS_INCLUDED_COUNT" -eq 0 ]]; then
    printf 'No headless test files were selected.\n' >&2
    return 1
  fi
}

modus_print_headless_selection() {
  printf '  Selected test files: %d\n' "$MODUS_HEADLESS_INCLUDED_COUNT"
  printf '  GUI-required files skipped: %d\n' "$MODUS_HEADLESS_SKIPPED_COUNT"

  if [[ "$MODUS_INCLUDE_GUI_REQUIRED" == "1" ]]; then
    printf '  GUI-required manifest: included by request\n'
  else
    printf '  GUI-required manifest: %s\n' "$MODUS_HEADLESS_GUI_REQUIRED_MANIFEST"
  fi
}
