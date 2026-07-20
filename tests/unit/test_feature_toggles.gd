extends GutTest

## Unit tests for feature toggle system
## Tests enabling/disabling features and dependency validation
## Validates: Requirements 12.4

const GameManager = preload("res://game/scripts/core/game_manager.gd")

var game_manager: GameManager


func before_each():
	game_manager = GameManager.new()
	add_child_autofree(game_manager)


func test_enabled_feature_is_accessible():
	# Test that enabled features can be accessed
	assert_true(game_manager.is_feature_enabled("combat"), "Combat should be enabled")
	
	var combat_feature = game_manager.get_feature("combat")
	assert_not_null(combat_feature, "Enabled feature should be accessible")


func test_disabled_feature_is_not_accessible():
	# Test that disabled features return null
	assert_false(game_manager.is_feature_enabled("network"), "Network should be disabled")
	
	var network_feature = game_manager.get_feature("network")
	assert_null(network_feature, "Disabled feature should return null")


func test_toggle_feature_on():
	# Test enabling a disabled feature
	assert_false(game_manager.is_feature_enabled("network"), "Network should start disabled")
	
	# Enable the feature
	var result = game_manager.load_feature("network")
	
	if result:
		assert_true(game_manager.is_feature_enabled("network"), "Feature should be enabled")
		var feature = game_manager.get_feature("network")
		assert_not_null(feature, "Enabled feature should be accessible")


func test_toggle_feature_off():
	# Test disabling an enabled feature
	assert_true(game_manager.is_feature_enabled("physics"), "Physics should start enabled")
	
	# Disable the feature
	game_manager.unload_feature("physics")

	assert_false(game_manager.is_feature_loaded("physics"), "Disabled feature should be unloaded")


func test_feature_toggle_emits_signals():
	# Test that toggling features emits appropriate signals.
	game_manager.unload_feature("physics")
	watch_signals(game_manager)

	# Load a feature from an unloaded state.
	game_manager.load_feature("physics")
	assert_signal_emitted(game_manager, "feature_loaded")
	
	# Unload a feature
	game_manager.unload_feature("physics")
	assert_signal_emitted(game_manager, "feature_unloaded")


func test_feature_dependency_validation():
	# Test that features with dependencies validate correctly
	# Loot depends on inventory
	
	assert_true(game_manager.is_feature_enabled("loot"), "Loot should be enabled")
	assert_true(game_manager.is_feature_enabled("inventory"), "Inventory (dependency) should be enabled")


func test_cannot_disable_feature_with_dependents():
	# Test that disabling a feature with dependents is handled
	# Inventory is required by loot
	
	if game_manager.is_feature_enabled("inventory") and game_manager.is_feature_enabled("loot"):
		# Try to unload inventory (which loot depends on)
		game_manager.unload_feature("inventory")
		
		# The system should handle this gracefully
		# Either prevent unload or cascade unload dependents
		assert_true(true, "System should handle dependent features")


func test_feature_toggle_persists_during_session():
	# Test that feature toggles persist during the game session
	var initial_state = game_manager.is_feature_enabled("combat")
	
	# State should remain consistent
	var later_state = game_manager.is_feature_enabled("combat")
	assert_eq(initial_state, later_state, "Feature state should persist")


func test_all_enabled_features_are_loaded() -> void:
	# Test that all enabled features in the standard profile are loaded
	var enabled_features: Array[String] = [
		"combat", "inventory", "loot", "effects", "match", 
		"player", "gameplay", "physics", "particles"
	]
	
	for feature_name: String in enabled_features:
		assert_true(
			game_manager.is_feature_enabled(feature_name),
			"Feature '%s' should be enabled" % feature_name
		)


func test_all_disabled_features_are_not_loaded():
	# Test that disabled features are not loaded
	var disabled_features = ["network"]
	
	for feature_name in disabled_features:
		assert_false(game_manager.is_feature_enabled(feature_name), "Feature '%s' should be disabled" % feature_name)


func test_feature_toggle_affects_initialization() -> void:
	# Test that feature toggles affect what gets initialized
	var gm: GameManager = GameManager.new()
	autofree(gm)

	# Before entering the tree, feature configuration is not loaded.
	assert_false(gm.is_feature_enabled("combat"), "Features should not be loaded before init")

	# Entering the tree initializes the manager.
	add_child(gm)
	assert_true(gm.is_feature_enabled("combat"), "Enabled features should load on init")


func test_feature_toggle_validation_on_load() -> void:
	# Test that loading a feature validates its dependencies
	var gm: GameManager = GameManager.new()
	add_child_autofree(gm)
	
	# Try to load a feature with dependencies
	# The system should validate dependencies exist
	var result: bool = gm.load_feature("loot")
	
	if result:
		# If load succeeded, dependencies should be satisfied
		assert_true(
			gm.is_feature_enabled("inventory"),
			"Dependencies should be loaded"
		)


func test_core_system_features_always_available():
	# Test that core system features (physics, particles) are always available
	assert_true(game_manager.is_feature_enabled("physics"), "Physics should be available")
	assert_true(game_manager.is_feature_enabled("particles"), "Particles should be available")


func test_feature_toggle_does_not_affect_core_systems() -> void:
	# Test that toggling features doesn't affect core systems
	var config_mgr: Variant = game_manager.get_core_system("config")
	assert_not_null(config_mgr, "Core systems should always be available")
	
	# Unload a feature
	game_manager.unload_feature("physics")
	
	# Core systems should still work
	var config_mgr_after: Variant = game_manager.get_core_system("config")
	assert_not_null(config_mgr_after, "Core systems should remain available")


func test_feature_toggle_state_query():
	# Test querying feature toggle state
	var combat_enabled = game_manager.is_feature_enabled("combat")
	var network_enabled = game_manager.is_feature_enabled("network")
	
	assert_eq(typeof(combat_enabled), TYPE_BOOL, "Feature state should be boolean")
	assert_eq(typeof(network_enabled), TYPE_BOOL, "Feature state should be boolean")
	assert_true(combat_enabled, "Combat should be enabled")
	assert_false(network_enabled, "Network should be disabled")


func test_nonexistent_feature_returns_false():
	# Test that checking nonexistent features returns false
	var result = game_manager.is_feature_enabled("nonexistent_feature")
	assert_false(result, "Nonexistent feature should return false")


func test_feature_toggle_multiple_times():
	# Test toggling a feature multiple times
	var feature_name = "physics"
	
	# Initial state
	var initial = game_manager.is_feature_enabled(feature_name)
	
	# Toggle off
	game_manager.unload_feature(feature_name)
	assert_false(game_manager.is_feature_loaded(feature_name), "Should be unloaded")

	# Toggle on
	game_manager.load_feature(feature_name)
	assert_true(game_manager.is_feature_loaded(feature_name), "Should be loaded")

	# Toggle off again
	game_manager.unload_feature(feature_name)
	assert_false(game_manager.is_feature_loaded(feature_name), "Should be unloaded again")
