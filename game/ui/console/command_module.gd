class_name CommandModule
extends RefCounted

var _registry: Object


func register_commands(registry: Object) -> void:
	_registry = registry
	# Override to register commands using registry.register()


## Helper to register a command


func register(name: String, callback: Callable, help_text: String, usage: String = "") -> void:
	if _registry:
		_registry.register(name, callback, help_text, usage)


## Helper to get a service safely
## Returns the service Node if found, null if GameManager unavailable or service not registered
## Always check for null before using the returned service
func get_service(name: String) -> Node:
	if not GameManager:
		push_warning("[CommandModule] GameManager not available")
		return null

	var service: Node = GameManager.get_core_system(name)
	if not service:
		push_warning("[CommandModule] Service '%s' not found" % name)
	return service


## Helper to get the local player
## Returns the player Node if found, null if world or player not available
## Always check for null before using the returned player
func get_player() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		push_warning("[CommandModule] SceneTree not available")
		return null

	var world: Node = tree.root.get_node_or_null("World")
	if not world:
		push_warning("[CommandModule] World node not found")
		return null

	if world.has_method("get_player"):
		var mp_api: MultiplayerAPI = tree.multiplayer
		var player: Node = world.get_player(mp_api.get_unique_id())
		if not player:
			push_warning("[CommandModule] Player not found for peer %d" % mp_api.get_unique_id())
		return player

	# Fallback: legacy scene tree search
	var player: Node = world.get_node_or_null("Player")
	if not player:
		push_warning("[CommandModule] Player node not found in World")
	return player
