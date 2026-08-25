extends Node

signal save_completed(slot: String)
signal load_completed(slot: String)
signal save_failed(error: String)
signal load_failed(error: String)

const SAVE_VERSION: String = "1.0"
const SAVE_DIR: String = "user://saves/"
const QUICKSAVE_SLOT: String = "quicksave"

var save_slots: Array[String] = [QUICKSAVE_SLOT, "slot1", "slot2", "slot3"]

# Session time tracking
var _session_start_time: float = 0.0
var _total_session_time: float = 0.0


func _ready() -> void:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR.replace("user://", OS.get_user_data_dir() + "/"))

	# Start session timer
	_session_start_time = Time.get_ticks_msec() / 1000.0


## Get current session play time in seconds
func get_session_time() -> float:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	return _total_session_time + (current_time - _session_start_time)


## Reset session timer (call when starting new game)
func reset_session_time() -> void:
	_session_start_time = Time.get_ticks_msec() / 1000.0
	_total_session_time = 0.0


## Pause session timer (call when pausing)
func pause_session_time() -> void:
	var current_time: float = Time.get_ticks_msec() / 1000.0
	_total_session_time += (current_time - _session_start_time)


## Resume session timer (call when unpausing)
func resume_session_time() -> void:
	_session_start_time = Time.get_ticks_msec() / 1000.0


## Save game to slot (Server only)


func save_game(slot: String = QUICKSAVE_SLOT) -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		push_warning("Only server can save game")
		return

	var save_svc: Node = GameManager.get_core_system("save")
	if not save_svc:
		push_error("[GameStateManager] SaveService not found!")
		save_failed.emit("SaveService missing")
		return

	var save_data: Dictionary = serialize_world()
	save_data["version"] = SAVE_VERSION
	save_data["timestamp"] = Time.get_datetime_string_from_system(true)
	save_data["slot"] = slot

	var metadata: Dictionary = {
		"version": SAVE_VERSION,
		"player_count": get_tree().get_nodes_in_group("player").size(),
		"time_played": get_session_time()
	}

	if save_svc.save_data(slot, save_data, metadata):
		GameManager.get_core_system("logger").info(
			"[GameStateManager] Saved to slot: " + " " + str(slot), "Core"
		)
		save_completed.emit(slot)
	else:
		save_failed.emit("Write failed")


## Load game from slot (Server only, syncs to clients)


func load_game(slot: String = QUICKSAVE_SLOT) -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		push_warning("Only server can load game")
		return

	var save_svc: Node = GameManager.get_core_system("save")
	if not save_svc:
		push_error("[GameStateManager] SaveService not found!")
		load_failed.emit("SaveService missing")
		return

	var save_data: Dictionary = save_svc.load_data(slot)
	if save_data.is_empty():
		load_failed.emit("Load failed or empty data")
		return

	# Version check
	if save_data.get("version", "") != SAVE_VERSION:
		push_warning("Save version mismatch, attempting load anyway")

	await deserialize_world(save_data)

	# Sync to all clients
	_sync_load_to_clients.rpc(save_data)

	GameManager.get_core_system("logger").info(
		"[GameStateManager] Loaded from slot: " + " " + str(slot), "Core"
	)
	load_completed.emit(slot)


@rpc("authority", "call_remote", "reliable")
func _sync_load_to_clients(save_data: Dictionary) -> void:
	# Clients receive world state from server
	await deserialize_world(save_data)
	load_completed.emit(save_data.get("slot", "unknown"))


## Serialize entire world state


func serialize_world() -> Dictionary:
	var data: Dictionary = {}

	# Match state
	data["match"] = _serialize_match()

	# Players
	data["players"] = _serialize_players()

	# Enemies
	data["enemies"] = _serialize_enemies()

	# Items/Pickups
	data["items"] = _serialize_items()

	# Environment (doors, destructibles)
	data["environment"] = _serialize_environment()

	return data


## Deserialize and restore world state


# FIXED: Made async to properly await the async deserialization methods
func deserialize_world(data: Dictionary) -> void:
	# Match state
	if data.has("match"):
		_deserialize_match(data["match"])

	# Players
	if data.has("players"):
		_deserialize_players(data["players"])

	# Enemies - FIXED: Await the async deserialization to prevent race conditions
	if data.has("enemies"):
		await _deserialize_enemies(data["enemies"])

	# Items
	if data.has("items"):
		await _deserialize_items(data["items"])

	# Environment
	if data.has("environment"):
		_deserialize_environment(data["environment"])


# -------------------------------------------------------------------------
# Serialization Helpers
# -------------------------------------------------------------------------


func _serialize_match() -> Dictionary:
	var match_data: Dictionary = {}

	# Get from MatchService if available
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		var t_left: float = gs.match_service.time_left
		match_data["time_left"] = t_left if is_finite(t_left) else 0.0
		match_data["state"] = gs.match_service.current_match_state
		match_data["scores"] = gs.match_service.player_scores.duplicate()

	return match_data


func _deserialize_match(data: Dictionary) -> void:
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service:
		gs.match_service.time_left = data.get("time_left", 0.0)
		gs.match_service.current_match_state = data.get("state", 0)
		if data.has("scores"):
			gs.match_service.player_scores = _normalize_player_scores(data["scores"])


func _normalize_player_scores(scores: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for raw_peer_id: Variant in scores:
		var peer_id: int
		if raw_peer_id is int:
			peer_id = raw_peer_id
		elif str(raw_peer_id).is_valid_int():
			peer_id = int(raw_peer_id)
		else:
			continue
		normalized[peer_id] = scores[raw_peer_id]
	return normalized


func _serialize_players() -> Array:
	var players_data: Array = []

	for node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D:
			# Access properties via components (Player uses health_component and weapon_manager)
			var health_val: float = 100.0
			var armor_val: float = 0.0
			var weapon_idx: int = 0
			var ammo_data: Dictionary = {}

			if "health_component" in node and node.health_component:
				health_val = node.health_component.current_health
				armor_val = node.health_component.current_armor

			if "weapon_manager" in node and node.weapon_manager:
				weapon_idx = node.weapon_manager.current_weapon_index
				ammo_data = node.weapon_manager.get_ammo_data()

			var player_data: Dictionary = {
				"peer_id": node.get_multiplayer_authority(),
				"position": _vec3_to_array(node.global_position),
				"rotation": _vec3_to_array(node.global_rotation),
				"health": health_val,
				"armor": armor_val,
				"current_weapon_index": weapon_idx,
				"weapon_ammo": ammo_data
			}

			players_data.append(player_data)

	return players_data


func _deserialize_players(data: Array) -> void:
	for player_data: Dictionary in data:
		var peer_id: int = player_data.get("peer_id", 0)

		# Find player node by authority
		for node in get_tree().get_nodes_in_group("player"):
			if node.get_multiplayer_authority() == peer_id:
				node.global_position = _array_to_vec3(player_data.get("position", [0, 0, 0]))
				node.global_rotation = _array_to_vec3(player_data.get("rotation", [0, 0, 0]))

				# Restore health/armor via health_component
				if "health_component" in node and node.health_component:
					node.health_component.current_health = player_data.get("health", 100)
					node.health_component.current_armor = player_data.get("armor", 0)

				# Restore weapon state via weapon_manager
				if "weapon_manager" in node and node.weapon_manager:
					var saved_idx: int = player_data.get("current_weapon_index", 0)
					node.weapon_manager.switch_to_weapon(saved_idx)

					if player_data.has("weapon_ammo"):
						var saved_ammo: Variant = player_data["weapon_ammo"]
						if saved_ammo is Dictionary:
							node.weapon_manager.apply_ammo_data(saved_ammo)
						elif saved_ammo is Array and node.weapon_manager.ammo_system:
							var current_ammo: Array = node.weapon_manager.ammo_system.weapon_ammo
							var limit: int = mini(saved_ammo.size(), current_ammo.size())
							for i in range(limit):
								current_ammo[i] = saved_ammo[i]
							node.weapon_manager.ammo_system.emit_ammo_update()
				break


func _serialize_enemies() -> Array:
	var enemies_data: Array = []

	for node in get_tree().get_nodes_in_group("enemies"):
		if node is CharacterBody3D:
			var enemy_data: Dictionary = {
				"id": node.enemy_id if "enemy_id" in node else "",
				"name": node.name,
				"position": _vec3_to_array(node.global_position),
				"rotation": _vec3_to_array(node.global_rotation),
				"health": node.health if "health" in node else 100
			}
			enemies_data.append(enemy_data)

	return enemies_data


func _deserialize_enemies(data: Array) -> void:
	# Clear existing enemies first
	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Respawn enemies from save
	for enemy_data: Dictionary in data:
		var enemy_id: String = enemy_data.get("id", "basic_enemy")
		var position: Vector3 = _array_to_vec3(enemy_data.get("position", [0, 0, 0]))
		var health: float = enemy_data.get("health", 100)

		# Spawn enemy (using world's spawn method if available)
		var world: Node = get_tree().current_scene
		if world and world.has_method("spawn_enemy_at"):
			var enemy: Node = world.spawn_enemy_at(position, enemy_id)
			if enemy and "health" in enemy:
				enemy.health = health

	# Optimize AI after spawning all enemies (stagger updates for performance)
	if multiplayer.is_server():
		await get_tree().process_frame
		var ps: Node = GameManager.get_core_system("performance")
		if ps and ps.has_method("optimize_ai_pathfinding"):
			ps.optimize_ai_pathfinding()


func _serialize_items() -> Array:
	var items_data: Array = []

	for node in get_tree().get_nodes_in_group("items"):
		# Only save if not collected
		var is_collected: bool = node.collected if "collected" in node else false
		if not is_collected:
			var item_data: Dictionary = {
				"scene_path": node.scene_file_path,
				"name": node.pickup_name if "pickup_name" in node else node.name,
				"position": _vec3_to_array(node.global_position),
				"rotation": _vec3_to_array(node.global_rotation)
			}
			# Only save if it has a scene file (instantiable)
			if not item_data["scene_path"].is_empty():
				items_data.append(item_data)

	return items_data


func _deserialize_items(data: Array) -> void:
	# Clear existing items first
	for node in get_tree().get_nodes_in_group("items"):
		node.queue_free()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Spawn items from save data
	var items_per_batch: int = 5
	var count: int = 0

	for item_data: Dictionary in data:
		count += 1
		# Yield every few items to avoid freezing
		if count % items_per_batch == 0:
			await get_tree().process_frame

		var scene_path: String = item_data.get("scene_path", "")
		if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
			continue

		var scene: Resource = load(scene_path)
		if scene:
			var item: Node3D = scene.instantiate()
			get_tree().current_scene.add_child(item)

			item.global_position = _array_to_vec3(item_data.get("position", [0, 0, 0]))
			item.global_rotation = _array_to_vec3(item_data.get("rotation", [0, 0, 0]))

			if "pickup_name" in item and item_data.has("name"):
				item.pickup_name = item_data["name"]


func _serialize_environment() -> Dictionary:
	var env_data: Dictionary = {"doors": [], "destructibles": []}

	# Doors
	for door in get_tree().get_nodes_in_group("doors"):
		env_data["doors"].append(
			{
				"path": door.get_path(),
				"is_open": door.is_open if "is_open" in door else false,
				"is_locked": door.is_locked if "is_locked" in door else false
			}
		)

	# Destructibles
	for destr in get_tree().get_nodes_in_group("destructibles"):
		env_data["destructibles"].append(
			{
				"path": destr.get_path(),
				"is_broken": destr.is_broken if "is_broken" in destr else false
			}
		)

	return env_data


func _deserialize_environment(data: Dictionary) -> void:
	# Restore doors
	for door_data: Dictionary in data.get("doors", []):
		var door: Node = get_node_or_null(door_data.get("path", ""))
		if door:
			if "is_open" in door:
				door.is_open = door_data.get("is_open", false)


# -------------------------------------------------------------------------
# Utility Functions
# -------------------------------------------------------------------------


func _vec3_to_array(vec: Vector3) -> Array:
	if not vec.is_finite():
		push_warning("[GameStateManager] NaN/Inf detected in vector serialization: ", vec)
		return [0.0, 0.0, 0.0]
	return [vec.x, vec.y, vec.z]


func _array_to_vec3(arr: Array) -> Vector3:
	if arr.size() >= 3:
		return Vector3(arr[0], arr[1], arr[2])
	return Vector3.ZERO


## Get list of existing saves


func get_save_list() -> Array[Dictionary]:
	var save_svc: Node = GameManager.get_core_system("save")
	if save_svc and save_svc.has_method("get_all_saves"):
		return save_svc.get_all_saves()
	return []


## Delete a save


func delete_save(slot: String) -> void:
	var save_svc: Node = GameManager.get_core_system("save")
	if save_svc and save_svc.has_method("delete_save"):
		save_svc.delete_save(slot)
	GameManager.get_core_system("logger").info(
		"[GameStateManager] Deleted save: " + " " + str(slot), "Core"
	)


## Check if save exists


func save_exists(slot: String) -> bool:
	var save_svc: Node = GameManager.get_core_system("save")
	return save_svc and save_svc.has_method("save_exists") and save_svc.save_exists(slot)
