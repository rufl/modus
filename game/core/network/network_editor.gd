class_name NetworkEditor
extends Node

signal block_placed(data: Dictionary)
signal node_painted(data: Dictionary)
signal entity_placed(data: Dictionary)
signal node_transformed(data: Dictionary)
signal node_deleted(path: String)

var is_edit_mode: bool = false
var editor_state: Node = null  # Reference to local EditorState

var _registered_network_service: Node = null
var _standalone_notice_logged: bool = false


func _ready() -> void:
	_resolve_editor_state()
	if not editor_state and is_inside_tree():
		call_deferred("_resolve_editor_state")

	var network_service: Node = _get_owning_network_service()
	if network_service:
		_standalone_notice_logged = false
		if (
			_registered_network_service != network_service
			and network_service.has_method("register_network_editor")
		):
			network_service.call("register_network_editor", self)
			_registered_network_service = network_service
		return

	if not _standalone_notice_logged:
		_standalone_notice_logged = true
		var logger: Variant = _get_logger()
		if logger and logger.has_method("warning"):
			logger.warning(
				"[NetworkEditor] No owning NetworkSvc found; continuing in standalone mode",
				"NetworkEditor"
			)
		else:
			push_warning("[NetworkEditor] No owning NetworkSvc found; continuing in standalone mode")


func _resolve_editor_state() -> void:
	if is_instance_valid(editor_state):
		return
	editor_state = null

	var tree: SceneTree = get_tree()
	if not tree or not tree.root:
		return

	var embedded_editor: Node = tree.root.find_child("EmbeddedLevelEditor", true, false)
	if embedded_editor:
		if "editor_state" in embedded_editor:
			var state: Variant = embedded_editor.get("editor_state")
			if state is Node and is_instance_valid(state):
				editor_state = state
				return
		var child_state: Node = embedded_editor.get_node_or_null("EditorState")
		if child_state:
			editor_state = child_state
			return

	var state_node: Node = tree.root.find_child("EditorState", true, false)
	if state_node:
		editor_state = state_node


func _get_owning_network_service() -> Node:
	var current: Node = get_parent()
	while current:
		if current is NetworkSvc:
			return current
		current = current.get_parent()
	return null


func _get_logger() -> Variant:
	var game_manager: Node = get_node_or_null("/root/GameManager")
	return game_manager.get_core_system("logger") if game_manager else null


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
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _validate_editor_rpc_rate(sender_id, "place_block", [data])
		or not _validate_edit_permission(sender_id, "allow_place_blocks")
		or not _validate_editor_payload("place_block", data)
	):
		return

	# Embed origin peer ID for proper echo prevention on clients
	data["_origin_peer"] = sender_id

	# Execute locally on server
	if editor_state:
		block_placed.emit(data)

	# Broadcast to all clients (including server via call_local)
	_sync_place_block.rpc(data)


func _validate_editor_rpc_rate(peer_id: int, method: String, args: Array) -> bool:
	if peer_id <= 0:
		return false
	var gm: Node = get_node_or_null("/root/GameManager")
	var network_svc: Variant = gm.get_core_system("network") if gm else null
	var network_manager: Variant = network_svc.network_manager if network_svc is NetworkSvc else null
	if not network_manager or not network_manager.has_method("validate_rpc"):
		push_warning("[NetworkEditor] Network manager unavailable; rejecting editor RPC")
		return false
	if not network_manager.validate_rpc(peer_id, method, args):
		push_warning("[NetworkEditor] Rate limit or RPC validation rejected %s from peer %d" % [method, peer_id])
		return false
	return true


func _is_editor_avatar(player: Node) -> bool:
	if not is_instance_valid(player):
		return false
	if player.name.begins_with("editor_") or player.get_class() == "EditorAvatar":
		return true
	var script: Script = player.get_script()
	return script != null and script.resource_path.ends_with("/editor_avatar.gd")


func _get_editor_player(peer_id: int) -> Node:
	var gm: Node = get_node_or_null("/root/GameManager")
	var gameplay: Variant = gm.get_core_system("gameplay") if gm else null
	var registry: Variant = gameplay.entity_registry if gameplay is GameplaySvc else null
	if not registry or not registry.has_method("get_player"):
		return null
	return registry.get_player(peer_id)


func _validate_edit_permission(peer_id: int, action: String = "") -> bool:
	if peer_id <= 0:
		return false
	var player: Node = _get_editor_player(peer_id)
	if not _is_editor_avatar(player):
		return false

	var gm: Node = get_node_or_null("/root/GameManager")
	var cfg: Variant = gm.get_core_system("config") if gm else null
	if not cfg:
		return false
	if not bool(cfg.get_value("player_modes.editor.validate_permissions", false)):
		return false
	if not action.is_empty():
		return bool(cfg.get_value("player_modes.editor.%s" % action, false))
	return true


func _is_level_subtree_path(value: Variant) -> bool:
	if not _is_safe_relative_path(value):
		return false
	var root: Node = _get_level_root()
	if not root:
		return false
	var target: Node = root.get_node_or_null(value)
	return target != null and target != root and root.is_ancestor_of(target)


func _is_allowed_scene_path(value: Variant) -> bool:
	if not _is_bounded_string(value, 512):
		return false
	var path: String = value
	if not path.begins_with("res://") or not path.ends_with(".tscn"):
		return false
	var allowed_prefixes: Array[String] = [
		"res://game/entities/enemies/",
		"res://game/world/actors/props/",
		"res://game/world/actors/props/scenes/",
		"res://game/world/actors/hazards/",
		"res://game/scenes/environment/hazards/",
		"res://game/scenes/environment/traversal/",
		"res://game/scenes/environment/interactables/",
		"res://game/scenes/items/pickups/",
	]
	for prefix: String in allowed_prefixes:
		if path.begins_with(prefix):
			return ResourceLoader.exists(path) and load(path) is PackedScene
	return false

@rpc("any_peer", "call_remote", "reliable")
func _server_delete_node(relative_path: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _validate_editor_rpc_rate(sender_id, "delete_node", [relative_path])
		or not _validate_edit_permission(sender_id, "allow_delete_nodes")
		or not _validate_editor_payload("delete_node", relative_path)
	):
		return
	_sync_delete_node.rpc(relative_path)


@rpc("any_peer", "call_remote", "reliable")
func _server_paint_node(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _validate_editor_rpc_rate(sender_id, "paint_block", [data])
		or not _validate_edit_permission(sender_id, "allow_paint")
		or not _validate_editor_payload("paint_block", data)
	):
		return
	data["_origin_peer"] = sender_id
	_sync_paint_node.rpc(data)


@rpc("any_peer", "call_remote", "reliable")
func _server_place_entity(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _validate_editor_rpc_rate(sender_id, "place_entity", [data])
		or not _validate_edit_permission(sender_id, "allow_place_entities")
		or not _validate_editor_payload("place_entity", data)
	):
		return
	data["_origin_peer"] = sender_id
	_sync_place_entity.rpc(data)


@rpc("any_peer", "call_remote", "reliable")
func _server_transform_node(data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _validate_editor_rpc_rate(sender_id, "transform_node", [data])
		or not _validate_edit_permission(sender_id, "allow_transform")
		or not _validate_editor_payload("transform_node", data)
	):
		return
	data["_origin_peer"] = sender_id
	_sync_transform_node.rpc(data)


func _validate_editor_payload(action: String, payload: Variant) -> bool:
	match action:
		"delete_node":
			return _is_level_subtree_path(payload)
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
				_is_level_subtree_path(payload.get("path", ""))
				and _is_material_path(payload.get("material_path", ""))
			)
		"place_entity":
			if not payload is Dictionary:
				return false
			if payload.get("type", "") != "entity_placer":
				return false
			if not _is_finite_vector(payload.get("position")) or not _is_finite_number(payload.get("rotation_y")):
				return false
			if payload.get("subtype", "") == "static":
				return _is_allowed_scene_path(payload.get("scene_path", ""))
			var spawn_type: Variant = payload.get("spawn_type")
			var id: Variant = payload.get("enemy_id", "") if spawn_type == 1 else payload.get("item_id", "")
			return (
				payload.get("subtype", "") == "spawn_point"
				and spawn_type is int
				and spawn_type in [1, 2]
				and _is_bounded_string(id, 128)
			)
		"transform_node":
			if not payload is Dictionary or not _is_level_subtree_path(payload.get("path", "")):
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

func _is_material_path(value: Variant) -> bool:
	if not _is_resource_path(value):
		return false
	return load(value) is Material

func _is_optional_resource_path(value: Variant) -> bool:
	return value == "" or _is_material_path(value)


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
	var current_scene: Node = get_tree().current_scene
	return current_scene.get_node_or_null("LevelRoot") if current_scene else null


func _get_relative_path(full_path: String) -> String:
	# Convert absolute path to path relative to LevelRoot
	# This is tricky if nodes are dynamically named.
	# For v1 with blocks, we might need unique IDs or precise paths.
	return full_path
