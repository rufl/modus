extends PropertyBasedTesting

## Property-Based Test: Script Scanner Completeness
## Feature: architecture-refactoring, Property 1: Complete script scanning
## Validates: Requirements 1.1

const ScriptScanner = preload("res://tools/analyzer/script_scanner.gd")

## Property 1: Complete script scanning
## For any directory structure containing GDScript files, when the Architecture_Analyzer
## scans specified directories, all .gd files in those directories and subdirectories
## should be included in the analysis results.


func test_property_all_scripts_discovered() -> void:
	# Property: For any directory with .gd files, scan_directory should find all of them
	
	await run_enhanced_property_test(
		"All scripts discovered",
		_test_all_scripts_found,
		100,
		SamplingStrategy.MIXED,
		"ScriptScanner should discover all .gd files in directory tree"
	)


func _test_all_scripts_found(test_data: Dictionary) -> bool:
	var scanner := ScriptScanner.new()
	
	# Test on known directories that exist in the project
	var test_dirs := [
		"res://tools/analyzer",
		"res://game/scripts/core",
		"res://tests/property"
	]
	
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	var test_dir: String = test_dirs[rng.randi_range(0, test_dirs.size() - 1)]
	
	# Count actual .gd files in the directory
	var expected_files := _count_gd_files_recursive(test_dir)
	
	# Scan the directory
	var results: Array = scanner.scan_directory(test_dir)
	
	# Verify all files were found
	return results.size() == expected_files.size()


func test_property_no_duplicate_files() -> void:
	# Property: scan_directory should not return duplicate file paths
	
	await run_enhanced_property_test(
		"No duplicate files",
		_test_no_duplicates,
		100,
		SamplingStrategy.MIXED,
		"ScriptScanner should not return duplicate file paths"
	)


func _test_no_duplicates(test_data: Dictionary) -> bool:
	var scanner := ScriptScanner.new()
	
	var test_dirs := [
		"res://tools/analyzer",
		"res://game/scripts/core",
		"res://tests/property"
	]
	
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	var test_dir: String = test_dirs[rng.randi_range(0, test_dirs.size() - 1)]
	
	var results: Array = scanner.scan_directory(test_dir)
	
	# Check for duplicates by comparing file paths
	var seen_paths := {}
	for result in results:
		var file_path: String = result.file_path
		if seen_paths.has(file_path):
			return false  # Found duplicate
		seen_paths[file_path] = true
	
	return true


func test_property_hidden_directories_excluded() -> void:
	# Property: Directories starting with '.' should be excluded from scanning
	
	await run_enhanced_property_test(
		"Hidden directories excluded",
		_test_hidden_dirs_excluded,
		100,
		SamplingStrategy.MIXED,
		"ScriptScanner should exclude hidden directories (starting with '.')"
	)


func _test_hidden_dirs_excluded(test_data: Dictionary) -> bool:
	var scanner := ScriptScanner.new()
	
	# Scan from project root which contains .godot directory
	var results: Array = scanner.scan_directory("res://")
	
	# Verify no results come from hidden directories
	for result in results:
		var file_path: String = result.file_path
		# Check if path contains a hidden directory component
		var path_parts := file_path.split("/")
		for part in path_parts:
			if part.begins_with(".") and part != "." and part != "..":
				return false  # Found file in hidden directory
	
	return true


func test_property_only_gd_files_included() -> void:
	# Property: Only files ending with .gd should be included in results
	
	await run_enhanced_property_test(
		"Only .gd files included",
		_test_only_gd_files,
		100,
		SamplingStrategy.MIXED,
		"ScriptScanner should only include .gd files"
	)


func _test_only_gd_files(test_data: Dictionary) -> bool:
	var scanner := ScriptScanner.new()
	
	var test_dirs := [
		"res://tools/analyzer",
		"res://game/scripts/core",
		"res://tests/property"
	]
	
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	var test_dir: String = test_dirs[rng.randi_range(0, test_dirs.size() - 1)]
	
	var results: Array = scanner.scan_directory(test_dir)
	
	# Verify all results are .gd files
	for result in results:
		var file_path: String = result.file_path
		if not file_path.ends_with(".gd"):
			return false
	
	return true


func test_property_recursive_scanning() -> void:
	# Property: scan_directory should recursively scan subdirectories
	
	await run_enhanced_property_test(
		"Recursive scanning",
		_test_recursive_scan,
		100,
		SamplingStrategy.MIXED,
		"ScriptScanner should recursively scan subdirectories"
	)


func _test_recursive_scan(test_data: Dictionary) -> bool:
	var scanner := ScriptScanner.new()
	
	# Scan a directory known to have subdirectories
	var results: Array = scanner.scan_directory("res://game/scripts")
	
	# Check if we found files from subdirectories
	var has_subdirectory_files := false
	for result in results:
		var file_path: String = result.file_path
		# Count directory separators - if more than base path, it's from a subdirectory
		var relative_path := file_path.replace("res://game/scripts/", "")
		if "/" in relative_path:
			has_subdirectory_files = true
			break
	
	# Should find files in subdirectories
	return has_subdirectory_files


func test_property_script_info_completeness() -> void:
	# Property: Each ScriptInfo should have required fields populated
	
	await run_enhanced_property_test(
		"ScriptInfo completeness",
		_test_script_info_complete,
		100,
		SamplingStrategy.MIXED,
		"Each ScriptInfo should have file_path and line_count populated"
	)


func _test_script_info_complete(test_data: Dictionary) -> bool:
	var scanner := ScriptScanner.new()
	
	var test_dirs := [
		"res://tools/analyzer",
		"res://game/scripts/core"
	]
	
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	var test_dir: String = test_dirs[rng.randi_range(0, test_dirs.size() - 1)]
	
	var results: Array = scanner.scan_directory(test_dir)
	
	# Verify each result has required fields
	for result in results:
		if result.file_path.is_empty():
			return false
		if result.line_count <= 0:
			return false
	
	return true


func test_property_empty_directory_returns_empty() -> void:
	# Property: Scanning a non-existent or empty directory should return empty array
	
	await run_enhanced_property_test(
		"Empty directory returns empty",
		_test_empty_dir,
		100,
		SamplingStrategy.EDGE_CASE,
		"ScriptScanner should return empty array for non-existent directories"
	)


func _test_empty_dir(test_data: Dictionary) -> bool:
	var scanner := ScriptScanner.new()
	
	# Test with non-existent directory
	var results: Array = scanner.scan_directory("res://nonexistent_directory_12345")
	
	# Should return empty array
	return results.size() == 0


## Helper function to count .gd files recursively
func _count_gd_files_recursive(dir_path: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(dir_path)
	
	if not dir:
		return files
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			# Skip hidden directories
			if not file_name.begins_with("."):
				var subdir_path := dir_path.path_join(file_name)
				files.append_array(_count_gd_files_recursive(subdir_path))
		elif file_name.ends_with(".gd"):
			files.append(dir_path.path_join(file_name))
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return files
