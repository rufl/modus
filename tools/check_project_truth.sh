#!/usr/bin/env bash
set -euo pipefail

failures=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

require_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    fail "missing required file: $path"
  fi
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
    fail "$path still contains stale text: $needle"
  fi
}

reject_stale_config_claims() {
  local stale_claims='game/cfg/|game/data/cfg/|game/config/balance/|game/config/gameplay\.json5'
  local roots=(docs README.md standalone game/data game/world game/core game/scripts)
  local stale_files
  stale_files=$(rg -l "$stale_claims" "${roots[@]}" -g '!*.import' || true)
  if [[ -n "$stale_files" ]]; then
    while IFS= read -r stale_file; do
      [[ -z "$stale_file" ]] && continue
      if [[ "$stale_file" == *.md ]] \
        && grep -Fq -- '**Documentation status: historical snapshot.**' "$stale_file"; then
        continue
      fi
      fail "$stale_file contains a retired configuration path claim"
    done <<< "$stale_files"
  fi
}

require_file "BACKLOG.md"
require_file "LICENSE"
require_file "ROADMAP.md"
require_file "README.md"
require_file "docs/DOCUMENTATION_TRUTH.md"
require_file "docs/CURRENT_STATUS.md"
require_file "docs/INDEX.md"
require_file "docs/README.md"
require_file "docs/ROADMAP.md"
require_file "docs/SHOWCASE_ROUTE.md"
require_file "docs/MULTIPLAYER_PROFILE_SMOKE.md"
require_file "tools/run_multiplayer_profile_smoke.sh"
require_file "docs/ENET_LOCAL_HOST_JOIN_SMOKE.md"
require_file "docs/MODDING_SAMPLE_MOD.md"
require_file "docs/MOD_PACKAGE_VALIDATION.md"
require_file "docs/EDITOR_ROUNDTRIP_PROOF.md"
require_file "docs/WORKSHOP_LOCAL_SIMULATION_PROOF.md"
require_file "docs/PERFORMANCE_BASELINE_PROOF.md"
require_file "docs/PROVENANCE_LEDGER.csv"
require_file "docs/licenses/KENNEY_CC0-1.0.txt"
require_file "docs/licenses/DIP000_BLOODY_POOL_MIT.txt"
require_file "tools/run_performance_evidence_capture.gd"
require_file "game/scripts/features/modding/mod_package_validator.gd"
require_file "tools/validate_mod_packages.gd"
require_file "mods/modus_sdk_sample/mod.json"
require_file "mods/modus_sdk_sample/scripts/sample_mod.gd"
require_file "tools/run_enet_local_smoke.sh"
require_file "tests/runners/run_all_tests_headless.sh"
require_file "tests/runners/run_tests_by_category.sh"
require_file "tests/runners/headless_common.sh"
require_file "tests/runners/headless_gui_required_tests.txt"
require_file "addons/gut/gut_cmdln.gd"
require_file "tools/check_headless_runner_manifest.sh"
require_file "tools/check_documentation_truth.sh"
require_file "tools/generate_provenance_ledger.py"
require_file "tools/run_main_player_path_smoke.sh"
require_file "tools/run_showcase_golden_demo_smoke.sh"
require_file "tools/showcase_golden_demo_smoke.gd"
require_file "tools/validate_manual_evidence.sh"
require_file "tools/run_manual_showcase_session.sh"
require_file "tests/manual/manual_evidence_overlay.tscn"
require_file "tests/manual/manual_evidence_overlay.gd"
require_file "tests/manual/manual_showcase_session.gd"
require_file "tests/runners/test_manual_evidence_validator.sh"
require_file "tools/validate_performance_evidence.sh"
require_file "tools/validate_release_readiness.sh"
require_file "tools/validate_production_readiness.sh"
require_file "game/data/weapons.json5"
require_file "game/data/enemies.json5"
require_file "game/data/loot_tables.json5"
require_file "game/ui/menus/welcome_screen.tscn"

require_text "project.godot" 'config/features=PackedStringArray("4.7")'
require_text "project.godot" 'GameManager="*res://game/scripts/core/game_manager.gd"'
require_text "project.godot" 'MapGenerator="*res://game/scripts/map_generator/map_generator.gd"'
require_text "README.md" "Godot 4.7+"
require_text "README.md" "./tests/runners/run_all_tests_headless.sh"
require_text "README.md" "game/data/"
require_text "docs/SHOWCASE_ROUTE.md" "res://game/world/maps/showcase.tscn"
require_text "shared/ui_core/screens/main_menu_screen.gd" "res://game/world/maps/showcase.tscn"
require_text "export_presets.cfg" "docs/PROVENANCE_LEDGER.csv"
require_text "game/ui/menus/welcome_screen.tscn" "BeginButton"
require_text "shared/shaders/blood_pool.gdshader" "HEIGHTMAP_STRENGTH;"
require_text "tools/run_multiplayer_profile_smoke.sh" "MODUS_FEATURE_PROFILE=multiplayer_demo"
require_text "tools/run_enet_local_smoke.sh" "enet_loopback_probe.gd"
require_text "tools/validate_mod_packages.gd" "MOD_PACKAGE_VALIDATION"
require_text "tests/runners/run_all_tests_headless.sh" "modus_collect_gut_tests tests/unit tests/integration tests/property"
require_text "tests/runners/run_tests_by_category.sh" "run_test_category \"Integration\" tests/integration"
require_text "tests/runners/run_tests_by_category.sh" "--report PATH"
require_text "tests/runners/headless_common.sh" "MODUS_INCLUDE_GUI_REQUIRED"
require_text "tests/runners/headless_gui_required_tests.txt" "res://tests/integration/test_player_experience_integration.gd"
require_text "tools/run_main_player_path_smoke.sh" "Main player path smoke report"
require_text "tools/run_showcase_golden_demo_smoke.sh" "Golden demo smoke report"
require_text "tools/showcase_golden_demo_smoke.gd" 'SAMPLE_MOD_ID := "modus_sdk_sample"'
require_text "tools/validate_manual_evidence.sh" "Manual evidence report"
require_text "tools/run_manual_showcase_session.sh" "MODUS_MANUAL_EVIDENCE_DIR"
require_text "tests/manual/manual_evidence_overlay.gd" "JOY_BUTTON_BACK"
require_text "tools/validate_performance_evidence.sh" "Performance evidence report"
require_text "tools/validate_release_readiness.sh" "Release readiness report"

if ! tools/generate_provenance_ledger.py --check; then
  fail "provenance ledger is stale"
fi

reject_text "README.md" "res://tests/run_tests.gd"
reject_text "README.md" "game/cfg/"
reject_text "README.md" "gameplay.json5"
reject_text "README.md" "docs/FEATURES.md"
reject_text "README.md" "docs/IMPLEMENTATION_SUMMARY.md"
reject_text "README.md" "docs/guides/GUIDES.md"
reject_text "shared/shaders/blood_pool.gdshader" "HEIGHTMAP_STRENGHT"
reject_text "README.md" "docs/STRUCTURE.md"
reject_text "README.md" "docs/DOCS.md"
reject_stale_config_claims

if ! bash tools/check_documentation_truth.sh; then
  fail "documentation truth check failed"
fi

if [[ $failures -gt 0 ]]; then
  printf '\nProject truth check failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf 'Project truth check passed.\n'
