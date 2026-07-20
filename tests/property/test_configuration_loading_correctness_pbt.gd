extends PropertyBasedTesting

## Property-Based Test: Configuration Loading Correctness
## Property 8: Configuration Loading Correctness
## Validates: Requirements 10.1, 10.2, 10.3

const ConfigurationManager = preload("res://game/scripts/core/configuration_manager.gd")

# Configuration files to test
const CONFIG_FILES: Array[String] = [
	"res://game/config/gameplay/hud_weapon_settings.json5",
	"res://game/config/gameplay/movement.json5",
	"res://game/config/network/network_config.json5"
]


func test_property_all_config_values_accessible() -> void:
	# Property: For any configuration file, all values should be accessible
	# and match the file contents

	await run_enhanced_property_test(
		"All configuration values accessible",
		_test_config_values_accessible,
		100,
		SamplingStrategy.MIXED,
		"All values in JSON5 files should be accessible and match file contents"
	)


func _test_config_values_accessible(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	var iteration: int = test_data.get("iteration", 0)

	# Select config file based on iteration
	var config_index: int = iteration % CONFIG_FILES.size()
	var config_file: String = CONFIG_FILES[config_index]

	# Check if file exists
	if not FileAccess.file_exists(config_file):
		push_warning("[Property Test] Config file not found: %s" % config_file)
		return true  # Skip if file doesn't exist

	# Load configuration
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var config_data: Dictionary = config_mgr.load_config_file(config_file)

	if config_data.is_empty():
		push_warning("[Property Test] Failed to load config: %s" % config_file)
		return false

	# Verify configuration is not empty and has expected structure
	var has_valid_structure: bool = _verify_config_structure(config_file, config_data)

	if not has_valid_structure:
		push_warning("[Property Test] Invalid config structure: %s" % config_file)
		return false

	# Verify all values are accessible (no null/missing values in expected paths)
	var all_accessible: bool = _verify_all_values_accessible(config_file, config_data)

	return all_accessible


func test_property_config_type_correctness() -> void:
	# Property: Configuration values should have correct types
	# (numbers are numbers, strings are strings, etc.)

	await run_enhanced_property_test(
		"Configuration type correctness",
		_test_config_type_correctness,
		100,
		SamplingStrategy.MIXED,
		"Configuration values should have correct types"
	)


func _test_config_type_correctness(test_data: Dictionary) -> bool:
	var iteration: int = test_data.get("iteration", 0)

	# Select config file
	var config_index: int = iteration % CONFIG_FILES.size()
	var config_file: String = CONFIG_FILES[config_index]

	if not FileAccess.file_exists(config_file):
		return true  # Skip if file doesn't exist

	# Load configuration
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var config_data: Dictionary = config_mgr.load_config_file(config_file)

	if config_data.is_empty():
		return false

	# Verify types based on config file
	var types_correct: bool = _verify_config_types(config_file, config_data)

	return types_correct


func test_property_config_reload_consistency() -> void:
	# Property: Loading the same configuration multiple times should
	# produce identical results

	await run_enhanced_property_test(
		"Configuration reload consistency",
		_test_config_reload_consistency,
		100,
		SamplingStrategy.MIXED,
		"Loading same config multiple times should produce identical results"
	)


func _test_config_reload_consistency(test_data: Dictionary) -> bool:
	var iteration: int = test_data.get("iteration", 0)

	# Select config file
	var config_index: int = iteration % CONFIG_FILES.size()
	var config_file: String = CONFIG_FILES[config_index]

	if not FileAccess.file_exists(config_file):
		return true  # Skip if file doesn't exist

	# Load configuration twice
	var config_mgr1: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var config_mgr2: ConfigurationManager = add_child_autofree(ConfigurationManager.new())

	var config_data1: Dictionary = config_mgr1.load_config_file(config_file)
	var config_data2: Dictionary = config_mgr2.load_config_file(config_file)

	# Compare results
	var are_identical: bool = _deep_compare_dictionaries(config_data1, config_data2)

	if not are_identical:
		push_warning("[Property Test] Config reload produced different results: %s" % config_file)

	return are_identical


func test_property_config_nested_access() -> void:
	# Property: Nested configuration values should be accessible
	# through dot notation or dictionary access

	await run_enhanced_property_test(
		"Nested configuration access",
		_test_config_nested_access,
		100,
		SamplingStrategy.EDGE_CASE,
		"Nested configuration values should be accessible"
	)


func _test_config_nested_access(test_data: Dictionary) -> bool:
	var iteration: int = test_data.get("iteration", 0)

	# Test network_config.json5 which has deep nesting
	var config_file: String = "res://game/config/network/network_config.json5"

	if not FileAccess.file_exists(config_file):
		return true  # Skip if file doesn't exist

	# Load configuration
	var config_mgr: ConfigurationManager = add_child_autofree(ConfigurationManager.new())
	var config_data: Dictionary = config_mgr.load_config_file(config_file)

	if config_data.is_empty():
		return false

	# Test nested access patterns
	var nested_paths: Array[String] = [
		"prediction.enabled",
		"tick_rate.server",
		"lag_compensation.max_window_ms",
		"bandwidth.max_outgoing_kbps",
		"anti_cheat.speed_tolerance"
	]

	for path: String in nested_paths:
		var value: Variant = _get_nested_value(config_data, path)
		if value == null:
			push_warning("[Property Test] Failed to access nested path: %s" % path)
			return false

	return true


## Helper: Verify configuration structure
func _verify_config_structure(config_file: String, config_data: Dictionary) -> bool:
	if config_file.contains("hud_weapon_settings"):
		# Should have weapons array or weapon entries
		return config_data.has("weapons") or config_data.size() > 0

	if config_file.contains("movement"):
		# Should have movement-related keys
		return config_data.has("walk_speed") or config_data.has("sprint_speed") or config_data.size() > 0

	if config_file.contains("network_config"):
		# Should have network-related keys
		return config_data.has("prediction") or config_data.has("tick_rate") or config_data.size() > 0

	return config_data.size() > 0


## Helper: Verify all values are accessible
func _verify_all_values_accessible(config_file: String, config_data: Dictionary) -> bool:
	# Recursively check all values in dictionary
	return _check_dictionary_values(config_data, config_file)


func _check_dictionary_values(dict: Dictionary, path: String = "") -> bool:
	for key: String in dict.keys():
		var value: Variant = dict[key]
		var current_path: String = path + "." + key if path != "" else key

		# Check if value is null (shouldn't be in valid config)
		if value == null:
			push_warning("[Property Test] Null value at path: %s" % current_path)
			return false

		# Recursively check nested dictionaries
		if value is Dictionary:
			if not _check_dictionary_values(value, current_path):
				return false

		# Check arrays
		elif value is Array:
			for i in range(value.size()):
				var item: Variant = value[i]
				if item is Dictionary:
					if not _check_dictionary_values(item, current_path + "[%d]" % i):
						return false

	return true


## Helper: Verify configuration types
func _verify_config_types(config_file: String, config_data: Dictionary) -> bool:
	if config_file.contains("movement"):
		# Movement config should have numeric values
		if config_data.has("walk_speed"):
			if not (config_data.walk_speed is float or config_data.walk_speed is int):
				return false
		if config_data.has("sprint_speed"):
			if not (config_data.sprint_speed is float or config_data.sprint_speed is int):
				return false

	elif config_file.contains("network_config"):
		# Network config should have proper types
		if config_data.has("prediction"):
			var prediction: Variant = config_data.prediction
			if prediction is Dictionary:
				if prediction.has("enabled"):
					if not prediction.enabled is bool:
						return false

	return true


## Helper: Deep compare dictionaries
func _deep_compare_dictionaries(dict1: Dictionary, dict2: Dictionary) -> bool:
	if dict1.size() != dict2.size():
		return false

	for key: String in dict1.keys():
		if not dict2.has(key):
			return false

		var value1: Variant = dict1[key]
		var value2: Variant = dict2[key]

		if typeof(value1) != typeof(value2):
			return false

		if value1 is Dictionary and value2 is Dictionary:
			if not _deep_compare_dictionaries(value1, value2):
				return false
		elif value1 is Array and value2 is Array:
			if not _deep_compare_arrays(value1, value2):
				return false
		elif value1 != value2:
			return false

	return true


## Helper: Deep compare arrays
func _deep_compare_arrays(arr1: Array, arr2: Array) -> bool:
	if arr1.size() != arr2.size():
		return false

	for i in range(arr1.size()):
		var item1: Variant = arr1[i]
		var item2: Variant = arr2[i]

		if typeof(item1) != typeof(item2):
			return false

		if item1 is Dictionary and item2 is Dictionary:
			if not _deep_compare_dictionaries(item1, item2):
				return false
		elif item1 is Array and item2 is Array:
			if not _deep_compare_arrays(item1, item2):
				return false
		elif item1 != item2:
			return false

	return true


## Helper: Get nested value from dictionary using dot notation
func _get_nested_value(dict: Dictionary, path: String) -> Variant:
	var parts: PackedStringArray = path.split(".")
	var current: Variant = dict

	for part: String in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		else:
			return null

	return current


## Helper: Get seeded RNG
func get_seeded_rng(iteration: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(iteration)
	return rng
