class_name ModScript
extends Node

var mod_info: Dictionary = {}


func _ready() -> void:
	_mod_init()


## Override this to initialize your mod


func _mod_init() -> void:
	pass


## Override this for mod cleanup


func _mod_cleanup() -> void:
	pass


## Helper to get game manager


func get_game_manager() -> Node:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return null
	var gs: Variant = gm.get_core_system("gameplay")
	if gs and gs is GameplaySvc:
		return gs.match_service
	return null


## Helper to get loot manager


func get_loot_manager() -> Node:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return null
	var gs: Variant = gm.get_core_system("gameplay")
	if gs and gs is GameplaySvc:
		return gs.loot
	return null


## Helper to find player


func get_local_player() -> Node:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for player: Node in players:
		if player.is_multiplayer_authority():
			return player
	return null


## Helper to print mod message


func mod_print(message: String) -> void:
	var mod_name: String = mod_info.get("name", "UnknownMod")
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[%s] %s" % [mod_name, message], "Core")


## Called when mod is loaded - lifecycle method for tests


func on_mod_loaded() -> void:
	_mod_init()


## Called when mod is unloaded - lifecycle method for tests


func on_mod_unloaded() -> void:
	_mod_cleanup()


## Called when mod is unloaded


func _exit_tree() -> void:
	_mod_cleanup()
