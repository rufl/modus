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
	if not multiplayer.is_server() or not _validate_editor_payload("place_block", data):
		return
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
		block_placed.emit(data)

	# Broadcast to all clients (including server via call_local)
	_sync_place_block.rpc(data)


## Validate if a peer has edit permission
## Returns true if editing is allowed, false otherwise


func _validate_edit_permission(peer_id: int, action: String = "") -> bool:
	if peer_id <= 0:
		return false
	# Server always has permission
	if peer_id == 1:
		return true

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return false

	var cfg: Variant = gm.get_core_system("config")
	if not cfg:
		return false

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
	if not multiplayer.is_server() or not _validate_editor_payload("delete_node", relative_path):
		return
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
	if not multiplayer.is_server() or not _validate_editor_payload("paint_block", data):
		return
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
	if not multiplayer.is_server() or not _validate_editor_payload("place_entity", data):
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var network_mgr: Variant = gm.get_core_system("network")
		if (
			network_mgr
			and network_mgr.has_method("validate_rpc")
			and not network_mgr.validate_rpc(sender_id, "place_entity", [data])
		):
			return
	# Validate permissions
	if not _validate_edit_permission(sender_id, "allow_place_entities"):
		push_warning("[NetworkEditor] Entity place denied for peer %d" % sender_id)
		return

	data["_origin_peer"] = sender_id
	_sync_place_entity.rpc(data)


@rpc("any_peer", "call_remote", "reliable")
func _server_transform_node(data: Dictionary) -> void:
	if not multiplayer.is_server() or not _validate_editor_payload("transform_node", data):
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var network_mgr: Variant = gm.get_core_system("network")
		if (
			network_mgr
			and network_mgr.has_method("validate_rpc")
			and not network_mgr.validate_rpc(sender_id, "transform_node", [data])
		):
			return
	if not _validate_edit_permission(sender_id, "allow_transform"):
		push_warning("[NetworkEditor] Transform denied for peer %d" % sender_id)
		return

	data["_origin_peer"] = sender_id
	_sync_transform_node.rpc(data)


func _validate_editor_payload(action: String, payload: Variant) -> bool:
	match action:
		"delete_node":
			return payload is String and _is_safe_relative_path(payload)
		"place_block":
			if not payload is Dictionary:
				return false
			return (
				payload.get("type", "") == "block_brush"
				and _is_finite_vector(payload.get("position"))
				and _is_positive_bounded_vector(payload.get("size"), 100.0)
				and _is_optional_resource_path(payload.get("material_path", ""))
			)
		"paint_block":
			if not payload is Dictionary:
				return false
			return (
				_is_safe_relative_path(payload.get("path", ""))
				and _is_resource_path(payload.get("material_path", ""))
			)
		"place_entity":
			if not payload is Dictionary:
				return false
			var spawn_type: Variant = payload.get("spawn_type")
			var id: String = (
				payload.get("enemy_id", "") if spawn_type == 1 else payload.get("item_id", "")
			)
			return (
				payload.get("type", "") == "entity_placer"
				and payload.get("subtype", "") == "spawn_point"
				and spawn_type is int
				and spawn_type in [1, 2]
				and _is_bounded_string(id, 128)
				and _is_finite_vector(payload.get("position"))
				and _is_finite_number(payload.get("rotation_y"))
			)
		"transform_node":
			if not payload is Dictionary or not _is_safe_relative_path(payload.get("path", "")):
				return false
			for field in ["position", "rotation", "scale"]:
				if payload.has(field) and not _is_finite_vector(payload[field]):
					return false
			return payload.has("position") or payload.has("rotation") or payload.has("scale")
	return false


func _is_finite_vector(value: Variant) -> bool:
	return value is Vector3 and value.is_finite()


func _is_positive_bounded_vector(value: Variant, maximum: float) -> bool:
	if not _is_finite_vector(value):
		return false
	var vector: Vector3 = value
	return (
		vector.x > 0.0
		and vector.y > 0.0
		and vector.z > 0.0
		and vector.x <= maximum
		and vector.y <= maximum
		and vector.z <= maximum
	)


func _is_finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


func _is_bounded_string(value: Variant, maximum: int) -> bool:
	if not value is String:
		return false
	var text: String = value
	return (
		not text.is_empty()
		and text.length() <= maximum
		and not text.contains("\n")
		and not text.contains("\r")
	)


func _is_safe_relative_path(value: Variant) -> bool:
	if not _is_bounded_string(value, 256):
		return false
	var path: String = value
	return (
		not path.begins_with("/") and not path.contains("..") and not NodePath(path).is_absolute()
	)


func _is_resource_path(value: Variant) -> bool:
	if not _is_bounded_string(value, 512):
		return false
	var path: String = value
	return path.begins_with("res://") and ResourceLoader.exists(path)


func _is_optional_resource_path(value: Variant) -> bool:
	return value == "" or _is_resource_path(value)


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
