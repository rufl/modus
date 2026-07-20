extends Node
class_name ModScriptManager

signal script_loaded(mod_name: String, script_path: String)
signal script_failed(mod_name: String, error: String)
signal hook_executed(hook_name: String, mod_name: String)

var loaded_scripts: Dictionary = {}  # mod_name -> [script paths]
var script_instances: Dictionary = {}  # mod_name -> [script instances]

var _mod_loader: Node = null


func _ready() -> void:
	_mod_loader = GameManager.get_core_system("mod_loader")
	if _mod_loader and _mod_loader.has_signal("all_mods_loaded"):
		_mod_loader.all_mods_loaded.connect(_on_mods_loaded)


func _on_mods_loaded(_mod_count: int) -> void:
	## Called when all mods are loaded
	GameManager.get_core_system("logger").info("[ModScriptManager] Loading mod scripts...", "Core")
	_load_all_mod_scripts()


func _load_all_mod_scripts() -> void:
	## Load scripts from all mods
	if not _mod_loader:
		return

	if not _mod_loader.has_method("get_mod_load_order"):
		return

	for mod_name: Variant in _mod_loader.get_mod_load_order():
		var mod_path: String = _get_mod_path(mod_name)
		var scripts_dir: String = mod_path + "scripts/"

		# Check if scripts directory exists
		if not DirAccess.dir_exists_absolute(scripts_dir):
			continue

		# Load all .gd files in scripts directory
		var dir: DirAccess = DirAccess.open(scripts_dir)
		if not dir:
			continue

		dir.list_dir_begin()
		var file_name: String = dir.get_next()

		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".gd"):
				var script_path: String = scripts_dir + file_name
				_load_mod_script(str(mod_name), script_path)

			file_name = dir.get_next()

		dir.list_dir_end()

	GameManager.get_core_system("logger").info(
		"[ModScriptManager] Loaded %d mod scripts" % _count_instances(), "Core"
	)


func _load_mod_script(mod_name: String, script_path: String) -> bool:
	## Load and instantiate a mod script
	# Load the script
	var script: Script = load(script_path)
	if not script:
		var error_msg: String = "Failed to load script"
		script_failed.emit(mod_name, error_msg)
		push_error("[ModScriptManager] %s: %s" % [error_msg, script_path])
		return false

	# Validate script extends ModScript
	if not _validate_script(script):
		var error_msg: String = "Script does not extend ModScript"
		script_failed.emit(mod_name, error_msg)
		push_error("[ModScriptManager] %s: %s" % [error_msg, script_path])
		return false

	# Create instance
	var instance: Node = script.new()

	if not instance:
		var error_msg: String = "Failed to instantiate script"
		script_failed.emit(mod_name, error_msg)
		push_error("[ModScriptManager] %s: %s" % [error_msg, script_path])
		return false

	# Set mod info if available
	if "mod_info" in instance and _mod_loader:
		if _mod_loader.has_method("get_mod_info"):
			instance.mod_info = _mod_loader.get_mod_info(mod_name)

	# Add to scene tree
	add_child(instance)

	# Store script reference
	if not loaded_scripts.has(mod_name):
		loaded_scripts[mod_name] = []
		script_instances[mod_name] = []

	loaded_scripts[mod_name].append(script_path)
	script_instances[mod_name].append(instance)

	script_loaded.emit(mod_name, script_path)
	GameManager.get_core_system("logger").info(
		"[ModScriptManager] Loaded script: %s/%s" % [mod_name, script_path.get_file()], "Core"
	)
	return true


func _validate_script(script: Script) -> bool:
	## Validate that script extends ModScript
	var base_class_name: String = "ModScript"
	var current: Script = script

	while current:
		if current.get_global_name() == base_class_name:
			return true

		# Check filename as fallback
		if current.resource_path.ends_with("mod_script.gd"):
			return true

		current = current.get_base_script()

	return false


func _get_mod_path(mod_name: Variant) -> String:
	## Get path to mod directory
	if _mod_loader and _mod_loader.has_method("get_mod_path"):
		return _mod_loader.get_mod_path(mod_name)
	return ""


func _count_instances() -> int:
	## Count total script instances
	var count: int = 0
	for mod_name: String in script_instances:
		count += script_instances[mod_name].size()
	return count


# =============================================================================
# HOOK EXECUTION
# =============================================================================


func execute_hook_game_start() -> void:
	## Execute on_game_start hook for all mod scripts
	_execute_hook("on_game_start", [])


func execute_hook_game_end() -> void:
	## Execute on_game_end hook for all mod scripts
	_execute_hook("on_game_end", [])


func execute_hook_level_loaded(level_name: String) -> void:
	## Execute on_level_loaded hook for all mod scripts
	_execute_hook("on_level_loaded", [level_name])


func execute_hook_enemy_spawn(enemy: Node, enemy_type: String) -> void:
	## Execute on_enemy_spawn hook for all mod scripts
	_execute_hook("on_enemy_spawn", [enemy, enemy_type])


func execute_hook_enemy_died(enemy: Node, killer: Node) -> void:
	## Execute on_enemy_died hook for all mod scripts
	_execute_hook("on_enemy_died", [enemy, killer])


func execute_hook_loot_drop(position: Vector3, loot_table: String, items: Array) -> void:
	## Execute on_loot_drop hook for all mod scripts
	_execute_hook("on_loot_drop", [position, loot_table, items])


func execute_hook_player_damage(player: Node, amount: float, source: Node) -> void:
	## Execute on_player_damage hook for all mod scripts
	_execute_hook("on_player_damage", [player, amount, source])


func execute_hook_player_level_up(player: Node, new_level: int) -> void:
	## Execute on_player_level_up hook for all mod scripts
	_execute_hook("on_player_level_up", [player, new_level])


func execute_hook_weapon_fired(weapon: Node, weapon_name: String) -> void:
	## Execute on_weapon_fired hook for all mod scripts
	_execute_hook("on_weapon_fired", [weapon, weapon_name])


func execute_hook_prop_destroyed(prop: Node, destroyer: Node) -> void:
	## Execute on_prop_destroyed hook for all mod scripts
	_execute_hook("on_prop_destroyed", [prop, destroyer])


func execute_hook_traversal_started(player: Node, traversal_type: String) -> void:
	## Execute on_traversal_started hook for all mod scripts
	_execute_hook("on_traversal_started", [player, traversal_type])


func execute_custom_hook(hook_name: String, args: Array) -> void:
	## Execute a custom hook with arbitrary arguments
	_execute_hook(hook_name, args)


func _execute_hook(hook_name: String, args: Array) -> void:
	## Execute a hook on all mod scripts
	for mod_name: String in script_instances:
		for instance: Node in script_instances[mod_name]:
			if not is_instance_valid(instance):
				continue

			if instance.has_method(hook_name):
				var error: String = _safe_call(instance, hook_name, args)
				if error:
					push_error(
						(
							"[ModScriptManager] Hook '%s' failed in %s: %s"
							% [hook_name, mod_name, error]
						)
					)
				else:
					hook_executed.emit(hook_name, mod_name)


func _safe_call(instance: Node, method: String, args: Array) -> String:
	## Safely call a method with error handling
	var result: Variant = instance.callv(method, args)

	# Check for error return
	if result is String and result.begins_with("ERROR"):
		return result

	return ""


# =============================================================================
# PUBLIC API
# =============================================================================


func get_loaded_scripts() -> Dictionary:
	## Get all loaded script paths by mod
	return loaded_scripts.duplicate()


func get_script_instances() -> Dictionary:
	## Get all script instances by mod
	return script_instances.duplicate()


func get_script_count() -> int:
	## Get total number of loaded scripts
	return _count_instances()


func reload_mod_scripts() -> void:
	## Reload all mod scripts (development mode)
	GameManager.get_core_system("logger").info(
		"[ModScriptManager] Reloading mod scripts...", "Core"
	)

	# Remove existing instances
	for mod_name: String in script_instances:
		for instance: Node in script_instances[mod_name]:
			if is_instance_valid(instance):
				instance.queue_free()

	loaded_scripts.clear()
	script_instances.clear()

	_load_all_mod_scripts()


func unload_mod_scripts(mod_name: String) -> void:
	## Unload scripts for a specific mod
	if not script_instances.has(mod_name):
		return

	for instance: Node in script_instances[mod_name]:
		if is_instance_valid(instance):
			instance.queue_free()

	loaded_scripts.erase(mod_name)
	script_instances.erase(mod_name)
	GameManager.get_core_system("logger").info(
		"[ModScriptManager] Unloaded scripts for mod: %s" % mod_name, "Core"
	)
