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
  stale_files=$(grep -RIlE --exclude='*.import' --exclude-dir=.git --exclude-dir=.godot \
    "$stale_claims" "${roots[@]}" 2>/dev/null || true)
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
require_file "BACKLOG_ARCHIVE.md"
require_file "LICENSE"
require_file "MEMORY.md"
require_file "ROADMAP.md"
require_file "README.md"
require_file "docs/DOCUMENTATION_TRUTH.md"
require_file "docs/CURRENT_STATUS.md"
require_file "docs/INDEX.md"
require_file "docs/README.md"
require_file "docs/ROADMAP.md"
require_file "docs/MAIN_PLAYER_PATH_SMOKE.md"
require_file "docs/SHOWCASE_LAUNCH_SMOKE.md"
require_file "docs/GOLDEN_DEMO_SMOKE.md"
require_file "docs/AUTOMATED_TEST_LANES_REPORT.md"
require_file "docs/MANUAL_EVIDENCE_REPORT.md"
require_file "docs/PERFORMANCE_EVIDENCE_REPORT.md"
require_file "docs/RELEASE_READINESS_REPORT.md"
require_file "docs/PRODUCTION_READINESS_REPORT.md"
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
require_text "BACKLOG.md" "[truth:source-audit]"
require_text "BACKLOG.md" "[truth:docs]"
require_text "BACKLOG.md" "Current Verification Boundaries"
require_text "BACKLOG_ARCHIVE.md" "2026-07-08 - Planning Truth Control Docs"
require_text "MEMORY.md" "./tests/runners/run_all_tests_headless.sh"
require_text "MEMORY.md" "game/data/"
require_text "ROADMAP.md" "Godot 4.7+"
require_text "README.md" "Godot 4.7+"
require_text "README.md" "./tests/runners/run_all_tests_headless.sh"
require_text "README.md" "game/data/"
require_text "docs/README.md" "0.9.5-beta"
require_text "docs/DOCUMENTATION_TRUTH.md" "NOT READY with 2 validator-tracked blockers"
require_text "docs/CURRENT_STATUS.md" "1440/1440 passing"
require_text "docs/CURRENT_STATUS.md" "1056/1056 passing"
require_text "docs/CURRENT_STATUS.md" "Map-generator threading"
require_text "docs/INDEX.md" "Automated Test Lanes Report"
require_text "docs/INDEX.md" "bodies have not been revalidated against the current tree"
require_text "docs/ROADMAP.md" "0.9.5-beta"
require_text "docs/ROADMAP.md" "AUTOMATED_TEST_LANES_REPORT.md"
require_text "docs/MAIN_PLAYER_PATH_SMOKE.md" "MODUS Main Player Path Smoke Report"
require_text "docs/MAIN_PLAYER_PATH_SMOKE.md" "Overall Status"
require_text "docs/SHOWCASE_LAUNCH_SMOKE.md" "Overall Status"
require_text "docs/SHOWCASE_LAUNCH_SMOKE.md" "**Target:** world"
require_text "docs/GOLDEN_DEMO_SMOKE.md" "**Overall Status:** PASS"
require_text "docs/GOLDEN_DEMO_SMOKE.md" '`mod_loading` | **PASS**'
require_text "docs/MANUAL_EVIDENCE_REPORT.md" "MODUS Manual Evidence Report"
require_text "docs/MANUAL_EVIDENCE_REPORT.md" "Overall Status"
require_text "docs/MANUAL_EVIDENCE_REPORT.md" "Validated test hours"
require_text "docs/MANUAL_EVIDENCE_REPORT.md" "manual_evidence_overlay.tscn"
require_text "docs/PERFORMANCE_EVIDENCE_REPORT.md" "MODUS Performance Evidence Report"
require_text "docs/PERFORMANCE_EVIDENCE_REPORT.md" "Overall Status"
require_text "docs/RELEASE_READINESS_REPORT.md" "MODUS Release Readiness Report"
require_text "docs/RELEASE_READINESS_REPORT.md" "Overall Status"
require_text "docs/PRODUCTION_READINESS_REPORT.md" "MODUS Production Readiness Report"
require_text "docs/PRODUCTION_READINESS_REPORT.md" "Overall Status"
require_text "docs/PRODUCTION_READINESS_REPORT.md" "Latest Automated Lane Triage"
require_text "docs/PRODUCTION_READINESS_REPORT.md" "Tests 1440 Passing Tests 1440 Asserts 20475 Time 702.76s"
require_text "docs/SHOWCASE_ROUTE.md" "res://game/world/maps/showcase.tscn"
require_text "docs/RELEASE_EVIDENCE_BUNDLE.md" "main_menu_1280x720.png"
require_text "shared/ui_core/screens/main_menu_screen.gd" "res://game/world/maps/showcase.tscn"
require_text "docs/SHOWCASE_ROUTE.md" "validate_manual_evidence.sh --strict"
require_text "docs/ATTRIBUTION.md" "220 assets: 8 cleared, 12 identified but requiring rights evidence, and 200 unverified"
require_text "export_presets.cfg" "docs/PROVENANCE_LEDGER.csv"
require_text "game/ui/menus/welcome_screen.tscn" "BeginButton"
require_text "shared/shaders/blood_pool.gdshader" "HEIGHTMAP_STRENGTH;"
require_text "docs/MULTIPLAYER_PROFILE_SMOKE.md" "multiplayer_demo"
require_text "docs/MULTIPLAYER_PROFILE_SMOKE.md" "host/join runtime proof remains blocked"
require_text "tools/run_multiplayer_profile_smoke.sh" "MODUS_FEATURE_PROFILE=multiplayer_demo"
require_text "docs/ENET_LOCAL_HOST_JOIN_SMOKE.md" "separate Godot 4.7 server and client processes"
require_text "tools/run_enet_local_smoke.sh" "enet_loopback_probe.gd"
require_text "docs/MODDING_SAMPLE_MOD.md" "tests/integration/test_sample_mod_sdk.gd"
require_text "docs/MODDING_SAMPLE_MOD.md" "Workshop upload"
require_text "docs/MOD_PACKAGE_VALIDATION.md" "duplicate active override ownership"
require_text "docs/EDITOR_ROUNDTRIP_PROOF.md" "tests/integration/test_editor_roundtrip.gd"
require_text "docs/EDITOR_ROUNDTRIP_PROOF.md" "live editor UI interaction"
require_text "docs/WORKSHOP_LOCAL_SIMULATION_PROOF.md" "tests/integration/test_workshop_local_simulation.gd"
require_text "docs/WORKSHOP_LOCAL_SIMULATION_PROOF.md" "Real Steam Workshop status: BLOCKED"
require_text "docs/PERFORMANCE_BASELINE_PROOF.md" "showcase_baseline_20260713.csv"
require_text "docs/PERFORMANCE_BASELINE_PROOF.md" "unthrottled capture context"
require_text "tools/run_performance_evidence_capture.gd" "showcase_baseline_20260713"
require_text "tools/validate_mod_packages.gd" "MOD_PACKAGE_VALIDATION"
require_text "docs/AUTOMATED_TEST_LANES_REPORT.md" "MODUS Automated Test Lanes Report"
require_text "docs/AUTOMATED_TEST_LANES_REPORT.md" "Durable Failure Lanes"
require_text "docs/technical/JSON_SCHEMAS.md" "Ownership Boundary"
require_text "docs/technical/JSON_SCHEMAS.md" 'user://mods/'
require_text "shared/shaders/README.md" "fresh Godot 4.7 parse/render"
require_text "docs/technical/STEAM_INTEGRATION.md" "Current Proof Boundary"
require_text "docs/technical/STEAM_INTEGRATION.md" "Real Steam/GodotSteam"
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

reject_text "MEMORY.md" "docs/unknown"
reject_text "MEMORY.md" "no maintained local verification gate was inferred"
reject_text "ROADMAP.md" "Stack signals: docs/unknown"
reject_text "README.md" "res://tests/run_tests.gd"
reject_text "README.md" "game/cfg/"
reject_text "README.md" "gameplay.json5"
reject_text "README.md" "docs/FEATURES.md"
reject_text "README.md" "docs/IMPLEMENTATION_SUMMARY.md"
reject_text "README.md" "docs/guides/GUIDES.md"
reject_text "shared/shaders/blood_pool.gdshader" "HEIGHTMAP_STRENGHT"
reject_text "README.md" "docs/STRUCTURE.md"
reject_text "README.md" "docs/DOCS.md"
reject_text "docs/README.md" "**Version:** 1.0.0"
reject_text "docs/ROADMAP.md" "**Current Version:** 1.0.0"
reject_stale_config_claims

if ! bash tools/check_documentation_truth.sh; then
  fail "documentation truth check failed"
fi

if [[ $failures -gt 0 ]]; then
  printf '\nProject truth check failed with %d issue(s).\n' "$failures" >&2
  exit 1
fi

printf 'Project truth check passed.\n'
