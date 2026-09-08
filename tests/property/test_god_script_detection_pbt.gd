extends PropertyBasedTesting

## Property-Based Test: God Script Detection Accuracy
## Feature: architecture-refactoring, Property 3: God script detection accuracy
## Validates: Requirements 1.3, 4.1

const GodScriptDetectorClass = preload("res://tools/analyzer/god_script_detector.gd")

## Property 3: God script detection accuracy
## For any GDScript file, if it has more than 300 lines OR more than 10 public methods,
## the Architecture_Analyzer should classify it as a god script.


func test_property_line_count_threshold_detection() -> void:
	# Property: Scripts with >300 lines should be classified as god scripts

	await run_enhanced_property_test(
		"Line count threshold detection",
		_test_line_count_threshold,
		100,
		SamplingStrategy.MIXED,
		"Scripts exceeding 300 lines should be classified as god scripts"
	)


func _test_line_count_threshold(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate a script with >300 lines
	var line_count := rng.randi_range(301, 1000)
	var public_method_count := rng.randi_range(0, 10)  # Keep methods below threshold

	var script_content := _generate_test_script(line_count, public_method_count, rng)
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))

	var detector := GodScriptDetector.new()
	var result := detector.analyze_script(temp_file)

	_cleanup_temp_script(temp_file)

	if not result:
		return false

	# Should be classified as god script due to line count
	return result.is_god_script and result.reasons.has("exceeds 300 lines")


func test_property_public_method_threshold_detection() -> void:
	# Property: Scripts with >10 public methods should be classified as god scripts

	await run_enhanced_property_test(
		"Public method threshold detection",
		_test_public_method_threshold,
		100,
		SamplingStrategy.MIXED,
		"Scripts exceeding 10 public methods should be classified as god scripts"
	)


func _test_public_method_threshold(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate a script with >10 public methods but <300 lines
	var public_method_count := rng.randi_range(11, 30)
	var line_count := rng.randi_range(50, 300)  # Keep lines below threshold

	var script_content := _generate_test_script(line_count, public_method_count, rng)
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))

	var detector := GodScriptDetector.new()
	var result := detector.analyze_script(temp_file)

	_cleanup_temp_script(temp_file)

	if not result:
		return false

	# Should be classified as god script due to public method count
	return result.is_god_script and result.reasons.has("exceeds 10 public methods")


func test_property_normal_script_not_classified() -> void:
	# Property: Scripts with <=300 lines AND <=10 public methods should NOT be god scripts

	await run_enhanced_property_test(
		"Normal scripts not classified as god scripts",
		_test_normal_script,
		100,
		SamplingStrategy.MIXED,
		"Scripts within thresholds should not be classified as god scripts"
	)


func _test_normal_script(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate a script within both thresholds
	var line_count := rng.randi_range(10, 300)
	var public_method_count := rng.randi_range(0, 10)

	var script_content := _generate_test_script_exact(line_count, public_method_count, rng)
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))

	var detector := GodScriptDetector.new()
	var result := detector.analyze_script(temp_file)

	_cleanup_temp_script(temp_file)

	if not result:
		return false

	# Verify the actual line count matches what we intended
	if result.line_count != line_count:
		return false

	# Should NOT be classified as god script
	return not result.is_god_script


func test_property_both_thresholds_exceeded() -> void:
	# Property: Scripts exceeding both thresholds should have both reasons listed

	await run_enhanced_property_test(
		"Both thresholds exceeded",
		_test_both_thresholds,
		100,
		SamplingStrategy.MIXED,
		"Scripts exceeding both thresholds should list both reasons"
	)


func _test_both_thresholds(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate a script exceeding both thresholds
	var line_count := rng.randi_range(301, 1000)
	var public_method_count := rng.randi_range(11, 30)

	var script_content := _generate_test_script(line_count, public_method_count, rng)
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))

	var detector := GodScriptDetector.new()
	var result := detector.analyze_script(temp_file)

	_cleanup_temp_script(temp_file)

	if not result:
		return false

	# Should be classified as god script with both reasons
	return (
		result.is_god_script
		and result.reasons.has("exceeds 300 lines")
		and result.reasons.has("exceeds 10 public methods")
	)


func test_property_boundary_values_line_count() -> void:
	# Property: Test boundary values for line count (exactly 300, 301)

	await run_enhanced_property_test(
		"Line count boundary values",
		_test_line_count_boundary,
		100,
		SamplingStrategy.BOUNDARY_VALUES,
		"Boundary values for line count should be correctly classified"
	)


func _test_line_count_boundary(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	var detector := GodScriptDetector.new()

	# Test exactly 300 lines (should NOT be god script)
	var script_300 := _generate_test_script_exact(300, 5, rng)
	var temp_file_300 := _write_temp_script(script_300, test_data.get("iteration", 0) * 2)
	var result_300 := detector.analyze_script(temp_file_300)
	_cleanup_temp_script(temp_file_300)

	if not result_300:
		return false

	# Verify actual line count
	if result_300.line_count != 300:
		return false

	if result_300.is_god_script:
		return false

	# Test exactly 301 lines (should be god script)
	var script_301 := _generate_test_script_exact(301, 5, rng)
	var temp_file_301 := _write_temp_script(script_301, test_data.get("iteration", 0) * 2 + 1)
	var result_301 := detector.analyze_script(temp_file_301)
	_cleanup_temp_script(temp_file_301)

	if not result_301:
		return false

	# Verify actual line count
	if result_301.line_count != 301:
		return false

	if not result_301.is_god_script:
		return false

	return true


func test_property_boundary_values_method_count() -> void:
	# Property: Test boundary values for public method count (exactly 10, 11)

	await run_enhanced_property_test(
		"Public method count boundary values",
		_test_method_count_boundary,
		100,
		SamplingStrategy.BOUNDARY_VALUES,
		"Boundary values for method count should be correctly classified"
	)


func _test_method_count_boundary(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	var detector := GodScriptDetector.new()

	# Test exactly 10 public methods (should NOT be god script)
	var script_10 := _generate_test_script(100, 10, rng)
	var temp_file_10 := _write_temp_script(script_10, test_data.get("iteration", 0) * 2)
	var result_10 := detector.analyze_script(temp_file_10)
	_cleanup_temp_script(temp_file_10)

	if not result_10 or result_10.is_god_script:
		return false

	# Test exactly 11 public methods (should be god script)
	var script_11 := _generate_test_script(100, 11, rng)
	var temp_file_11 := _write_temp_script(script_11, test_data.get("iteration", 0) * 2 + 1)
	var result_11 := detector.analyze_script(temp_file_11)
	_cleanup_temp_script(temp_file_11)

	if not result_11 or not result_11.is_god_script:
		return false

	return true


func test_property_private_methods_not_counted() -> void:
	# Property: Private methods (starting with _) should not count toward threshold

	await run_enhanced_property_test(
		"Private methods not counted",
		_test_private_methods,
		100,
		SamplingStrategy.MIXED,
		"Private methods should not count toward public method threshold"
	)


func _test_private_methods(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate script with many private methods but few public ones
	var public_count := rng.randi_range(1, 10)
	var private_count := rng.randi_range(15, 30)

	var script_content := _generate_script_with_private_methods(
		200, public_count, private_count, rng
	)
	var temp_file := _write_temp_script(script_content, test_data.get("iteration", 0))

	var detector := GodScriptDetector.new()
	var result := detector.analyze_script(temp_file)

	_cleanup_temp_script(temp_file)

	if not result:
		return false

	# Should NOT be god script (private methods don't count)
	return not result.is_god_script and result.public_method_count == public_count


## Helper: Generate a test script with specified characteristics
func _generate_test_script(
	target_lines: int, public_methods: int, _rng: RandomNumberGenerator
) -> String:
	var script := "extends RefCounted\n\n"
	script += "## Test script for god script detection\n\n"

	# Add public methods
	for i in range(public_methods):
		script += "func test_method_%d() -> void:\n" % i
		script += "\tpass\n\n"

	# Add filler lines to reach target line count
	var current_lines := script.split("\n").size()
	var lines_needed := target_lines - current_lines

	if lines_needed > 0:
		script += "# Filler content to reach target line count\n"
		for i in range(lines_needed):
			script += "# Line %d\n" % i

	return script


## Helper: Generate a test script with EXACT line count
func _generate_test_script_exact(
	exact_lines: int, public_methods: int, _rng: RandomNumberGenerator
) -> String:
	var lines: Array[String] = []

	# Line 1: extends statement
	lines.append("extends RefCounted")

	# Line 2: empty line
	lines.append("")

	# Add public methods (each method takes 2 lines: declaration + pass)
	for i in range(public_methods):
		lines.append("func test_method_%d() -> void:" % i)
		lines.append("\tpass")

	# Calculate remaining lines needed
	var current_line_count := lines.size()
	var lines_needed := exact_lines - current_line_count

	# Add filler comment lines to reach exact count
	for i in range(lines_needed):
		lines.append("# Filler line %d" % i)

	# Join with newlines - this will create exact_lines when split by \n
	return "\n".join(lines)


## Helper: Generate script with both public and private methods
func _generate_script_with_private_methods(
	target_lines: int, public_methods: int, private_methods: int, _rng: RandomNumberGenerator
) -> String:
	var script := "extends RefCounted\n\n"
	script += "## Test script with private methods\n\n"

	# Add public methods
	for i in range(public_methods):
		script += "func public_method_%d() -> void:\n" % i
		script += "\tpass\n\n"

	# Add private methods
	for i in range(private_methods):
		script += "func _private_method_%d() -> void:\n" % i
		script += "\tpass\n\n"

	# Add filler lines to reach target line count
	var current_lines := script.split("\n").size()
	var lines_needed := target_lines - current_lines

	if lines_needed > 0:
		script += "# Filler content\n"
		for i in range(lines_needed):
			script += "# Line %d\n" % i

	return script


## Helper: Write script content to temporary file
func _write_temp_script(content: String, iteration: int) -> String:
	var temp_dir := "user://test_temp"
	DirAccess.make_dir_absolute(temp_dir)

	var temp_file := "%s/test_god_script_%d.gd" % [temp_dir, iteration]
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
