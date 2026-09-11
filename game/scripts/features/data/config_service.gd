extends Node

signal config_loaded
signal config_reloaded
signal config_value_changed(path: String, old_value: Variant, new_value: Variant)

const CONFIG_DIR: String = "res://game/config/gameplay/"
const CONFIG_FILES: Array[String] = [
	"system", "gameplay", "visuals", "audio", "weapons", "enemies", "items", "ui"
]

var json5_loader_class: GDScript = JSON5Loader

var _virtual_category_map: Dictionary = {
	"game_rules": "gameplay.rules",
	"balance": "gameplay.balance",
	"systems_enabled": "system.features"
}
var _config: Dictionary = {}
var _schemas: Dictionary = {}
var _mod_overrides: Array[Dictionary] = []
var _loaded_categories: Dictionary = {}


func _ready() -> void:
	# Subsystem is added as child of GameCore
	pass


## Initialize method for GameCore service pattern


func initialize() -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info("[ConfigService] Initializing...", "ConfigService")
	_define_schemas()
	# Optional: _load_all_configs() or lazy load
	await get_tree().process_frame


## Get service initialization priority (lower = earlier)


func get_init_priority() -> int:
	return 10  # Load early


## Load all configuration files


func _load_all_configs() -> void:
	_config.clear()

	for config_name: String in CONFIG_FILES:
		var data: Dictionary = _load_config_file(config_name)

		if _schemas.has(config_name):
			if not _validate_data(data, _schemas[config_name], config_name):
				push_warning(
					"[ConfigService] Validation failed for %s. Using partial data." % config_name
				)

		if not data.is_empty():
			_config[config_name] = data

	_apply_all_mod_overrides()
	config_loaded.emit()
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info("[ConfigService] All configs loaded", "ConfigService")


func _load_config_file(config_name: String) -> Dictionary:
	var json5_path: String = CONFIG_DIR + config_name + ".json5"
	if FileAccess.file_exists(json5_path):
		var data: Variant = json5_loader_class.load_file(json5_path)
		if data != null and typeof(data) == TYPE_DICTIONARY:
			return data

	var json_path: String = CONFIG_DIR + config_name + ".json"
	return _load_json_file(json_path)


func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json: JSON = JSON.new()
	var err: Error = json.parse(file.get_as_text())
	file.close()

	if err != OK:
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.error("[ConfigService] JSON parse error in %s" % path, "ConfigService")
		return {}

	return json.data if typeof(json.data) == TYPE_DICTIONARY else {}


func _resolve_path(path: String) -> String:
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 0:
		return path

	var root: String = parts[0]
	if _virtual_category_map.has(root):
		var new_prefix: String = _virtual_category_map[root]
		if parts.size() > 1:
			var remainder: String = path.substr(root.length() + 1)
			return new_prefix + "." + remainder
		return new_prefix
	return path


func get_value(path: String, default: Variant = null) -> Variant:
	path = _resolve_path(path)
	var parts: PackedStringArray = path.split(".")
	if parts.size() == 0:
		return default

	var config_name: String = parts[0]
	if not _loaded_categories.has(config_name) and config_name in CONFIG_FILES:
		_load_and_cache_config(config_name)

	var current: Variant = _config
	for part in parts:
		if typeof(current) != TYPE_DICTIONARY or not current.has(part):
			return default
		current = current[part]
	return current


func _load_and_cache_config(config_name: String) -> void:
	if _loaded_categories.has(config_name):
		return
	_loaded_categories[config_name] = true
	if not config_name in CONFIG_FILES:
		return

	var data: Dictionary = _load_config_file(config_name)
	if _schemas.has(config_name):
		_validate_data(data, _schemas[config_name], config_name)

	_config[config_name] = data
	_apply_overrides_to_category(config_name)


func set_value(path: String, value: Variant, should_emit_signal: bool = true) -> void:
	path = _resolve_path(path)
	var parts: PackedStringArray = path.split(".")
	var current: Dictionary = _config

	var config_name: String = parts[0]
	if not _loaded_categories.has(config_name) and config_name in CONFIG_FILES:
		_load_and_cache_config(config_name)

	for i in range(parts.size() - 1):
		var part: String = parts[i]
		if not current.has(part):
			current[part] = {}
		current = current[part]

	var key: String = parts[parts.size() - 1]
	var old_value: Variant = current.get(key)
	current[key] = value

	if should_emit_signal and old_value != value:
		config_value_changed.emit(path, old_value, value)


func is_feature_enabled(feature_id: String) -> bool:
	var systems: Dictionary = get_value("systems_enabled", {})
	return systems.get(feature_id, true)


func get_rule(key: String, default: Variant = null) -> Variant:
	return get_value("game_rules." + key, default)


func get_balance(key: String, default: Variant = null) -> Variant:
	return get_value("balance." + key, default)


func reload_configs() -> void:
	_load_all_configs()
	config_reloaded.emit()


func apply_mod_overrides(overrides: Dictionary, priority: int, mod_name: String) -> void:
	_mod_overrides.append({"priority": priority, "overrides": overrides, "mod_name": mod_name})
	_mod_overrides.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.priority < b.priority
	)
	_apply_all_mod_overrides()


func _apply_all_mod_overrides() -> void:
	for mod_data in _mod_overrides:
		_config = _deep_merge(_config, mod_data.overrides)


func _apply_overrides_to_category(category: String) -> void:
	for mod_data in _mod_overrides:
		if mod_data.overrides.has(category):
			_config = _deep_merge(_config, {category: mod_data.overrides[category]})


func _deep_merge(base: Dictionary, override: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: String in override:
		if (
			result.has(key)
			and typeof(result[key]) == TYPE_DICTIONARY
			and typeof(override[key]) == TYPE_DICTIONARY
		):
			result[key] = _deep_merge(result[key], override[key])
		else:
			result[key] = override[key]
	return result


func _define_schemas() -> void:
	_schemas["system"] = {"type": "object"}
	_schemas["gameplay"] = {"type": "object"}
	_schemas["visuals"] = {"type": "object"}


func _validate_data(data: Variant, schema: Dictionary, path: String) -> bool:
	if not schema.has("type"):
		return true

	var schema_type: String = schema.type
	var type_valid := _matches_schema_type(data, schema_type)
	if not type_valid:
		push_warning("[ConfigService] %s must be %s" % [path, schema_type])
		return false

	if schema.has("enum") and data not in schema.enum:
		push_warning("[ConfigService] %s has an invalid value" % path)
		return false

	if schema_type == "object":
		var object_data: Dictionary = data
		for required_key: String in schema.get("required", []):
			if not object_data.has(required_key):
				push_warning("[ConfigService] %s is missing %s" % [path, required_key])
				return false
		for key: String in schema.get("properties", {}):
			if (
				object_data.has(key)
				and not _validate_data(
					object_data[key], schema.properties[key], "%s.%s" % [path, key]
				)
			):
				return false
	elif schema_type == "array" and schema.has("items"):
		for index: int in data.size():
			if not _validate_data(data[index], schema.items, "%s[%d]" % [path, index]):
				return false

	if schema.has("min") and float(data) < float(schema.min):
		push_warning("[ConfigService] %s is below the minimum" % path)
		return false
	if schema.has("max") and float(data) > float(schema.max):
		push_warning("[ConfigService] %s exceeds the maximum" % path)
		return false
	if schema.has("min_length") and data.size() < int(schema.min_length):
		push_warning("[ConfigService] %s is shorter than required" % path)
		return false
	return true


func _matches_schema_type(value: Variant, schema_type: String) -> bool:
	match schema_type:
		"object":
			return value is Dictionary
		"array":
			return value is Array
		"string":
			return value is String
		"number":
			return value is int or value is float
		"integer":
			return value is int
		"boolean":
			return value is bool
		"null":
			return value == null
		_:
			push_warning("[ConfigService] Unknown schema type: %s" % schema_type)
			return false
