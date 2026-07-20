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
  MEMORY.md
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

require_file BACKLOG_ARCHIVE.md
require_text BACKLOG_ARCHIVE.md "$historical_marker"

require_text docs/DOCUMENTATION_TRUTH.md '**Overall readiness:** **NOT READY**'
require_text docs/DOCUMENTATION_TRUTH.md '1431/1431 passing'
require_text docs/DOCUMENTATION_TRUTH.md 'July 19 Unit 1056/1056, Integration 200/200, and Property 175/175'
require_text docs/DOCUMENTATION_TRUTH.md 'finished in 1770.186 seconds'
require_text docs/DOCUMENTATION_TRUTH.md '66.4-second, 130-sample'
require_text docs/DOCUMENTATION_TRUTH.md '0.00 recorded hours'
require_text docs/DOCUMENTATION_TRUTH.md 'NOT READY with 2 validator-tracked blockers'
require_text docs/CURRENT_STATUS.md '| Performance evidence | **PASS** |'
require_text docs/CURRENT_STATUS.md '| Production readiness | **NOT READY** |'
require_text docs/CURRENT_STATUS.md '| Latest batched Unit lane | **PASS** | July 19: 1056/1056 passing'
require_text docs/CURRENT_STATUS.md '| Map-generator threading | 8/8, 30 assertions;'
require_text docs/INDEX.md 'bodies have not been revalidated against the current tree'
require_text docs/README.md 'Historical files are unvalidated snapshots'
require_text docs/ATTRIBUTION.md 'No reviewed upstream license is stored in this checkout.'
require_text docs/CURRENT_STATUS.md 'The two-count is the scope of `tools/validate_production_readiness.sh`'
require_text shared/shaders/README.md 'HEIGHTMAP_STRENGHT'
require_text shared/shaders/README.md 'does **not** register `blood_effects_global.gd`'
require_text docs/MOVEMENT_MECHANICS_STATUS.md 'not end-to-end proven'
require_text tests/docs/PLAYER_EXPERIENCE_TESTS.md 'There is no `tests/runners/run_player_experience_tests.gd` runner'
require_text tests/README.md 'passes 1431/1431 tests with 20,362 assertions'
require_text tests/README.md 'latest category packet also passes Unit 1056/1056 with zero orphans, Integration 200/200, and Property 175/175'
require_text standalone/editor/README.md 'source prototype with a green focused data round-trip'
require_text docs/technical/JSON_SCHEMAS.md 'does not enable or poll file watching'
require_text docs/technical/README.md 'All other Markdown files in this directory are historical snapshots'

for path in \
  mods/alien_blood/README.md \
  mods/harder_enemies/README.md \
  mods/more_loot/README.md \
  mods/new_weapons/README.md; do
  require_text "$path" 'enabled: false'
done

for path in README.md ROADMAP.md MEMORY.md BACKLOG.md docs/README.md docs/INDEX.md docs/CURRENT_STATUS.md docs/ROADMAP.md docs/hardware_requirements.md; do
  reject_text "$path" '901/1417'
  reject_text "$path" 'Readiness Blockers:** 4'
  reject_text "$path" 'production readiness remains NOT READY with four blockers'
  reject_text "$path" 'manual, performance, and release evidence validators refreshed and remain BLOCKED'
  reject_text "$path" 'Legacy non-CSG showcase map'
done

for path in README.md ROADMAP.md MEMORY.md docs/CURRENT_STATUS.md docs/DOCUMENTATION_TRUTH.md docs/ROADMAP.md tests/README.md; do
  reject_text "$path" 'Unit emitted no complete summary'
  reject_text "$path" 'Unit did not emit a complete summary'
  reject_text "$path" 'Integration/Property not run'
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
    if ! grep -Fq -- 'not been revalidated' "$path"; then
      fail "$path is historical but does not warn that its body was not revalidated"
    fi
  elif [[ $has_maintained -eq 1 ]]; then
    maintained_docs+=("$path")
  elif grep -Fq -- '**Overall Status:**' "$path"; then
    : # Generated evidence report.
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
