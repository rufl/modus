extends Node

signal mod_loaded(mod_info: Dictionary)
signal mod_load_failed(mod_name: String, reason: String)
signal all_mods_loaded

const MODS_DIR: String = "user://mods"
const RES_MODS_DIR: String = "res://mods"
const JSON5LoaderClass: GDScript = preload("res://game/core/json5_loader.gd")

var _loaded_mods: Array[Dictionary] = []
var _mod_configs: Dictionary = {}  ## mod_name -> config
var _all_discovered_mods: Array[Dictionary] = []
var _texture_overrides: Dictionary = {}
var _audio_overrides: Dictionary = {}
var _scene_overrides: Dictionary = {}
var _registered_features: Dictionary = {}
var _registered_components: Dictionary = {}
var _registered_entities: Dictionary = {}
var _resource_overrides: Dictionary = {}
var _detected_conflicts: Array[Dictionary] = []


func _ready() -> void:
	name = "ModLoader"
	add_to_group("mod_loader")

	# Ensure mods directory exists
	DirAccess.make_dir_recursive_absolute(MODS_DIR)

	GameManager.get_core_system("logger").info("[ModLoader] Initialized", "Core")

	# Automatically discover and load all mods on startup
	_load_packed_mods()  # Load PCK/ZIPs first so their assets are available
	_discover_all_mods()
	_load_mod_settings()
	load_all_mods()


## Discover all mods (for UI listing)


func _discover_all_mods() -> void:
	_all_discovered_mods.clear()
	GameManager.get_core_system("logger").info("[ModLoader] Discovering mods...", "Core")

	# Check project mods directory (bundled mods)
	if DirAccess.dir_exists_absolute(RES_MODS_DIR):
		_scan_for_discovery(RES_MODS_DIR)

	# Check user mods directory
	_scan_for_discovery(MODS_DIR)

	_all_discovered_mods.sort_custom(_sort_by_priority)
	GameManager.get_core_system("logger").info(
		"[ModLoader] Discovered %d mods" % _all_discovered_mods.size(), "Core"
	)


## Scan directory and add all mods to discovery list


func _scan_for_discovery(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var folder_name: String = dir.get_next()

	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var mod_path: String = path.path_join(folder_name)
			var mod_info: Dictionary = _read_mod_manifest(mod_path)
			if not mod_info.is_empty():
				_all_discovered_mods.append(mod_info)
		folder_name = dir.get_next()

	dir.list_dir_end()


## Read mod manifest without loading


func _read_mod_manifest(mod_path: String) -> Dictionary:
	var manifest_path: String = mod_path.path_join("mod.json")

	if not FileAccess.file_exists(manifest_path):
		return {}

	# Try JSON5 load (supports comments)
	var data: Variant = JSON5LoaderClass.load_file(manifest_path)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		return {}

	var manifest: Dictionary = data
	if not manifest.has("name") or not manifest.has("version"):
		return {}

	return {
		"id": manifest.get("id", mod_path.get_file()),
		"name": manifest.get("name", "Unknown"),
		"version": manifest.get("version", "1.0.0"),
		"author": manifest.get("author", "Unknown"),
		"description": manifest.get("description", ""),
		"priority": manifest.get("priority", 100),
		"enabled": false,  # Default to disabled, ignoring manifest preference
		"path": mod_path,
		"dependencies": manifest.get("dependencies", []),
		"config_overrides": manifest.get("config_overrides", {}),
		"scripts": manifest.get("scripts", []),
		"assets": manifest.get("assets", {}),
		"features": manifest.get("features", {}),
		"components": manifest.get("components", {}),
		"entities": manifest.get("entities", {})
	}


## Load all enabled mods


func load_all_mods() -> void:
	GameManager.get_core_system("logger").info("[ModLoader] Loading enabled mods...", "Core")
	_loaded_mods.clear()
	_mod_configs.clear()
	_registered_features.clear()
	_registered_components.clear()
	_registered_entities.clear()
	_resource_overrides.clear()
	clear_conflicts()

	# Collect enabled mods
	var enabled_mods: Array[Dictionary] = []
	for mod: Dictionary in _all_discovered_mods:
		if mod.get("enabled", false):
			enabled_mods.append(mod)

	# Priority sort first (tie-breaker within same dependency level)
	enabled_mods.sort_custom(_sort_by_priority)

	# Topological sort for dependency order
	_loaded_mods = _resolve_load_order(enabled_mods)

	# Register loaded mods
	for mod: Dictionary in _loaded_mods:
		_mod_configs[mod.name] = mod
		_register_manifest_content(mod)

	# Apply all mod configs
	for mod: Dictionary in _loaded_mods:
		_apply_mod_config(mod)

	GameManager.get_core_system("logger").info(
		"[ModLoader] Loaded %d enabled mods (dependency-ordered)" % _loaded_mods.size(), "Core"
	)
	all_mods_loaded.emit()


## Load mods (alias for load_all_mods for test compatibility)


func load_mods() -> void:
	load_all_mods()


## Scan a directory for mod folders


func _scan_mods_directory(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var folder_name: String = dir.get_next()

	while folder_name != "":
		if dir.current_is_dir() and not folder_name.begins_with("."):
			var mod_path: String = path.path_join(folder_name)
			_try_load_mod(mod_path)
		folder_name = dir.get_next()

	dir.list_dir_end()


## Try to load a mod from a directory


func _try_load_mod(mod_path: String) -> void:
	var manifest_path: String = mod_path.path_join("mod.json")

	# Check for mod.json manifest
	if not FileAccess.file_exists(manifest_path):
		push_warning("[ModLoader] No mod.json found in: %s" % mod_path)
		return

	# Parse manifest
	# Parse manifest (supports JSON5)
	var data: Variant = JSON5LoaderClass.load_file(manifest_path)
	if data == null or typeof(data) != TYPE_DICTIONARY:
		mod_load_failed.emit(mod_path, "Invalid JSON/JSON5 in mod.json")
		return

	var manifest: Dictionary = data

	# Validate required fields
	if not manifest.has("name") or not manifest.has("version"):
		mod_load_failed.emit(mod_path, "Missing required fields (name, version)")
		return

	# Create mod info
	var mod_info: Dictionary = {
		"name": manifest.get("name", "Unknown"),
		"version": manifest.get("version", "1.0.0"),
		"author": manifest.get("author", "Unknown"),
		"description": manifest.get("description", ""),
		"priority": manifest.get("priority", 100),
		"enabled": false,  # Default to disabled, ignoring manifest preference
		"path": mod_path,
		"dependencies": manifest.get("dependencies", []),
		"config_overrides": manifest.get("config_overrides", {}),
		"scripts": manifest.get("scripts", []),
		"assets": manifest.get("assets", {}),
		"features": manifest.get("features", {}),
		"components": manifest.get("components", {}),
		"entities": manifest.get("entities", {})
	}

	# Check if enabled
	if not mod_info.enabled:
		GameManager.get_core_system("logger").info(
			"[ModLoader] Mod '%s' is disabled, skipping" % mod_info.name, "Core"
		)
		return

	# Check dependencies
	if not _check_dependencies(mod_info):
		mod_load_failed.emit(mod_info.name, "Missing dependencies")
		return

	# Load mod
	_loaded_mods.append(mod_info)
	_mod_configs[mod_info.name] = mod_info

	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(
			(
				"[ModLoader] Loaded mod: %s v%s by %s"
				% [mod_info.name, mod_info.version, mod_info.author]
			),
			"Modding"
		)

	mod_loaded.emit(mod_info)


## Check if mod dependencies are met


func _check_dependencies(mod_info: Dictionary) -> bool:
	var deps: Array = mod_info.get("dependencies", [])

	for dep: String in deps:
		var found: bool = false
		for loaded: Dictionary in _loaded_mods:
			if loaded.name == dep:
				found = true
				break

		if not found:
			push_warning("[ModLoader] Mod '%s' missing dependency: %s" % [mod_info.name, dep])
			return false

	return true


## Sort mods by priority (lower = earlier)


func _sort_by_priority(a: Dictionary, b: Dictionary) -> bool:
	return a.get("priority", 100) < b.get("priority", 100)


## Resolve mod load order using topological sort (dependency-aware).
## Returns mods sorted so dependencies are loaded before dependents.


func _resolve_load_order(mods: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var visited: Dictionary = {}  # mod_name -> bool (true = processed)
	var temp_marks: Dictionary = {}  # mod_name -> bool (true = in progress)
	var mod_by_name: Dictionary = {}  # mod_name -> mod_info

	# Build name -> mod map
	for mod: Dictionary in mods:
		var mod_name: String = mod.get("name", "")
		mod_by_name[mod_name] = mod

	# Recursive visit function
	var visit: Callable
	visit = func(mod: Dictionary) -> bool:
		var mod_name: String = mod.get("name", "")

		if visited.get(mod_name, false):
			return true  # Already processed

		if temp_marks.get(mod_name, false):
			push_error("[ModLoader] Circular dependency detected: %s" % mod_name)
			mod_load_failed.emit(mod_name, "Circular dependency")
			return false  # Circular dependency

		temp_marks[mod_name] = true

		# Process dependencies first
		var deps: Array = mod.get("dependencies", [])
		for dep: String in deps:
			if mod_by_name.has(dep):
				if not visit.call(mod_by_name[dep]):
					return false
			else:
				# Dependency not in enabled mod list
				push_warning(
					"[ModLoader] Mod '%s' depends on '%s' which is not enabled" % [mod_name, dep]
				)
				mod_load_failed.emit(mod_name, "Missing dependency: %s" % dep)
				return false

		temp_marks[mod_name] = false
		visited[mod_name] = true
		result.append(mod)
		return true

	# Visit each mod
	for mod: Dictionary in mods:
		if not visited.get(mod.get("name", ""), false):
			if not visit.call(mod):
				# If visit fails, continue with remaining mods
				continue

	return result


## Get dependency tree for debugging.


func get_dependency_tree() -> Dictionary:
	var tree: Dictionary = {}
	for mod: Dictionary in _loaded_mods:
		tree[mod.get("name", "")] = mod.get("dependencies", [])
	return tree


## Apply mod configuration overrides


func _apply_mod_config(mod_info: Dictionary) -> void:
	var overrides: Dictionary = mod_info.get("config_overrides", {})
	var priority: int = mod_info.get("priority", 100)
	var mod_name: String = mod_info.get("name", "Unknown")

	# Apply system overrides (toggle systems on/off)
	if overrides.has("systems"):
		_apply_system_overrides(overrides.systems, priority, mod_name)

	# Apply weapon overrides
	if overrides.has("weapons"):
		_apply_weapon_overrides(overrides.weapons, mod_name)

	# Apply enemy overrides
	if overrides.has("enemies"):
		_apply_enemy_overrides(overrides.enemies, mod_name)

	# Apply loot overrides
	if overrides.has("loot"):
		_apply_loot_overrides(overrides.loot, mod_name)

	# Apply loot table overrides
	if overrides.has("loot_tables"):
		_apply_loot_table_overrides(overrides.loot_tables, mod_name)

	# Load asset overrides
	var assets: Dictionary = mod_info.get("assets", {})
	_load_asset_overrides(assets, mod_info.path)

	# Run mod scripts
	var scripts: Array = mod_info.get("scripts", [])
	_run_mod_scripts(scripts, mod_info.path)


## Apply system enable/disable overrides via GameManager.get_core_system("config")


func _apply_system_overrides(overrides: Dictionary, priority: int, mod_name: String) -> void:
	GameManager.get_core_system("logger").info(
		"[ModLoader] Applying system overrides from '%s'" % mod_name, "Core"
	)

	if (
		GameManager.get_core_system("config")
		and GameManager.get_core_system("config").has_method("apply_mod_overrides")
	):
		GameManager.get_core_system("config").apply_mod_overrides(overrides, priority, mod_name)
	else:
		push_warning(
			'[ModLoader] GameManager.get_core_system("config").apply_mod_overrides not available'
		)


## Apply weapon configuration overrides


func _apply_weapon_overrides(overrides: Dictionary, mod_name: String) -> void:
	GameManager.get_core_system("logger").info(
		"[ModLoader] Applying weapon overrides from '%s'" % mod_name, "Core"
	)

	# Access data service if available
	var data_service: Node = GameManager.get_core_system("data")
	if not data_service:
		return

	for weapon_id: String in overrides.keys():
		var weapon_data: Dictionary = overrides[weapon_id]
		if data_service.has_method("register_mod_weapon"):
			data_service.register_mod_weapon(weapon_id, weapon_data)
		else:
			push_warning("[ModLoader] DataService.register_mod_weapon not found")


## Apply enemy configuration overrides


func _apply_enemy_overrides(overrides: Dictionary, mod_name: String) -> void:
	GameManager.get_core_system("logger").info(
		"[ModLoader] Applying enemy overrides from '%s'" % mod_name, "Core"
	)

	var data_service: Node = GameManager.get_core_system("data")
	if not data_service:
		return

	for enemy_id: String in overrides.keys():
		var enemy_data: Dictionary = overrides[enemy_id]
		if data_service.has_method("register_mod_enemy"):
			data_service.register_mod_enemy(enemy_id, enemy_data)


## Apply loot configuration overrides


func _apply_loot_overrides(overrides: Dictionary, mod_name: String) -> void:
	GameManager.get_core_system("logger").info(
		"[ModLoader] Applying loot overrides from '%s'" % mod_name, "Core"
	)

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.loot:
		return

	if gs.loot.has_method("apply_mod_overrides"):
		gs.loot.apply_mod_overrides(overrides)


## Apply loot table overrides


func _apply_loot_table_overrides(overrides: Dictionary, mod_name: String) -> void:
	GameManager.get_core_system("logger").info(
		"[ModLoader] Applying loot table overrides from '%s'" % mod_name, "Core"
	)

	var data_service: Node = GameManager.get_core_system("data")
	if not data_service:
		return

	for table_id: String in overrides.keys():
		var table_data: Dictionary = overrides[table_id]
		# Loot tables are stored in data_service.loot_tables dictionary
		if data_service and "loot_tables" in data_service:
			data_service.loot_tables[table_id] = table_data


## Load asset overrides (textures, audio, scenes)


func _load_asset_overrides(assets: Dictionary, mod_path: String) -> void:
	# Generic override handler for all asset types
	var categories: Array[String] = [
		"textures", "audio", "scenes", "meshes", "materials", "decals", "fonts", "icons"
	]

	for category in categories:
		if assets.has(category):
			for original_path: String in assets[category].keys():
				var replacement_rel: String = assets[category][original_path]
				var replacement_full: String = mod_path.path_join(replacement_rel)
				_override_resource(original_path, replacement_full)


## Override a resource using take_over_path


func _override_resource(original_path: String, replacement_path: String) -> void:
	if not FileAccess.file_exists(replacement_path):
		push_warning("[ModLoader] Asset override not found: %s" % replacement_path)
		return

	# Load the replacement resource
	var replacement_res: Resource = load(replacement_path)
	if not replacement_res:
		push_warning("[ModLoader] Failed to load override: %s" % replacement_path)
		return

	var mod_name := replacement_path.get_base_dir().get_file()
	if _resource_overrides.has(original_path):
		_report_conflict(
			"resource override",
			original_path,
			str(_resource_overrides[original_path].get("mod_name", "Unknown")),
			mod_name
		)
	_resource_overrides[original_path] = {
		"replacement_path": replacement_path,
		"mod_name": mod_name
	}

	# Register with AssetManager if available for tracking
	var asset_manager: Node = GameManager.get_core_system("assets")
	if asset_manager and asset_manager.has_method("register_overrides"):
		asset_manager.register_overrides({original_path: replacement_path})

	# ALWAYS use take_over_path for engine-level overrides
	# This ensures load() calls throughout the codebase pick up the modded asset
	replacement_res.take_over_path(original_path)

	GameManager.get_core_system("logger").info(
		"[ModLoader] Overrode asset: %s" % original_path, "Core"
	)


## Run mod scripts


func _run_mod_scripts(scripts: Array, mod_path: String) -> void:
	for script_path: String in scripts:
		var full_path: String = mod_path.path_join(script_path)

		if not FileAccess.file_exists(full_path):
			push_warning("[ModLoader] Script not found: %s" % full_path)
			continue

		var script: GDScript = load(full_path) as GDScript
		if script:
			var instance: Node = script.new()
			if instance:
				add_child(instance)
				GameManager.get_core_system("logger").info(
					"[ModLoader] Loaded mod script: %s" % script_path, "Core"
				)


## Get texture with mod override support
## Get texture (Helper for backward compatibility, but standard load works now)


func get_texture(original_path: String) -> Texture2D:
	return load(original_path) as Texture2D


func _register_manifest_content(mod_info: Dictionary) -> void:
	var mod_name: String = mod_info.get("name", "Unknown")
	for feature_id: String in mod_info.get("features", {}).keys():
		register_feature(feature_id, mod_info.features[feature_id], mod_name)
	for component_name: String in mod_info.get("components", {}).keys():
		register_component(component_name, mod_info.components[component_name], mod_name)
	for entity_name: String in mod_info.get("entities", {}).keys():
		register_entity(entity_name, mod_info.entities[entity_name], mod_name)


## Register mod-provided content and report duplicate ownership.
func register_feature(feature_id: String, feature_data: Dictionary, mod_name: String = "Unknown") -> bool:
	if _registered_features.has(feature_id):
		_report_conflict("feature", feature_id, str(_registered_features[feature_id].mod_name), mod_name)
		return false
	_registered_features[feature_id] = {"data": feature_data, "mod_name": mod_name}
	return true


func register_component(component_name: String, component_data: Variant, mod_name: String = "Unknown") -> bool:
	if _registered_components.has(component_name):
		_report_conflict("component", component_name, str(_registered_components[component_name].mod_name), mod_name)
		return false
	_registered_components[component_name] = {"data": component_data, "mod_name": mod_name}
	return true


func register_entity(entity_name: String, entity_data: Variant, mod_name: String = "Unknown") -> bool:
	if _registered_entities.has(entity_name):
		_report_conflict("entity", entity_name, str(_registered_entities[entity_name].mod_name), mod_name)
		return false
	_registered_entities[entity_name] = {"data": entity_data, "mod_name": mod_name}
	return true


func get_registered_features() -> Dictionary:
	return _registered_features.duplicate(true)


func get_registered_components() -> Dictionary:
	return _registered_components.duplicate(true)


func get_registered_entities() -> Dictionary:
	return _registered_entities.duplicate(true)


func _report_conflict(conflict_type: String, target: String, mod1: String, mod2: String) -> void:
	var message := "Mods '%s' and '%s' conflict on %s '%s'" % [mod1, mod2, conflict_type, target]
	_detected_conflicts.append({
		"type": conflict_type,
		"target": target,
		"mod1": mod1,
		"mod2": mod2,
		"message": message
	})
	push_warning("[ModLoader] " + message)


func get_conflicts() -> Array[Dictionary]:
	return _detected_conflicts.duplicate(true)


func has_conflicts() -> bool:
	return not _detected_conflicts.is_empty()


func clear_conflicts() -> void:
	_detected_conflicts.clear()


## Get loaded mods


func get_loaded_mods() -> Array[Dictionary]:
	return _loaded_mods.duplicate()


## Check if a mod is loaded


func is_mod_loaded(mod_name: String) -> bool:
	return mod_name in _mod_configs


## Get mod info by name


func get_mod_info(mod_name: String) -> Dictionary:
	return _mod_configs.get(mod_name, {})


## Get all installed mods (for UI - includes disabled)


func get_installed_mods() -> Array:
	return _all_discovered_mods.duplicate(true)


## Set mod enabled state


func set_mod_enabled(mod_id: String, enabled: bool) -> void:
	for mod: Dictionary in _all_discovered_mods:
		if mod.get("id", "") == mod_id or mod.get("name", "") == mod_id:
			mod["enabled"] = enabled
			_save_mod_settings()
			return


## Change mod priority


func change_mod_priority(mod_id: String, delta: int) -> void:
	for mod: Dictionary in _all_discovered_mods:
		if mod.get("id", "") == mod_id or mod.get("name", "") == mod_id:
			mod["priority"] = mod.get("priority", 0) + delta
			_all_discovered_mods.sort_custom(_sort_by_priority)
			_save_mod_settings()
			return


## Reload all mods


func reload_mods() -> void:
	_loaded_mods.clear()
	_mod_configs.clear()
	_registered_features.clear()
	_registered_components.clear()
	_registered_entities.clear()
	_resource_overrides.clear()
	clear_conflicts()
	_texture_overrides.clear()
	_audio_overrides.clear()
	_scene_overrides.clear()
	load_all_mods()


## Save mod settings to user preferences


func _save_mod_settings() -> void:
	var config: ConfigFile = ConfigFile.new()

	for mod: Dictionary in _all_discovered_mods:
		var mod_id: String = mod.get("id", mod.get("name", ""))
		if mod_id.is_empty():
			continue
		config.set_value(mod_id, "enabled", mod.get("enabled", false))
		config.set_value(mod_id, "priority", mod.get("priority", 0))

	config.save("user://mod_settings.cfg")


## Load mod settings from user preferences


func _load_mod_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load("user://mod_settings.cfg")
	if err != OK:
		return

	for mod: Dictionary in _all_discovered_mods:
		var mod_id: String = mod.get("id", mod.get("name", ""))
		if mod_id.is_empty():
			continue

		if config.has_section(mod_id):
			mod["enabled"] = config.get_value(mod_id, "enabled", false)
			mod["priority"] = config.get_value(mod_id, "priority", 0)


## Load .pck and .zip mod packages


func _load_packed_mods() -> void:
	GameManager.get_core_system("logger").info(
		"[ModLoader] Scanning for packed mods (.pck, .zip)...", "Core"
	)

	# Scan both search directories
	var paths: Array[String] = [RES_MODS_DIR, MODS_DIR]

	for base_path in paths:
		if not DirAccess.dir_exists_absolute(base_path):
			continue

		var dir := DirAccess.open(base_path)
		if not dir:
			continue

		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if file_name.ends_with(".pck") or file_name.ends_with(".zip"):
					var full_path := base_path.path_join(file_name)
					_load_pack(full_path)
			file_name = dir.get_next()
		dir.list_dir_end()


func _load_pack(path: String) -> void:
	var success := ProjectSettings.load_resource_pack(path)
	if success:
		GameManager.get_core_system("logger").info(
			"[ModLoader] Loaded resource pack: %s" % path, "Core"
		)
	else:
		push_error("[ModLoader] Failed to load resource pack: %s" % path)
