class_name ConfigurationManager
extends Node

## Configuration Manager for loading and managing JSON5 configuration files
##
## Features:
## - JSON5 file loading with caching
## - Dot-notation path access (e.g., "gameplay.movement.speed")
## - Configuration validation with error reporting
## - Hot-reload support for development mode
## - Fallback to default values when keys don't exist

signal config_reloaded(file_path: String)
signal config_error(file_path: String, error_message: String)

const JSON5LoaderClass = preload("res://game/core/json5_loader.gd")

# Configuration cache: file_path -> parsed_data
var _config_cache: Dictionary = {}

# File watching for hot-reload
var _watch_files: bool = false
var _file_timestamps: Dictionary = {}

# Base configuration directory
const CONFIG_DIR: String = "res://game/config/"


## Load a JSON5 configuration file and cache it
## Returns the parsed configuration Dictionary, or an empty Dictionary on error
func load_config_file(path: String) -> Dictionary:
	var full_path := _resolve_path(path)

	# Check cache first (caching optimization)
	if _config_cache.has(full_path):
		return _config_cache[full_path]

	if not JSON5LoaderClass.file_exists(full_path):
		var error_msg := "Configuration file not found: %s" % full_path
		push_error("[ConfigurationManager] " + error_msg)
		config_error.emit(full_path, error_msg)
		return {}

	var data: Variant = JSON5LoaderClass.load_file(full_path)

	if data == null:
		var error_msg := "Failed to parse JSON5 file: %s" % full_path
		push_error("[ConfigurationManager] " + error_msg)
		config_error.emit(full_path, error_msg)
		return {}

	if not data is Dictionary:
		var error_msg := (
			"Configuration file must contain a JSON object (Dictionary): %s" % full_path
		)
		push_error("[ConfigurationManager] " + error_msg)
		config_error.emit(full_path, error_msg)
		return {}

	_config_cache[full_path] = data

	if _watch_files:
		_update_file_timestamp(full_path)

	return data


## Get a configuration value using dot-notation path
## Example: get_value("gameplay.movement.speed", 10.0)
## Returns the default value if the path doesn't exist
func get_value(path: String, default: Variant = null) -> Variant:
	var parts := path.split(".", false)
	if parts.is_empty():
		push_warning("[ConfigurationManager] Empty path provided")
		return default

	# Try to find the value in any cached config file
	for config_path: String in _config_cache.keys():
		var config_data: Dictionary = _config_cache[config_path]
		var value: Variant = _traverse_path(config_data, parts)
		if value != null:
			return value

		value = _traverse_namespaced_path(config_path, config_data, parts)
		if value != null:
			return value

	# Value not found, return default
	if default != null:
		push_warning(
			(
				"[ConfigurationManager] Configuration key not found: '%s', using default: %s"
				% [path, default]
			)
		)

	return default


## Check if a feature is enabled in the configuration
## Looks for the feature in systems_enabled dictionary
## Returns true by default if not found (opt-out model)
func is_feature_enabled(feature_id: String) -> bool:
	var systems: Dictionary = get_value("systems_enabled", {})
	return systems.get(feature_id, true)


## Set a configuration value using dot-notation path (runtime only, not persisted)
## Example: set_value("gameplay.movement.speed", 15.0)
func set_value(path: String, value: Variant) -> void:
	var parts := path.split(".", false)
	if parts.is_empty():
		push_warning("[ConfigurationManager] Empty path provided")
		return

	# Set in the first cached config file, or create a new runtime config
	if _config_cache.is_empty():
		_config_cache["runtime"] = {}

	var config_data: Dictionary = _config_cache.values()[0]
	_set_path_value(config_data, parts, value)


## Reload all cached configuration files
## Useful for hot-reloading during development
func reload_all() -> void:
	var paths: Array = _config_cache.keys()
	_config_cache.clear()

	for config_path: String in paths:
		if config_path == "runtime":
			continue
		load_config_file(config_path)
		config_reloaded.emit(config_path)


## Reload a specific configuration file
func reload_file(path: String) -> void:
	var full_path := _resolve_path(path)
	if _config_cache.has(full_path):
		_config_cache.erase(full_path)
		load_config_file(path)
		config_reloaded.emit(full_path)


## Enable file watching for hot-reload support
## Checks for file modifications and automatically reloads changed files
func enable_file_watching() -> void:
	_watch_files = true
	for path: String in _config_cache.keys():
		if path != "runtime":
			_update_file_timestamp(path)


## Disable file watching
func disable_file_watching() -> void:
	_watch_files = false
	_file_timestamps.clear()


## Check for modified files and reload them (call this periodically)
func check_for_changes() -> void:
	if not _watch_files:
		return

	for file_path: String in _file_timestamps.keys():
		var current_time := FileAccess.get_modified_time(file_path)
		if current_time > _file_timestamps[file_path]:
			reload_file(file_path)


## Validate configuration against a schema
## Schema format: { "key": TYPE_INT, "nested.key": TYPE_STRING }
## Returns true if valid, false otherwise
func validate_config(config: Dictionary, schema: Dictionary) -> bool:
	var is_valid := true

	for schema_key: String in schema.keys():
		var expected_type: int = schema[schema_key]
		var value: Variant = _traverse_path(config, schema_key.split(".", false))

		if value == null:
			push_error(
				"[ConfigurationManager] Validation failed: Missing required key '%s'" % schema_key
			)
			is_valid = false
			continue

		var actual_type := typeof(value)
		if actual_type != expected_type:
			push_error(
				(
					"[ConfigurationManager] Validation failed: Key '%s' has type %s, expected %s"
					% [schema_key, _type_to_string(actual_type), _type_to_string(expected_type)]
				)
			)
			is_valid = false

	return is_valid


## Clear all cached configuration
func clear_cache() -> void:
	_config_cache.clear()
	_file_timestamps.clear()


## Get all cached configuration data (for debugging)
func get_all_config() -> Dictionary:
	return _config_cache.duplicate(true)


# Private helper methods


func _resolve_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	if path.begins_with("game/config/"):
		return "res://" + path
	if path.begins_with("config/"):
		return "res://game/" + path
	return CONFIG_DIR + path


func _traverse_path(data: Dictionary, parts: Array) -> Variant:
	var current: Variant = data

	for part_key: String in parts:
		if current is Dictionary and current.has(part_key):
			current = current[part_key]
		else:
			return null

	return current


func _traverse_namespaced_path(config_path: String, data: Dictionary, parts: Array) -> Variant:
	if parts.size() < 2:
		return null

	var normalized_path: String = config_path
	if normalized_path.begins_with(CONFIG_DIR):
		normalized_path = normalized_path.substr(CONFIG_DIR.length())
	elif normalized_path.begins_with("res://game/config/"):
		normalized_path = normalized_path.substr("res://game/config/".length())

	var segments: PackedStringArray = normalized_path.split("/", false)
	if segments.is_empty():
		return null

	var config_namespace: String = segments[0]
	if parts[0] != config_namespace:
		return null

	var scoped_parts: Array = []
	for i: int in range(1, parts.size()):
		scoped_parts.append(parts[i])

	return _traverse_path(data, scoped_parts)


func _set_path_value(data: Dictionary, parts: Array, value: Variant) -> void:
	var current: Dictionary = data

	for i in range(parts.size() - 1):
		var part: String = parts[i]
		if not current.has(part):
			current[part] = {}
		current = current[part]

	current[parts[-1]] = value


func _update_file_timestamp(path: String) -> void:
	_file_timestamps[path] = FileAccess.get_modified_time(path)


func _type_to_string(type: int) -> String:
	match type:
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING:
			return "string"
		TYPE_ARRAY:
			return "Array"
		TYPE_DICTIONARY:
			return "Dictionary"
		_:
			return "type_%d" % type
