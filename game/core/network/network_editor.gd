class_name NetworkEditor
extends Node

signal block_placed(data: Dictionary)
signal node_painted(data: Dictionary)
signal entity_placed(data: Dictionary)
signal node_transformed(data: Dictionary)
signal node_deleted(path: String)

var is_edit_mode: bool = false
var editor_state: Node = null  # Reference to local EditorState


func _ready() -> void:
	# Register self if needed
	pass


# ============================================================================
# CLIENT REQUESTS (Called by Client)
# ============================================================================

## Request to place a block/entity


func request_place_block(data: Dictionary) -> void:
	if not is_inside_tree():
		return
	rpc_id(1, "_server_place_block", data)


## Request to delete a node


func request_delete_node(node_path: String) -> void:
	if not is_inside_tree():
		return
	var relative_path := _get_relative_path(node_path)
	rpc_id(1, "_server_delete_node", relative_path)


func request_paint_node(data: Dictionary) -> void:
	if not is_inside_tree():
		return
	rpc_id(1, "_server_paint_node", data)


func request_place_entity(data: Dictionary) -> void:
	if not is_inside_tree():
		return
	rpc_id(1, "_server_place_entity", data)


func request_transform_node(data: Dictionary) -> void:
	if not is_inside_tree():
		return
	rpc_id(1, "_server_transform_node", data)


# ============================================================================
# SERVER HANDLERS (Called on Server)
# ============================================================================

@rpc("any_peer", "call_remote", "reliable")
func _server_place_block(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	# RPC Rate Limiting Validation
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var network_mgr: Variant = gm.get_core_system("network")
		if network_mgr and network_mgr.has_method("validate_rpc"):
			if not network_mgr.validate_rpc(sender_id, "place_block", [data]):
				push_warning("[NetworkEditor] Rate limit exceeded for peer %d" % sender_id)
				return

	# Validate permissions - check if player has edit rights
	if not _validate_edit_permission(sender_id, "allow_place_blocks"):
		var msg: String = "[NetworkEditor] Block place denied for peer %d"
		push_warning(msg % sender_id)
		return

	# Embed origin peer ID for proper echo prevention on clients
	data["_origin_peer"] = sender_id

	# Execute locally on server
	if editor_state:
		# We assume data is valid for now
		block_placed.emit(data)

	# Broadcast to all clients (including server via call_local)
	_sync_place_block.rpc(data)


## Validate if a peer has edit permission
## Returns true if editing is allowed, false otherwise


func _validate_edit_permission(peer_id: int, action: String = "") -> bool:
	# Server always has permission
	if peer_id == 1:
		return true

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return true  # Default to allowed if no GameManager

	var cfg: Variant = gm.get_core_system("config")
	if not cfg:
		return true

	# 1. Global Killswitch
	var allow_global: bool = cfg.get_value("game_rules.allow_level_editing", true)
	if not allow_global:
		return false

	# 2. Granular Action Check
	if action != "":
		var perm_key: String = "player_modes.editor.%s" % action
		return cfg.get_value(perm_key, true)

	# Future: Check if player is admin via PlayerService or similar
	# For now, allow all authenticated players if global switch is on
	return true


@rpc("any_peer", "call_remote", "reliable")
func _server_delete_node(relative_path: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	# RPC Rate Limiting Validation
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var network_mgr: Variant = gm.get_core_system("network")
		if network_mgr and network_mgr.has_method("validate_rpc"):
			if not network_mgr.validate_rpc(sender_id, "delete_node", [relative_path]):
				push_warning("[NetworkEditor] Rate limit exceeded for peer %d" % sender_id)
				return

	# Validate permissions
	if not _validate_edit_permission(sender_id, "allow_delete_nodes"):
		push_warning("[NetworkEditor] Delete denied for peer %d" % sender_id)
		return

	# Broadcast to all clients
	_sync_delete_node.rpc(relative_path)


@rpc("any_peer", "call_remote", "reliable")
func _server_paint_node(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	# RPC Rate Limiting Validation
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var network_mgr: Variant = gm.get_core_system("network")
		if network_mgr and network_mgr.has_method("validate_rpc"):
			if not network_mgr.validate_rpc(sender_id, "paint_block", [data]):
				push_warning("[NetworkEditor] Rate limit exceeded for peer %d" % sender_id)
				return

	# Validate permissions
	if not _validate_edit_permission(sender_id, "allow_paint"):
		push_warning("[NetworkEditor] Paint denied for peer %d" % sender_id)
		return

	data["_origin_peer"] = sender_id
	_sync_paint_node.rpc(data)


@rpc("any_peer", "call_remote", "reliable")
func _server_place_entity(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	# Validate permissions
	if not _validate_edit_permission(sender_id, "allow_place_entities"):
		push_warning("[NetworkEditor] Entity place denied for peer %d" % sender_id)
		return

	data["_origin_peer"] = sender_id
	_sync_place_entity.rpc(data)


@rpc("any_peer", "call_remote", "reliable")
func _server_transform_node(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()

	if not _validate_edit_permission(sender_id, "allow_transform"):
		push_warning("[NetworkEditor] Transform denied for peer %d" % sender_id)
		return

	data["_origin_peer"] = sender_id
	_sync_transform_node.rpc(data)


# ============================================================================
# CLIENT SYNC (Called on All Clients)
# ============================================================================

@rpc("authority", "call_local", "reliable")
func _sync_place_block(data: Dictionary) -> void:
	# Skip if we are the originating peer (client-side prediction already applied)
	var origin_peer: int = data.get("_origin_peer", 0)
	if origin_peer == multiplayer.get_unique_id():
		return

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Variant = gm.get_core_system("logger")
		if logger and logger.has_method("debug"):
			logger.debug("[NetworkEditor] Syncing block placement from peer %d" % origin_peer)
	block_placed.emit(data)


@rpc("authority", "call_local", "reliable")
func _sync_delete_node(relative_path: String) -> void:
	var root: Node = _get_level_root()
	if not root:
		return

	var node: Node = root.get_node_or_null(relative_path)
	if node:
		node_deleted.emit(node.get_path())  # Emit the actual node path instead of relative_path
		node.queue_free()


@rpc("authority", "call_local", "reliable")
func _sync_paint_node(data: Dictionary) -> void:
	var origin_peer: int = data.get("_origin_peer", 0)
	if origin_peer == multiplayer.get_unique_id():
		return
	node_painted.emit(data)


@rpc("authority", "call_local", "reliable")
func _sync_place_entity(data: Dictionary) -> void:
	var origin_peer: int = data.get("_origin_peer", 0)
	if origin_peer == multiplayer.get_unique_id():
		return
	entity_placed.emit(data)


@rpc("authority", "call_local", "reliable")
func _sync_transform_node(data: Dictionary) -> void:
	var origin_peer: int = data.get("_origin_peer", 0)
	if origin_peer == multiplayer.get_unique_id():
		return
	node_transformed.emit(data)


# ============================================================================
# HELPERS
# ============================================================================


func _get_level_root() -> Node:
	# Assume standard scene structure
	return get_tree().current_scene.get_node_or_null("LevelRoot")


func _get_relative_path(full_path: String) -> String:
	# Convert absolute path to path relative to LevelRoot
	# This is tricky if nodes are dynamically named.
	# For v1 with blocks, we might need unique IDs or precise paths.
	return full_path
