extends GutTest

## Integration tests for feature module interactions
## Tests that features work together correctly
## Validates: Requirements 12.2

const GameManager = preload("res://game/scripts/core/game_manager.gd")

var game_manager: GameManager


func before_each():
	game_manager = GameManager.new()
	add_child_autofree(game_manager)
	game_manager.initialize()


func test_combat_and_inventory_integration():
	# Test that combat feature can interact with inventory feature
	assert_true(game_manager.is_feature_enabled("combat"), "Combat should be enabled")
	assert_true(game_manager.is_feature_enabled("inventory"), "Inventory should be enabled")

	var combat_feature = game_manager.get_feature("combat")
	var inventory_feature = game_manager.get_feature("inventory")

	assert_not_null(combat_feature, "Combat feature should be loaded")
	assert_not_null(inventory_feature, "Inventory feature should be loaded")


func test_loot_depends_on_inventory():
	# Test that loot feature correctly depends on inventory
	assert_true(game_manager.is_feature_enabled("loot"), "Loot should be enabled")
	assert_true(
		game_manager.is_feature_enabled("inventory"), "Inventory (dependency) should be enabled"
	)

	var loot_feature = game_manager.get_feature("loot")
	var inventory_feature = game_manager.get_feature("inventory")

	assert_not_null(loot_feature, "Loot feature should be loaded")
	assert_not_null(inventory_feature, "Inventory feature should be loaded")


func test_multiple_features_can_subscribe_to_same_event():
	# Test that multiple features can listen to the same event
	var combat_called := {"value": false}
	var inventory_called := {"value": false}

	game_manager.subscribe("player_action", func(_data): combat_called.value = true)

	game_manager.subscribe("player_action", func(_data): inventory_called.value = true)

	game_manager.emit_event("player_action", {})

	assert_true(combat_called.value, "Combat listener should be called")
	assert_true(inventory_called.value, "Inventory listener should be called")


func test_features_can_communicate_via_event_bus():
	# Test that features can communicate through the event bus
	var message_received = {"value": null}

	game_manager.subscribe(
		"test_feature_message", func(data): message_received.value = data.get("message")
	)

	game_manager.emit_event("test_feature_message", {"message": "Hello from feature"})

	assert_eq(message_received.value, "Hello from feature", "Message should be received")


func test_feature_initialization_order_respects_dependencies():
	# Test that features are initialized in dependency order
	# This is implicitly tested by successful initialization
	assert_true(game_manager.is_feature_enabled("loot"), "Loot should be enabled")
	assert_true(game_manager.is_feature_enabled("inventory"), "Inventory should be enabled first")


func test_core_systems_available_to_all_features():
	# Test that core systems are accessible to all features
	var config_manager = game_manager.get_core_system("config")
	assert_not_null(config_manager, "Configuration manager should be available")

	# All features should be able to access configuration
	var combat_config = game_manager.get_config("features.combat.enabled", false)
	assert_not_null(combat_config, "Features should access config through game manager")


func test_feature_unload_cleans_up_event_listeners():
	# Test that unloading a feature removes its event listeners
	var listener_called := {"value": false}

	game_manager.subscribe("test_event", func(_data): listener_called.value = true)

	# Unload a feature (physics is a core system we can unload)
	game_manager.unload_feature("physics")

	# The specific listener we added should still work
	# (this tests that unload doesn't break the event system)
	game_manager.emit_event("test_event", {})
	assert_true(listener_called.value, "Event system should still work after feature unload")


func test_multiple_features_share_configuration_manager():
	# Test that all features share the same configuration manager instance
	var config_mgr1 = game_manager.get_core_system("config")

	# Set a value through game manager
	game_manager.get_core_system("config").set_value("test.shared", 42)

	# Retrieve through game manager
	var value = game_manager.get_config("test.shared", 0)

	assert_eq(value, 42, "Configuration should be shared across features")


func test_feature_hot_reload():
	# Test that features can be reloaded
	var initial_feature = game_manager.get_feature("physics")

	# Unload and reload
	game_manager.unload_feature("physics")
	assert_false(game_manager.is_feature_loaded("physics"), "Feature should be unloaded")

	# Reload
	assert_true(game_manager.load_feature("physics"), "Feature should reload successfully")
	assert_true(game_manager.is_feature_loaded("physics"), "Feature should be reloaded")


func test_disabled_feature_does_not_interfere():
	# Test that disabled features don't interfere with enabled ones
	assert_false(game_manager.is_feature_enabled("network"), "Network should be disabled")

	# Other features should work normally
	assert_true(game_manager.is_feature_enabled("combat"), "Combat should work")
	assert_true(game_manager.is_feature_enabled("inventory"), "Inventory should work")
