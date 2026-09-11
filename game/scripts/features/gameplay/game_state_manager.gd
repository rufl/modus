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

	# Validate every destructive section before changing live nodes.
	if not _validate_world_data(save_data):
		load_failed.emit("Invalid save data")
		return

	if not await deserialize_world(save_data):
		load_failed.emit("World restoration failed")
		return

	# Sync to all clients only after the authoritative world was restored.
	_sync_load_to_clients.rpc(save_data)

	GameManager.get_core_system("logger").info(
		"[GameStateManager] Loaded from slot: " + " " + str(slot), "Core"
	)
	load_completed.emit(slot)


@rpc("authority", "call_remote", "reliable")
func _sync_load_to_clients(save_data: Dictionary) -> void:
	# Clients receive world state from server
	if not _validate_world_data(save_data):
		load_failed.emit("Invalid synchronized save data")
		return
	if not await deserialize_world(save_data):
		load_failed.emit("Synchronized world restoration failed")
		return
	load_completed.emit(save_data.get("slot", "unknown"))


func _validate_world_data(data: Dictionary) -> bool:
	if data.has("enemies") and not _validate_enemy_records(data["enemies"]):
		return false
	if data.has("items") and not _validate_item_records(data["items"]):
		return false
	if data.has("environment") and not _validate_environment_records(data["environment"]):
		return false
	if data.has("players") and not _validate_player_records(data["players"]):
		return false
	return true


func _validate_player_records(data: Variant) -> bool:
	if not data is Array:
		return false
	for record: Variant in data:
		if not record is Dictionary:
			return false
		if not record.has("peer_id") or not record.peer_id is int:
			return false
		if record.has("position") and not _is_valid_vec3_array(record.position):
			return false
		if record.has("rotation") and not _is_valid_vec3_array(record.rotation):
			return false
	return true


func _validate_enemy_records(data: Variant) -> bool:
	if not data is Array:
		return false
	var world: Node = get_tree().current_scene
	if (
		not world
		or not world.has_method("prepare_enemy_for_restore")
		or not world.has_method("commit_enemy_restore")
	):
		return false
	var config: Node = GameManager.get_core_system("config")
	var max_enemies: int = int(config.get_value("enemies.max_count", 30)) if config else 30
	if data.size() > max_enemies:
		return false
	var data_service: Node = GameManager.get_core_system("data")
	if not data_service or not data_service.has_method("get_enemy_data"):
		return false
	for record: Variant in data:
		if not record is Dictionary:
			return false
		var enemy_id: Variant = record.get("id", "")
		if not enemy_id is String or enemy_id.strip_edges().is_empty():
			return false
		if not _is_valid_vec3_array(record.get("position", null)):
			return false
		if not _is_valid_vec3_array(record.get("rotation", null)):
			return false
		var health: Variant = record.get("health", 100.0)
		if (
			(health is bool)
			or not (health is int or health is float)
			or not is_finite(float(health))
		):
			return false
		if float(health) < 0.0:
			return false
		if data_service.get_enemy_data(enemy_id).is_empty():
			return false
	return true


func _validate_item_records(data: Variant) -> bool:
	if not data is Array:
		return false
	for record: Variant in data:
		if not record is Dictionary:
			return false
		var scene_path: Variant = record.get("scene_path", "")
		if not scene_path is String or scene_path.is_empty():
			return false
		if not ResourceLoader.exists(scene_path, "PackedScene"):
			return false
		if not _is_valid_vec3_array(record.get("position", null)):
			return false
		if not _is_valid_vec3_array(record.get("rotation", null)):
			return false
		if record.has("name") and not record.name is String:
			return false
		if record.has("item_data") and not record.item_data is Dictionary:
			return false
		if record.has("owner_peer_id") and not record.owner_peer_id is int:
			return false
		if record.has("rarity_tier") and not record.rarity_tier is int:
			return false
	return true


func _validate_environment_records(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	for key: String in ["doors", "destructibles"]:
		if data.has(key) and not data[key] is Array:
			return false
		for record: Variant in data.get(key, []):
			if not record is Dictionary:
				return false
			var path: Variant = record.get("path", "")
			if not path is String or path.is_empty():
				return false
			var actor: Node = get_node_or_null(path)
			if not actor:
				return false
			if key == "doors":
				if not actor.has_method("restore_state"):
					return false
				if record.has("is_open") and not record.is_open is bool:
					return false
				if record.has("is_locked") and not record.is_locked is bool:
					return false
			else:
				if not actor.has_method("restore_state"):
					return false
				if record.has("is_broken") and not record.is_broken is bool:
					return false
	return true


func _is_valid_vec3_array(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for component: Variant in value:
		if component is bool or not (component is int or component is float):
			return false
		if not is_finite(float(component)):
			return false
	return true


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


func deserialize_world(data: Dictionary) -> bool:
	if not _validate_world_data(data):
		return false

	# Match state and players are non-destructive; enemy/item restoration is
	# staged before their existing nodes are removed.
	if data.has("match"):
		if not data.match is Dictionary:
			return false
		_deserialize_match(data["match"])

	if data.has("players"):
		_deserialize_players(data["players"])

	if data.has("enemies") and not await _deserialize_enemies(data["enemies"]):
		return false

	if data.has("items") and not await _deserialize_items(data["items"]):
		return false

	if data.has("environment") and not _deserialize_environment(data["environment"]):
		return false
	return true


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

				# The server restores lifecycle and health once, then replicates both.
				if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
					var hp: float = player_data.get("health", 100)
					var armor: float = player_data.get("armor", 0)
					if "state_manager" in node and node.state_manager:
						node.state_manager.restore_health(hp, armor)
					elif "health_component" in node and node.health_component:
						node.health_component.set_health(hp, armor)

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


func _deserialize_enemies(data: Array) -> bool:
	var world: Node = get_tree().current_scene
	if (
		not world
		or not world.has_method("prepare_enemy_for_restore")
		or not world.has_method("commit_enemy_restore")
	):
		return false

	# Instantiate every replacement off-tree first. A failed record therefore
	# cannot erase the currently active enemies.
	var staged: Array[Dictionary] = []
	for enemy_data: Dictionary in data:
		var enemy: Node = world.prepare_enemy_for_restore(
			_array_to_vec3(enemy_data.position), enemy_data.id, _array_to_vec3(enemy_data.rotation)
		)
		if not enemy:
			for entry: Dictionary in staged:
				entry.enemy.free()
			return false
		staged.append({"enemy": enemy, "health": float(enemy_data.get("health", 100.0))})

	for node in get_tree().get_nodes_in_group("enemies"):
		node.queue_free()
	await get_tree().process_frame

	for entry: Dictionary in staged:
		var enemy: Node = entry.enemy
		if not world.commit_enemy_restore(enemy):
			for rollback_entry: Dictionary in staged:
				var rollback_enemy: Node = rollback_entry.enemy
				if is_instance_valid(rollback_enemy):
					rollback_enemy.queue_free()
			return false
		if "health" in enemy:
			enemy.health = entry.health

	if multiplayer.is_server():
		await get_tree().process_frame
		var ps: Node = GameManager.get_core_system("performance")
		if ps and ps.has_method("optimize_ai_pathfinding"):
			ps.optimize_ai_pathfinding()
	return true


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
			if node is PickupBase:
				item_data["item_data"] = node.item_data.duplicate(true)
				item_data["owner_peer_id"] = node.owner_peer_id
				item_data["rarity_tier"] = node.rarity_tier
			# Only save if it has a scene file (instantiable)
			if not item_data["scene_path"].is_empty():
				items_data.append(item_data)

	return items_data


func _deserialize_items(data: Array) -> bool:
	var world: Node = get_tree().current_scene
	if not world:
		return false

	# Fully instantiate and configure replacements before deleting live items.
	var staged: Array[Node3D] = []
	var items_per_batch: int = 5
	for index: int in range(data.size()):
		var item_data: Dictionary = data[index]
		var scene: PackedScene = load(item_data.scene_path) as PackedScene
		if not scene:
			for staged_item: Node3D in staged:
				staged_item.free()
			return false
		var item: Node = scene.instantiate()
		if not item or not item is Node3D:
			if item:
				item.free()
			for staged_item: Node3D in staged:
				staged_item.free()
			return false

		var item_3d: Node3D = item as Node3D
		var world_transform := Transform3D(
			Basis.from_euler(_array_to_vec3(item_data.rotation)), _array_to_vec3(item_data.position)
		)
		item_3d.transform = (
			(world as Node3D).global_transform.affine_inverse() * world_transform
			if world is Node3D
			else world_transform
		)
		if "pickup_name" in item and item_data.has("name"):
			item.pickup_name = item_data.name
		if item is PickupBase:
			item.item_data = item_data.get("item_data", {}).duplicate(true)
			item.owner_peer_id = int(item_data.get("owner_peer_id", 0))
			item.rarity_tier = int(item_data.get("rarity_tier", -1))
		staged.append(item_3d)

		# Keep batching without exposing a partially restored world.
		if (index + 1) % items_per_batch == 0:
			await get_tree().process_frame

	for node in get_tree().get_nodes_in_group("items"):
		node.queue_free()
	await get_tree().process_frame

	for item: Node3D in staged:
		world.add_child(item, true)
		var loot := LootSvc.get_instance()
		if loot and item is PickupBase:
			loot._track_pickup(item, item.owner_peer_id, item.rarity_tier)
	return true


func _serialize_environment() -> Dictionary:
	var env_data: Dictionary = {"doors": [], "destructibles": []}

	for door in get_tree().get_nodes_in_group("doors"):
		env_data["doors"].append(
			{
				"path": door.get_path(),
				"is_open": door.is_open if "is_open" in door else false,
				"is_locked": door.is_locked if "is_locked" in door else false
			}
		)

	# DestructibleObject uses the singular group; keep compatibility with
	# scenes that use the plural group and avoid duplicate records.
	var destructibles: Array[Node] = []
	for group_name: String in ["destructible", "destructibles", "breakables"]:
		for destr: Node in get_tree().get_nodes_in_group(group_name):
			if destr not in destructibles:
				destructibles.append(destr)
	for destr: Node in destructibles:
		env_data["destructibles"].append(
			{
				"path": destr.get_path(),
				"is_broken": destr.is_broken if "is_broken" in destr else false
			}
		)
	return env_data


func _deserialize_environment(data: Dictionary) -> bool:
	for door_data: Dictionary in data.get("doors", []):
		var door: Node = get_node_or_null(door_data.path)
		if not door or not door.has_method("restore_state"):
			return false
		if not door.restore_state(
			bool(door_data.get("is_locked", false)), bool(door_data.get("is_open", false))
		):
			return false

	for destr_data: Dictionary in data.get("destructibles", []):
		var destr: Node = get_node_or_null(destr_data.path)
		if not destr or not destr.has_method("restore_state"):
			return false
		if not destr.restore_state(bool(destr_data.get("is_broken", false))):
			return false
	return true


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
