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
	if not _validate_slot_name(slot_name):
		_handle_error("Invalid save slot name: %s" % slot_name)
		return false

	var data_path: String = SAVE_DIR + slot_name + DATA_EXT
	var meta_path: String = SAVE_DIR + slot_name + METADATA_EXT
	var staged_data_path: String = data_path + ".staging"
	var staged_meta_path: String = meta_path + ".staging"

	# Remove remnants from an interrupted save before creating a new transaction.
	if not _remove_file_if_exists(staged_data_path) or not _remove_file_if_exists(staged_meta_path):
		return false

	metadata["timestamp"] = Time.get_unix_time_from_system()
	metadata["date_string"] = Time.get_datetime_string_from_system()
	metadata["version"] = ProjectSettings.get_setting("application/config/version", "1.0")

	var data_json: String = JSONHelperClass.safe_stringify(data)
	var metadata_json: String = JSONHelperClass.safe_stringify(metadata, "\t")

	if not _write_encrypted_stage(staged_data_path, data_json):
		_cleanup_staged_files(staged_data_path, staged_meta_path)
		return false
	if not _write_plaintext_stage(staged_meta_path, metadata_json):
		_cleanup_staged_files(staged_data_path, staged_meta_path)
		return false

	# Re-open both staged files and parse them before touching the current save.
	if not _validate_staged_files(staged_data_path, staged_meta_path):
		_cleanup_staged_files(staged_data_path, staged_meta_path)
		return false

	var promoted: bool = _promote_staged_files(
		data_path, meta_path, staged_data_path, staged_meta_path
	)
	_cleanup_staged_files(staged_data_path, staged_meta_path)
	if not promoted:
		return false

	save_completed.emit(slot_name)
	return true


func _write_encrypted_stage(path: String, content: String) -> bool:
	var file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, ENCRYPTION_KEY)
	if not file:
		_handle_error("Failed to open staged save file for writing: %s" % path)
		return false

	file.store_string(content)
	file.flush()
	var err: Error = file.get_error()
	file.close()
	if err != OK:
		_handle_error("Failed to write staged save file %s: %s" % [path, error_string(err)])
		return false
	return true


func _write_plaintext_stage(path: String, content: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_handle_error("Failed to open staged metadata file for writing: %s" % path)
		return false

	file.store_string(content)
	file.flush()
	var err: Error = file.get_error()
	file.close()
	if err != OK:
		_handle_error("Failed to write staged metadata file %s: %s" % [path, error_string(err)])
		return false
	return true


func _validate_staged_files(data_path: String, meta_path: String) -> bool:
	var data_file: FileAccess = FileAccess.open_encrypted_with_pass(
		data_path, FileAccess.READ, ENCRYPTION_KEY
	)
	if not data_file:
		_handle_error("Failed to validate staged save file: %s" % data_path)
		return false
	var data_content: String = data_file.get_as_text()
	var data_err: Error = data_file.get_error()
	data_file.close()
	if data_err != OK:
		_handle_error("Failed to read staged save file %s: %s" % [data_path, error_string(data_err)])
		return false

	var data_json := JSON.new()
	if data_json.parse(data_content) != OK or typeof(data_json.data) != TYPE_DICTIONARY:
		_handle_error("Staged save data is invalid: %s" % data_path)
		return false

	var meta_file: FileAccess = FileAccess.open(meta_path, FileAccess.READ)
	if not meta_file:
		_handle_error("Failed to validate staged metadata file: %s" % meta_path)
		return false
	var meta_content: String = meta_file.get_as_text()
	var meta_err: Error = meta_file.get_error()
	meta_file.close()
	if meta_err != OK:
		_handle_error("Failed to read staged metadata file %s: %s" % [meta_path, error_string(meta_err)])
		return false

	var meta_json := JSON.new()
	if meta_json.parse(meta_content) != OK or typeof(meta_json.data) != TYPE_DICTIONARY:
		_handle_error("Staged metadata is invalid: %s" % meta_path)
		return false
	return true


func _promote_staged_files(
	data_path: String, meta_path: String, staged_data_path: String, staged_meta_path: String
) -> bool:
	var data_backup_path: String = data_path + ".backup"
	var meta_backup_path: String = meta_path + ".backup"
	if not _remove_file_if_exists(data_backup_path) or not _remove_file_if_exists(meta_backup_path):
		return false

	var had_data: bool = FileAccess.file_exists(data_path)
	var had_meta: bool = FileAccess.file_exists(meta_path)
	if had_data and DirAccess.rename_absolute(data_path, data_backup_path) != OK:
		_handle_error("Failed to protect existing save data: %s" % data_path)
		return false
	if had_meta and DirAccess.rename_absolute(meta_path, meta_backup_path) != OK:
		# The original metadata is still at meta_path because its rename failed.
		if had_data and FileAccess.file_exists(data_backup_path):
			DirAccess.rename_absolute(data_backup_path, data_path)
		_handle_error("Failed to protect existing save metadata: %s" % meta_path)
		return false

	var data_promoted: bool = DirAccess.rename_absolute(staged_data_path, data_path) == OK
	if not data_promoted:
		_restore_promoted_files(
			data_path, meta_path, data_backup_path, meta_backup_path, had_data, had_meta
		)
		_handle_error("Failed to promote save data: %s" % data_path)
		return false

	var meta_promoted: bool = DirAccess.rename_absolute(staged_meta_path, meta_path) == OK
	if not meta_promoted:
		_restore_promoted_files(
			data_path, meta_path, data_backup_path, meta_backup_path, had_data, had_meta
		)
		_handle_error("Failed to promote save metadata: %s" % meta_path)
		return false

	_remove_file_if_exists(data_backup_path)
	_remove_file_if_exists(meta_backup_path)
	return true


func _restore_promoted_files(
	data_path: String,
	meta_path: String,
	data_backup_path: String,
	meta_backup_path: String,
	had_data: bool,
	had_meta: bool
) -> void:
	if FileAccess.file_exists(data_path):
		DirAccess.remove_absolute(data_path)
	if FileAccess.file_exists(meta_path):
		DirAccess.remove_absolute(meta_path)
	if had_data and FileAccess.file_exists(data_backup_path):
		DirAccess.rename_absolute(data_backup_path, data_path)
	if had_meta and FileAccess.file_exists(meta_backup_path):
		DirAccess.rename_absolute(meta_backup_path, meta_path)


func _cleanup_staged_files(staged_data_path: String, staged_meta_path: String) -> void:
	_remove_file_if_exists(staged_data_path)
	_remove_file_if_exists(staged_meta_path)


func _remove_file_if_exists(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var err: Error = DirAccess.remove_absolute(path)
	if err != OK:
		_handle_error("Failed to remove temporary save file %s: %s" % [path, error_string(err)])
		return false
	return true


func _validate_slot_name(slot_name: String) -> bool:
	if slot_name.is_empty() or slot_name == "." or slot_name == "..":
		return false
	if slot_name.contains("..") or slot_name.contains("/") or slot_name.contains("\\"):
		return false
	for character: String in slot_name:
		var is_lower: bool = character >= "a" and character <= "z"
		var is_upper: bool = character >= "A" and character <= "Z"
		var is_digit: bool = character >= "0" and character <= "9"
		if not (is_lower or is_upper or is_digit or character == "_" or character == "-"):
			return false
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
	if not _validate_slot_name(slot_name):
		_handle_error("Invalid save slot name: %s" % slot_name)
		return {}

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
	if not _validate_slot_name(slot_name):
		_handle_error("Invalid save slot name: %s" % slot_name)
		return {}

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
			var slot_name: String = file_name.trim_suffix(METADATA_EXT)
			# Only complete, safely named pairs are listable slots.
			if _validate_slot_name(slot_name) and FileAccess.file_exists(SAVE_DIR + slot_name + DATA_EXT):
				var meta: Dictionary = get_slot_metadata(slot_name)
				meta["slot_name"] = slot_name
				saves.append(meta)

		file_name = dir.get_next()

	dir.list_dir_end()

	# Sort by timestamp descending (newest first)
	saves.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.get("timestamp", 0) > b.get("timestamp", 0)
	)

	return saves


func save_exists(slot_name: String) -> bool:
	if not _validate_slot_name(slot_name):
		return false
	return (
		FileAccess.file_exists(SAVE_DIR + slot_name + DATA_EXT)
		and FileAccess.file_exists(SAVE_DIR + slot_name + METADATA_EXT)
	)


func delete_save(slot_name: String) -> void:
	if not _validate_slot_name(slot_name):
		_handle_error("Invalid save slot name: %s" % slot_name)
		return

	var data_path: String = SAVE_DIR + slot_name + DATA_EXT
	var meta_path: String = SAVE_DIR + slot_name + METADATA_EXT
	_cleanup_staged_files(data_path + ".staging", meta_path + ".staging")
	_remove_file_if_exists(data_path)
	_remove_file_if_exists(meta_path)

func _handle_error(msg: String) -> void:
	push_error("[SaveService] " + msg)
	error_occurred.emit(msg)
