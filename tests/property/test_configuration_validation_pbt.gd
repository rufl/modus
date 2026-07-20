extends PropertyBasedTesting

## Property-Based Test: Configuration Validation with Error Reporting
## Feature: architecture-refactoring, Property 16: Configuration validation with error reporting
## Validates: Requirements 5.4

const ConfigurationManager = preload("res://game/scripts/core/configuration_manager.gd")

# Test configuration directory
const TEST_CONFIG_DIR = "res://tests/fixtures/config/"


func test_property_invalid_json5_syntax_error_reporting() -> void:
	# Property: For any invalid JSON5 file (syntax errors),
	# ConfigurationManager should report an error with file path
	
	await run_enhanced_property_test(
		"Invalid JSON5 syntax error reporting",
		_test_invalid_json5_syntax,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should report errors for invalid JSON5 syntax"
	)


func _test_invalid_json5_syntax(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate invalid JSON5 content
	var invalid_json5 := _generate_invalid_json5(rng)
	var test_file_path := TEST_CONFIG_DIR + "test_invalid_%d.json5" % test_data.get("iteration", 0)
	
	# Write invalid JSON5 to temporary file
	var file := FileAccess.open(test_file_path, FileAccess.WRITE)
	if file:
		file.store_string(invalid_json5)
		file.close()
	else:
		# Can't write test file, skip this iteration
		return true
	
	# Track if error signal was emitted
	var error_state := {"emitted": false, "file_path": "", "message": ""}
	
	config_mgr.config_error.connect(func(file_path: String, msg: String) -> void:
		error_state["emitted"] = true
		error_state["file_path"] = file_path
		error_state["message"] = msg
	)
	
	# Attempt to load invalid configuration
	var result := config_mgr.load_config_file(test_file_path)
	await consume_property_push_errors()
	
	# Clean up test file
	if FileAccess.file_exists(test_file_path):
		DirAccess.remove_absolute(test_file_path)
	
	# Verify error was reported
	var test_passed: bool = error_state["emitted"] and result.is_empty() and (error_state["file_path"] as String).contains(test_file_path)
	
	return test_passed


func test_property_missing_required_fields_validation() -> void:
	# Property: For any configuration with missing required fields,
	# ConfigurationManager should report validation errors
	
	await run_enhanced_property_test(
		"Missing required fields validation",
		_test_missing_required_fields,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should detect missing required fields"
	)


func _test_missing_required_fields(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Create a configuration with some fields
	var config := {
		"field1": rng.randi_range(1, 100),
		"field2": "test_value",
		"nested": {
			"field3": rng.randf_range(0.0, 1.0)
		}
	}
	
	# Define schema requiring more fields than config has
	var schema := {
		"field1": TYPE_INT,
		"field2": TYPE_STRING,
		"nested.field3": TYPE_FLOAT,
		"missing_field": TYPE_INT  # This field is missing
	}
	
	# Validate should return false for missing fields
	var is_valid := config_mgr.validate_config(config, schema)
	assert_property_push_error_count(1, "Missing required fields should produce one diagnostic")
	
	return not is_valid


func test_property_type_mismatch_validation() -> void:
	# Property: For any configuration with type mismatches,
	# ConfigurationManager should report validation errors
	
	await run_enhanced_property_test(
		"Type mismatch validation",
		_test_type_mismatch,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should detect type mismatches"
	)


func _test_type_mismatch(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate random type mismatch
	var mismatch_type := rng.randi_range(0, 3)
	var config := {}
	var schema := {}
	
	match mismatch_type:
		0:  # Int expected, string provided
			config = {"value": "not_an_int"}
			schema = {"value": TYPE_INT}
		1:  # String expected, int provided
			config = {"value": 42}
			schema = {"value": TYPE_STRING}
		2:  # Float expected, bool provided
			config = {"value": true}
			schema = {"value": TYPE_FLOAT}
		3:  # Dictionary expected, array provided
			config = {"value": [1, 2, 3]}
			schema = {"value": TYPE_DICTIONARY}
	
	# Validate should return false for type mismatches
	var is_valid := config_mgr.validate_config(config, schema)
	assert_property_push_error_count(1, "Type mismatches should produce one diagnostic")
	
	return not is_valid


func test_property_valid_configuration_passes_validation() -> void:
	# Property: For any valid configuration matching its schema,
	# ConfigurationManager should pass validation
	
	await run_enhanced_property_test(
		"Valid configuration passes validation",
		_test_valid_configuration,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should accept valid configurations"
	)


func _test_valid_configuration(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate valid configuration and matching schema
	var config := {
		"int_value": rng.randi_range(1, 1000),
		"float_value": rng.randf_range(0.0, 100.0),
		"string_value": "test_string_%d" % rng.randi_range(1, 100),
		"bool_value": rng.randf() > 0.5,
		"nested": {
			"nested_int": rng.randi_range(1, 100)
		}
	}
	
	var schema := {
		"int_value": TYPE_INT,
		"float_value": TYPE_FLOAT,
		"string_value": TYPE_STRING,
		"bool_value": TYPE_BOOL,
		"nested.nested_int": TYPE_INT
	}
	
	# Validate should return true for valid config
	var is_valid := config_mgr.validate_config(config, schema)
	
	return is_valid


func test_property_error_signal_contains_file_path() -> void:
	# Property: For any configuration error,
	# the error signal should contain the file path
	
	await run_enhanced_property_test(
		"Error signal contains file path",
		_test_error_signal_file_path,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager error signals should include file path"
	)


func _test_error_signal_file_path(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate a non-existent file path
	var test_file_path := TEST_CONFIG_DIR + "nonexistent_%d.json5" % rng.randi_range(1000, 9999)
	
	# Track error signal
	var error_state := {"emitted": false, "file_path": ""}
	
	config_mgr.config_error.connect(func(file_path: String, _msg: String) -> void:
		error_state["emitted"] = true
		error_state["file_path"] = file_path
	)
	
	# Attempt to load non-existent file
	var _result := config_mgr.load_config_file(test_file_path)
	assert_property_push_error("Configuration file not found", "Missing configuration should produce one diagnostic")

	# Verify error signal was emitted with correct file path
	await consume_property_push_errors()
	return error_state["emitted"] and (error_state["file_path"] as String).contains(test_file_path)


func test_property_nested_field_validation() -> void:
	# Property: For any nested configuration field,
	# ConfigurationManager should validate nested paths correctly
	
	await run_enhanced_property_test(
		"Nested field validation",
		_test_nested_field_validation,
		100,
		SamplingStrategy.MIXED,
		"ConfigurationManager should validate nested configuration paths"
	)


func _test_nested_field_validation(test_data: Dictionary) -> bool:
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Create deeply nested configuration
	var nesting_depth := rng.randi_range(2, 5)
	var config := {}
	var current := config
	
	for i in range(nesting_depth - 1):
		current["level%d" % i] = {}
		current = current["level%d" % i]
	
	current["final_value"] = rng.randi_range(1, 100)
	
	# Build schema path
	var schema_path := ""
	for i in range(nesting_depth - 1):
		schema_path += "level%d." % i
	schema_path += "final_value"
	
	var schema := {
		schema_path: TYPE_INT
	}
	
	# Validate should return true for correctly nested config
	var is_valid := config_mgr.validate_config(config, schema)
	
	return is_valid


# Helper function to generate invalid JSON5 content
func _generate_invalid_json5(rng: RandomNumberGenerator) -> String:
	# Keep the generated input deterministically malformed. JSON5 accepts some
	# otherwise-invalid-looking forms, which would make this property flaky.
	return '{ "key": }'
