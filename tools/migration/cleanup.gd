class_name MigrationCleanup
extends RefCounted

## Cleanup script for removing adapter classes and old autoload files
## after migration is complete.
##
## **Validates: Requirements 8.6**

var tracker: MigrationTracker
var _deleted_files: Array[String] = []
var _errors: Array[Dictionary] = []


func _init(migration_tracker: MigrationTracker = null) -> void:
	if migration_tracker:
		tracker = migration_tracker
	else:
		tracker = MigrationTracker.new()


## Remove adapter classes
func remove_adapter_classes() -> Dictionary:
	var adapter_patterns = [
		"*_adapter.gd",
		"*Adapter.gd",
		"*_compat.gd",
		"*Compat.gd"
	]
	
	var results = {
		"files_deleted": 0,
		"errors": []
	}
	
	# Search for adapter files in common locations
	var search_dirs = [
		"res://game/core/adapters",
		"res://game/scripts/adapters",
		"res://game/adapters"
	]
	
	for dir_path in search_dirs:
		if DirAccess.dir_exists_absolute(dir_path):
			var adapter_files = _find_files_in_directory(dir_path, adapter_patterns)
			for file_path in adapter_files:
				if _delete_file(file_path):
					results["files_deleted"] += 1
					_deleted_files.append(file_path)
				else:
					results["errors"].append({
						"file": file_path,
						"error": "Failed to delete adapter file"
					})
	
	return results


## Remove old autoload files
func remove_old_autoloads() -> Dictionary:
	var old_autoloads = [
		"res://game/core/autoload/game_core.gd",
		"res://game/core/autoload/event_bus.gd",
		"res://game/core/autoload/game_database.gd"
	]
	
	var results = {
		"files_deleted": 0,
		"errors": []
	}
	
	for file_path in old_autoloads:
		# Only delete if the file has been migrated
		if tracker.is_migrated(file_path):
			if FileAccess.file_exists(file_path):
				if _delete_file(file_path):
					results["files_deleted"] += 1
					_deleted_files.append(file_path)
				else:
					results["errors"].append({
						"file": file_path,
						"error": "Failed to delete old autoload file"
					})
		else:
			results["errors"].append({
				"file": file_path,
				"error": "File not migrated yet, skipping deletion"
			})
	
	return results


## Remove empty directories
func remove_empty_directories() -> Dictionary:
	var results = {
		"dirs_deleted": 0,
		"errors": []
	}
	
	var dirs_to_check = [
		"res://game/core/autoload",
		"res://game/core/services",
		"res://game/core/systems",
		"res://game/core/adapters",
		"res://game/adapters"
	]
	
	for dir_path in dirs_to_check:
		if DirAccess.dir_exists_absolute(dir_path):
			if _is_directory_empty(dir_path):
				if _delete_directory(dir_path):
					results["dirs_deleted"] += 1
				else:
					results["errors"].append({
						"directory": dir_path,
						"error": "Failed to delete empty directory"
					})
	
	return results


## Perform full cleanup (adapters, old autoloads, empty directories)
func cleanup_all() -> Dictionary:
	var adapter_results = remove_adapter_classes()
	var autoload_results = remove_old_autoloads()
	var dir_results = remove_empty_directories()
	
	return {
		"adapters": adapter_results,
		"autoloads": autoload_results,
		"directories": dir_results,
		"total_files_deleted": adapter_results["files_deleted"] + autoload_results["files_deleted"],
		"total_dirs_deleted": dir_results["dirs_deleted"]
	}


## Verify migration is complete before cleanup
func verify_migration_complete() -> Dictionary:
	var percentage = tracker.get_migration_percentage()
	var unmigrated = tracker.get_unmigrated_files()
	
	return {
		"is_complete": percentage >= 100.0,
		"percentage": percentage,
		"unmigrated_count": unmigrated.size(),
		"unmigrated_files": unmigrated
	}


## Generate cleanup report
func generate_cleanup_report() -> String:
	var report = ""
	report += "============================================================\n"
	report += "MIGRATION CLEANUP REPORT\n"
	report += "============================================================\n\n"
	
	# Migration status
	var verification = verify_migration_complete()
	report += "Migration Status:\n"
	report += "------------------------------------------------------------\n"
	report += "  Complete: %s\n" % ("Yes" if verification["is_complete"] else "No")
	report += "  Progress: %.2f%%\n" % verification["percentage"]
	report += "  Unmigrated Files: %d\n\n" % verification["unmigrated_count"]
	
	if not verification["is_complete"]:
		report += "WARNING: Migration is not complete!\n"
		report += "Cleanup should only be performed after 100%% migration.\n\n"
	
	# Deleted files
	if _deleted_files.is_empty():
		report += "No files have been deleted yet.\n\n"
	else:
		report += "Deleted Files:\n"
		report += "------------------------------------------------------------\n"
		for file_path in _deleted_files:
			report += "  - %s\n" % file_path
		report += "\n"
	
	# Errors
	if _errors.is_empty():
		report += "No errors encountered.\n"
	else:
		report += "Errors:\n"
		report += "------------------------------------------------------------\n"
		for error in _errors:
			report += "  File: %s\n" % error.get("file", error.get("directory", "Unknown"))
			report += "  Error: %s\n\n" % error["error"]
	
	report += "============================================================\n"
	
	return report


## Get list of deleted files
func get_deleted_files() -> Array[String]:
	return _deleted_files.duplicate()


## Get list of errors
func get_errors() -> Array[Dictionary]:
	return _errors.duplicate()


## Delete a file
func _delete_file(file_path: String) -> bool:
	var dir = DirAccess.open(file_path.get_base_dir())
	if dir == null:
		push_error("Failed to open directory for file deletion: " + file_path)
		return false
	
	var err = dir.remove(file_path.get_file())
	if err != OK:
		push_error("Failed to delete file: " + file_path + " (Error: " + str(err) + ")")
		return false
	
	return true


## Delete a directory
func _delete_directory(dir_path: String) -> bool:
	var parent_dir = DirAccess.open(dir_path.get_base_dir())
	if parent_dir == null:
		push_error("Failed to open parent directory: " + dir_path.get_base_dir())
		return false
	
	var err = parent_dir.remove(dir_path.get_file())
	if err != OK:
		push_error("Failed to delete directory: " + dir_path + " (Error: " + str(err) + ")")
		return false
	
	return true


## Check if directory is empty
func _is_directory_empty(dir_path: String) -> bool:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return false
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Ignore . and .. and hidden files
		if file_name != "." and file_name != ".." and not file_name.begins_with("."):
			dir.list_dir_end()
			return false
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return true


## Find files matching patterns in a directory
func _find_files_in_directory(directory: String, patterns: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var dir = DirAccess.open(directory)
	
	if dir == null:
		return result
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = directory.path_join(file_name)
		
		if dir.current_is_dir():
			# Recursively search subdirectories
			if not file_name.begins_with("."):
				result.append_array(_find_files_in_directory(full_path, patterns))
		else:
			# Check if file matches any pattern
			for pattern in patterns:
				if file_name.match(pattern):
					result.append(full_path)
					break
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return result


## Create backup before cleanup
func create_backup(backup_dir: String = "user://migration_backup/") -> Dictionary:
	var results = {
		"success": false,
		"backed_up_files": 0,
		"errors": []
	}
	
	# Create backup directory
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("migration_backup"):
		var err = dir.make_dir("migration_backup")
		if err != OK:
			results["errors"].append({
				"error": "Failed to create backup directory"
			})
			return results
	
	# Backup files that will be deleted
	var files_to_backup = _get_files_to_cleanup()
	
	for file_path in files_to_backup:
		if FileAccess.file_exists(file_path):
			var backup_path = backup_dir + file_path.get_file()
			if _copy_file(file_path, backup_path):
				results["backed_up_files"] += 1
			else:
				results["errors"].append({
					"file": file_path,
					"error": "Failed to backup file"
				})
	
	results["success"] = results["errors"].is_empty()
	return results


## Get list of files that will be cleaned up
func _get_files_to_cleanup() -> Array[String]:
	var files: Array[String] = []
	
	# Add adapter files
	var adapter_patterns = ["*_adapter.gd", "*Adapter.gd", "*_compat.gd", "*Compat.gd"]
	var search_dirs = ["res://game/core/adapters", "res://game/scripts/adapters", "res://game/adapters"]
	
	for dir_path in search_dirs:
		if DirAccess.dir_exists_absolute(dir_path):
			files.append_array(_find_files_in_directory(dir_path, adapter_patterns))
	
	# Add old autoloads
	var old_autoloads = [
		"res://game/core/autoload/game_core.gd",
		"res://game/core/autoload/event_bus.gd",
		"res://game/core/autoload/game_database.gd"
	]
	
	for file_path in old_autoloads:
		if FileAccess.file_exists(file_path) and tracker.is_migrated(file_path):
			files.append(file_path)
	
	return files


## Copy a file
func _copy_file(source: String, destination: String) -> bool:
	var source_file = FileAccess.open(source, FileAccess.READ)
	if source_file == null:
		return false
	
	var content = source_file.get_buffer(source_file.get_length())
	source_file.close()
	
	var dest_file = FileAccess.open(destination, FileAccess.WRITE)
	if dest_file == null:
		return false
	
	dest_file.store_buffer(content)
	dest_file.close()
	
	return true
