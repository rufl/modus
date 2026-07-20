extends Node

var entity_history: Dictionary = {}  # entity_id -> Array of HistoricalState
var history_duration: float = 1.0  # Keep 1 second of history
var max_history_size: int = 128  # Cap at 128 snapshots per entity
var enabled: bool = true
var hitscan_only: bool = true  # Only compensate hitscan, not projectiles


class HistoricalState:
	## Single historical state of an entity
	var timestamp_ms: float
	var position: Vector3
	var rotation: Vector3
	var hitbox_data: Dictionary  # Optional: custom hitbox positions

	func _init(
		p_time: float, p_pos: Vector3, p_rot: Vector3 = Vector3.ZERO, p_hitbox: Dictionary = {}
	) -> void:
		timestamp_ms = p_time
		position = p_pos
		rotation = p_rot
		hitbox_data = p_hitbox


func _ready() -> void:
	# Load config from NetworkManager
	# Load config from NetworkService.network_manager
	var net_config: Resource = null
	var ns: Node = GameManager.get_core_system("network")
	if ns and ns.network_manager:
		net_config = ns.network_manager.config

	if net_config:
		enabled = net_config.enable_lag_compensation
		history_duration = net_config.lag_comp_history_duration
		hitscan_only = net_config.lag_comp_hitscan_only
		max_history_size = net_config.max_snapshot_history

	# Only run on server
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		set_process(false)
		return

	# Connect to server tick
	if ns and ns.network_manager and ns.network_manager.has_signal("tick_completed"):
		if not ns.network_manager.tick_completed.is_connected(_on_server_tick):
			ns.network_manager.tick_completed.connect(_on_server_tick)

	var logger: Variant = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[LagComp] Lag compensation enabled (history: %.1fs)" % history_duration, "Core"
		)
	else:
		print("[LagComp] Lag compensation enabled (history: %.1fs)" % history_duration)


func _on_server_tick() -> void:
	## Capture entity states every server tick
	if not enabled:
		return

	# Capture all player states
	var gs: Node = GameManager.get_core_system("gameplay")
	var players: Array = gs.entity_registry.get_all_players() if gs and gs.entity_registry else []
	for player: Node in players:
		if player is Node3D:
			record_entity_state(player)

	# Cleanup old history
	_cleanup_old_history()


func record_entity_state(entity: Node3D) -> void:
	## Record current state of entity for lag compensation
	var entity_id: int = entity.get_instance_id()
	var timestamp: float = Time.get_ticks_msec()

	# Create historical state
	var state := HistoricalState.new(timestamp, entity.global_position, entity.rotation)

	# Add to history
	if not entity_history.has(entity_id):
		entity_history[entity_id] = []

	var history: Array = entity_history[entity_id]
	history.append(state)

	# Cap history size
	if history.size() > max_history_size:
		history.pop_front()


func rewind_entity_to_time(entity: Node3D, target_time_ms: float) -> Dictionary:
	## Rewind entity to specific timestamp, returns restore data
	## Returns empty dict if no history available

	var entity_id: int = entity.get_instance_id()
	if not entity_history.has(entity_id):
		return {}  # No history

	var history: Array = entity_history[entity_id]
	if history.is_empty():
		return {}

	# Find the two states to interpolate between
	var before_state: HistoricalState = null
	var after_state: HistoricalState = null

	for i in range(history.size() - 1):
		var current: HistoricalState = history[i]
		var next: HistoricalState = history[i + 1]

		if current.timestamp_ms <= target_time_ms and next.timestamp_ms >= target_time_ms:
			before_state = current
			after_state = next
			break

	# Fallback: use closest state if exact match not found
	if not before_state:
		# Find closest state
		var closest: HistoricalState = history[0]
		var min_diff: float = absf(target_time_ms - closest.timestamp_ms)

		for state: HistoricalState in history:
			var diff: float = absf(target_time_ms - state.timestamp_ms)
			if diff < min_diff:
				min_diff = diff
				closest = state

		before_state = closest
		after_state = closest

	# Calculate interpolation
	var rewound_pos: Vector3
	var rewound_rot: Vector3

	if before_state == after_state:
		# Exact match or no interpolation needed
		rewound_pos = before_state.position
		rewound_rot = before_state.rotation
	else:
		# Interpolate between states
		var time_delta: float = after_state.timestamp_ms - before_state.timestamp_ms
		var t: float = (target_time_ms - before_state.timestamp_ms) / time_delta
		t = clampf(t, 0.0, 1.0)

		rewound_pos = before_state.position.lerp(after_state.position, t)
		rewound_rot = before_state.rotation.lerp(after_state.rotation, t)

	# Store original state for restoration
	var restore_data: Dictionary = {
		"entity_id": entity_id,
		"original_position": entity.global_position,
		"original_rotation": entity.rotation,
		"rewound_position": rewound_pos,
		"rewound_rotation": rewound_rot
	}

	# Apply rewind
	entity.global_position = rewound_pos
	entity.rotation = rewound_rot

	return restore_data


func restore_entity(restore_data: Dictionary) -> void:
	## Restore entity to original state after lag compensation
	if restore_data.is_empty():
		return

	var entity_id: int = restore_data.entity_id
	var entity: Node3D = instance_from_id(entity_id)

	if not entity:
		return

	# Restore original state
	entity.global_position = restore_data.original_position
	entity.rotation = restore_data.original_rotation


var _active_restore_list: Array[Dictionary] = []


func start_compensation(shooter_peer_id: int) -> void:
	## Begin a lag compensation session (rewind world to shooter's view)
	## Use this for multi-ray weapons (shotguns) to avoid rewinding per ray
	if not enabled or not _active_restore_list.is_empty():
		return

	# Calculate shooter's latency
	var latency_ms: float = _get_peer_latency(shooter_peer_id)
	var target_time_ms: float = Time.get_ticks_msec() - latency_ms

	# Rewind all entities (except shooter)
	var gs: Node = GameManager.get_core_system("gameplay")
	var players: Array = gs.entity_registry.get_all_players() if gs and gs.entity_registry else []

	for player: Node in players:
		if player is Node3D and player.name.to_int() != shooter_peer_id:
			var restore_data: Dictionary = rewind_entity_to_time(player, target_time_ms)
			if not restore_data.is_empty():
				_active_restore_list.append(restore_data)


func end_compensation() -> void:
	## End lag compensation session and restore world
	if _active_restore_list.is_empty():
		return

	for restore_data: Dictionary in _active_restore_list:
		restore_entity(restore_data)

	_active_restore_list.clear()


func perform_lag_compensated_hitscan(
	shooter_peer_id: int, ray_origin: Vector3, ray_direction: Vector3, max_distance: float = 1000.0
) -> Dictionary:
	## Perform lag-compensated raycast for hitscan weapons
	## Returns hit result with victim entity

	if not enabled:
		# No lag compensation, do normal raycast
		return _perform_raycast(ray_origin, ray_direction, max_distance)

	# Calculate shooter's latency
	var latency_ms: float = _get_peer_latency(shooter_peer_id)
	var target_time_ms: float = Time.get_ticks_msec() - latency_ms
	var restore_list: Array[Dictionary] = []

	# Rewind all entities to shooter's view
	var gs: Node = GameManager.get_core_system("gameplay")
	var players: Array = gs.entity_registry.get_all_players() if gs and gs.entity_registry else []

	for player: Node in players:
		if player is Node3D and player.name.to_int() != shooter_peer_id:
			var restore_data: Dictionary = rewind_entity_to_time(player, target_time_ms)
			if not restore_data.is_empty():
				restore_list.append(restore_data)

	# Perform raycast in rewound state
	var hit_result: Dictionary = _perform_raycast(ray_origin, ray_direction, max_distance)

	# Restore all entities
	for restore_data: Dictionary in restore_list:
		restore_entity(restore_data)

	# Add lag comp info to result
	if not hit_result.is_empty():
		hit_result["lag_compensated"] = true
		hit_result["compensation_ms"] = latency_ms

	return hit_result


func _perform_raycast(origin: Vector3, direction: Vector3, max_distance: float) -> Dictionary:
	## Internal raycast helper
	var space_state: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction.normalized() * max_distance
	)

	# Exclude certain layers if needed
	query.collision_mask = 1  # Layer 1 (players/enemies)

	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return {}

	return {
		"position": result.position,
		"normal": result.normal,
		"collider": result.collider,
		"collider_id": result.collider.get_instance_id() if result.collider else 0,
		"lag_compensated": false
	}


func _get_peer_latency(peer_id: int) -> float:
	## Get peer's round-trip latency in milliseconds
	## Uses NetworkManager's peer tracking if available, otherwise falls back to default

	# Try to get RTT from ENet peer directly
	if (
		multiplayer
		and multiplayer.has_multiplayer_peer()
		and multiplayer.multiplayer_peer is ENetMultiplayerPeer
	):
		# Skip RTT lookup for the local/server peer (latency to self is 0)
		if peer_id == multiplayer.get_unique_id():
			return 0.0
		var enet_peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer
		# Use get_peer() directly with safety check
		if enet_peer.has_method("get_peer"):
			var packet_peer: ENetPacketPeer = enet_peer.get_peer(peer_id)
			if packet_peer:
				var rtt: float = packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
				return clampf(rtt, 5.0, 500.0)

	# Fallback: use configured default or 50ms
	var ns: Node = GameManager.get_core_system("network")
	if ns and ns.network_manager and ns.network_manager.config:
		var val: Variant = ns.network_manager.config.get("default_latency_ms")
		if val != null:
			return float(val)
	return 50.0  # Default fallback


func _cleanup_old_history() -> void:
	## Remove historical states older than history_duration
	var cutoff_time: float = Time.get_ticks_msec() - (history_duration * 1000.0)

	for entity_id: int in entity_history.keys():
		var history: Array = entity_history[entity_id]

		# Remove old states
		var new_history: Array = []
		for state: HistoricalState in history:
			if state.timestamp_ms > cutoff_time:
				new_history.append(state)

		entity_history[entity_id] = new_history

		# Remove empty histories
		if new_history.is_empty():
			entity_history.erase(entity_id)


func get_diagnostics() -> Dictionary:
	## Return diagnostic information
	var total_states: int = 0
	for history: Array in entity_history.values():
		total_states += history.size()

	return {
		"enabled": enabled,
		"tracked_entities": entity_history.size(),
		"total_states": total_states,
		"history_duration_ms": history_duration * 1000.0,
		"hitscan_only": hitscan_only
	}
