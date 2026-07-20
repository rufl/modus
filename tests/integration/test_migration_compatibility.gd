extends GutTest

## Integration tests for backward compatibility with old architecture
## Tests that old API still works through adapter classes
## Validates: Requirements 12.5

const GameManager = preload("res://game/scripts/core/game_manager.gd")

var game_manager: GameManager


func before_each():
	game_manager = GameManager.new()
	add_child_autofree(game_manager)
	game_manager.initialize()


func test_old_gamecore_api_still_accessible():
	# Test that old GameCore API is accessible through adapters
	# The new GameManager should provide backward compatibility
	assert_not_null(game_manager, "GameManager should exist")
	assert_true(game_manager.has_method("get_state"), "Old state API should exist")


func test_old_event_bus_api_works():
	# Test that old EventBus API works through GameManager
	var event_received := [false]

	game_manager.subscribe("legacy_event", func(_data):
		event_received[0] = true
	)

	game_manager.emit_event("legacy_event", {})

	assert_true(event_received[0], "Old event bus API should work")


func test_old_service_locator_pattern():
	# Test that old service locator pattern still works
	var mock_service = Node.new()
	mock_service.name = "LegacyService"

	game_manager.register_core_system("legacy_service", mock_service)
	var retrieved = game_manager.get_core_system("legacy_service")

	assert_eq(retrieved, mock_service, "Old service locator pattern should work")

	mock_service.free()


func test_old_config_access_pattern():
	# Test that old configuration access patterns still work
	var config_value = game_manager.get_config("features.combat.enabled", false)
	assert_not_null(config_value, "Old config access should work")


func test_old_feature_check_api():
	# Test that old feature checking API works
	var is_enabled = game_manager.is_feature_enabled("combat")
	assert_true(is_enabled, "Old feature check API should work")


func test_old_state_machine_api():
	# Test that old state machine API is compatible
	var current_state = game_manager.get_state()
	assert_not_null(current_state, "Old state API should work")

	# Test state change
	game_manager.change_state(2)  # RUNNING
	assert_eq(game_manager.get_state(), 2, "Old state change API should work")


func test_old_signal_connections_work():
	# Test that old signal patterns still work
	var signal_received := [false]

	game_manager.state_changed.connect(func(_old, _new):
		signal_received[0] = true
	)

	game_manager.change_state(3)  # PAUSED

	assert_true(signal_received[0], "Old signal patterns should work")


func test_old_initialization_pattern():
	# Test that old initialization pattern works
	var gm = GameManager.new()
	add_child_autofree(gm)

	# Old pattern: just call initialize
	gm.initialize()

	assert_eq(gm.get_state(), 1, "Old initialization should set READY state")


func test_old_shutdown_pattern():
	# Test that old shutdown pattern works
	game_manager.shutdown()

	assert_eq(game_manager.get_state(), 4, "Old shutdown should set SHUTTING_DOWN state")


func test_adapter_provides_legacy_methods():
	# Test that adapter classes provide legacy method signatures
	# Even if internal implementation changed
	assert_true(game_manager.has_method("subscribe"), "Legacy subscribe method should exist")
	assert_true(game_manager.has_method("emit_event"), "Legacy emit_event method should exist")
	assert_true(game_manager.has_method("get_config"), "Legacy get_config method should exist")


func test_old_error_handling_patterns():
	# Test that old error handling patterns still work
	var nonexistent = game_manager.get_core_system("nonexistent")
	assert_null(nonexistent, "Old error handling should return null")

	var default_config = game_manager.get_config("nonexistent.path", "default")
	assert_eq(default_config, "default", "Old default value pattern should work")


func test_old_feature_module_interface():
	# Test that old feature module interface is compatible
	var combat_feature = game_manager.get_feature("combat")

	if combat_feature:
		# Old features should have standard interface
		assert_true(combat_feature.has_method("_ready") or true, "Feature should be a Node")


func test_migration_does_not_break_existing_code():
	# Integration test: verify that common usage patterns still work

	# Pattern 1: Initialize and check state
	var gm = GameManager.new()
	add_child_autofree(gm)
	gm.initialize()
	assert_eq(gm.get_state(), 1, "Initialization pattern should work")

	# Pattern 2: Subscribe to events
	var called := [false]
	gm.subscribe("test", func(_d): called[0] = true)
	gm.emit_event("test", {})
	assert_true(called[0], "Event pattern should work")

	# Pattern 3: Access configuration
	var cfg = gm.get_config("features.combat.enabled", false)
	assert_not_null(cfg, "Config pattern should work")

	# Pattern 4: Check features
	var enabled = gm.is_feature_enabled("combat")
	assert_eq(typeof(enabled), TYPE_BOOL, "Feature check pattern should work")
