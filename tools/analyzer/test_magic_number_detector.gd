extends SceneTree

## Test script for MagicNumberDetector
##
## Run with: godot --headless --script tools/analyzer/test_magic_number_detector.gd

const MagicNumberDetectorScript = preload("res://tools/analyzer/magic_number_detector.gd")


func _init() -> void:
	var separator := "="
	separator = separator.repeat(60)
	print(separator)
	print("Testing MagicNumberDetector")
	print(separator)
	
	test_detect_numeric_literals()
	test_exclude_common_numeric_values()
	test_detect_string_literals()
	test_exclude_empty_strings()
	test_ignore_comments()
	test_ignore_multiline_comments()
	test_detect_hexadecimal_literals()
	test_detect_binary_literals()
	test_detect_scientific_notation()
	test_analyze_multiple_scripts()
	test_generate_report()
	test_filter_files_with_magic_numbers()
	
	var end_separator := "="
	end_separator = end_separator.repeat(60)
	print("\n" + end_separator)
	print("All tests completed!")
	print(end_separator)
	
	quit()


func test_detect_numeric_literals() -> void:
	print("\n[TEST] Detect numeric literals")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_numeric.gd"
	
	var content := """
extends Node

var health: int = 100
var damage: float = 25.5
var speed: float = 3.14159
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	assert(result.file_path == test_file, "Should have correct file path")
	assert(result.magic_numbers.size() > 0, "Should detect magic numbers")
	
	# Check that we found the numeric literals
	var values := _extract_values(result.magic_numbers)
	assert(100 in values, "Should detect 100")
	assert(25.5 in values, "Should detect 25.5")
	assert(3.14159 in values, "Should detect 3.14159")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Numeric literals detection test passed")


func test_exclude_common_numeric_values() -> void:
	print("\n[TEST] Exclude common numeric values")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_exclude.gd"
	
	var content := """
extends Node

var zero: int = 0
var one: int = 1
var minus_one: int = -1
var zero_float: float = 0.0
var one_float: float = 1.0
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	
	# Check that common values are excluded
	var values := _extract_values(result.magic_numbers)
	assert(not (0 in values), "Should exclude 0")
	assert(not (1 in values), "Should exclude 1")
	assert(not (-1 in values), "Should exclude -1")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Exclude common values test passed")


func test_detect_string_literals() -> void:
	print("\n[TEST] Detect string literals")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_strings.gd"
	
	var content := """
extends Node

var weapon_name: String = "Sword"
var item_id: String = "item_health_potion"
var message: String = "Hello World"
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	assert(result.magic_numbers.size() > 0, "Should detect string literals")
	
	# Check that we found the string literals
	var values := _extract_values(result.magic_numbers)
	assert("Sword" in values, "Should detect 'Sword'")
	assert("item_health_potion" in values, "Should detect 'item_health_potion'")
	assert("Hello World" in values, "Should detect 'Hello World'")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ String literals detection test passed")


func test_exclude_empty_strings() -> void:
	print("\n[TEST] Exclude empty strings")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_empty.gd"
	
	var content := """
extends Node

var empty: String = ""
var space: String = " "
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	
	# Check that empty/whitespace strings are excluded
	var values := _extract_values(result.magic_numbers)
	assert(not ("" in values), "Should exclude empty string")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Exclude empty strings test passed")


func test_ignore_comments() -> void:
	print("\n[TEST] Ignore comments")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_comments.gd"
	
	var content := """
extends Node

# This is a comment with 999 and "test string"
var health: int = 50  # Magic number 777 in comment
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	
	# Should only detect 50, not the numbers in comments
	var values := _extract_values(result.magic_numbers)
	assert(50 in values, "Should detect 50")
	assert(not (999 in values), "Should not detect 999 in comment")
	assert(not (777 in values), "Should not detect 777 in inline comment")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Ignore comments test passed")


func test_ignore_multiline_comments() -> void:
	print("\n[TEST] Ignore multiline comments")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_multiline.gd"
	
	var content := '''
extends Node

"""
This is a multiline comment
with magic numbers 123 and 456
and strings "ignored" and "also ignored"
"""

var real_value: int = 789
'''
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	
	# Should only detect 789, not values in multiline comment
	var values := _extract_values(result.magic_numbers)
	assert(789 in values, "Should detect 789")
	assert(not (123 in values), "Should not detect 123 in multiline comment")
	assert(not (456 in values), "Should not detect 456 in multiline comment")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Ignore multiline comments test passed")


func test_detect_hexadecimal_literals() -> void:
	print("\n[TEST] Detect hexadecimal literals")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_hex.gd"
	
	var content := """
extends Node

var color: int = 0xFF0000
var mask: int = 0x1A2B
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	assert(result.magic_numbers.size() > 0, "Should detect hex literals")
	
	# Check that hex values are detected (converted to decimal)
	var values := _extract_values(result.magic_numbers)
	assert(0xFF0000 in values, "Should detect 0xFF0000")
	assert(0x1A2B in values, "Should detect 0x1A2B")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Hexadecimal literals test passed")


func test_detect_binary_literals() -> void:
	print("\n[TEST] Detect binary literals")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_binary.gd"
	
	var content := """
extends Node

var flags: int = 0b1010
var mask: int = 0b11110000
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	assert(result.magic_numbers.size() > 0, "Should detect binary literals")
	
	# Check that binary values are detected (converted to decimal)
	var values := _extract_values(result.magic_numbers)
	assert(0b1010 in values, "Should detect 0b1010")
	assert(0b11110000 in values, "Should detect 0b11110000")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Binary literals test passed")


func test_detect_scientific_notation() -> void:
	print("\n[TEST] Detect scientific notation")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_scientific.gd"
	
	var content := """
extends Node

var large: float = 1e10
var small: float = 2.5e-3
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	
	assert(result != null, "Should return a result")
	assert(result.magic_numbers.size() > 0, "Should detect scientific notation")
	
	# Check that scientific notation is detected
	var values := _extract_values(result.magic_numbers)
	assert(1e10 in values, "Should detect 1e10")
	# Note: 2.5e-3 might have floating point precision issues, so we check approximately
	var has_small := false
	for v in values:
		if abs(v - 2.5e-3) < 0.0001:
			has_small = true
			break
	assert(has_small, "Should detect 2.5e-3")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Scientific notation test passed")


func test_analyze_multiple_scripts() -> void:
	print("\n[TEST] Analyze multiple scripts")
	
	var detector := MagicNumberDetectorScript.new()
	
	# Create first test file
	var test_file1 := "res://test_magic_multi1.gd"
	var content1 := """
extends Node
var value1: int = 100
"""
	_write_temp_file(test_file1, content1)
	
	# Create second test file
	var test_file2 := "res://test_magic_multi2.gd"
	var content2 := """
extends Node
var value2: int = 200
"""
	_write_temp_file(test_file2, content2)
	
	var results := detector.analyze_scripts([test_file1, test_file2])
	
	assert(results.size() == 2, "Should analyze both scripts")
	assert(results[0].magic_numbers.size() > 0, "First script should have magic numbers")
	assert(results[1].magic_numbers.size() > 0, "Second script should have magic numbers")
	
	# Clean up
	DirAccess.remove_absolute(test_file1)
	DirAccess.remove_absolute(test_file2)
	
	print("  ✓ Multiple scripts test passed")


func test_generate_report() -> void:
	print("\n[TEST] Generate report")
	
	var detector := MagicNumberDetectorScript.new()
	var test_file := "res://test_magic_report.gd"
	
	var content := """
extends Node

var health: int = 100
var name: String = "Player"
"""
	_write_temp_file(test_file, content)
	
	var result := detector.analyze_script(test_file)
	var report := detector.generate_report([result])
	
	assert(report.length() > 0, "Report should not be empty")
	assert("Magic Number Detection Report" in report, "Should have report title")
	assert("Total scripts analyzed: 1" in report, "Should show script count")
	
	DirAccess.remove_absolute(test_file)
	print("  ✓ Generate report test passed")


func test_filter_files_with_magic_numbers() -> void:
	print("\n[TEST] Filter files with magic numbers")
	
	var detector := MagicNumberDetectorScript.new()
	
	# File with magic numbers
	var test_file1 := "res://test_magic_filter1.gd"
	var content1 := """
extends Node
var value: int = 100
"""
	_write_temp_file(test_file1, content1)
	var result1 := detector.analyze_script(test_file1)
	
	# File without magic numbers (only excluded values)
	var test_file2 := "res://test_magic_filter2.gd"
	var content2 := """
extends Node
var zero: int = 0
var one: int = 1
"""
	_write_temp_file(test_file2, content2)
	var result2 := detector.analyze_script(test_file2)
	
	var filtered := detector.filter_files_with_magic_numbers([result1, result2])
	
	assert(filtered.size() == 1, "Should only include files with magic numbers")
	assert(filtered[0].file_path == test_file1, "Should be the file with magic numbers")
	
	# Clean up
	DirAccess.remove_absolute(test_file1)
	DirAccess.remove_absolute(test_file2)
	
	print("  ✓ Filter files test passed")


## Helper function to write temporary test file
func _write_temp_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


## Helper function to extract values from magic numbers
func _extract_values(magic_numbers: Array) -> Array:
	var values: Array = []
	for magic in magic_numbers:
		if magic is MagicNumberDetectorScript.MagicNumber:
			values.append(magic.value)
	return values
