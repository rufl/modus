extends GutTest

# Unit tests for FeatureModule base class
# Requirements: 2.3, 2.4


# Test helper: Mock FeatureModule for testing
class MockFeatureModule:
	extends FeatureModule
	var initialize_called: bool = false
	var shutdown_called: bool = false
	var reload_config_called: bool = false

	func _init(id: String = "test_feature") -> void:
		super._init(id)

	func initialize() -> void:
		initialize_called = true
		super.initialize()

	func shutdown() -> void:
		shutdown_called = true
		super.shutdown()

	func reload_config() -> void:
		reload_config_called = true
		# Don't call super to avoid GameManager dependency in tests
		config = {}
		config_reloaded.emit()


func before_each() -> void:
	# Wait for autoloads to initialize
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	# Basic cleanup
	pass


func _feature(id: String = "test_feature") -> MockFeatureModule:
	return autofree(MockFeatureModule.new(id)) as MockFeatureModule


# =============================================================================
# INITIALIZATION TESTS
# =============================================================================


func test_feature_module_requires_id() -> void:
	# Creating a feature without an ID should log an error (but still work)
	# We expect this error, so we ignore it for the test
	gut.p("Creating feature with empty ID - error expected")
	var feature: MockFeatureModule = _feature("")
	assert_push_error("FeatureModule: feature_id cannot be empty")
	# The error is expected, so we just verify the ID is empty
	assert_eq(feature.feature_id, "", "Empty ID should be preserved")


func test_feature_module_sets_id_and_name() -> void:
	var feature: MockFeatureModule = _feature("combat")
	assert_eq(feature.feature_id, "combat", "Feature ID should be set")
	assert_eq(feature.feature_name, "Combat", "Feature name should be capitalized ID")


func test_feature_module_starts_uninitialized() -> void:
	var feature: MockFeatureModule = _feature("test")
	assert_false(feature.is_initialized(), "Feature should start uninitialized")


func test_feature_module_initialize_sets_flag() -> void:
	var feature: MockFeatureModule = _feature("test")
	feature.initialize()
	assert_true(feature.is_initialized(), "Feature should be initialized after initialize()")
	assert_true(feature.initialize_called, "Subclass initialize should be called")


func test_feature_module_initialize_emits_signal() -> void:
	var feature: MockFeatureModule = _feature("test")
	watch_signals(feature)

	feature.initialize()

	assert_signal_emitted(feature, "initialized")


func test_feature_module_double_initialize_warns() -> void:
	var feature: MockFeatureModule = _feature("test")
	feature.initialize()

	# Second initialization should warn but not crash
	feature.initialize()

	assert_true(feature.is_initialized(), "Feature should still be initialized")


# =============================================================================
# SHUTDOWN TESTS
# =============================================================================


func test_feature_module_shutdown_clears_flag() -> void:
	var feature: MockFeatureModule = _feature("test")
	feature.initialize()
	feature.shutdown()

	assert_false(feature.is_initialized(), "Feature should be uninitialized after shutdown()")
	assert_true(feature.shutdown_called, "Subclass shutdown should be called")


func test_feature_module_shutdown_emits_signal() -> void:
	var feature: MockFeatureModule = _feature("test")
	feature.initialize()
	watch_signals(feature)

	feature.shutdown()

	assert_signal_emitted(feature, "shutdown_complete")


func test_feature_module_shutdown_without_init() -> void:
	var feature: MockFeatureModule = _feature("test")

	# Shutting down without initialization should not crash
	feature.shutdown()

	assert_false(feature.is_initialized(), "Feature should remain uninitialized")


# =============================================================================
# CONFIGURATION TESTS
# =============================================================================


func test_feature_module_reload_config_emits_signal() -> void:
	var feature: MockFeatureModule = _feature("test")
	watch_signals(feature)

	feature.reload_config()

	assert_signal_emitted(feature, "config_reloaded")


func test_feature_module_get_config_value_with_default() -> void:
	var feature: MockFeatureModule = _feature("test")
	feature.config = {"max_health": 100, "speed": 5.0}

	assert_eq(feature.get_config_value("max_health"), 100, "Should return config value")
	assert_eq(feature.get_config_value("speed"), 5.0, "Should return float config value")
	assert_eq(
		feature.get_config_value("missing_key", 42), 42, "Should return default for missing key"
	)
	assert_null(
		feature.get_config_value("missing_key"), "Should return null when no default provided"
	)


# =============================================================================
# DEPENDENCY TESTS
# =============================================================================


func test_feature_module_declare_dependencies() -> void:
	var feature: MockFeatureModule = _feature("test")
	feature.declare_dependencies(["combat", "inventory"])

	assert_eq(feature.dependencies.size(), 2, "Should have 2 dependencies")
	assert_true(feature.dependencies.has("combat"), "Should have combat dependency")
	assert_true(feature.dependencies.has("inventory"), "Should have inventory dependency")


func test_feature_module_starts_with_no_dependencies() -> void:
	var feature: MockFeatureModule = _feature("test")
	assert_eq(feature.dependencies.size(), 0, "Should start with no dependencies")


func test_feature_module_validate_dependencies_with_no_deps() -> void:
	var feature: MockFeatureModule = _feature("test")

	# Feature with no dependencies should validate without GameManager.
	var result: bool = feature.validate_dependencies()
	assert_true(result, "A feature without dependencies should validate")


# =============================================================================
# LIFECYCLE INTEGRATION TESTS
# =============================================================================


func test_feature_module_full_lifecycle() -> void:
	var feature: MockFeatureModule = _feature("test")

	# Initial state
	assert_false(feature.is_initialized(), "Should start uninitialized")

	# Initialize
	feature.initialize()
	assert_true(feature.is_initialized(), "Should be initialized")
	assert_true(feature.initialize_called, "Initialize callback should be called")

	# Shutdown
	feature.shutdown()
	assert_false(feature.is_initialized(), "Should be uninitialized after shutdown")
	assert_true(feature.shutdown_called, "Shutdown callback should be called")


func test_feature_module_config_loaded_on_initialize() -> void:
	var feature: MockFeatureModule = _feature("test")

	feature.initialize()

	assert_true(feature.reload_config_called, "Config should be reloaded during initialization")


# =============================================================================
# EDGE CASE TESTS
# =============================================================================


func test_feature_module_empty_config() -> void:
	var feature: MockFeatureModule = _feature("test")
	feature.config = {}

	assert_null(feature.get_config_value("any_key"), "Empty config should return null")
	assert_eq(feature.get_config_value("any_key", "default"), "default", "Should use default value")


func test_feature_module_config_with_nested_values() -> void:
	var feature: MockFeatureModule = _feature("test")
	feature.config = {"combat": {"damage": 50, "range": 10.0}, "enabled": true}

	var combat_config: Dictionary = feature.get_config_value("combat", {})
	assert_eq(combat_config.get("damage"), 50, "Should retrieve nested dictionary")
	assert_eq(feature.get_config_value("enabled"), true, "Should retrieve boolean")


func test_feature_module_multiple_dependency_declarations() -> void:
	var feature: MockFeatureModule = _feature("test")

	feature.declare_dependencies(["dep1", "dep2"])
	assert_eq(feature.dependencies.size(), 2, "Should have 2 dependencies")

	# Declaring again should replace, not append
	feature.declare_dependencies(["dep3"])
	assert_eq(feature.dependencies.size(), 1, "Should have 1 dependency after redeclaration")
	assert_true(feature.dependencies.has("dep3"), "Should have new dependency")
	assert_false(feature.dependencies.has("dep1"), "Should not have old dependency")
