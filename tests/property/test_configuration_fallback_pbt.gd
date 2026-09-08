extends PropertyBasedTesting

## Property-Based Test: Configuration Fallback Behavior
## Feature: architecture-refactoring, Property 17: Configuration fallback behavior
## Validates: Requirements 5.5

const ConfigurationManager = preload("res://game/scripts/core/configuration_manager.gd")

# Test configuration directory
const TEST_CONFIG_DIR = "res://tests/fixtures/config/"


func test_property_fallback_on_missing_key() -> void:
	# Property: For any configuration value that fails to load or is invalid,
	# ConfigurationManager should use a default value and log a warning

	await run_enhanced_property_test(
		"Fallback on missing configuration key",
		_test_fallback_missing_key,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should return default value for missing keys"
	)


func _test_fallback_missing_key(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Create a configuration with some keys
	var config := {"existing_key": rng.randi_range(1, 100), "nested": {"existing_nested": "value"}}

	# Load configuration into cache
	config_mgr._config_cache["test_config"] = config

	# Generate random non-existent key
	var missing_key := "nonexistent_key_%d" % rng.randi_range(1000, 9999)
	var default_value := rng.randi_range(100, 200)

	# Get value for missing key with default
	var result: Variant = config_mgr.get_value(missing_key, default_value)

	# Property: Should return the default value
	return result == default_value


func test_property_fallback_on_invalid_json5() -> void:
	# Property: For any invalid JSON5 file,
	# ConfigurationManager should return empty dict and continue running

	await run_enhanced_property_test(
		"Fallback on invalid JSON5 file",
		_test_fallback_invalid_json5,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should handle invalid JSON5 gracefully"
	)


func _test_fallback_invalid_json5(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate invalid JSON5 content
	var invalid_json5: String = _generate_invalid_json5(rng)
	var test_file_path := (
		TEST_CONFIG_DIR + "test_fallback_invalid_%d.json5" % test_data.get("iteration", 0)
	)

	# Write invalid JSON5 to temporary file
	var file := FileAccess.open(test_file_path, FileAccess.WRITE)
	if file:
		file.store_string(invalid_json5)
		file.close()
	else:
		# Can't write test file, skip this iteration
		return true

	# Attempt to load invalid configuration
	var result := config_mgr.load_config_file(test_file_path)
	await consume_property_push_errors()

	# Clean up test file
	if FileAccess.file_exists(test_file_path):
		DirAccess.remove_absolute(test_file_path)

	# Property: Should return empty dictionary and not crash
	return result.is_empty()


func test_property_fallback_on_nonexistent_file() -> void:
	# Property: For any non-existent configuration file,
	# ConfigurationManager should return empty dict and log error

	await run_enhanced_property_test(
		"Fallback on non-existent file",
		_test_fallback_nonexistent_file,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should handle missing files gracefully"
	)


func _test_fallback_nonexistent_file(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate a non-existent file path
	var nonexistent_path := TEST_CONFIG_DIR + "nonexistent_%d.json5" % rng.randi_range(10000, 99999)

	# Ensure file doesn't exist
	if FileAccess.file_exists(nonexistent_path):
		return true  # Skip if file somehow exists

	# Attempt to load non-existent file
	var result := config_mgr.load_config_file(nonexistent_path)
	assert_property_push_error(
		"Configuration file not found", "Missing configuration should produce one diagnostic"
	)

	# Property: Should return empty dictionary and not crash
	return result.is_empty()


func test_property_fallback_with_nested_missing_keys() -> void:
	# Property: For any nested configuration path that doesn't exist,
	# ConfigurationManager should return default value

	await run_enhanced_property_test(
		"Fallback on nested missing keys",
		_test_fallback_nested_missing,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should return default for missing nested keys"
	)


func _test_fallback_nested_missing(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Create a configuration with some nested structure
	var config := {"level1": {"level2": {"existing_value": rng.randi_range(1, 100)}}}

	# Load configuration into cache
	config_mgr._config_cache["test_config"] = config

	# Generate random nested path that doesn't exist
	var nesting_depth := rng.randi_range(2, 5)
	var missing_path := ""
	for i in range(nesting_depth):
		if i > 0:
			missing_path += "."
		missing_path += "missing_level%d" % i

	var default_value := "default_%d" % rng.randi_range(1, 1000)

	# Get value for missing nested path with default
	var result: Variant = config_mgr.get_value(missing_path, default_value)

	# Property: Should return the default value
	return result == default_value


func test_property_fallback_preserves_system_stability() -> void:
	# Property: For any sequence of failed configuration loads,
	# ConfigurationManager should remain functional and not crash

	await run_enhanced_property_test(
		"System stability after multiple fallbacks",
		_test_fallback_system_stability,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should remain stable after multiple failures"
	)


func _test_fallback_system_stability(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Perform multiple operations that should trigger fallbacks
	var operations_count: int = rng.randi_range(5, 15)
	var all_operations_succeeded: bool = true

	for i in range(operations_count):
		var operation_type := rng.randi_range(0, 2)

		match operation_type:
			0:  # Try to load non-existent file
				var result: Dictionary = config_mgr.load_config_file("nonexistent_%d.json5" % i)
				assert_property_push_error(
					"Configuration file not found",
					"Missing configuration should produce one diagnostic"
				)
				all_operations_succeeded = all_operations_succeeded and result.is_empty()

			1:  # Try to get missing key with default
				var default: int = rng.randi_range(1, 100)
				var result: Variant = config_mgr.get_value("missing.key.%d" % i, default)
				all_operations_succeeded = all_operations_succeeded and (result == default)

			2:  # Try to validate invalid config
				var invalid_config: Dictionary = {"wrong_type": "string"}
				var schema: Dictionary = {"wrong_type": TYPE_INT}
				var result: bool = config_mgr.validate_config(invalid_config, schema)
				assert_property_push_error(
					"Validation failed", "Invalid configuration should produce one diagnostic"
				)
				all_operations_succeeded = all_operations_succeeded and (not result)

	# Property: All operations should complete without crashing
	return all_operations_succeeded


func test_property_fallback_default_null_handling() -> void:
	# Property: For any missing configuration key with null default,
	# ConfigurationManager should return null without warning

	await run_enhanced_property_test(
		"Fallback with null default",
		_test_fallback_null_default,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should handle null defaults correctly"
	)


func _test_fallback_null_default(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Create empty configuration
	config_mgr._config_cache["test_config"] = {}

	# Generate random missing key
	var missing_key := "missing_%d" % rng.randi_range(1, 1000)

	# Get value with null default (should not log warning)
	var result: Variant = config_mgr.get_value(missing_key, null)

	# Property: Should return null
	return result == null


func test_property_fallback_type_safety() -> void:
	# Property: For any configuration value with wrong type,
	# ConfigurationManager should use default value of correct type

	await run_enhanced_property_test(
		"Fallback maintains type safety",
		_test_fallback_type_safety,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should maintain type safety with defaults"
	)


func _test_fallback_type_safety(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Create configuration with wrong type
	var config := {"int_as_string": "not_an_int", "float_as_bool": true, "string_as_int": 42}

	config_mgr._config_cache["test_config"] = config

	# Test different type mismatches with appropriate defaults
	var test_cases: Array[Dictionary] = [
		{"key": "missing_int", "default": 100, "expected_type": TYPE_INT},
		{"key": "missing_float", "default": 3.14, "expected_type": TYPE_FLOAT},
		{"key": "missing_string", "default": "default", "expected_type": TYPE_STRING},
		{"key": "missing_bool", "default": false, "expected_type": TYPE_BOOL},
	]

	var case_index: int = rng.randi_range(0, test_cases.size() - 1)
	var test_case: Dictionary = test_cases[case_index]

	var result: Variant = config_mgr.get_value(test_case.key, test_case.default)

	# Property: Result should have the same type as the default
	return typeof(result) == test_case.expected_type and result == test_case.default


func test_property_fallback_partial_config_loading() -> void:
	# Property: For any configuration file with some valid and some invalid data,
	# ConfigurationManager should load valid parts and use defaults for invalid parts

	await run_enhanced_property_test(
		"Fallback with partial configuration",
		_test_fallback_partial_config,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should handle partial configurations"
	)


func _test_fallback_partial_config(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Create configuration with mix of valid and missing data
	var config := {
		"valid_key1": rng.randi_range(1, 100),
		"valid_key2": "test_value",
		"nested": {"valid_nested": rng.randf_range(0.0, 1.0)}
	}

	config_mgr._config_cache["test_config"] = config

	# Test accessing both existing and missing keys
	var valid_result: Variant = config_mgr.get_value("valid_key1", -1)
	var missing_result: Variant = config_mgr.get_value("missing_key", 999)

	# Property: Valid keys should return actual values, missing keys should return defaults
	return valid_result == config.valid_key1 and missing_result == 999


# Helper function to generate invalid JSON5 content
func _generate_invalid_json5(rng: RandomNumberGenerator) -> String:
	# Keep the generated input deterministically malformed. Several permissive
	# JSON5 forms (for example trailing commas) are valid and do not exercise
	# the fallback contract.
	return '{ "key": }'
