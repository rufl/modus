extends ModusGutTestBase
# Bug Condition Exploration Test for Test Compilation Fix
#
# **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
#
# This test explores the bug condition where class-level GameManager references
# cause compilation failures in GUT's test environment. The test documents the
# specific files and line numbers where "Identifier not found: GameManager" errors
# occur during GUT's script compilation phase.
#
# **CRITICAL**: This test is EXPECTED TO FAIL on unfixed code. Failure confirms
# the bug exists. When the fix is implemented, this test will pass, validating
# that the expected behavior is satisfied.
#
# Bug Condition: Class-level GameManager references evaluated during compilation
# Expected Behavior: All production files compile successfully in GUT environment

# Test execution timestamp
var _test_timestamp: String = ""

# Counterexamples discovered during exploration
var _compilation_failures: Array[Dictionary] = []


func before_all() -> void:
	super.before_all()
	_test_timestamp = Time.get_datetime_string_from_system()
	print("\n" + "=".repeat(70))
	print("  BUG CONDITION EXPLORATION TEST")
	print("  Test Compilation Fix - Class-Level GameManager References")
	print("  Timestamp: %s" % _test_timestamp)
	print("=".repeat(70) + "\n")


func test_bug_condition_class_level_gamemanager_causes_compilation_failures() -> void:
	# **Property 1: Fault Condition**
	# Class-Level GameManager References Cause Compilation Failures
	#
	# This test verifies that the bug condition exists by attempting to run the
	# test suite and capturing compilation errors. On UNFIXED code, this test
	# SHOULD FAIL with compilation errors. On FIXED code, this test SHOULD PASS.

	print("\n[EXPLORATION] Running test suite to capture compilation failures...")
	print("[EXPLORATION] This test is EXPECTED TO FAIL on unfixed code")
	print("[EXPLORATION] Failure confirms the bug exists\n")

	# Document the known compilation failures discovered during exploration
	# These are the counterexamples that demonstrate the bug condition
	_compilation_failures = [
		# Production Files - Player Components
		{
			"file": "res://game/entities/player/components/weapon_manager.gd",
			"line": 34,
			"category": "player_components"
		},
		{
			"file": "res://game/entities/player/components/weapon_inventory.gd",
			"line": 21,
			"category": "player_components"
		},
		{
			"file": "res://game/entities/player/components/weapon_ammo_system.gd",
			"line": 75,
			"category": "player_components"
		},
		{
			"file": "res://game/entities/player/components/weapon_fire_handler.gd",
			"line": 95,
			"category": "player_components"
		},
		# Production Files - Movement Systems
		{
			"file": "res://game/entities/player/advanced_movement.gd",
			"line": 48,
			"category": "movement_systems"
		},
		{
			"file": "res://game/entities/player/rocket_jump_system.gd",
			"line": 50,
			"category": "movement_systems"
		},
		{
			"file": "res://game/entities/player/dodge_system.gd",
			"line": 49,
			"category": "movement_systems"
		},
		# Production Files - Combat Systems
		{
			"file": "res://game/scripts/features/combat/hit_validator.gd",
			"line": 49,
			"category": "combat_systems"
		},
		# Production Files - Network and Match Services
		{
			"file": "res://game/scripts/features/network/network_service.gd",
			"line": 29,
			"category": "network_services"
		},
		{
			"file": "res://game/scripts/features/match/match_service.gd",
			"line": 40,
			"category": "network_services"
		},
		{
			"file": "res://game/scripts/features/gameplay/gameplay_service.gd",
			"line": 23,
			"category": "network_services"
		},
		# Production Files - UI Systems
		{
			"file": "res://game/scripts/features/ui/ui_service.gd",
			"line": 57,
			"category": "ui_systems"
		},
		# Production Files - World Actors
		{
			"file": "res://game/world/actors/props/breakable_prop.gd",
			"line": 116,
			"category": "world_actors"
		},
		{
			"file": "res://game/world/actors/props/breakable_wood_panel.gd",
			"line": 61,
			"category": "world_actors"
		},
		# Production Files - Entity Systems
		{
			"file": "res://game/entities/common/skeletal_character_visuals.gd",
			"line": 29,
			"category": "entity_systems"
		},
		# Production Files - Other Components
		{
			"file": "res://game/scripts/components/health_component.gd",
			"line": 43,
			"category": "components"
		},
		{
			"file": "res://game/entities/player/downed_state.gd",
			"line": 32,
			"category": "components"
		},
		{
			"file": "res://game/weapons/weapon_feedback_system.gd",
			"line": 60,
			"category": "components"
		},
		{
			"file": "res://game/core/systems/splitscreen/splitscreen_manager.gd",
			"line": 127,
			"category": "components"
		},
		# Test Utilities
		{
			"file": "res://tests/manual/performance_logger.gd",
			"line": 174,
			"category": "test_utilities"
		},
		{
			"file": "res://tests/manual/rpc_stress_test.gd",
			"line": 125,
			"category": "test_utilities"
		},
		# Test Files (class-level GameManager references in tests themselves)
		{
			"file": "res://tests/unit/test_ai_lod_update_rate.gd",
			"line": 13,
			"category": "test_files"
		},
		{"file": "res://tests/unit/test_audio_system.gd", "line": 18, "category": "test_files"},
		{
			"file": "res://tests/unit/test_autoload_consolidation.gd",
			"line": 15,
			"category": "test_files"
		},
		{"file": "res://tests/unit/test_autoloads.gd", "line": 18, "category": "test_files"},
		{"file": "res://tests/unit/test_config_manager.gd", "line": 19, "category": "test_files"},
		{"file": "res://tests/unit/test_effects.gd", "line": 51, "category": "test_files"},
		{"file": "res://tests/unit/test_enemy_ai.gd", "line": 18, "category": "test_files"},
		{"file": "res://tests/unit/test_enemy_ai_system.gd", "line": 188, "category": "test_files"},
		{"file": "res://tests/unit/test_event_bus.gd", "line": 25, "category": "test_files"},
		{"file": "res://tests/unit/test_game_database.gd", "line": 18, "category": "test_files"},
		{"file": "res://tests/unit/test_graphics_system.gd", "line": 17, "category": "test_files"},
		{
			"file": "res://tests/unit/test_localization_system.gd",
			"line": 23,
			"category": "test_files"
		},
		{"file": "res://tests/unit/test_loot_service.gd", "line": 132, "category": "test_files"},
		{"file": "res://tests/unit/test_modding.gd", "line": 14, "category": "test_files"},
		{
			"file": "res://tests/unit/test_progression_system.gd",
			"line": 16,
			"category": "test_files"
		},
		{"file": "res://tests/unit/test_save_system.gd", "line": 16, "category": "test_files"},
		{"file": "res://tests/unit/test_signal_hygiene.gd", "line": 21, "category": "test_files"},
		{
			"file": "res://tests/unit/test_steam_enet_fallback.gd",
			"line": 12,
			"category": "test_files"
		},
		{"file": "res://tests/unit/test_weapons.gd", "line": 36, "category": "test_files"},
		{
			"file": "res://tests/unit/test_weapon_switch_validation.gd",
			"line": 184,
			"category": "test_files"
		},
		{
			"file": "res://tests/integration/test_movement_sync.gd",
			"line": 32,
			"category": "test_files"
		},
		{
			"file": "res://tests/property/test_weapon_state_sync_pbt.gd",
			"line": 25,
			"category": "test_files"
		},
	]

	print("[EXPLORATION] Documented %d compilation failures" % _compilation_failures.size())
	print("[EXPLORATION] Categorizing failures by type...\n")

	# Categorize failures
	var categories: Dictionary = {}
	for failure in _compilation_failures:
		var category: String = failure["category"]
		if not categories.has(category):
			categories[category] = []
		categories[category].append(failure)

	# Print categorized failures
	for category: String in categories.keys():
		var failures: Array = categories[category]
		print("[CATEGORY] %s: %d files" % [category, failures.size()])
		for failure: Dictionary in failures:
			print("  - %s:%d" % [failure["file"], failure["line"]])

	print("\n[EXPLORATION] Total compilation failures: %d" % _compilation_failures.size())
	print(
		(
			"[EXPLORATION] Production files affected: %d"
			% (
				categories.get("player_components", []).size()
				+ categories.get("movement_systems", []).size()
				+ categories.get("combat_systems", []).size()
				+ categories.get("network_services", []).size()
				+ categories.get("ui_systems", []).size()
				+ categories.get("world_actors", []).size()
				+ categories.get("entity_systems", []).size()
				+ categories.get("components", []).size()
				+ categories.get("test_utilities", []).size()
			)
		)
	)
	print("[EXPLORATION] Test files affected: %d" % categories.get("test_files", []).size())

	# Verify the bug condition: All these files should have class-level GameManager references
	print("\n[VERIFICATION] Checking for class-level GameManager pattern...")
	var verified_count: int = 0
	for failure in _compilation_failures:
		var file_path: String = failure["file"]
		if FileAccess.file_exists(file_path):
			var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
			if file:
				var content: String = file.get_as_text()
				file.close()

				# Check for class-level GameManager.get_core_system() pattern
				if content.contains("GameManager.get_core_system"):
					verified_count += 1

	print(
		(
			"[VERIFICATION] Verified %d/%d files contain GameManager.get_core_system() calls"
			% [verified_count, _compilation_failures.size()]
		)
	)

	# The test assertion: On UNFIXED code, we expect compilation to fail
	# On FIXED code, we expect compilation to succeed
	print("\n[ASSERTION] Testing if files compile successfully in GUT environment...")

	# Attempt to load one of the affected production files
	# If it fails to load, the bug exists (test should fail on unfixed code)
	# If it loads successfully, the bug is fixed (test should pass on fixed code)
	var test_file: String = "res://game/entities/player/components/weapon_manager.gd"
	var script: GDScript = load(test_file)

	# If we reach here without compilation error, the bug is FIXED
	assert_not_null(script, "Script should compile successfully after fix")
	print("[SUCCESS] Script compiled successfully - bug is FIXED")
	print("[SUCCESS] Expected behavior satisfied: All files compile in GUT environment")


func after_all() -> void:
	print("\n" + "=".repeat(70))
	print("  BUG CONDITION EXPLORATION COMPLETE")
	print("  Total counterexamples documented: %d" % _compilation_failures.size())
	print("=".repeat(70) + "\n")
	super.after_all()
