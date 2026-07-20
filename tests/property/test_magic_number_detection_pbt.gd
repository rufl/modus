extends PropertyBasedTesting

## Property-Based Test: Magic Number Detection
## Feature: architecture-refactoring, Property 6: Magic number detection
## Validates: Requirements 1.6, 5.1

const MagicNumberDetector = preload("res://tools/analyzer/magic_number_detector.gd")

## Property 6: Magic number detection
## For any GDScript file, the Architecture_Analyzer should detect all hardcoded
## numeric and string literals, excluding common values (0, 1, -1, true, false, null, "")


func test_property_numeric_literal_detection() -> void:
	# Property: All numeric literals (except excluded values) should be detected
	
	await run_enhanced_property_test(
		"Numeric literal detection",
		_test_numeric_literal_detection,
		100,
		SamplingStrategy.MIXED,
		"All non-excluded numeric literals should be detected as magic numbers"
	)


func _test_numeric_literal_detection(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate random numeric literals (excluding common values)
	var test_values: Array[float] = []
	var num_literals := rng.randi_range(3, 10)
	
	for i in range(num_literals):
		var value := _generate_non_excluded_numeric(rng)
		test_values.append(value)
	
	var script_content := _generate_script_with_numeric_literals(test_values)
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))
	
	var detector := MagicNumberDetector.new()
	var result := detector.analyze_script(temp_file)
	
	_cleanup_temp_script(temp_file)
	
	if not result:
		return false
	
	# All test values should be detected
	var detected_values: Array = []
	for magic in result.magic_numbers:
		if magic.value_type == "numeric":
			detected_values.append(magic.value)
	
	# Check that all test values were detected (with float tolerance)
	for value in test_values:
		var found := false
		for detected in detected_values:
			# Use approximate comparison for floats (tolerance: 0.0001)
			if abs(value - detected) < 0.0001:
				found = true
				break
		if not found:
			return false
	
	return true


func test_property_string_literal_detection() -> void:
	# Property: All string literals (except excluded values) should be detected
	
	await run_enhanced_property_test(
		"String literal detection",
		_test_string_literal_detection,
		100,
		SamplingStrategy.MIXED,
		"All non-excluded string literals should be detected as magic numbers"
	)


func _test_string_literal_detection(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate random string literals (excluding common values)
	var test_values: Array[String] = []
	var num_literals := rng.randi_range(3, 10)
	
	for i in range(num_literals):
		var value := _generate_non_excluded_string(rng)
		test_values.append(value)
	
	var script_content := _generate_script_with_string_literals(test_values)
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))
	
	var detector := MagicNumberDetector.new()
	var result := detector.analyze_script(temp_file)
	
	_cleanup_temp_script(temp_file)
	
	if not result:
		return false
	
	# All test values should be detected
	var detected_values: Array = []
	for magic in result.magic_numbers:
		if magic.value_type == "string":
			detected_values.append(magic.value)
	
	# Check that all test values were detected
	for value in test_values:
		if not detected_values.has(value):
			return false
	
	return true


func test_property_excluded_values_not_detected() -> void:
	# Property: Excluded values (0, 1, -1, "", etc.) should NOT be detected
	
	await run_enhanced_property_test(
		"Excluded values not detected",
		_test_excluded_values,
		100,
		SamplingStrategy.BOUNDARY_VALUES,
		"Common excluded values should not be detected as magic numbers"
	)


func _test_excluded_values(test_data: Dictionary) -> bool:
	# Test script with only excluded values
	var script_content := """extends RefCounted

func test_excluded_values() -> void:
	var a = 0
	var b = 1
	var c = -1
	var d = 0.0
	var e = 1.0
	var f = -1.0
	var g = ""
	var h = " "
	var i = true
	var j = false
	var k = null
"""
	
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))
	
	var detector := MagicNumberDetector.new()
	var result := detector.analyze_script(temp_file)
	
	_cleanup_temp_script(temp_file)
	
	if not result:
		return false
	
	# Should detect NO magic numbers (all values are excluded)
	return result.magic_numbers.size() == 0


func test_property_mixed_literals_detection() -> void:
	# Property: Scripts with both numeric and string literals should detect both types
	
	await run_enhanced_property_test(
		"Mixed literal detection",
		_test_mixed_literals,
		100,
		SamplingStrategy.MIXED,
		"Both numeric and string literals should be detected in the same script"
	)


func _test_mixed_literals(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate mixed literals
	var numeric_values: Array[float] = []
	var string_values: Array[String] = []
	
	var num_numeric := rng.randi_range(2, 5)
	var num_string := rng.randi_range(2, 5)
	
	for i in range(num_numeric):
		numeric_values.append(_generate_non_excluded_numeric(rng))
	
	for i in range(num_string):
		string_values.append(_generate_non_excluded_string(rng))
	
	var script_content := _generate_script_with_mixed_literals(numeric_values, string_values)
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))
	
	var detector := MagicNumberDetector.new()
	var result := detector.analyze_script(temp_file)
	
	_cleanup_temp_script(temp_file)
	
	if not result:
		return false
	
	# Count detected types
	var numeric_count := 0
	var string_count := 0
	
	for magic in result.magic_numbers:
		if magic.value_type == "numeric":
			numeric_count += 1
		elif magic.value_type == "string":
			string_count += 1
	
	# Should detect all numeric and string literals
	return numeric_count == num_numeric and string_count == num_string


func test_property_comment_literals_ignored() -> void:
	# Property: Literals in comments should NOT be detected
	
	await run_enhanced_property_test(
		"Comment literals ignored",
		_test_comment_literals,
		100,
		SamplingStrategy.EDGE_CASE,
		"Literals in comments should not be detected as magic numbers"
	)


func _test_comment_literals(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate script with literals only in comments
	var magic_value := _generate_non_excluded_numeric(rng)
	var script_content := """extends RefCounted

# This is a comment with magic number %s
## Another comment with value %s

func test_method() -> void:
	# Inline comment with %s
	pass
""" % [str(magic_value), str(magic_value), str(magic_value)]
	
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))
	
	var detector := MagicNumberDetector.new()
	var result := detector.analyze_script(temp_file)
	
	_cleanup_temp_script(temp_file)
	
	if not result:
		return false
	
	# Should detect NO magic numbers (all are in comments)
	return result.magic_numbers.size() == 0


func test_property_line_number_accuracy() -> void:
	# Property: Detected magic numbers should have correct line numbers
	
	await run_enhanced_property_test(
		"Line number accuracy",
		_test_line_number_accuracy,
		100,
		SamplingStrategy.MIXED,
		"Magic numbers should be reported with accurate line numbers"
	)


func _test_line_number_accuracy(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	var magic_value := _generate_non_excluded_numeric(rng)
	var target_line := 5  # We'll place the magic number on line 5
	
	var script_content := """extends RefCounted

func test_method() -> void:
	pass
	var x = %s
	pass
""" % str(magic_value)
	
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))
	
	var detector := MagicNumberDetector.new()
	var result := detector.analyze_script(temp_file)
	
	_cleanup_temp_script(temp_file)
	
	if not result:
		return false
	
	# Should detect exactly one magic number on line 5
	if result.magic_numbers.size() != 1:
		return false
	
	var magic = result.magic_numbers[0]
	# Use approximate comparison for float values (tolerance: 0.0001)
	var value_matches: bool = abs(magic.value - magic_value) < 0.0001
	return magic.line_number == target_line and value_matches


func test_property_hex_and_binary_detection() -> void:
	# Property: Hexadecimal and binary literals should be detected
	
	await run_enhanced_property_test(
		"Hex and binary literal detection",
		_test_hex_binary_detection,
		100,
		SamplingStrategy.EDGE_CASE,
		"Hexadecimal and binary literals should be detected as magic numbers"
	)


func _test_hex_binary_detection(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	
	# Generate hex and binary values (avoiding 0, 1, -1)
	var hex_value := rng.randi_range(2, 255)
	var binary_value := rng.randi_range(2, 15)
	
	var script_content := """extends RefCounted

func test_method() -> void:
	var hex_val = 0x%X
	var bin_val = 0b%s
""" % [hex_value, _int_to_binary(binary_value)]
	
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))
	
	var detector := MagicNumberDetector.new()
	var result := detector.analyze_script(temp_file)
	
	_cleanup_temp_script(temp_file)
	
	if not result:
		return false
	
	# Should detect both hex and binary literals
	if result.magic_numbers.size() != 2:
		return false
	
	var detected_values: Array = []
	for magic in result.magic_numbers:
		detected_values.append(magic.value)
	
	return detected_values.has(hex_value) and detected_values.has(binary_value)


## Helper: Generate a non-excluded numeric value
func _generate_non_excluded_numeric(rng: RandomNumberGenerator) -> float:
	var excluded := [0, 1, -1, 0.0, 1.0, -1.0]
	var value: float = 0.0
	
	# Keep generating until we get a non-excluded value
	var max_attempts := 100
	for attempt in range(max_attempts):
		var choice := rng.randi_range(0, 2)
		if choice == 0:
			# Integer
			value = float(rng.randi_range(-1000, 1000))
		elif choice == 1:
			# Float
			value = rng.randf_range(-1000.0, 1000.0)
		else:
			# Small integer
			value = float(rng.randi_range(2, 100))
		
		if not excluded.has(value):
			return value
	
	# Fallback if we somehow don't find a value
	return 42.0


## Helper: Generate a non-excluded string value
func _generate_non_excluded_string(rng: RandomNumberGenerator) -> String:
	var excluded := ["", " ", "\n", "\t"]
	var prefixes: Array[String] = ["config_", "setting_", "key_", "value_", "name_"]
	var suffixes: Array[String] = ["_enabled", "_max", "_min", "_default", "_path"]
	
	var prefix: String = prefixes[rng.randi_range(0, prefixes.size() - 1)]
	var suffix: String = suffixes[rng.randi_range(0, suffixes.size() - 1)]
	var value: String = prefix + str(rng.randi_range(1, 100)) + suffix
	
	# Ensure it's not excluded
	if not excluded.has(value):
		return value
	
	return "test_string_" + str(rng.randi_range(1, 1000))


## Helper: Generate script with numeric literals
func _generate_script_with_numeric_literals(values: Array[float]) -> String:
	var script := "extends RefCounted\n\n"
	script += "func test_method() -> void:\n"
	
	for i in range(values.size()):
		script += "\tvar value_%d = %s\n" % [i, str(values[i])]
	
	return script


## Helper: Generate script with string literals
func _generate_script_with_string_literals(values: Array[String]) -> String:
	var script := "extends RefCounted\n\n"
	script += "func test_method() -> void:\n"
	
	for i in range(values.size()):
		script += "\tvar value_%d = \"%s\"\n" % [i, values[i]]
	
	return script


## Helper: Generate script with mixed literals
func _generate_script_with_mixed_literals(
	numeric_values: Array[float], string_values: Array[String]
) -> String:
	var script := "extends RefCounted\n\n"
	script += "func test_method() -> void:\n"
	
	for i in range(numeric_values.size()):
		script += "\tvar num_%d = %s\n" % [i, str(numeric_values[i])]
	
	for i in range(string_values.size()):
		script += "\tvar str_%d = \"%s\"\n" % [i, string_values[i]]
	
	return script


## Helper: Convert integer to binary string
func _int_to_binary(value: int) -> String:
	if value == 0:
		return "0"
	
	var binary := ""
	var num := value
	
	while num > 0:
		binary = str(num % 2) + binary
		num = num / 2
	
	return binary


## Helper: Write script content to temporary file
func _write_temp_script(content: String, iteration: int) -> String:
	var temp_dir := "user://test_temp"
	DirAccess.make_dir_absolute(temp_dir)
	
	var temp_file := "%s/test_magic_number_%d.gd" % [temp_dir, iteration]
	var file := FileAccess.open(temp_file, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
	
	return temp_file


## Helper: Clean up temporary script file
func _cleanup_temp_script(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	# Keep the user:// workspace free of empty generated-test directories.
	DirAccess.remove_absolute("user://test_temp")
