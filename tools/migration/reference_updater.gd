class_name ReferenceUpdater
extends RefCounted

## Scans .tscn files and GDScript files for file references and updates them
## to new paths after migration.
##
## **Validates: Requirements 3.5**

var tracker: MigrationTracker
var _updated_references: Dictionary = {}  # file -> count of updates
var _broken_references: Array[Dictionary] = []


func _init(migration_tracker: MigrationTracker = null) -> void:
	if migration_tracker:
		tracker = migration_tracker
	else:
		tracker = MigrationTracker.new()


## Scan all .tscn files and update references
func update_scene_references() -> Dictionary:
	var scenes = _find_all_files("res://", ["*.tscn"])
	var results = {
		"total_scenes": scenes.size(),
		"scenes_updated": 0,
		"total_references_updated": 0,
		"errors": []
	}
	
	for scene_path in scenes:
		var update_count = _update_references_in_scene(scene_path)
		if update_count > 0:
			results["scenes_updated"] += 1
			results["total_references_updated"] += update_count
	
	return results


## Scan all .gd files and update import statements
func update_script_references() -> Dictionary:
	var scripts = _find_all_files("res://", ["*.gd"])
	var results = {
		"total_scripts": scripts.size(),
		"scripts_updated": 0,
		"total_references_updated": 0,
		"errors": []
	}
	
	for script_path in scripts:
		var update_count = _update_references_in_script(script_path)
		if update_count > 0:
			results["scripts_updated"] += 1
			results["total_references_updated"] += update_count
	
	return results


## Update all references (scenes and scripts)
func update_all_references() -> Dictionary:
	var scene_results = update_scene_references()
	var script_results = update_script_references()
	
	return {
		"scenes": scene_results,
		"scripts": script_results,
		"total_updates": scene_results["total_references_updated"] + script_results["total_references_updated"]
	}


## Validate that all references resolve correctly
func validate_all_references() -> Dictionary:
	_broken_references.clear()
	
	# Validate scene references
	var scenes = _find_all_files("res://", ["*.tscn"])
	for scene_path in scenes:
		_validate_references_in_scene(scene_path)
	
	# Validate script references
	var scripts = _find_all_files("res://", ["*.gd"])
	for script_path in scripts:
		_validate_references_in_script(script_path)
	
	return {
		"total_broken": _broken_references.size(),
		"broken_references": _broken_references.duplicate()
	}


## Get broken references found during validation
func get_broken_references() -> Array[Dictionary]:
	return _broken_references.duplicate()


## Update references in a single scene file
func _update_references_in_scene(scene_path: String) -> int:
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open scene file: " + scene_path)
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	var original_content = content
	var update_count = 0
	
	# Update ext_resource paths
	var regex = RegEx.new()
	regex.compile('path="(res://[^"]+)"')
	
	var matches = regex.search_all(content)
	for match_obj in matches:
		var old_path = match_obj.get_string(1)
		var new_path = tracker.get_new_path(old_path)
		
		if new_path != "" and new_path != old_path:
			content = content.replace('path="' + old_path + '"', 'path="' + new_path + '"')
			update_count += 1
	
	# Update script paths
	regex.compile('script = ExtResource\\("([^"]+)"\\)')
	matches = regex.search_all(content)
	# Note: ExtResource references are by ID, not path, so we don't need to update them
	
	# Save if changes were made
	if content != original_content:
		var write_file = FileAccess.open(scene_path, FileAccess.WRITE)
		if write_file == null:
			push_error("Failed to write scene file: " + scene_path)
			return 0
		write_file.store_string(content)
		write_file.close()
	
	return update_count


## Update references in a single script file
func _update_references_in_script(script_path: String) -> int:
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open script file: " + script_path)
		return 0
	
	var content = file.get_as_text()
	file.close()
	
	var original_content = content
	var update_count = 0
	
	# Update preload statements
	var regex = RegEx.new()
	regex.compile('preload\\("(res://[^"]+)"\\)')
	
	var matches = regex.search_all(content)
	for match_obj in matches:
		var old_path = match_obj.get_string(1)
		var new_path = tracker.get_new_path(old_path)
		
		if new_path != "" and new_path != old_path:
			content = content.replace('preload("' + old_path + '")', 'preload("' + new_path + '")')
			update_count += 1
	
	# Update load statements (but not preload)
	regex.compile('(?<!pre)load\\("(res://[^"]+)"\\)')
	matches = regex.search_all(content)
	for match_obj in matches:
		var old_path = match_obj.get_string(1)
		var new_path = tracker.get_new_path(old_path)
		
		if new_path != "" and new_path != old_path:
			content = content.replace('load("' + old_path + '")', 'load("' + new_path + '")')
			update_count += 1
	
	# Update ResourceLoader.load statements
	regex.compile('ResourceLoader\\.load\\("(res://[^"]+)"')
	matches = regex.search_all(content)
	for match_obj in matches:
		var old_path = match_obj.get_string(1)
		var new_path = tracker.get_new_path(old_path)
		
		if new_path != "" and new_path != old_path:
			content = content.replace('ResourceLoader.load("' + old_path + '"', 'ResourceLoader.load("' + new_path + '"')
			update_count += 1
	
	# Save if changes were made
	if content != original_content:
		var write_file = FileAccess.open(script_path, FileAccess.WRITE)
		if write_file == null:
			push_error("Failed to write script file: " + script_path)
			return 0
		write_file.store_string(content)
		write_file.close()
	
	return update_count


## Validate references in a scene file
func _validate_references_in_scene(scene_path: String) -> void:
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if file == null:
		return
	
	var content = file.get_as_text()
	file.close()
	
	var regex = RegEx.new()
	regex.compile('path="(res://[^"]+)"')
	
	var matches = regex.search_all(content)
	for match_obj in matches:
		var referenced_path = match_obj.get_string(1)
		if not FileAccess.file_exists(referenced_path) and not DirAccess.dir_exists_absolute(referenced_path):
			_broken_references.append({
				"source_file": scene_path,
				"referenced_path": referenced_path,
				"type": "scene_resource"
			})


## Validate references in a script file
func _validate_references_in_script(script_path: String) -> void:
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Check preload statements
	var regex = RegEx.new()
	regex.compile('preload\\("(res://[^"]+)"\\)')
	
	var matches = regex.search_all(content)
	for match_obj in matches:
		var referenced_path = match_obj.get_string(1)
		if not FileAccess.file_exists(referenced_path):
			_broken_references.append({
				"source_file": script_path,
				"referenced_path": referenced_path,
				"type": "preload"
			})
	
	# Check load statements (but not preload)
	regex.compile('(?<!pre)load\\("(res://[^"]+)"\\)')
	matches = regex.search_all(content)
	for match_obj in matches:
		var referenced_path = match_obj.get_string(1)
		if not FileAccess.file_exists(referenced_path):
			_broken_references.append({
				"source_file": script_path,
				"referenced_path": referenced_path,
				"type": "load"
			})
	
	# Check ResourceLoader.load statements
	regex.compile('ResourceLoader\\.load\\("(res://[^"]+)"')
	matches = regex.search_all(content)
	for match_obj in matches:
		var referenced_path = match_obj.get_string(1)
		if not FileAccess.file_exists(referenced_path):
			_broken_references.append({
				"source_file": script_path,
				"referenced_path": referenced_path,
				"type": "ResourceLoader.load"
			})


## Find all files matching patterns in a directory
func _find_all_files(directory: String, patterns: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(directory)
	
	if dir == null:
		push_error("Failed to open directory: " + directory)
		return result
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = directory.path_join(file_name)
		
		if dir.current_is_dir():
			# Skip hidden directories and .godot
			if not file_name.begins_with(".") and file_name != "addons":
				result.append_array(_find_all_files(full_path, patterns))
		else:
			# Check if file matches any pattern
			for pattern in patterns:
				if file_name.match(pattern):
					result.append(full_path)
					break
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return result


## Generate a report of all updates made
func generate_update_report() -> String:
	var report = ""
	report += "============================================================\n"
	report += "REFERENCE UPDATE REPORT\n"
	report += "============================================================\n\n"
	
	if _updated_references.is_empty():
		report += "No references were updated.\n"
	else:
		report += "Updated References:\n"
		report += "------------------------------------------------------------\n"
		for file_path in _updated_references:
			report += "  %s: %d updates\n" % [file_path, _updated_references[file_path]]
		report += "\n"
	
	if _broken_references.is_empty():
		report += "No broken references found.\n"
	else:
		report += "Broken References:\n"
		report += "------------------------------------------------------------\n"
		for broken_ref in _broken_references:
			report += "  Source: %s\n" % broken_ref["source_file"]
			report += "  Missing: %s\n" % broken_ref["referenced_path"]
			report += "  Type: %s\n\n" % broken_ref["type"]
	
	report += "============================================================\n"
	
	return report
