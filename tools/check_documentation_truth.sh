#!/usr/bin/env bash
set -euo pipefail

failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "missing required documentation file: $path"
}

require_text() {
  local path="$1"
  local needle="$2"
  if ! grep -Fq -- "$needle" "$path"; then
    fail "$path is missing required text: $needle"
  fi
}

reject_text() {
  local path="$1"
  local needle="$2"
  if grep -Fq -- "$needle" "$path"; then
    fail "$path still contains stale current-facing text: $needle"
  fi
}

maintained_marker='**Documentation status: maintained reference.**'
historical_marker='**Documentation status: historical snapshot.**'

current_docs=(
  README.md
  ROADMAP.md
  BACKLOG.md
  CHANGELOG.md
  docs/README.md
  docs/INDEX.md
  docs/DOCUMENTATION_TRUTH.md
  docs/CURRENT_STATUS.md
  docs/ROADMAP.md
  docs/architecture.md
  docs/TECHNICAL_REFERENCE.md
  docs/ATTRIBUTION.md
  docs/hardware_requirements.md
  docs/technical/README.md
  docs/technical/JSON_SCHEMAS.md
  tests/README.md
  tests/runners/README.md
  tests/docs/PLAYER_EXPERIENCE_TESTS.md
  shared/shaders/README.md
  standalone/editor/README.md
)

for path in "${current_docs[@]}"; do
  require_file "$path"
  require_text "$path" "$maintained_marker"
done

for path in \
  mods/alien_blood/README.md \
  mods/harder_enemies/README.md \
  mods/more_loot/README.md \
  mods/new_weapons/README.md; do
  require_text "$path" 'enabled: false'
done

maintained_docs=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue

  has_maintained=0
  has_historical=0
  grep -Fq -- "$maintained_marker" "$path" && has_maintained=1
  grep -Fq -- "$historical_marker" "$path" && has_historical=1

  if [[ $has_maintained -eq 1 && $has_historical -eq 1 ]]; then
    fail "$path has both maintained and historical classifications"
  elif [[ $has_historical -eq 1 ]]; then
    fail "$path is a local-only historical snapshot, not published documentation"
  elif [[ $has_maintained -eq 1 ]]; then
    maintained_docs+=("$path")
  elif grep -Fq -- '**Overall Status:**' "$path"; then
    fail "$path is generated evidence; keep it local-only or publish it as a CI artifact"
  else
    fail "$path has no maintained, generated, or historical truth classification"
  fi
done < <(rg --files -g '*.md' -g '!addons/**' -g '!assets/**' -g '!game/art/**' | sort)

stale_maintained_phrases=(
  '**Version:** 1.0.0'
  '75,000+ lines'
  'automated tests cover 96% of the codebase'
  'All breakable prop classes (`BreakableProp`, `BreakableGlass`, `BreakableWoodPanel`) are fully compatible'
  '**Status**: Official Standard'
  "That's it! The profiler will automatically initialize"
  'You now have a fully functional blood pool system'
  'All 40 tasks complete'
)

for path in "${maintained_docs[@]}"; do
  for phrase in "${stale_maintained_phrases[@]}"; do
    reject_text "$path" "$phrase"
  done

  while IFS= read -r reference; do
    [[ -z "$reference" ]] && continue
    local_path="${reference#res://}"
    if [[ ! -e "$local_path" ]]; then
      fail "$path references missing resource path: $reference"
    fi
  done < <(rg -o 'res://[A-Za-z0-9_./-]+' "$path" | sort -u || true)

  while IFS= read -r markdown_link; do
    [[ -z "$markdown_link" ]] && continue
    target="${markdown_link#*](}"
    target="${target%)}"
    target="${target%%#*}"
    case "$target" in
      ''|http://*|https://*|mailto:*|user://*|res://*) continue ;;
    esac
    resolved="$(dirname "$path")/$target"
    if [[ ! -e "$resolved" ]]; then
      fail "$path contains a broken local Markdown link: $target"
    fi
  done < <(grep -oE '\[[^][]+\]\([^)]+\)' "$path" || true)
done

if [[ $failures -gt 0 ]]; then
  printf '\nDocumentation truth check failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf 'Documentation truth check passed: %d maintained files checked.\n' "${#maintained_docs[@]}"
