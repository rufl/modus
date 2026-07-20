class_name DataService
extends Node

const JSON5LoaderClass: GDScript = preload("res://game/core/json5_loader.gd")
const DATA_DIR: String = "res://game/data/"

var weapons: Dictionary = {}
var enemies: Dictionary = {}
var game_rules: Dictionary = {}
var loot_tables: Dictionary = {}
var balance: Dictionary = {}
var items: Dictionary = {}

var _is_initialized: bool = false
var _init_priority: int = 10  # Initialize early


## Helper method for safe logging
func _log(message: String, category: String = "DataService") -> void:
	# Safe access during initialization - use get_node_or_null to avoid compile errors
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		print("[%s] %s" % [category, message])
		return
	var logger: Node = game_manager.call("get_core_system", "logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


## Helper method for safe debug logging
func _log_debug(message: String, category: String = "DataService") -> void:
	# Safe access during initialization - use get_node_or_null to avoid compile errors
	var game_manager: Node = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	var logger: Node = game_manager.call("get_core_system", "logger")
	if logger and logger.has_method("debug"):
		logger.debug(message, category)


func get_init_priority() -> int:
	return _init_priority


func _ready() -> void:
	_log_debug("_ready() called")
	# Ensure data is loaded immediately to avoid race conditions with early initiators
	initialize()


func initialize() -> void:
	_log_debug("initialize() called, _is_initialized=%s" % _is_initialized)
	if _is_initialized:
		return

	refresh_all_data()
	_is_initialized = true
	_log("Initialized and data loaded.")


## Reload all data files from disk


func refresh_all_data() -> void:
	_log_debug("refresh_all_data() called")
	_log("Refreshing all game data...")

	# Load Base Data
	weapons = _load_data_file("weapons")
	_log_debug("Loaded weapons dictionary with %d entries" % weapons.size())
	if weapons.size() > 0:
		_log_debug("Weapon keys: %s" % str(weapons.keys()))

	enemies = _normalize_enemy_records(_load_data_file("enemies"))
	game_rules = _load_data_file("game_rules")
	loot_tables = _load_data_file("loot_tables")
	balance = _load_data_file("balance")

	# Items have special structure in sample_items.json5
	var raw_items: Dictionary = _load_data_file("sample_items")
	if raw_items.has("items"):
		items = raw_items.items
	else:
		items = raw_items

	_log(
		(
			"Loaded: Weapons: %d, Enemies: %d, Items: %d, LootTables: %d"
			% [weapons.size(), enemies.size(), items.size(), loot_tables.size()]
		)
	)


## Generic load with override support (User > Res)


func _load_data_file(file_name: String) -> Dictionary:
	var final_data: Dictionary = {}

	# 1. Base (res://game/data/file.json5 or .json)
	var base_path_5: String = DATA_DIR + file_name + ".json5"
	var base_path_json: String = DATA_DIR + file_name + ".json"

	if FileAccess.file_exists(base_path_5):
		final_data = _load_file_generic(base_path_5)
	elif FileAccess.file_exists(base_path_json):
		final_data = _load_file_generic(base_path_json)

	# 2. User Overrides (user://overrides/data/file.json5)
	var user_path: String = "user://overrides/data/" + file_name + ".json5"
	if FileAccess.file_exists(user_path):
		var override_data: Dictionary = _load_file_generic(user_path)
		_deep_merge(final_data, override_data)
		_log("Applied override: %s" % user_path)

	return final_data


func _load_file_generic(path: String) -> Dictionary:
	_log_debug("Loading file: %s" % path)

	# Try JSON5 Loader first if extension matches or forced
	if path.ends_with(".json5"):
		var data: Variant = JSON5LoaderClass.load_file(path)
		if data != null and typeof(data) == TYPE_DICTIONARY:
			_log_debug("Successfully loaded JSON5 with %d keys" % (data as Dictionary).size())
			return data
		push_warning("[DataService] Failed to load JSON5: %s" % path)
		return {}

	# Fallback to standard JSON
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[DataService] File not found: %s" % path)
		return {}

	var content: String = file.get_as_text()
	var json: JSON = JSON.new()
	if json.parse(content) != OK:
		push_error("[DataService] JSON Parse Error in %s: %s" % [path, json.get_error_message()])
		return {}

	if not json.data is Dictionary:
		push_warning("[DataService] JSON data is not a dictionary")
		return {}

	_log_debug("Successfully loaded JSON with %d keys" % (json.data as Dictionary).size())
	return json.data


func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key: String in source:
		var source_val: Variant = source[key]
		if target.has(key) and target[key] is Dictionary and source_val is Dictionary:
			_deep_merge(target[key], source_val)
		else:
			target[key] = source_val


func _normalize_enemy_records(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for enemy_id: String in source.keys():
		var enemy_data: Variant = source[enemy_id]
		if enemy_data is Dictionary:
			normalized[enemy_id] = _normalize_enemy_record(enemy_data)
		else:
			normalized[enemy_id] = enemy_data
	return normalized


func _normalize_enemy_record(data: Dictionary) -> Dictionary:
	var normalized: Dictionary = data.duplicate(true)
	var ai_config: Dictionary = {}
	if normalized.get("ai_config") is Dictionary:
		ai_config = normalized.ai_config.duplicate(true)

	var stats: Dictionary = normalized.get("stats", {}) if normalized.get("stats") is Dictionary else {}
	var combat: Dictionary = normalized.get("combat", {}) if normalized.get("combat") is Dictionary else {}
	var movement: Dictionary = normalized.get("movement", {}) if normalized.get("movement") is Dictionary else {}
	var perception: Dictionary = (
		normalized.get("perception", {}) if normalized.get("perception") is Dictionary else {}
	)

	if not ai_config.has("attack_type"):
		ai_config.attack_type = combat.get("attack_type", "melee")
	if not ai_config.has("can_fly"):
		ai_config.can_fly = movement.get("can_fly", false)
	if not ai_config.has("perception") and not perception.is_empty():
		ai_config.perception = perception.duplicate(true)
	if not ai_config.has("behavior"):
		ai_config.behavior = _behavior_for_enemy(normalized.get("role", "basic"), stats)
	if not ai_config.has("combat_style"):
		ai_config.combat_style = _combat_style_for_enemy(normalized.get("role", "basic"), stats)

	normalized.ai_config = ai_config
	return normalized


func _behavior_for_enemy(role: String, stats: Dictionary) -> String:
	match role:
		"support":
			return "defensive"
		"swarm", "damage":
			return "aggressive"
		"scout":
			return "scout"
		_:
			var aggression: float = float(stats.get("aggression", 0.5))
			if aggression <= 0.3:
				return "defensive"
			return "aggressive"


func _combat_style_for_enemy(role: String, stats: Dictionary) -> String:
	match role:
		"support":
			return "defensive"
		"damage", "swarm":
			return "aggressive"
		_:
			var aggression: float = float(stats.get("aggression", 0.5))
			if aggression >= 0.75:
				return "aggressive"
			if aggression <= 0.3:
				return "defensive"
			return "balanced"


# --- Public Accessors ---


func get_weapon_data(id: String) -> Dictionary:
	return weapons.get(id, {})


func get_enemy_data(id: String) -> Dictionary:
	return enemies.get(id, {})


func get_item_data(id: String) -> Dictionary:
	return items.get(id, {})


func get_loot_table(id: String) -> Dictionary:
	return loot_tables.get(id, {})


func get_game_rule(category: String, key: String, default: Variant = null) -> Variant:
	if game_rules.has(category) and game_rules[category].has(key):
		return game_rules[category][key]
	return default


func get_balance_value(category: String, key: String, default: Variant = null) -> Variant:
	if balance.has(category) and balance[category].has(key):
		return balance[category][key]
	return default


# --- Modding Support ---


func register_mod_weapon(id: String, data: Dictionary) -> void:
	if weapons.has(id):
		_deep_merge(weapons[id], data)
	else:
		weapons[id] = data


func register_mod_enemy(id: String, data: Dictionary) -> void:
	if enemies.has(id):
		_deep_merge(enemies[id], data)
		enemies[id] = _normalize_enemy_record(enemies[id])
	else:
		enemies[id] = _normalize_enemy_record(data)
