extends SceneTree

## Test script for GodScriptDetector
##
## Run with: godot --headless --script tools/analyzer/test_god_script_detector.gd

const GodScriptDetector = preload("res://tools/analyzer/god_script_detector.gd")


func _init() -> void:
	var separator := "="
	separator = separator.repeat(60)
	print(separator)
	print("Testing GodScriptDetector")
	print(separator)

	test_line_count_threshold()
	test_public_method_threshold()
	test_both_thresholds()
	test_normal_script()
	test_analyze_multiple_scripts()
	test_filter_god_scripts()
	test_generate_report()

	var end_separator := "="
	end_separator = end_separator.repeat(60)
	print("\n" + end_separator)
	print("All tests completed!")
	print(end_separator)

	quit()


func test_line_count_threshold() -> void:
	print("\n[TEST] Line count threshold (>300 lines)")

	var detector := GodScriptDetector.new()

	# Create a temporary test file with >300 lines
	var test_file := "res://test_god_script_lines.gd"
	var file := FileAccess.open(test_file, FileAccess.WRITE)

	file.store_string("class_name TestGodScript\n")
	file.store_string("extends Node\n\n")

	# Add 301 lines of code
	for i in range(301):
		file.store_string("# Line %d\n" % i)

	file.close()

	var result := detector.analyze_script(test_file)

	assert(result != null, "Result should not be null")
	assert(result.is_god_script, "Should be classified as god script")
	assert(result.line_count > 300, "Line count should exceed 300")
	assert("exceeds 300 lines" in result.reasons, "Should have line count reason")

	# Cleanup
	DirAccess.remove_absolute(test_file)

	print("  ✓ Line count threshold test passed")


func test_public_method_threshold() -> void:
	print("\n[TEST] Public method threshold (>10 methods)")

	var detector := GodScriptDetector.new()

	# Create a temporary test file with >10 public methods
	var test_file := "res://test_god_script_methods.gd"
	var file := FileAccess.open(test_file, FileAccess.WRITE)

	file.store_string("class_name TestGodScript\n")
	file.store_string("extends Node\n\n")

	# Add 11 public methods
	for i in range(11):
		file.store_string("func public_method_%d() -> void:\n" % i)
		file.store_string("\tpass\n\n")

	file.close()

	var result := detector.analyze_script(test_file)

	assert(result != null, "Result should not be null")
	assert(result.is_god_script, "Should be classified as god script")
	assert(result.public_method_count > 10, "Public method count should exceed 10")
	assert("exceeds 10 public methods" in result.reasons, "Should have method count reason")

	# Cleanup
	DirAccess.remove_absolute(test_file)

	print("  ✓ Public method threshold test passed")


func test_both_thresholds() -> void:
	print("\n[TEST] Both thresholds exceeded")

	var detector := GodScriptDetector.new()

	# Create a temporary test file with both >300 lines and >10 methods
	var test_file := "res://test_god_script_both.gd"
	var file := FileAccess.open(test_file, FileAccess.WRITE)

	file.store_string("class_name TestGodScript\n")
	file.store_string("extends Node\n\n")

	# Add 11 public methods
	for i in range(11):
		file.store_string("func public_method_%d() -> void:\n" % i)
		file.store_string("\tpass\n\n")

	# Add more lines to exceed 300
	for i in range(290):
		file.store_string("# Line %d\n" % i)

	file.close()

	var result := detector.analyze_script(test_file)

	assert(result != null, "Result should not be null")
	assert(result.is_god_script, "Should be classified as god script")
	assert(result.reasons.size() == 2, "Should have both reasons")

	# Cleanup
	DirAccess.remove_absolute(test_file)

	print("  ✓ Both thresholds test passed")


func test_normal_script() -> void:
	print("\n[TEST] Normal script (within limits)")

	var detector := GodScriptDetector.new()

	# Create a temporary test file with normal size
	var test_file := "res://test_normal_script.gd"
	var file := FileAccess.open(test_file, FileAccess.WRITE)

	file.store_string("class_name TestNormalScript\n")
	file.store_string("extends Node\n\n")

	# Add 5 public methods
	for i in range(5):
		file.store_string("func public_method_%d() -> void:\n" % i)
		file.store_string("\tpass\n\n")

	# Add 3 private methods
	for i in range(3):
		file.store_string("func _private_method_%d() -> void:\n" % i)
		file.store_string("\tpass\n\n")

	file.close()

	var result := detector.analyze_script(test_file)

	assert(result != null, "Result should not be null")
	assert(not result.is_god_script, "Should NOT be classified as god script")
	assert(result.line_count <= 300, "Line count should be within limit")
	assert(result.public_method_count <= 10, "Public method count should be within limit")
	assert(result.reasons.is_empty(), "Should have no reasons")

	# Cleanup
	DirAccess.remove_absolute(test_file)

	print("  ✓ Normal script test passed")


func test_analyze_multiple_scripts() -> void:
	print("\n[TEST] Analyze multiple scripts")

	var detector := GodScriptDetector.new()

	# Create two test files
	var test_files := ["res://test_multi_1.gd", "res://test_multi_2.gd"]

	for test_file in test_files:
		var file := FileAccess.open(test_file, FileAccess.WRITE)
		file.store_string("class_name TestScript\n")
		file.store_string("extends Node\n\n")
		file.store_string("func test() -> void:\n")
		file.store_string("\tpass\n")
		file.close()

	var results := detector.analyze_scripts(test_files)

	assert(results.size() == 2, "Should analyze 2 scripts")

	# Cleanup
	for test_file in test_files:
		DirAccess.remove_absolute(test_file)

	print("  ✓ Multiple scripts test passed")


func test_filter_god_scripts() -> void:
	print("\n[TEST] Filter god scripts")

	var detector := GodScriptDetector.new()

	# Create mixed test files
	var god_script_file := "res://test_filter_god.gd"
	var normal_script_file := "res://test_filter_normal.gd"

	# Create god script
	var file := FileAccess.open(god_script_file, FileAccess.WRITE)
	file.store_string("class_name TestGodScript\n")
	for i in range(301):
		file.store_string("# Line %d\n" % i)
	file.close()

	# Create normal script
	file = FileAccess.open(normal_script_file, FileAccess.WRITE)
	file.store_string("class_name TestNormalScript\n")
	file.store_string("func test() -> void:\n")
	file.store_string("\tpass\n")
	file.close()

	var results := detector.analyze_scripts([god_script_file, normal_script_file])
	var god_scripts := detector.filter_god_scripts(results)

	assert(god_scripts.size() == 1, "Should filter to 1 god script")
	assert(god_scripts[0].is_god_script, "Filtered result should be god script")

	# Cleanup
	DirAccess.remove_absolute(god_script_file)
	DirAccess.remove_absolute(normal_script_file)

	print("  ✓ Filter god scripts test passed")


func test_generate_report() -> void:
	print("\n[TEST] Generate report")

	var detector := GodScriptDetector.new()

	# Create test files
	var god_script_file := "res://test_report_god.gd"
	var normal_script_file := "res://test_report_normal.gd"

	# Create god script
	var file := FileAccess.open(god_script_file, FileAccess.WRITE)
	file.store_string("class_name TestGodScript\n")
	for i in range(301):
		file.store_string("# Line %d\n" % i)
	file.close()

	# Create normal script
	file = FileAccess.open(normal_script_file, FileAccess.WRITE)
	file.store_string("class_name TestNormalScript\n")
	file.store_string("func test() -> void:\n")
	file.store_string("\tpass\n")
	file.close()

	var results := detector.analyze_scripts([god_script_file, normal_script_file])
	var report := detector.generate_report(results)

	assert(report.length() > 0, "Report should not be empty")
	assert("God Script Detection Report" in report, "Report should have title")
	assert("Total scripts analyzed: 2" in report, "Report should show total count")
	assert("God scripts found: 1" in report, "Report should show god script count")

	# Cleanup
	DirAccess.remove_absolute(god_script_file)
	DirAccess.remove_absolute(normal_script_file)

	print("  ✓ Generate report test passed")
