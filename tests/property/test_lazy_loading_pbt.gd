extends PropertyBasedTesting

## Property-Based Test: Lazy Loading Behavior
## Feature: architecture-refactoring, Property 34: Lazy loading behavior
## **Validates: Requirements 11.1**

const GameManagerClass = preload("res://game/scripts/core/game_manager.gd")


func test_property_features_not_loaded_until_accessed() -> void:
	# Property: For any feature module, it should not be initialized until
	# it is first accessed or explicitly loaded, reducing startup time

	await run_enhanced_property_test(
		"Features not loaded until accessed",
		_test_features_not_loaded_until_accessed,
		100,
		SamplingStrategy.MIXED,
		"Features should not be initialized during GameManager startup"
	)


func _test_features_not_loaded_until_accessed(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)

	# Initialize GameManager (should not load features yet)
	gm.initialize()

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random enabled feature
	var available_features: Array[String] = ["combat", "inventory", "loot", "audio"]
	var feature_id: String = available_features[rng.randi_range(0, available_features.size() - 1)]

	# Check if feature is enabled
	if not gm.is_feature_enabled(feature_id):
		# Skip if feature is not enabled
		return true

	# Property: Feature should NOT be loaded immediately after initialization
	var feature_before_access = gm._features.get(feature_id, null)
	var not_loaded_initially: bool = feature_before_access == null

	# Now access the feature (should trigger lazy loading)
	var feature_after_access = gm.get_feature(feature_id)

	# Property: Feature should be loaded after first access
	var loaded_after_access: bool = feature_after_access != null

	var result: bool = not_loaded_initially and loaded_after_access

	return result


func test_property_lazy_loading_reduces_startup_time() -> void:
	# Property: Lazy startup should defer non-core feature construction. Wall-clock
	# timing is covered by the performance evidence lane; per-iteration millisecond
	# comparisons are scheduler-sensitive and are not a correctness contract.

	await run_enhanced_property_test(
		"Lazy loading defers eager startup work",
		_test_lazy_loading_reduces_startup_time,
		50,
		SamplingStrategy.MIXED,
		"Lazy startup should construct fewer feature modules than eager startup"
	)


func _test_lazy_loading_reduces_startup_time(_test_data: Dictionary) -> bool:
	var gm_lazy: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm_lazy)
	gm_lazy.initialize()
	var lazy_feature_count: int = gm_lazy._features.size()

	var gm_eager: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm_eager)
	gm_eager.initialize()
	gm_eager.load_all_features()
	var eager_feature_count: int = gm_eager._features.size()

	return eager_feature_count > lazy_feature_count


func test_property_lazy_loaded_feature_same_as_eager() -> void:
	# Property: A feature loaded lazily should behave identically to
	# a feature loaded eagerly

	await run_enhanced_property_test(
		"Lazy loaded feature same as eager",
		_test_lazy_loaded_feature_same_as_eager,
		100,
		SamplingStrategy.MIXED,
		"Lazy and eager loaded features should be functionally identical"
	)


func _test_lazy_loaded_feature_same_as_eager(test_data: Dictionary) -> bool:
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random enabled feature
	var available_features: Array[String] = ["combat", "inventory", "loot", "audio"]
	var feature_id: String = available_features[rng.randi_range(0, available_features.size() - 1)]

	# Test lazy loading
	var gm_lazy: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm_lazy)
	gm_lazy.initialize()
	var lazy_feature = gm_lazy.get_feature(feature_id)

	# Test eager loading
	var gm_eager: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm_eager)
	gm_eager.initialize()
	gm_eager.load_all_features()
	var eager_feature = gm_eager.get_feature(feature_id)

	# Property: Both should have the same result (both loaded or both null)
	var result: bool = (lazy_feature == null) == (eager_feature == null)

	# If both loaded, they should both be valid Node instances
	if lazy_feature != null and eager_feature != null:
		result = result and (lazy_feature is Node) and (eager_feature is Node)


	return result


func test_property_multiple_accesses_dont_reload() -> void:
	# Property: Accessing a feature multiple times should not reload it,
	# it should return the same instance

	await run_enhanced_property_test(
		"Multiple accesses don't reload feature",
		_test_multiple_accesses_dont_reload,
		100,
		SamplingStrategy.MIXED,
		"Feature should only be loaded once, not on every access"
	)


func _test_multiple_accesses_dont_reload(test_data: Dictionary) -> bool:
	var gm: GameManagerClass = GameManagerClass.new()
	add_child_autofree(gm)
	gm.initialize()

	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Pick a random enabled feature
	var available_features: Array[String] = ["combat", "inventory", "loot", "audio"]
	var feature_id: String = available_features[rng.randi_range(0, available_features.size() - 1)]

	# Check if feature is enabled
	if not gm.is_feature_enabled(feature_id):
		return true

	# Access the feature multiple times
	var first_access = gm.get_feature(feature_id)
	var second_access = gm.get_feature(feature_id)
	var third_access = gm.get_feature(feature_id)

	# Property: All accesses should return the same instance
	var result: bool = (first_access == second_access) and (second_access == third_access)

	return result
