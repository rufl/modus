class_name MigrationTracker
extends RefCounted

## Tracks which files have been migrated to the new architecture structure
## and persists migration status to disk.
##
## This tool maintains a record of:
## - Files that have been migrated to the new structure
## - Files that remain in the old structure
## - Migration timestamp for each file
##
## **Validates: Requirements 8.4**

const MIGRATION_STATUS_FILE = "user://.migration_status.json"

# Migration status for each file
# Key: file path (relative to project root)
# Value: Dictionary with { "migrated": bool, "timestamp": int, "old_path": String, "new_path": String }
var _file_status: Dictionary = {}

# Statistics
var _total_files: int = 0
var _migrated_files: int = 0


func _init() -> void:
	load_status()


## Load migration status from persistent storage
func load_status() -> void:
	if not FileAccess.file_exists(MIGRATION_STATUS_FILE):
		_file_status = {}
		_total_files = 0
		_migrated_files = 0
		return
	
	var file = FileAccess.open(MIGRATION_STATUS_FILE, FileAccess.READ)
	if file == null:
		push_error("Failed to open migration status file: " + str(FileAccess.get_open_error()))
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var err = json.parse(json_string)
	if err != OK:
		push_error("Failed to parse migration status JSON: " + json.get_error_message())
		return
	
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Invalid migration status data format")
		return
	
	_file_status = data.get("files", {})
	_total_files = data.get("total_files", 0)
	_migrated_files = data.get("migrated_files", 0)


## Save migration status to persistent storage
func save_status() -> bool:
	var data = {
		"files": _file_status,
		"total_files": _total_files,
		"migrated_files": _migrated_files,
		"last_updated": Time.get_unix_time_from_system()
	}
	
	var json_string = JSONHelper.safe_stringify(data, "\t")
	
	var file = FileAccess.open(MIGRATION_STATUS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create migration status file: " + str(FileAccess.get_open_error()))
		return false
	
	file.store_string(json_string)
	file.close()
	return true


## Register a file that needs to be migrated
func register_file(file_path: String) -> void:
	if not _file_status.has(file_path):
		_file_status[file_path] = {
			"migrated": false,
			"timestamp": 0,
			"old_path": file_path,
			"new_path": ""
		}
		_total_files += 1


## Mark a file as migrated from old_path to new_path
func mark_migrated(old_path: String, new_path: String) -> void:
	if not _file_status.has(old_path):
		register_file(old_path)
	
	var status = _file_status[old_path]
	if not status["migrated"]:
		_migrated_files += 1
	
	status["migrated"] = true
	status["timestamp"] = Time.get_unix_time_from_system()
	status["new_path"] = new_path
	
	save_status()


## Mark a file as not migrated (rollback)
func mark_not_migrated(file_path: String) -> void:
	if not _file_status.has(file_path):
		return
	
	var status = _file_status[file_path]
	if status["migrated"]:
		_migrated_files -= 1
	
	status["migrated"] = false
	status["timestamp"] = 0
	status["new_path"] = ""
	
	save_status()


## Check if a file has been migrated
func is_migrated(file_path: String) -> bool:
	if not _file_status.has(file_path):
		return false
	return _file_status[file_path]["migrated"]


## Get the new path for a migrated file
func get_new_path(old_path: String) -> String:
	if not _file_status.has(old_path):
		return ""
	return _file_status[old_path].get("new_path", "")


## Get the old path for a file (if it was migrated)
func get_old_path(new_path: String) -> String:
	for old_path in _file_status:
		var status = _file_status[old_path]
		if status["new_path"] == new_path:
			return old_path
	return ""


## Get all files that have been migrated
func get_migrated_files() -> Array[String]:
	var result: Array[String] = []
	for file_path in _file_status:
		if _file_status[file_path]["migrated"]:
			result.append(file_path)
	return result


## Get all files that have not been migrated
func get_unmigrated_files() -> Array[String]:
	var result: Array[String] = []
	for file_path in _file_status:
		if not _file_status[file_path]["migrated"]:
			result.append(file_path)
	return result


## Get total number of files tracked
func get_total_files() -> int:
	return _total_files


## Get number of migrated files
func get_migrated_count() -> int:
	return _migrated_files


## Get number of unmigrated files
func get_unmigrated_count() -> int:
	return _total_files - _migrated_files


## Get migration percentage (0.0 to 100.0)
func get_migration_percentage() -> float:
	if _total_files == 0:
		return 0.0
	return (_migrated_files / float(_total_files)) * 100.0


## Clear all migration status (use with caution)
func clear_all() -> void:
	_file_status.clear()
	_total_files = 0
	_migrated_files = 0
	save_status()


## Get detailed status for a specific file
func get_file_status(file_path: String) -> Dictionary:
	if not _file_status.has(file_path):
		return {}
	return _file_status[file_path].duplicate()


## Get all file statuses
func get_all_statuses() -> Dictionary:
	return _file_status.duplicate(true)


## Scan a directory and register all files matching patterns
func scan_and_register(directory: String, patterns: Array[String] = ["*.gd", "*.tscn"]) -> int:
	var registered_count = 0
	var files = _scan_directory_recursive(directory, patterns)
	
	for file_path in files:
		register_file(file_path)
		registered_count += 1
	
	save_status()
	return registered_count


## Recursively scan directory for files matching patterns
func _scan_directory_recursive(directory: String, patterns: Array[String]) -> Array[String]:
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
			if not file_name.begins_with("."):
				result.append_array(_scan_directory_recursive(full_path, patterns))
		else:
			# Check if file matches any pattern
			for pattern in patterns:
				if file_name.match(pattern):
					result.append(full_path)
					break
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return result
