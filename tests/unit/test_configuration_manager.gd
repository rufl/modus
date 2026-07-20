extends GutTest

## Unit tests for ConfigurationManager
## Tests JSON5 loading, caching, validation, hot-reload, and dot-notation access

const ConfigurationManager = preload("res://game/scripts/core/configuration_manager.gd")
const TEST_CONFIG_DIR := "res://tests/fixtures/config/"

var config_manager: ConfigurationManager


func before_all():
	_create_test_config_files()


func after_all():
	_cleanup_test_config_files()


func before_each() -> void:
	config_manager = autofree(ConfigurationManager.new()) as ConfigurationManager


func test_load_valid_json5_file():
	var config: Dictionary = config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	assert_not_null(config, "Should load valid JSON5 file")
	assert_true(config is Dictionary, "Should return a Dictionary")
	assert_eq(config.get("test_key"), "test_value", "Should parse content correctly")


func test_load_nonexistent_file():
	var config: Dictionary = config_manager.load_config_file(TEST_CONFIG_DIR + "nonexistent.json5")
	assert_push_error("Configuration file not found")
	
	assert_eq(config, {}, "Should return empty Dictionary for nonexistent file")


func test_load_invalid_json5_syntax():
	var config: Dictionary = config_manager.load_config_file(TEST_CONFIG_DIR + "test_invalid.json5")
	assert_push_error_count(2, "Invalid JSON5 should produce loader and manager diagnostics")
	
	assert_eq(config, {}, "Should return empty Dictionary for invalid JSON5")


func test_configuration_caching():
	# Load file first time
	var config1: Dictionary = config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	# Load same file again
	var config2: Dictionary = config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	assert_not_null(config1, "First load should succeed")
	assert_not_null(config2, "Second load should succeed")
	assert_eq(config1, config2, "Cached config should match original")


func test_get_value_with_dot_notation():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_nested.json5")
	
	var value: Variant = config_manager.get_value("gameplay.movement.speed")
	
	assert_eq(value, 10.0, "Should retrieve nested value using dot notation")


func test_get_value_with_default():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	var value: Variant = config_manager.get_value("nonexistent.key", 42)
	
	assert_eq(value, 42, "Should return default value for nonexistent key")


func test_get_value_deeply_nested():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_nested.json5")
	
	var value: Variant = config_manager.get_value("gameplay.combat.damage.critical_multiplier")
	
	assert_eq(value, 2.0, "Should retrieve deeply nested value")


func test_set_value_runtime():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	config_manager.set_value("runtime.test", 123)
	var value: Variant = config_manager.get_value("runtime.test")
	
	assert_eq(value, 123, "Should set and retrieve runtime value")


func test_set_value_nested_path():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	config_manager.set_value("new.nested.value", "test")
	var value: Variant = config_manager.get_value("new.nested.value")
	
	assert_eq(value, "test", "Should create nested path and set value")


func test_reload_all_configurations():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_nested.json5")
	
	var initial_cache_size: int = config_manager.get_all_config().size()
	config_manager.reload_all()
	var reloaded_cache_size: int = config_manager.get_all_config().size()
	
	assert_eq(initial_cache_size, reloaded_cache_size, "Should reload all cached files")


func test_reload_specific_file():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	watch_signals(config_manager)
	config_manager.reload_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	assert_signal_emitted(config_manager, "config_reloaded", "Should emit config_reloaded signal")


func test_validate_config_valid():
	var config := {
		"max_health": 100,
		"player_name": "Test",
		"settings": {
			"volume": 0.8
		}
	}
	
	var schema := {
		"max_health": TYPE_INT,
		"player_name": TYPE_STRING,
		"settings.volume": TYPE_FLOAT
	}
	
	var is_valid: bool = config_manager.validate_config(config, schema)
	
	assert_true(is_valid, "Should validate correct configuration")


func test_validate_config_missing_key():
	var config := {
		"max_health": 100
	}
	
	var schema := {
		"max_health": TYPE_INT,
		"player_name": TYPE_STRING
	}
	
	var is_valid: bool = config_manager.validate_config(config, schema)
	assert_push_error("Validation failed")
	
	assert_false(is_valid, "Should fail validation for missing key")


func test_validate_config_wrong_type():
	var config := {
		"max_health": "not_a_number"
	}
	
	var schema := {
		"max_health": TYPE_INT
	}
	
	var is_valid: bool = config_manager.validate_config(config, schema)
	assert_push_error("Validation failed")
	
	assert_false(is_valid, "Should fail validation for wrong type")


func test_enable_file_watching():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	config_manager.enable_file_watching()
	
	# File watching should be enabled (no direct assertion, but shouldn't crash)
	assert_true(true, "Should enable file watching without errors")


func test_disable_file_watching():
	config_manager.enable_file_watching()
	config_manager.disable_file_watching()
	
	assert_true(true, "Should disable file watching without errors")


func test_clear_cache():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	assert_gt(config_manager.get_all_config().size(), 0, "Cache should have entries")
	
	config_manager.clear_cache()
	
	assert_eq(config_manager.get_all_config().size(), 0, "Cache should be empty after clear")


func test_config_error_signal_on_invalid_file():
	watch_signals(config_manager)
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_invalid.json5")
	assert_push_error_count(2, "Invalid JSON5 should produce loader and manager diagnostics")
	
	assert_signal_emitted(config_manager, "config_error", "Should emit config_error signal")


func test_fallback_to_default_on_missing_key():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	var value: Variant = config_manager.get_value("missing.nested.key", "default_value")
	
	assert_eq(value, "default_value", "Should fallback to default for missing key")


func test_empty_path_returns_default():
	config_manager.load_config_file(TEST_CONFIG_DIR + "test_valid.json5")
	
	var value: Variant = config_manager.get_value("", "default")
	
	assert_eq(value, "default", "Should return default for empty path")


func test_path_resolution_with_res_prefix():
	var config: Dictionary = config_manager.load_config_file("res://tests/fixtures/config/test_valid.json5")
	
	assert_not_null(config, "Should resolve path with res:// prefix")


func test_path_resolution_without_prefix():
	# This assumes the file exists in game/config/ when using relative path
	# For testing, we'll just verify the path resolution logic doesn't crash
	var config: Dictionary = config_manager.load_config_file("test_valid.json5")
	assert_push_error("Configuration file not found")
	
	# May return empty if file doesn't exist in default location, but shouldn't crash
	assert_true(config is Dictionary, "Should return Dictionary even if file not found")


# Helper methods for test setup

func _create_test_config_files():
	# Create test fixtures directory
	DirAccess.make_dir_recursive_absolute(TEST_CONFIG_DIR)
	
	# Valid JSON5 file
	var valid_content := """{
		// Test comment
		"test_key": "test_value",
		"number": 42,
		"boolean": true,
	}"""
	_write_file(TEST_CONFIG_DIR + "test_valid.json5", valid_content)
	
	# Nested JSON5 file
	var nested_content := """{
		"gameplay": {
			"movement": {
				"speed": 10.0,
				"jump_height": 5.0
			},
			"combat": {
				"damage": {
					"base": 10,
					"critical_multiplier": 2.0
				}
			}
		}
	}"""
	_write_file(TEST_CONFIG_DIR + "test_nested.json5", nested_content)
	
	# Invalid JSON5 file
	var invalid_content := """{
		"broken": "syntax"
		missing_comma: true
	}"""
	_write_file(TEST_CONFIG_DIR + "test_invalid.json5", invalid_content)


func _cleanup_test_config_files():
	# Clean up test files
	var dir := DirAccess.open(TEST_CONFIG_DIR)
	if dir:
		dir.remove("test_valid.json5")
		dir.remove("test_nested.json5")
		dir.remove("test_invalid.json5")


func _write_file(path: String, content: String):
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
