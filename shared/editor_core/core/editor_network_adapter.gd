@tool
class_name EditorNetworkAdapter
extends Node


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


signal cursor_updated(peer_id: int, pos: Vector3, normal: Vector3)

var editor_state: Node = null


func setup(state: Node) -> void:
	editor_state = state
	if editor_state:
		# Connect to local editor actions
		if not editor_state.network_action_requested.is_connected(_on_network_action_requested):
			editor_state.network_action_requested.connect(_on_network_action_requested)

	# Monitor network state
	if multiplayer:
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.connected_to_server.connect(_on_connected_to_server)


func _on_connected_to_server() -> void:
	if editor_state:
		editor_state.is_networked = true
		var logger: Node = GameManager.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info(
				"[EditorNetwork] Connected to server, enabling networked mode", "EditorNetwork"
			)


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		if editor_state:
			editor_state.is_networked = true
		# Sync current level state to the new peer
		_sync_initial_state(id)


func _sync_initial_state(peer_id: int) -> void:
	# Iterate over level root children and send construction actions
	# This ensures the new client gets all placed blocks/entities
	if not editor_state:
		return
	var root: Node = editor_state.get_level_root()
	if not root:
		return

	for child in root.get_children():
		if child.get_meta("level_editor_placed", false):
			# Determine action type based on node type
			if child is CSGBox3D:
				var data: Dictionary = {
					"position": child.position,
					"size": child.size,
					"material_path": child.material.resource_path if child.material else ""
				}
				sync_action.rpc_id(peer_id, "place_block", data)
			elif child is Node3D and child.has_method("spawn_type"):  # SpawnPoint
				var data: Dictionary = {
					"subtype": "spawn_point",
					"position": child.position,
					"rotation_y": child.rotation.y,
					"spawn_type": child.get("spawn_type"),
					"enemy_id": child.get("enemy_id"),
					"item_id": child.get("item_id")
				}
				sync_action.rpc_id(peer_id, "place_entity", data)
			else:
				# Static Mesh/Scene?
				if not child.scene_file_path.is_empty():
					var data: Dictionary = {
						"subtype": "static",
						"position": child.position,
						"rotation_y": child.rotation.y,
						"scene_path": child.scene_file_path
					}
					sync_action.rpc_id(peer_id, "place_entity", data)

	_log("[EditorNetwork] Synced initial state to peer %d" % peer_id, "EditorNetwork")


func _on_network_action_requested(action: String, data: Dictionary) -> void:
	# Local editor produced an action. Send to server.
	if not multiplayer.has_multiplayer_peer():
		return

	if multiplayer.is_server():
		# We are server. Broadcast to others.
		_broadcast_action(action, data)
		# And since EditorState stopped local execution for "networked" actions,
		# we must execute it locally now (as the authority).
		_execute_local(action, data)
	else:
		# We are client. Request server to perform action.
		request_action.rpc_id(1, action, data)


## Client -> Server Request

@rpc("any_peer", "call_remote", "reliable")
func request_action(action: String, data: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _validate_editor_rpc_rate(sender_id, "request_action", [action, data])
		or not _validate_editor_permission(sender_id, action)
		or not _validate_action_payload(action, data)
	):
		push_error("[EditorNetwork] Rejected editor command from peer %d" % sender_id)
		multiplayer.disconnect_peer(sender_id)
		return

	_execute_local(action, data)
	_broadcast_action(action, data)


func _validate_editor_rpc_rate(peer_id: int, method: String, args: Array) -> bool:
	if peer_id <= 0:
		return false
	var gm: Node = get_node_or_null("/root/GameManager")
	var network_svc: Variant = gm.get_core_system("network") if gm else null
	var network_manager: Variant = (
		network_svc.network_manager if network_svc is NetworkSvc else null
	)
	if not network_manager or not network_manager.has_method("validate_rpc"):
		return false
	return network_manager.validate_rpc(peer_id, method, args)


func _is_editor_avatar(player: Node) -> bool:
	if not is_instance_valid(player):
		return false
	if player.name.begins_with("editor_") or player.get_class() == "EditorAvatar":
		return true
	var script: Script = player.get_script()
	return script != null and script.resource_path.ends_with("/editor_avatar.gd")


func _validate_editor_permission(peer_id: int, action: String = "") -> bool:
	if peer_id <= 0:
		return false
	var gameplay: Variant = GameManager.get_core_system("gameplay")
	var registry: Variant = gameplay.entity_registry if gameplay is GameplaySvc else null
	if not registry or not registry.has_method("get_player"):
		return false
	if not _is_editor_avatar(registry.get_player(peer_id)):
		return false

	var cfg: Variant = GameManager.get_core_system("config")
	if not cfg or not bool(cfg.get_value("player_modes.editor.validate_permissions", false)):
		return false
	if action.is_empty():
		return true
	if action == "place_block":
		return bool(cfg.get_value("player_modes.editor.allow_place_blocks", false))
	if action == "paint_node":
		return bool(cfg.get_value("player_modes.editor.allow_paint", false))
	if action == "delete_node":
		return bool(cfg.get_value("player_modes.editor.allow_delete_nodes", false))
	if action == "place_entity":
		return bool(cfg.get_value("player_modes.editor.allow_place_entities", false))
	if action in ["connect_nodes", "change_environment"]:
		return true
	return false


func _get_level_root() -> Node:
	if editor_state and editor_state.has_method("_get_level_root"):
		return editor_state.call("_get_level_root") as Node
	return null


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


func _is_level_subtree_path(value: Variant) -> bool:
	if not _is_safe_relative_path(value):
		return false
	var root: Node = _get_level_root()
	if not root:
		return false
	var target: Node = root.get_node_or_null(value)
	return target != null and target != root and root.is_ancestor_of(target)


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


func _is_material_path(value: Variant) -> bool:
	if not _is_bounded_string(value, 512) or not String(value).begins_with("res://"):
		return false
	return ResourceLoader.exists(value) and load(value) is Material


func _is_allowed_scene_path(value: Variant) -> bool:
	if not _is_bounded_string(value, 512):
		return false
	var path: String = value
	if not path.begins_with("res://") or not path.ends_with(".tscn"):
		return false
	var prefixes: Array[String] = [
		"res://game/entities/enemies/",
		"res://game/world/actors/props/",
		"res://game/world/actors/props/scenes/",
		"res://game/world/actors/hazards/",
		"res://game/scenes/environment/hazards/",
		"res://game/scenes/environment/traversal/",
		"res://game/scenes/environment/interactables/",
		"res://game/scenes/items/pickups/",
	]
	for prefix: String in prefixes:
		if path.begins_with(prefix):
			return ResourceLoader.exists(path) and load(path) is PackedScene
	return false


func _validate_action_payload(action: String, data: Dictionary) -> bool:
	match action:
		"place_block":
			return (
				data.get("type", "") == "block_brush"
				and _is_finite_vector(data.get("position"))
				and _is_positive_bounded_vector(data.get("size"), 100.0)
				and data.size() <= 8
				and (
					data.get("material_path", "") == ""
					or _is_material_path(data.get("material_path"))
				)
			)
		"paint_node":
			return (
				_is_level_subtree_path(data.get("path", ""))
				and _is_material_path(data.get("material_path", ""))
			)
		"delete_node":
			return _is_level_subtree_path(data.get("path", ""))
		"place_entity":
			if data.get("type", "") != "entity_placer":
				return false
			if (
				not _is_finite_vector(data.get("position"))
				or not _is_finite_number(data.get("rotation_y"))
			):
				return false
			if data.get("subtype", "") == "static":
				return _is_allowed_scene_path(data.get("scene_path", ""))
			var spawn_type: Variant = data.get("spawn_type")
			var identifier: Variant = (
				data.get("enemy_id", "") if spawn_type == 1 else data.get("item_id", "")
			)
			return (
				data.get("subtype", "") == "spawn_point"
				and spawn_type is int
				and spawn_type in [1, 2]
				and _is_bounded_string(identifier, 128)
			)
		"connect_nodes":
			return (
				_is_level_subtree_path(data.get("from_path", ""))
				and _is_level_subtree_path(data.get("to_path", ""))
				and _is_bounded_string(data.get("channel", ""), 128)
			)
		"change_environment":
			var environment_type: Variant = data.get("type")
			var value: Variant = data.get("value")
			match environment_type:
				"time":
					return _is_finite_number(value) and float(value) >= 0.0 and float(value) <= 24.0
				"clouds":
					return _is_finite_number(value) and float(value) >= 0.0 and float(value) <= 1.0
				"weather":
					return value is int and value >= 0 and value <= 32
				"wind":
					if value is Dictionary:
						return (
							_is_finite_number(value.get("strength"))
							and _is_finite_vector(value.get("direction", Vector3.ZERO))
						)
					return _is_finite_number(value)
	return false


## Server -> Client Sync

@rpc("authority", "call_remote", "reliable")
func sync_action(action: String, data: Dictionary) -> void:
	_execute_local(action, data)


func _broadcast_action(action: String, data: Dictionary) -> void:
	# Send to all peers
	sync_action.rpc(action, data)


## Cursor Sync - Unreliable for performance

@rpc("any_peer", "call_remote", "unreliable")
func update_cursor(pos: Vector3, normal: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _validate_editor_rpc_rate(sender_id, "update_cursor", [pos, normal])
		or not _validate_editor_permission(sender_id)
		or not _is_finite_vector(pos)
		or not _is_finite_vector(normal)
	):
		return
	sync_cursor.rpc(sender_id, pos, normal)


func _execute_local(action: String, data: Dictionary) -> void:
	if not editor_state:
		return

	match action:
		"place_block":
			editor_state.remote_place_block(data)
		"paint_node":
			editor_state.remote_paint_node(data)
		"delete_node":
			# data should contain "path"
			var path: String = data.get("path", "")
			if not path.is_empty():
				editor_state.remote_delete_node(path)
		"place_entity":
			editor_state.remote_place_entity(data)
		"connect_nodes":
			editor_state.remote_connect_nodes(data)
		"change_environment":
			editor_state.remote_change_environment(data)
