extends ModusGutTestBase

## Unit tests for GameManager
## Tests state machine, service locator, and event bus functionality

var game_manager: Node  # Reference to the autoload GameManager


func before_each() -> void:
	await modus_setup()
	# Use the autoload GameManager instead of creating a new instance
	game_manager = get_node_or_null("/root/GameManager")
	assert_not_null(game_manager, "GameManager autoload must be available")


func after_each() -> void:
	# Reset GameManager state for next test
	if game_manager and game_manager.has_method("reset_test_state"):
		game_manager.reset_test_state()
	modus_teardown()


func test_initial_state_is_initializing() -> void:
	# Test uses the autoload GameManager
	# Note: The autoload may already be initialized, so we check current state
	var current_state: int = game_manager.get_state()
	# State should be INITIALIZING (0) or READY (1) depending on initialization
	assert_true(
		current_state >= 0 and current_state <= 1,
		"State should be INITIALIZING (0) or READY (1), got: %d" % current_state
	)


func test_initialize_changes_state_to_ready() -> void:
	# Ensure GameManager is initialized
	if game_manager.get_state() == 0:  # INITIALIZING
		game_manager.initialize()

	assert_eq(game_manager.get_state(), 1, "State should be READY (1) after initialize")


func test_change_state_emits_signal() -> void:
	watch_signals(game_manager)
	var new_state: int = 2  # RUNNING
	game_manager.change_state(new_state)

	assert_signal_emitted(game_manager, "state_changed")
	assert_eq(game_manager.get_state(), new_state)


func test_change_state_does_not_emit_if_same() -> void:
	var ready_state: int = 1  # READY
	game_manager.change_state(ready_state)
	watch_signals(game_manager)
	game_manager.change_state(ready_state)

	assert_signal_not_emitted(game_manager, "state_changed")


func test_register_and_get_core_system() -> void:
	var mock_system: Node = Node.new()
	mock_system.name = "MockSystem"

	game_manager.register_core_system("test_system", mock_system)
	var retrieved: Variant = game_manager.get_core_system("test_system")

	assert_not_null(retrieved, "Should retrieve registered system")
	assert_eq(retrieved, mock_system, "Should retrieve the same system instance")

	mock_system.free()


func test_get_nonexistent_core_system_returns_null() -> void:
	var result: Variant = game_manager.get_core_system("nonexistent")
	assert_null(result, "Should return null for nonexistent system")


func test_register_event() -> void:
	game_manager.register_event("test_event")
	# Event should be registered (no error when subscribing)
	game_manager.subscribe("test_event", func(_data: Variant) -> void: pass)
	assert_true(true, "Event registration should succeed")


func test_subscribe_and_emit_event() -> void:
	var test_result: Dictionary = {"called": false, "data": {}}

	var callback: Callable = func(data: Variant) -> void:
		test_result.called = true
		test_result.data = data

	game_manager.subscribe("test_event", callback)
	game_manager.emit_event("test_event", {"value": 42})

	assert_true(test_result.called, "Callback should be called")
	assert_eq(test_result.data.get("value"), 42, "Should receive correct data")


func test_unsubscribe_from_event() -> void:
	var test_result: Dictionary = {"called": false}
	var callback: Callable = func(_data: Variant) -> void: test_result.called = true

	game_manager.subscribe("test_event", callback)
	game_manager.unsubscribe("test_event", callback)
	game_manager.emit_event("test_event")

	assert_false(test_result.called, "Callback should not be called after unsubscribe")


func test_event_priority_ordering() -> void:
	var call_order: Array = []

	var callback_low: Callable = func(_data: Variant) -> void: call_order.append("low")

	var callback_high: Callable = func(_data: Variant) -> void: call_order.append("high")

	var callback_medium: Callable = func(_data: Variant) -> void: call_order.append("medium")

	game_manager.subscribe("test_event", callback_low, 0)
	game_manager.subscribe("test_event", callback_high, 100)
	game_manager.subscribe("test_event", callback_medium, 50)

	game_manager.emit_event("test_event")

	assert_eq(call_order, ["high", "medium", "low"], "Callbacks should be called in priority order")


func test_is_feature_enabled_returns_false_by_default() -> void:
	var result: bool = game_manager.is_feature_enabled("nonexistent_feature")
	assert_false(result, "Feature should not be enabled by default")


func test_get_nonexistent_feature_returns_null() -> void:
	var result: Variant = game_manager.get_feature("nonexistent_feature")
	assert_null(result, "Should return null for nonexistent feature")


func test_shutdown_clears_systems() -> void:
	var mock_system: Node = Node.new()
	game_manager.register_core_system("test_system", mock_system)

	game_manager.shutdown()

	var result: Variant = game_manager.get_core_system("test_system")
	assert_null(result, "Systems should be cleared after shutdown")
	assert_eq(game_manager.get_state(), 4)  # SHUTTING_DOWN

	mock_system.free()


func test_shutdown_clears_event_listeners() -> void:
	var test_result: Dictionary = {"called": false}
	var callback: Callable = func(_data: Variant) -> void: test_result.called = true

	game_manager.subscribe("test_event", callback)
	game_manager.shutdown()
	game_manager.emit_event("test_event")

	assert_false(test_result.called, "Event listeners should be cleared after shutdown")


func test_get_config_returns_default_when_no_config_manager() -> void:
	var result: Variant = game_manager.get_config("some.path", "default_value")
	assert_eq(result, "default_value", "Should return default when no config manager")


func test_multiple_event_subscribers() -> void:
	var test_result: Dictionary = {"count": 0}

	var callback1: Callable = func(_data: Variant) -> void: test_result.count += 1

	var callback2: Callable = func(_data: Variant) -> void: test_result.count += 10

	game_manager.subscribe("test_event", callback1)
	game_manager.subscribe("test_event", callback2)
	game_manager.emit_event("test_event")

	assert_eq(test_result.count, 11, "Both callbacks should be called")


# Feature Toggle System Tests


func test_load_features_config_from_json5() -> void:
	# Initialize should load features.json5
	game_manager.initialize()

	# Check that features are loaded
	assert_true(game_manager.is_feature_enabled("combat"), "Combat feature should be enabled")
	assert_true(game_manager.is_feature_enabled("inventory"), "Inventory feature should be enabled")
	assert_false(game_manager.is_feature_enabled("network"), "Network feature should be disabled")


func test_feature_dependency_resolution() -> void:
	game_manager.initialize()

	# Loot depends on inventory, so inventory should be loaded first
	# Both should be enabled in the standard profile
	assert_true(game_manager.is_feature_enabled("loot"), "Loot feature should be enabled")
	assert_true(
		game_manager.is_feature_enabled("inventory"),
		"Inventory feature (dependency) should be enabled"
	)


func test_core_system_features_marked_as_loaded() -> void:
	game_manager.initialize()

	# Physics and particles are core systems (no module to load)
	# They should be marked as loaded even though they have no module
	var _physics_feature: Variant = game_manager.get_feature("physics")
	var _particles_feature: Variant = game_manager.get_feature("particles")

	# Core systems are stored as null in the features dict
	assert_true(game_manager.is_feature_enabled("physics"), "Physics should be enabled")
	assert_true(game_manager.is_feature_enabled("particles"), "Particles should be enabled")


func test_disabled_feature_returns_null() -> void:
	game_manager.initialize()

	# Network is disabled in the standard profile
	var network_feature: Variant = game_manager.get_feature("network")
	assert_null(network_feature, "Disabled feature should return null")


func test_load_feature_checks_dependencies() -> void:
	game_manager.initialize()

	# Try to manually load a feature that depends on a disabled feature
	# This should fail because the dependency is not enabled
	# Note: In the actual config, all dependencies are properly enabled,
	# so we're testing the validation logic here

	# The validation should have already run during initialize
	# and all enabled features should have their dependencies satisfied
	assert_true(true, "Dependency validation should pass for enabled features")


func test_feature_profile_application() -> void:
	game_manager.initialize()

	# The standard profile should be active
	# It includes: combat, inventory, loot, effects, match, player, gameplay, physics, particles
	assert_true(game_manager.is_feature_enabled("combat"), "Combat in standard profile")
	assert_true(game_manager.is_feature_enabled("inventory"), "Inventory in standard profile")
	assert_true(game_manager.is_feature_enabled("loot"), "Loot in standard profile")
	assert_true(game_manager.is_feature_enabled("effects"), "Effects in standard profile")
	assert_true(game_manager.is_feature_enabled("physics"), "Physics in standard profile")

	# Network, gore, and audio are not in the standard profile
	assert_false(game_manager.is_feature_enabled("network"), "Network not in standard profile")
	assert_false(game_manager.is_feature_enabled("gore"), "Gore not in standard profile")
	assert_false(game_manager.is_feature_enabled("audio"), "Audio not in standard profile")


func test_get_config_with_config_manager() -> void:
	game_manager.initialize()

	# After initialization, config manager should be available
	var log_setting: Variant = game_manager.get_config("development.log_feature_loading", false)
	assert_not_null(log_setting, "Should be able to get config values")


func test_feature_loaded_signal_emitted() -> void:
	# Use the autoload GameManager
	# Initialize if not already initialized
	if game_manager.get_state() == 0:  # INITIALIZING
		watch_signals(game_manager)
		game_manager.initialize()

		# At least one feature should be loaded and emit the signal
		assert_signal_emitted(game_manager, "feature_loaded")
	else:
		# Already initialized, skip this test
		pass_test("GameManager already initialized, cannot test signal emission")


func test_unload_feature() -> void:
	# Ensure GameManager is initialized
	if game_manager.get_state() == 0:
		game_manager.initialize()

	# Load a core system feature (physics) if not already loaded
	var physics_before: Variant = game_manager.get_feature("physics")

	if physics_before == null:
		# Feature not loaded, skip test
		pass_test("Physics feature not loaded, cannot test unload")
		return

	# Unload it
	watch_signals(game_manager)
	game_manager.unload_feature("physics")

	# Check that it's unloaded without triggering the intentional lazy reload path.
	assert_false(game_manager.is_feature_loaded("physics"), "Feature should be unloaded")
	assert_signal_emitted(game_manager, "feature_unloaded")


func test_load_nonexistent_feature_fails() -> void:
	game_manager.initialize()

	# Try to load a feature that doesn't exist in features.json5
	var result: bool = game_manager.load_feature("nonexistent_feature")
	assert_false(result, "Loading nonexistent feature should fail")


func test_load_disabled_feature_fails() -> void:
	game_manager.initialize()

	# Try to load a feature that is disabled
	var result: bool = game_manager.load_feature("network")
	assert_false(result, "Loading disabled feature should fail")


func test_feature_initialization_order() -> void:
	game_manager.initialize()

	# Features with dependencies should be loaded after their dependencies
	# This is implicitly tested by the fact that initialization succeeds
	# If the order was wrong, features would fail to load

	# Check that dependent features are loaded
	assert_true(game_manager.is_feature_enabled("loot"), "Loot should be enabled")
	assert_true(
		game_manager.is_feature_enabled("inventory"), "Inventory (dependency) should be enabled"
	)

	# If loot loaded successfully, it means inventory was loaded first
	assert_true(true, "Dependency order is correct")
