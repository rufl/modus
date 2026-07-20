extends RefCounted

## Property-Based Test: Dependency Detection Completeness
## Feature: architecture-refactoring, Property 2: Dependency detection completeness
## Validates: Requirements 1.2, 7.1

const DependencyAnalyzer = preload("res://tools/analyzer/dependency_analyzer.gd")

# Test directory for temporary test files
const TEST_DIR = "res://tests/temp_dependency_test/"

# Simple test counter
var tests_passed := 0
var tests_failed := 0


func test_property_all_imports_detected() -> void:
	# Property: For any GDScript file with imports (preload, load), 
	# the DependencyAnalyzer should identify all of them
	
	print("Testing: All imports detected")
	var iterations := 100
	var failures := 0
	
	for i in range(iterations):
		var test_data := {"iteration": i}
		if not _test_all_imports_found(test_data):
			failures += 1
	
	if failures > 0:
		print("  FAILED: %d/%d iterations failed" % [failures, iterations])
		tests_failed += 1
	else:
		print("  PASSED: All %d iterations passed" % iterations)
		tests_passed += 1


func test_property_all_get_node_calls_detected() -> void:
	# Property: For any GDScript file with get_node calls,
	# the DependencyAnalyzer should identify all of them
	
	print("Testing: All get_node calls detected")
	var iterations := 100
	var failures := 0
	
	for i in range(iterations):
		var test_data := {"iteration": i}
		if not _test_all_get_node_calls_found(test_data):
			failures += 1
	
	if failures > 0:
		print("  FAILED: %d/%d iterations failed" % [failures, iterations])
		tests_failed += 1
	else:
		print("  PASSED: All %d iterations passed" % iterations)
		tests_passed += 1


func test_property_all_autoload_references_detected() -> void:
	# Property: For any GDScript file with autoload references,
	# the DependencyAnalyzer should identify all of them
	
	print("Testing: All autoload references detected")
	var iterations := 100
	var failures := 0
	
	for i in range(iterations):
		var test_data := {"iteration": i}
		if not _test_all_autoload_refs_found(test_data):
			failures += 1
	
	if failures > 0:
		print("  FAILED: %d/%d iterations failed" % [failures, iterations])
		tests_failed += 1
	else:
		print("  PASSED: All %d iterations passed" % iterations)
		tests_passed += 1


func test_property_class_name_references_detected() -> void:
	# Property: For any GDScript file with class_name type annotations,
	# the DependencyAnalyzer should identify all of them
	
	print("Testing: All class_name references detected")
	var iterations := 100
	var failures := 0
	
	for i in range(iterations):
		var test_data := {"iteration": i}
		if not _test_all_class_refs_found(test_data):
			failures += 1
	
	if failures > 0:
		print("  FAILED: %d/%d iterations failed" % [failures, iterations])
		tests_failed += 1
	else:
		print("  PASSED: All %d iterations passed" % iterations)
		tests_passed += 1


func test_property_dollar_syntax_detected() -> void:
	# Property: For any GDScript file with $ node references,
	# the DependencyAnalyzer should identify all of them
	
	print("Testing: All $ syntax references detected")
	var iterations := 100
	var failures := 0
	
	for i in range(iterations):
		var test_data := {"iteration": i}
		if not _test_all_dollar_syntax_found(test_data):
			failures += 1
	
	if failures > 0:
		print("  FAILED: %d/%d iterations failed" % [failures, iterations])
		tests_failed += 1
	else:
		print("  PASSED: All %d iterations passed" % iterations)
		tests_passed += 1


func get_test_summary() -> Dictionary:
	return {
		"passed": tests_passed,
		"failed": tests_failed,
		"total": tests_passed + tests_failed
	}


# =============================================================================
# TEST IMPLEMENTATIONS
# =============================================================================


func _test_all_imports_found(test_data: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = test_data.get("iteration", 0) + Time.get_ticks_msec()
	
	# Generate test script with known number of imports
	var import_count := rng.randi_range(1, 10)
	var script_content := "extends Node\n\n"
	
	for i in range(import_count):
		var import_type: String = ["preload", "load"][rng.randi_range(0, 1)]
		var import_path := "res://test/path_%d.gd" % i
		script_content += "var resource_%d = %s(\"%s\")\n" % [i, import_type, import_path]
	
	# Write test file
	var test_file := _create_test_file("test_imports.gd", script_content)
	if not test_file:
		return false
	
	# Analyze the file
	var analyzer := DependencyAnalyzer.new()
	var dep_info := analyzer.analyze_script(test_file)
	
	# Cleanup
	_cleanup_test_file(test_file)
	
	if not dep_info:
		return false
	
	# Count only preload/load imports (not class_name references)
	var actual_import_count := 0
	for import_dep in dep_info.imports:
		if import_dep is DependencyAnalyzer.ImportDependency:
			if import_dep.import_type in ["preload", "load"]:
				actual_import_count += 1
	
	# Verify all imports were detected
	return actual_import_count == import_count


func _test_all_get_node_calls_found(test_data: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = test_data.get("iteration", 0) + Time.get_ticks_msec()
	
	# Generate test script with known number of get_node calls
	var get_node_count := rng.randi_range(1, 8)
	var script_content := "extends Node\n\nfunc _ready():\n"
	
	for i in range(get_node_count):
		var node_path := "Node%d" % i
		script_content += "\tvar node_%d = get_node(\"%s\")\n" % [i, node_path]
	
	# Write test file
	var test_file := _create_test_file("test_get_node.gd", script_content)
	if not test_file:
		return false
	
	# Analyze the file
	var analyzer := DependencyAnalyzer.new()
	var dep_info := analyzer.analyze_script(test_file)
	
	# Cleanup
	_cleanup_test_file(test_file)
	
	if not dep_info:
		return false
	
	# Verify all get_node calls were detected
	return dep_info.node_references.size() == get_node_count


func _test_all_autoload_refs_found(test_data: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = test_data.get("iteration", 0) + Time.get_ticks_msec()
	
	# Known autoloads to test
	var known_autoloads := ["GameManager", "EventBus", "GameDatabase", "GameManager"]
	var autoload_count := rng.randi_range(1, known_autoloads.size())
	
	var script_content := "extends Node\n\nfunc test():\n"
	var used_autoloads := []
	
	for i in range(autoload_count):
		var autoload: String = known_autoloads[i]
		used_autoloads.append(autoload)
		script_content += "\t%s.some_method()\n" % autoload
	
	# Write test file
	var test_file := _create_test_file("test_autoloads.gd", script_content)
	if not test_file:
		return false
	
	# Analyze the file
	var analyzer := DependencyAnalyzer.new()
	var dep_info := analyzer.analyze_script(test_file)
	
	# Cleanup
	_cleanup_test_file(test_file)
	
	if not dep_info:
		return false
	
	# Count unique autoload references
	var unique_autoloads := {}
	for autoload_dep in dep_info.autoload_references:
		if autoload_dep is DependencyAnalyzer.AutoloadDependency:
			unique_autoloads[autoload_dep.autoload_name] = true
	
	# Verify all used autoloads were detected
	return unique_autoloads.size() == autoload_count


func _test_all_class_refs_found(test_data: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = test_data.get("iteration", 0) + Time.get_ticks_msec()
	
	# Generate test script with known number of class references
	var class_count := rng.randi_range(1, 8)
	var script_content := "extends Node\n\n"
	
	for i in range(class_count):
		var class_name_val := "CustomClass%d" % i
		script_content += "var instance_%d: %s\n" % [i, class_name_val]
	
	# Write test file
	var test_file := _create_test_file("test_class_refs.gd", script_content)
	if not test_file:
		return false
	
	# Analyze the file
	var analyzer := DependencyAnalyzer.new()
	var dep_info := analyzer.analyze_script(test_file)
	
	# Cleanup
	_cleanup_test_file(test_file)
	
	if not dep_info:
		return false
	
	# Count class_name type imports
	var class_ref_count := 0
	for import_dep in dep_info.imports:
		if import_dep is DependencyAnalyzer.ImportDependency:
			if import_dep.import_type == "class_name":
				class_ref_count += 1
	
	# Verify all class references were detected
	return class_ref_count == class_count


func _test_all_dollar_syntax_found(test_data: Dictionary) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = test_data.get("iteration", 0) + Time.get_ticks_msec()
	
	# Generate test script with known number of $ references
	var dollar_count := rng.randi_range(1, 8)
	var script_content := "extends Node\n\nfunc _ready():\n"
	
	for i in range(dollar_count):
		var node_path := "Node%d" % i
		script_content += "\tvar node_%d = $%s\n" % [i, node_path]
	
	# Write test file
	var test_file := _create_test_file("test_dollar.gd", script_content)
	if not test_file:
		return false
	
	# Analyze the file
	var analyzer := DependencyAnalyzer.new()
	var dep_info := analyzer.analyze_script(test_file)
	
	# Cleanup
	_cleanup_test_file(test_file)
	
	if not dep_info:
		return false
	
	# Count $ syntax references
	var dollar_ref_count := 0
	for node_dep in dep_info.node_references:
		if node_dep is DependencyAnalyzer.NodeDependency:
			if node_dep.reference_type == "$":
				dollar_ref_count += 1
	
	# Verify all $ references were detected
	return dollar_ref_count == dollar_count


# =============================================================================
# HELPER METHODS
# =============================================================================


func _create_test_file(filename: String, content: String) -> String:
	# Ensure test directory exists
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_DIR)
	
	var file_path := TEST_DIR + filename
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create test file: %s" % file_path)
		return ""
	
	file.store_string(content)
	file.close()
	return file_path


func _cleanup_test_file(file_path: String) -> void:
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	_cleanup_test_directory()


func _cleanup_test_directory() -> void:
	if DirAccess.dir_exists_absolute(TEST_DIR):
		var dir := DirAccess.open(TEST_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name := dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(TEST_DIR)
