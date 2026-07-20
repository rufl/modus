## NetworkFeature - Feature module for networking system
##
## Manages networking functionality including multiplayer, Steam integration,
## dedicated server, and network editor. Can be toggled for single-player mode.
##
## Requirements: 2.3
class_name NetworkFeature
extends FeatureModule

## Network subsystems
var network_manager: Node
var steam_manager: Node
var dedicated_server: Node
var network_editor: Node

## Whether networking is enabled (can be disabled for single-player)
var networking_enabled: bool = true


## Constructor
func _init() -> void:
	super._init("network")
	feature_name = "Network System"


## Initialize the network feature
func initialize() -> void:
	super.initialize()

	# Check if networking should be enabled
	networking_enabled = get_config_value("enabled", true)

	if not networking_enabled:
		push_warning("[NetworkFeature] Networking is disabled in configuration")
		return

	var gm: Node = _get_game_manager()
	var network_service: Node = gm.get_core_system("network") if gm else null
	if network_service and network_service is NetworkSvc:
		steam_manager = network_service.steam_manager
		network_manager = network_service.network_manager
		dedicated_server = network_service.dedicated_server
		network_editor = network_service.network_editor
		return

	# Load subsystems in order
	steam_manager = _load_and_add("res://game/core/network/steam_manager.gd", "SteamManager")
	network_manager = _load_and_add("res://game/core/network/network_manager.gd", "NetworkManager")
	dedicated_server = _load_and_add(
		"res://game/core/network/dedicated_server.gd", "DedicatedServer"
	)
	network_editor = _load_and_add("res://game/core/network/network_editor.gd", "NetworkEditor")


func _get_game_manager() -> Node:
	var parent_node := get_parent()
	while parent_node:
		if parent_node.has_method("get_core_system"):
			return parent_node
		parent_node = parent_node.get_parent()

	return get_node_or_null("/root/GameManager")


## Shutdown the network feature
func shutdown() -> void:
	# Clean up subsystems
	if steam_manager and is_instance_valid(steam_manager):
		steam_manager.queue_free()
	if network_manager and is_instance_valid(network_manager):
		network_manager.queue_free()
	if dedicated_server and is_instance_valid(dedicated_server):
		dedicated_server.queue_free()
	if network_editor and is_instance_valid(network_editor):
		network_editor.queue_free()

	super.shutdown()


## Check if networking is available
func is_networking_enabled() -> bool:
	return networking_enabled and is_initialized()


## Get network manager
func get_network_manager() -> Node:
	return network_manager


## Get Steam manager
func get_steam_manager() -> Node:
	return steam_manager


## Get dedicated server
func get_dedicated_server() -> Node:
	return dedicated_server


## Get network editor
func get_network_editor() -> Node:
	return network_editor


## Load and add a subsystem script
func _load_and_add(path: String, node_name: String) -> Node:
	if not FileAccess.file_exists(path):
		push_error("[NetworkFeature] Script not found: %s" % path)
		return null

	var script: GDScript = load(path)
	if not script:
		push_error("[NetworkFeature] Failed to load script: %s" % path)
		return null

	var node: Node = Node.new()
	node.name = node_name
	node.set_script(script)
	add_child(node)
	return node
