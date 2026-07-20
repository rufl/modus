class_name SaveService
extends Node

signal save_completed(slot_name: String)
signal load_completed(slot_name: String, data: Dictionary)
signal error_occurred(msg: String)

const SAVE_DIR: String = "user://saves/"
const METADATA_EXT: String = ".meta"  # Unencrypted metadata
const DATA_EXT: String = ".sav"  # Encrypted data
const ENCRYPTION_KEY: String = "MODUS_SECURE_SAVE_KEY_2025"
const JSONHelperClass = preload("res://game/core/json_helper.gd")


func initialize() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err != OK:
			push_error("[SaveService] Failed to create save directory: %s" % error_string(err))


func get_init_priority() -> int:
	return 50  # Initialized early, after basic config


## Save data to a named slot


func save_data(slot_name: String, data: Dictionary, metadata: Dictionary = {}) -> bool:
	# 1. Prepare Paths
	var data_path: String = SAVE_DIR + slot_name + DATA_EXT
	var meta_path: String = SAVE_DIR + slot_name + METADATA_EXT

	# 2. Add system metadata
	metadata["timestamp"] = Time.get_unix_time_from_system()
	metadata["date_string"] = Time.get_datetime_string_from_system()
	metadata["version"] = ProjectSettings.get_setting("application/config/version", "1.0")

	# 3. Write Encrypted Data
	var file_data: FileAccess = FileAccess.open_encrypted_with_pass(
		data_path, FileAccess.WRITE, ENCRYPTION_KEY
	)

	if not file_data:
		_handle_error("Failed to open save file for writing: %s" % data_path)
		return false

	var json_string: String = JSONHelperClass.safe_stringify(data)
	file_data.store_string(json_string)
	file_data.close()

	# 4. Write Plaintext Metadata (for listing saves quickly)
	var file_meta: FileAccess = FileAccess.open(meta_path, FileAccess.WRITE)
	if file_meta:
		file_meta.store_string(JSONHelperClass.safe_stringify(metadata, "\t"))
		file_meta.close()

	save_completed.emit(slot_name)
	return true


## Legacy path-based save API retained for older tests and compatibility tools.
## Use save_data/load_data for production slot saves.
func save_game(save_path: String, data: Dictionary) -> bool:
	if save_path.begins_with("user://") or save_path.begins_with("res://"):
		var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
		if not file:
			_handle_error("Failed to open legacy save path for writing: %s" % save_path)
			return false
		file.store_string(var_to_str(data))
		file.close()
		save_completed.emit(save_path)
		return true

	return save_data(save_path, data)


## Load data from a named slot


func load_data(slot_name: String) -> Dictionary:
	var data_path: String = SAVE_DIR + slot_name + DATA_EXT

	if not FileAccess.file_exists(data_path):
		# Not an error - just no save exists yet (first run)
		return {}

	var file: FileAccess = FileAccess.open_encrypted_with_pass(
		data_path, FileAccess.READ, ENCRYPTION_KEY
	)

	if not file:
		_handle_error("Failed to open save file (Corrupted or wrong key): %s" % slot_name)
		return {}

	var content: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(content)

	if err != OK:
		_handle_error("JSON Parse Error in save file: %s" % json.get_error_message())
		return {}

	var result: Variant = json.data
	if typeof(result) != TYPE_DICTIONARY:
		_handle_error("Save data is not a dictionary!")
		return {}

	load_completed.emit(slot_name, result)
	return result


## Legacy path-based load API retained for older tests and compatibility tools.
func load_game(save_path: String) -> Dictionary:
	if save_path.begins_with("user://") or save_path.begins_with("res://"):
		if not FileAccess.file_exists(save_path):
			return {}

		var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
		if not file:
			_handle_error("Failed to open legacy save path for reading: %s" % save_path)
			return {}

		var content: String = file.get_as_text()
		file.close()

		var result: Variant = str_to_var(content)
		if typeof(result) != TYPE_DICTIONARY:
			return {}

		load_completed.emit(save_path, result)
		return result

	return load_data(save_path)


func validate_save_data(data: Dictionary) -> bool:
	if data.is_empty():
		return false

	if data.has("version") and typeof(data.version) != TYPE_STRING:
		return false

	return true


## Get metadata for a slot without decrypting the main file


func get_slot_metadata(slot_name: String) -> Dictionary:
	var meta_path: String = SAVE_DIR + slot_name + METADATA_EXT
	if not FileAccess.file_exists(meta_path):
		return {}

	var content: String = FileAccess.get_file_as_string(meta_path)
	var json := JSON.new()
	if json.parse(content) == OK:
		if typeof(json.data) == TYPE_DICTIONARY:
			return json.data
	return {}


## Get all available save slots with their metadata


func get_all_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return []

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(METADATA_EXT):
			var slot_name: String = file_name.replace(METADATA_EXT, "")
			# Verify data file exists
			if FileAccess.file_exists(SAVE_DIR + slot_name + DATA_EXT):
				var meta: Dictionary = get_slot_metadata(slot_name)
				meta["slot_name"] = slot_name
				saves.append(meta)

		file_name = dir.get_next()

	# Sort by timestamp descending (newest first)
	saves.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("timestamp", 0) > b.get("timestamp", 0)
	)

	return saves


func delete_save(slot_name: String) -> void:
	var data_path: String = SAVE_DIR + slot_name + DATA_EXT
	var meta_path: String = SAVE_DIR + slot_name + METADATA_EXT

	if FileAccess.file_exists(data_path):
		DirAccess.remove_absolute(data_path)
	if FileAccess.file_exists(meta_path):
		DirAccess.remove_absolute(meta_path)


func _handle_error(msg: String) -> void:
	push_error("[SaveService] " + msg)
	error_occurred.emit(msg)
