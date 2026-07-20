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
			logger.info("[EditorNetwork] Connected to server, enabling networked mode", "EditorNetwork")


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

	# SECURITY FIX: Validate editor permissions before executing commands
	if not _validate_editor_permission(sender_id):
		push_error("[EditorNetwork] UNAUTHORIZED editor command from peer %d - KICKING" % sender_id)
		multiplayer.disconnect_peer(sender_id)
		return

	# Execute on server
	_execute_local(action, data)

	# Broadcast to ALL clients (including sender, to confirm execution if we want strict authority)
	# Or broadcast to everyone except sender if we use client-side prediction?
	# EditorState usually stops local execution, so we should send back to sender too.
	_broadcast_action(action, data)


## Validate editor permissions (SECURITY FIX)
## Only authorized peers can execute editor commands
func _validate_editor_permission(peer_id: int) -> bool:
	# Check if peer is in editor mode
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if not gs or not gs.entity_registry:
		push_warning("[EditorNetwork] Cannot validate permissions: entity registry unavailable")
		return false
	
	var player: Node = gs.entity_registry.get_player(peer_id)
	if not player:
		push_warning("[EditorNetwork] Cannot validate permissions: player %d not found" % peer_id)
		return false
	
	# Check if player is an editor avatar (not a regular player)
	# Editor avatars are spawned with mode="editor" in world.gd
	if not player.name.begins_with("editor_") and player.get_class() != "EditorAvatar":
		push_warning("[EditorNetwork] Peer %d is not an editor avatar" % peer_id)
		return false
	
	return true


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
	# Broadcast to others (skip sender? No, sender knows his own pos)
	var sender_id: int = multiplayer.get_remote_sender_id()
	sync_cursor.rpc(sender_id, pos, normal)


@rpc("authority", "call_remote", "unreliable")
func sync_cursor(peer_id: int, pos: Vector3, normal: Vector3) -> void:
	# Update visual cursor for peer_id
	if editor_state:
		# We need a signal on EditorState or adapter itself
		# Let's emit on adapter, EditorFeatures can listen
		cursor_updated.emit(peer_id, pos, normal)


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
