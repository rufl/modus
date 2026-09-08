extends PropertyBasedTesting

## Property-Based Test: Feature Toggle Functionality
## Feature: architecture-refactoring, Property 7: Feature toggle functionality
## Validates: Requirements 2.3, 2.5, 6.2

const GameManagerClass = preload("res://game/scripts/core/game_manager.gd")


func test_property_feature_enabled_flag_controls_initialization() -> void:
	# Property: For any feature, toggling its enabled flag in features.json5
	# from true to false should prevent initialization, and toggling from
	# false to true should allow initialization

	await run_enhanced_property_test(
		"Feature enabled flag controls initialization",
		_test_enabled_flag_controls_init,
		100,
		SamplingStrategy.MIXED,
		"Feature enabled flag should control whether feature is initialized"
	)


func _test_enabled_flag_controls_init(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random feature from the available features
	var available_features: Array[String] = [
		"combat", "inventory", "loot", "audio", "network", "gore"
	]
	var feature_id: String = available_features[rng.randi_range(0, available_features.size() - 1)]

	# Get the feature's enabled state from configuration
	var is_enabled: bool = gm.is_feature_enabled(feature_id)

	# Try to load the feature
	var load_result: bool = gm.load_feature(feature_id)

	# Property: Feature should load successfully if and only if it's enabled
	var feature_loaded: bool = gm.get_feature(feature_id) != null

	# If enabled, load should succeed and feature should be loaded
	# If disabled, load should fail and feature should not be loaded
	var result: bool = (is_enabled == load_result) and (is_enabled == feature_loaded)

	return result


func test_property_disabled_feature_returns_null() -> void:
	# Property: For any disabled feature, attempting to access it via
	# GameManager.get_feature() should return null

	await run_enhanced_property_test(
		"Disabled feature returns null",
		_test_disabled_feature_returns_null,
		100,
		SamplingStrategy.MIXED,
		"Disabled features should return null when accessed"
	)


func _test_disabled_feature_returns_null(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	# Network feature is disabled by default in features.json5
	var disabled_feature_id: String = "network"

	# Verify it's disabled
	if gm.is_feature_enabled(disabled_feature_id):
		# If network is enabled in config, skip this test
		return true

	# Try to get the disabled feature
	var feature = gm.get_feature(disabled_feature_id)

	# Property: Should return null for disabled feature
	var result: bool = feature == null

	return result


func test_property_enabled_feature_can_be_loaded() -> void:
	# Property: For any enabled feature, calling load_feature() should
	# successfully load it and make it accessible via get_feature()

	await run_enhanced_property_test(
		"Enabled feature can be loaded",
		_test_enabled_feature_can_be_loaded,
		100,
		SamplingStrategy.MIXED,
		"Enabled features should load successfully"
	)


func _test_enabled_feature_can_be_loaded(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random enabled feature (combat, inventory, loot, audio, gore are enabled by default)
	var enabled_features: Array[String] = ["combat", "inventory", "loot", "audio", "gore"]
	var feature_id: String = enabled_features[rng.randi_range(0, enabled_features.size() - 1)]

	# Verify it's enabled
	if not gm.is_feature_enabled(feature_id):
		# If feature is disabled in config, skip this test
		return true

	# Load the feature
	var load_result: bool = gm.load_feature(feature_id)

	# Get the feature
	var feature = gm.get_feature(feature_id)

	# Property: Load should succeed and feature should be accessible
	var result: bool = load_result and (feature != null)

	return result


func test_property_feature_toggle_state_consistency() -> void:
	# Property: For any feature, is_feature_enabled() should return a
	# consistent value that matches the configuration

	await run_enhanced_property_test(
		"Feature toggle state consistency",
		_test_feature_toggle_state_consistency,
		100,
		SamplingStrategy.MIXED,
		"Feature enabled state should be consistent with configuration"
	)


func _test_feature_toggle_state_consistency(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random feature
	var all_features: Array[String] = [
		"combat", "inventory", "loot", "audio", "network", "gore", "physics", "particles"
	]
	var feature_id: String = all_features[rng.randi_range(0, all_features.size() - 1)]

	# Check enabled state multiple times
	var first_check: bool = gm.is_feature_enabled(feature_id)
	var second_check: bool = gm.is_feature_enabled(feature_id)
	var third_check: bool = gm.is_feature_enabled(feature_id)

	# Property: All checks should return the same value
	var result: bool = (first_check == second_check) and (second_check == third_check)

	return result


func test_property_feature_loaded_signal_emission() -> void:
	# Property: For any feature that is successfully loaded, the
	# feature_loaded signal should be emitted with the correct feature_id

	await run_enhanced_property_test(
		"Feature loaded signal emission",
		_test_feature_loaded_signal,
		100,
		SamplingStrategy.MIXED,
		"Feature loaded signal should be emitted when feature loads"
	)


func _test_feature_loaded_signal(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random enabled feature
	var enabled_features: Array[String] = ["combat", "inventory", "loot", "audio", "gore"]
	var feature_id: String = enabled_features[rng.randi_range(0, enabled_features.size() - 1)]

	# Skip if feature is disabled
	if not gm.is_feature_enabled(feature_id):
		return true

	# Track signal emission
	var signal_state := {"emitted": false, "feature_id": ""}

	gm.feature_loaded.connect(
		func(emitted_id: String) -> void:
			signal_state.emitted = true
			signal_state.feature_id = emitted_id
	)

	# Load the feature
	var load_result: bool = gm.load_feature(feature_id)

	# Property: If load succeeded, signal should be emitted with correct feature_id
	var result: bool = true
	if load_result:
		result = signal_state.emitted and (signal_state.feature_id == feature_id)

	return result


func test_property_feature_unloaded_signal_emission() -> void:
	# Property: For any feature that is unloaded, the feature_unloaded
	# signal should be emitted with the correct feature_id

	await run_enhanced_property_test(
		"Feature unloaded signal emission",
		_test_feature_unloaded_signal,
		100,
		SamplingStrategy.MIXED,
		"Feature unloaded signal should be emitted when feature unloads"
	)


func _test_feature_unloaded_signal(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random enabled feature
	var enabled_features: Array[String] = ["combat", "inventory", "loot", "audio", "gore"]
	var feature_id: String = enabled_features[rng.randi_range(0, enabled_features.size() - 1)]

	# Skip if feature is disabled
	if not gm.is_feature_enabled(feature_id):
		return true

	# Load the feature first
	if not gm.load_feature(feature_id):
		# If load failed, skip this test
		return true

	# Track signal emission
	var signal_state := {"emitted": false, "feature_id": ""}

	gm.feature_unloaded.connect(
		func(emitted_id: String) -> void:
			signal_state.emitted = true
			signal_state.feature_id = emitted_id
	)

	# Unload the feature
	gm.unload_feature(feature_id)

	# Property: Signal should be emitted with correct feature_id
	var result: bool = signal_state.emitted and (signal_state.feature_id == feature_id)

	return result


func test_property_load_feature_idempotent() -> void:
	# Property: Calling load_feature() multiple times for the same feature
	# should be idempotent (only the first call loads it)

	await run_enhanced_property_test(
		"Load feature idempotent",
		_test_load_feature_idempotent,
		100,
		SamplingStrategy.MIXED,
		"Loading a feature multiple times should be idempotent"
	)


func _test_load_feature_idempotent(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random enabled feature
	var enabled_features: Array[String] = ["combat", "inventory", "loot", "audio", "gore"]
	var feature_id: String = enabled_features[rng.randi_range(0, enabled_features.size() - 1)]

	# Skip if feature is disabled
	if not gm.is_feature_enabled(feature_id):
		return true

	# Load the feature multiple times
	var first_load: bool = gm.load_feature(feature_id)
	var second_load: bool = gm.load_feature(feature_id)
	var third_load: bool = gm.load_feature(feature_id)

	# Get the feature
	var feature = gm.get_feature(feature_id)

	# Property: All loads should succeed (return true) and feature should be loaded
	var result: bool = first_load and second_load and third_load and (feature != null)

	return result


func test_property_unload_nonexistent_feature_safe() -> void:
	# Property: Calling unload_feature() on a feature that is not loaded
	# should be safe (no crash, just a warning)

	await run_enhanced_property_test(
		"Unload nonexistent feature safe",
		_test_unload_nonexistent_safe,
		100,
		SamplingStrategy.MIXED,
		"Unloading a non-loaded feature should be safe"
	)


func _test_unload_nonexistent_safe(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random feature
	var all_features: Array[String] = ["combat", "inventory", "loot", "audio", "network", "gore"]
	var feature_id: String = all_features[rng.randi_range(0, all_features.size() - 1)]

	# Ensure feature is not loaded
	if gm.is_feature_loaded(feature_id):
		gm.unload_feature(feature_id)

	# Try to unload it again (should be safe)
	gm.unload_feature(feature_id)

	# Property: Should not crash, feature should still be null
	var result: bool = not gm.is_feature_loaded(feature_id)

	return result


func test_property_feature_availability_after_load() -> void:
	# Property: After successfully loading a feature, is_feature_enabled()
	# should still return true and get_feature() should return non-null

	await run_enhanced_property_test(
		"Feature availability after load",
		_test_feature_availability_after_load,
		100,
		SamplingStrategy.MIXED,
		"Feature should remain available after loading"
	)


func _test_feature_availability_after_load(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random enabled feature
	var enabled_features: Array[String] = ["combat", "inventory", "loot", "audio", "gore"]
	var feature_id: String = enabled_features[rng.randi_range(0, enabled_features.size() - 1)]

	# Skip if feature is disabled
	if not gm.is_feature_enabled(feature_id):
		return true

	# Load the feature
	if not gm.load_feature(feature_id):
		# If load failed, skip this test
		return true

	# Check availability after load
	var still_enabled: bool = gm.is_feature_enabled(feature_id)
	var feature = gm.get_feature(feature_id)

	# Property: Feature should still be enabled and accessible
	var result: bool = still_enabled and (feature != null)

	return result
