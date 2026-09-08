class_name NetworkSvc
extends Node

# Preload network subsystem scripts
const NetworkManagerScript: GDScript = preload("res://game/core/network/network_manager.gd")
const SteamManagerScript: GDScript = preload("res://game/core/network/steam_manager.gd")
const DedicatedServerScript: GDScript = preload("res://game/core/network/dedicated_server.gd")
const NetworkEditorScript: GDScript = preload("res://game/core/network/network_editor.gd")

## Network subsystem references
##
## These are dynamically instantiated at runtime via _create_and_add().
## Scripts are preloaded to enable proper type checking.
##
## TYPE SAFETY NOTE: Due to Godot's parse order, class_name types may not be
## available at parse time even with preload. Using Node type with runtime
## assertions provides type safety without parse errors.
##
## To access typed methods, cast at call site:
##   (network_manager as NetworkManager).some_method()
var network_manager: Node  # NetworkManager - handles multiplayer connections
var steam_manager: Node  # SteamManager - Steam API integration
var dedicated_server: Node  # DedicatedServer - dedicated server functionality
var network_editor: Node  # NetworkEditor - network debugging tools


static func get_service() -> NetworkSvc:
	# Get scene tree
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null

	# Try GameManager first
	var gm: Node = tree.root.get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_core_system"):
		var svc: Variant = gm.get_core_system("network")
		if svc is NetworkSvc:
			return svc as NetworkSvc

	# Fallback: Get autoload directly from scene tree
	if tree.root.has_node("NetworkService"):
		var node: Node = tree.root.get_node("NetworkService")
		if node is NetworkSvc:
			return node as NetworkSvc

	return null


func _ready() -> void:
	name = "NetworkService"

	# Register with GameManager
	var gm: Node = _get_game_manager()
	if gm and gm.has_method("register_core_system"):
		gm.register_core_system("network", self)

	# Load subsystems
	# Note: Order matters if they depend on each other.
	# SteamManager usually first if using Steam Networking.
	steam_manager = _create_and_add(SteamManagerScript, "SteamManager")
	network_manager = _create_and_add(NetworkManagerScript, "NetworkManager")
	dedicated_server = _create_and_add(DedicatedServerScript, "DedicatedServer")
	network_editor = _create_and_add(NetworkEditorScript, "NetworkEditor")

	var logger: Variant = gm.get_core_system("logger") if gm else null
	if logger and logger.has_method("info"):
		logger.info("NetworkService initialized", "NetworkService")


func _get_game_manager() -> Node:
	var parent_node := get_parent()
	while parent_node:
		if (
			parent_node.has_method("get_core_system")
			and parent_node.has_method("register_core_system")
		):
			return parent_node
		parent_node = parent_node.get_parent()

	return get_node_or_null("/root/GameManager")


func _create_and_add(script: GDScript, node_name: String) -> Node:
	if not script:
		push_error("NetworkService: Invalid script for: %s" % node_name)
		return null

	var node: Node = Node.new()
	node.name = node_name
	node.set_script(script)
	add_child(node)

	# Runtime type assertion for safety
	var expected_type: String = node_name  # NetworkManager, SteamManager, etc.
	if not node.get_script().get_global_name() == expected_type:
		push_warning(
			(
				"NetworkService: Type mismatch for %s (expected class_name: %s)"
				% [node_name, expected_type]
			)
		)

	return node
