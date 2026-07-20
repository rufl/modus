extends GutTest

## Property Test: Configuration externalization completeness
## **Validates: Requirements 5.2**
##
## Property 15: For any hardcoded value identified by the analyzer,
## after refactoring it should be replaced with a configuration lookup
## (GameManager.get_config()) and the value should exist in a JSON5 file.

const ConfigExternalizer = preload("res://tools/refactoring/config_externalizer.gd")
const MagicNumberDetector = preload("res://tools/analyzer/magic_number_detector.gd")

var config_externalizer: ConfigExternalizer
var temp_dir: String = "user://test_config_externalization/"


func before_each() -> void:
	config_externalizer = ConfigExternalizer.new()
	
	# Create temp directory
	if not DirAccess.dir_exists_absolute(temp_dir):
		DirAccess.make_dir_recursive_absolute(temp_dir)


func after_each() -> void:
	# Clean up temp files
	_cleanup_temp_dir()


func test_property_externalization_completeness_simple_numeric() -> void:
	# Property: All identified hardcoded values should be externalized
	
	# Create a test script with hardcoded values
	var test_script := """
class_name TestScript
extends Node

var speed: float = 100.0
var max_health: int = 500
var damage_multiplier: float = 1.5

func calculate_damage(base_damage: float) -> float:
	return base_damage * 2.0
"""
	
	var test_file := temp_dir + "test_script.gd"
	_write_file(test_file, test_script)
	
	# Externalize configuration
	var result: ConfigExternalizer.ExternalizationResult = config_externalizer.externalize_config(test_file, "test")
	
	# Verify replacements were created
	assert_not_null(result, "Externalization result should not be null")
	assert_gt(result.replacements.size(), 0, "Should have found hardcoded values to replace")
	
	# Verify config entries were created for each replacement
	assert_eq(
		result.config_entries.size(),
		result.replacements.size(),
		"Each replacement should have a corresponding config entry"
	)
	
	# Verify modified content contains GameManager.get_config calls
	assert_string_contains(
		result.modified_content,
		"GameManager.get_config(",
		"Modified content should contain config lookups"
	)
	
	# Verify original values are preserved in config entries
	var has_100 := false
	var has_500 := false
	var has_1_5 := false
	var has_2_0 := false
	
	for config_path in result.config_entries.keys():
		var value = result.config_entries[config_path]
		if value == 100.0 or value == 100:
			has_100 = true
		elif value == 500:
			has_500 = true
		elif value == 1.5:
			has_1_5 = true
		elif value == 2.0:
			has_2_0 = true
	
	assert_true(has_100, "Should preserve value 100.0")
	assert_true(has_500, "Should preserve value 500")
	assert_true(has_1_5, "Should preserve value 1.5")
	assert_true(has_2_0, "Should preserve value 2.0")


func test_property_externalization_completeness_string_literals() -> void:
	# Property: String literals should also be externalized
	
	var test_script := """
extends Node

var player_name: String = "DefaultPlayer"
var weapon_type: String = "sword"

func get_message() -> String:
	return "Welcome to the game"
"""
	
	var test_file := temp_dir + "test_strings.gd"
	_write_file(test_file, test_script)
	
	var result: ConfigExternalizer.ExternalizationResult = config_externalizer.externalize_config(test_file, "test")
	
	assert_not_null(result, "Externalization result should not be null")
	assert_gt(result.replacements.size(), 0, "Should have found string literals")
	
	# Verify string values are in config entries
	var has_default_player := false
	var has_sword := false
	var has_welcome := false
	
	for config_path in result.config_entries.keys():
		var value = result.config_entries[config_path]
		if value == "DefaultPlayer":
			has_default_player = true
		elif value == "sword":
			has_sword = true
		elif value == "Welcome to the game":
			has_welcome = true
	
	assert_true(has_default_player, "Should preserve 'DefaultPlayer' string")
	assert_true(has_sword, "Should preserve 'sword' string")
	assert_true(has_welcome, "Should preserve 'Welcome to the game' string")


func test_property_externalization_preserves_excluded_values() -> void:
	# Property: Common values (0, 1, -1, true, false, null) should NOT be externalized
	
	var test_script := """
extends Node

var counter: int = 0
var enabled: bool = true
var disabled: bool = false
var multiplier: int = 1
var offset: int = -1
var reference = null
"""
	
	var test_file := temp_dir + "test_excluded.gd"
	_write_file(test_file, test_script)
	
	var result: ConfigExternalizer.ExternalizationResult = config_externalizer.externalize_config(test_file, "test")
	
	assert_not_null(result, "Externalization result should not be null")
	
	# Verify excluded values are NOT in config entries
	for config_path in result.config_entries.keys():
		var value = result.config_entries[config_path]
		assert_ne(value, 0, "Should not externalize 0")
		assert_ne(value, 1, "Should not externalize 1")
		assert_ne(value, -1, "Should not externalize -1")
		assert_ne(value, true, "Should not externalize true")
		assert_ne(value, false, "Should not externalize false")
		assert_ne(value, null, "Should not externalize null")


func test_property_externalization_generates_valid_config_paths() -> void:
	# Property: Generated config paths should be valid dot-notation paths
	
	var test_script := """
extends Node

var max_speed: float = 250.0
var jump_height: float = 10.0
"""
	
	var test_file := temp_dir + "test_paths.gd"
	_write_file(test_file, test_script)
	
	var result: ConfigExternalizer.ExternalizationResult = config_externalizer.externalize_config(test_file, "gameplay")
	
	assert_not_null(result, "Externalization result should not be null")
	
	# Verify all config paths are valid
	for config_path in result.config_entries.keys():
		assert_true(
			config_path is String and not config_path.is_empty(),
			"Config path should be a non-empty string"
		)
		assert_true(
			"." in config_path,
			"Config path should use dot notation: " + config_path
		)
		assert_true(
			config_path.begins_with("gameplay."),
			"Config path should start with prefix: " + config_path
		)


func test_property_externalization_multiple_files() -> void:
	# Property: Externalization should work across multiple files
	
	var script1 := """
extends Node
var value1: float = 42.0
"""
	
	var script2 := """
extends Node
var value2: int = 99
"""
	
	var file1 := temp_dir + "script1.gd"
	var file2 := temp_dir + "script2.gd"
	
	_write_file(file1, script1)
	_write_file(file2, script2)
	
	var results: Array = config_externalizer.externalize_multiple_files([file1, file2], "test")
	
	assert_eq(results.size(), 2, "Should process both files")
	
	var total_entries := 0
	for result in results:
		if result is ConfigExternalizer.ExternalizationResult:
			total_entries += result.config_entries.size()
	
	assert_gt(total_entries, 0, "Should have config entries from both files")


func test_property_externalization_json5_generation() -> void:
	# Property: Generated JSON5 file should contain all externalized values
	
	var test_script := """
extends Node
var speed: float = 150.0
var health: int = 200
"""
	
	var test_file := temp_dir + "test_json5.gd"
	_write_file(test_file, test_script)
	
	var result: ConfigExternalizer.ExternalizationResult = config_externalizer.externalize_config(test_file, "test")
	var config_file := temp_dir + "generated_config.json5"
	
	var success: bool = config_externalizer.generate_config_file([result], config_file)
	
	assert_true(success, "Should successfully generate config file")
	assert_file_exists(config_file)
	
	# Read and verify config file content
	var file := FileAccess.open(config_file, FileAccess.READ)
	assert_not_null(file, "Should be able to read generated config file")
	
	var content := file.get_as_text()
	file.close()
	
	# Verify values are in the file
	assert_string_contains(content, "150", "Config file should contain speed value")
	assert_string_contains(content, "200", "Config file should contain health value")


func test_property_externalization_preserves_code_structure() -> void:
	# Property: Externalization should preserve code structure and only replace values
	
	var test_script := """
class_name TestClass
extends Node

signal health_changed(new_health: int)

const MAX_ITEMS: int = 10

var current_health: int = 100

func _ready() -> void:
	current_health = 100

func take_damage(amount: int) -> void:
	current_health -= amount
	health_changed.emit(current_health)
"""
	
	var test_file := temp_dir + "test_structure.gd"
	_write_file(test_file, test_script)
	
	var result: ConfigExternalizer.ExternalizationResult = config_externalizer.externalize_config(test_file, "test")
	
	assert_not_null(result, "Externalization result should not be null")
	
	# Verify code structure is preserved
	assert_string_contains(result.modified_content, "class_name TestClass")
	assert_string_contains(result.modified_content, "extends Node")
	assert_string_contains(result.modified_content, "signal health_changed")
	assert_string_contains(result.modified_content, "func _ready()")
	assert_string_contains(result.modified_content, "func take_damage")


# Helper methods

func _write_file(path: String, content: String) -> void:
	# Ensure directory exists
	var dir_path := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "Should be able to create test file: " + path)
	if file:
		file.store_string(content)
		file.close()


func _cleanup_temp_dir() -> void:
	var dir := DirAccess.open(temp_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		
		DirAccess.remove_absolute(temp_dir)
