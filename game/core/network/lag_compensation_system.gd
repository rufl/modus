extends Node

var entity_history: Dictionary = {}  # entity_id -> Array of HistoricalState
var history_duration: float = 1.0
var max_history_size: int = 128
var enabled: bool = true
var hitscan_only: bool = true

var _active_restore_list: Array[Dictionary] = []
var _compensation_active: bool = false
var _network_manager: Node
var _registry: Node
var _session_api: MultiplayerAPI
var _session_peer: MultiplayerPeer
var _session_status: int = -1
var _session_authority: bool = false


class HistoricalState:
	var timestamp_ms: float
	var position: Vector3
	var rotation: Vector3  # Global Euler angles, interpolated along the shortest arc.
	var hitbox_data: Dictionary

	func _init(
		p_time: float, p_pos: Vector3, p_rot: Vector3 = Vector3.ZERO, p_hitbox: Dictionary = {}
	) -> void:
		timestamp_ms = p_time
		position = p_pos
		rotation = p_rot
		hitbox_data = p_hitbox


func _ready() -> void:
	_bind_sources()
	_sync_session()


func _process(_delta: float) -> void:
	# Services and transports can appear after this node, or change between matches.
	_bind_sources()
	_sync_session()


func _exit_tree() -> void:
	_reset_history()
	_disconnect_sources()
	_disconnect_multiplayer()


func _bind_sources() -> void:
	var ns: Node = GameManager.get_core_system("network")
	var manager: Node = ns.network_manager if ns else null
	if manager != _network_manager:
		if is_instance_valid(_network_manager):
			_network_manager.tick_completed.disconnect(_on_server_tick)
			_network_manager.connection_established.disconnect(_on_connection_established)
			_network_manager.connection_lost.disconnect(_reset_history)
		_network_manager = manager
		_reset_history()
		if _network_manager:
			_network_manager.tick_completed.connect(_on_server_tick)
			_network_manager.connection_established.connect(_on_connection_established)
			_network_manager.connection_lost.connect(_reset_history)
			var config: Resource = _network_manager.config
			if config:
				enabled = config.enable_lag_compensation
				history_duration = config.lag_comp_history_duration
				hitscan_only = config.lag_comp_hitscan_only
				max_history_size = config.max_snapshot_history
	var registry: Node = GameManager.get_core_system("entities")
	if registry != _registry:
		_disconnect_registry()
		_registry = registry
		_reset_history()
		if _registry:
			_registry.player_unregistered.connect(_on_player_unregistered)
			_registry.enemy_unregistered.connect(_on_enemy_unregistered)


func _disconnect_sources() -> void:
	if is_instance_valid(_network_manager):
		_network_manager.tick_completed.disconnect(_on_server_tick)
		_network_manager.connection_established.disconnect(_on_connection_established)
		_network_manager.connection_lost.disconnect(_reset_history)
	_network_manager = null
	_disconnect_registry()


func _disconnect_registry() -> void:
	if is_instance_valid(_registry):
		_registry.player_unregistered.disconnect(_on_player_unregistered)
		_registry.enemy_unregistered.disconnect(_on_enemy_unregistered)
	_registry = null


func _disconnect_multiplayer() -> void:
	if _session_api:
		_session_api.peer_disconnected.disconnect(_on_peer_disconnected)
		_session_api.server_disconnected.disconnect(_reset_history)
	_session_api = null


func _sync_session() -> bool:
	if not is_inside_tree():
		return false
	var api: MultiplayerAPI = multiplayer
	if api != _session_api:
		_disconnect_multiplayer()
		_reset_history()
		_session_api = api
		api.peer_disconnected.connect(_on_peer_disconnected)
		api.server_disconnected.connect(_reset_history)
	var peer: MultiplayerPeer = api.multiplayer_peer
	var status: int = (
		peer.get_connection_status() if peer else MultiplayerPeer.CONNECTION_DISCONNECTED
	)
	var authority: bool = (
		peer != null and status == MultiplayerPeer.CONNECTION_CONNECTED and api.is_server()
	)
	if peer != _session_peer or status != _session_status or authority != _session_authority:
		_reset_history()
		_session_peer = peer
		_session_status = status
		_session_authority = authority
	if not authority or not enabled or not is_finite(history_duration) or history_duration <= 0.0:
		_reset_history()
		return false
	return true


func _reset_history() -> void:
	end_compensation()
	entity_history.clear()


func _on_connection_established(_is_host: bool) -> void:
	# Also catches transports reused in-place during host/join transitions.
	_reset_history()


func _on_peer_disconnected(_peer_id: int) -> void:
	# A reused peer ID must never inherit snapshots from a previous connection.
	_reset_history()


func _on_player_unregistered(_peer_id: int) -> void:
	# The registry has already removed its ID mapping when this signal arrives.
	_reset_history()


func _on_enemy_unregistered(enemy: Node) -> void:
	end_compensation()
	if is_instance_valid(enemy):
		entity_history.erase(enemy.get_instance_id())


func _on_server_tick() -> void:
	if not _sync_session() or _compensation_active or not is_instance_valid(_registry):
		return
	for player: Node in _registry.get_all_players():
		if (
			is_instance_valid(player)
			and player is Node3D
			and player.is_inside_tree()
			and player.multiplayer == multiplayer
		):
			record_entity_state(player)
	for enemy: Node in _registry.get_all_enemies():
		if (
			is_instance_valid(enemy)
			and enemy is Node3D
			and enemy.is_inside_tree()
			and enemy.multiplayer == multiplayer
		):
			record_entity_state(enemy)
	_cleanup_old_history()


func _get_time_ms() -> float:
	return Time.get_ticks_msec()


func record_entity_state(entity: Node3D) -> void:
	if not _sync_session() or _compensation_active or not is_instance_valid(entity):
		return
	if (
		not entity.is_inside_tree()
		or entity.multiplayer != multiplayer
		or not entity.global_transform.is_finite()
	):
		return
	var entity_id: int = entity.get_instance_id()
	var timestamp: float = _get_time_ms()
	var state := HistoricalState.new(timestamp, entity.global_position, entity.global_rotation)
	if not entity_history.has(entity_id):
		entity_history[entity_id] = []
	var history: Array = entity_history[entity_id]
	if not history.is_empty():
		var last: HistoricalState = history.back()
		if last.timestamp_ms > timestamp:
			history.clear()
		elif last.timestamp_ms == timestamp:
			history[history.size() - 1] = state
			return
	history.append(state)
	_trim_history(history, timestamp - history_duration * 1000.0)


func rewind_entity_to_time(entity: Node3D, target_time_ms: float) -> Dictionary:
	if not _sync_session() or not is_instance_valid(entity) or not is_finite(target_time_ms):
		return {}
	if not entity.is_inside_tree() or entity.multiplayer != multiplayer:
		return {}
	var now: float = _get_time_ms()
	if target_time_ms < now - history_duration * 1000.0 or target_time_ms > now:
		return {}
	var entity_id: int = entity.get_instance_id()
	var history: Array = entity_history.get(entity_id, [])
	if history.is_empty():
		return {}
	var first: HistoricalState = history.front()
	var last: HistoricalState = history.back()
	if target_time_ms < first.timestamp_ms or target_time_ms > last.timestamp_ms:
		return {}
	var before: HistoricalState = null
	var after: HistoricalState = null
	for state: HistoricalState in history:
		if (
			not is_finite(state.timestamp_ms)
			or not state.position.is_finite()
			or not state.rotation.is_finite()
		):
			return {}
		if state.timestamp_ms <= target_time_ms:
			before = state
		if state.timestamp_ms >= target_time_ms:
			after = state
			break
	if before == null or after == null:
		return {}
	var t: float = 0.0
	if before != after:
		var interval: float = after.timestamp_ms - before.timestamp_ms
		if interval <= 0.0:
			return {}
		t = (target_time_ms - before.timestamp_ms) / interval
	var rewound_pos: Vector3 = before.position.lerp(after.position, t)
	var rewound_rot := Vector3(
		lerp_angle(before.rotation.x, after.rotation.x, t),
		lerp_angle(before.rotation.y, after.rotation.y, t),
		lerp_angle(before.rotation.z, after.rotation.z, t)
	)
	var restore_data: Dictionary = {
		"entity_id": entity_id,
		"original_local_transform": entity.transform,
	}
	entity.global_position = rewound_pos
	entity.global_rotation = rewound_rot
	var proxies: Array[Dictionary] = []
	_create_query_proxies(entity, proxies)
	restore_data["query_proxies"] = proxies
	return restore_data


func restore_entity(restore_data: Dictionary) -> void:
	if restore_data.is_empty():
		return
	_release_query_proxies(restore_data.query_proxies)
	var entity: Node3D = instance_from_id(restore_data.entity_id) as Node3D
	if not is_instance_valid(entity) or not entity.is_inside_tree():
		return
	entity.transform = restore_data.original_local_transform
	_flush_collision_transforms(entity)


func _create_query_proxies(node: Node, proxies: Array[Dictionary]) -> void:
	# Kinematic transforms are deferred by Jolt until the next physics step.
	# Static query bodies share the actual shapes and object identity without
	# changing the live body's mode, velocity or pending kinematic transform.
	if node is PhysicsBody3D:
		var body: RID = node.get_rid()
		var shape_count: int = PhysicsServer3D.body_get_shape_count(body)
		if shape_count > 0:
			var proxy: RID = PhysicsServer3D.body_create()
			var layer: int = PhysicsServer3D.body_get_collision_layer(body)
			PhysicsServer3D.body_set_mode(proxy, PhysicsServer3D.BODY_MODE_STATIC)
			PhysicsServer3D.body_attach_object_instance_id(proxy, node.get_instance_id())
			PhysicsServer3D.body_set_collision_layer(proxy, layer)
			PhysicsServer3D.body_set_collision_mask(proxy, 0)
			for index: int in shape_count:
				PhysicsServer3D.body_add_shape(
					proxy,
					PhysicsServer3D.body_get_shape(body, index),
					PhysicsServer3D.body_get_shape_transform(body, index),
					node.is_shape_owner_disabled(node.shape_find_owner(index))
				)
			PhysicsServer3D.body_set_state(
				proxy, PhysicsServer3D.BODY_STATE_TRANSFORM, node.global_transform
			)
			PhysicsServer3D.body_set_space(proxy, node.get_world_3d().space)
			PhysicsServer3D.body_set_collision_layer(body, 0)
			proxies.append(
				{"proxy": proxy, "body": body, "owner_id": node.get_instance_id(), "layer": layer}
			)
	for index: int in node.get_child_count():
		_create_query_proxies(node.get_child(index), proxies)


func _release_query_proxies(proxies: Array[Dictionary]) -> void:
	for state: Dictionary in proxies:
		PhysicsServer3D.free_rid(state.proxy)
		var owner_node: PhysicsBody3D = instance_from_id(state.owner_id) as PhysicsBody3D
		if is_instance_valid(owner_node) and owner_node.get_rid() == state.body:
			PhysicsServer3D.body_set_collision_layer(state.body, state.layer)


func _flush_collision_transforms(node: Node) -> void:
	# Flush the restored scene pose; rewind queries use separate static bodies.
	if node is Node3D:
		node.force_update_transform()
	for index: int in node.get_child_count():
		_flush_collision_transforms(node.get_child(index))


func start_compensation(shooter_peer_id: int) -> bool:
	if not _sync_session() or _compensation_active:
		return false
	var latency_ms: float = _get_peer_latency(shooter_peer_id)
	if not is_finite(latency_ms) or latency_ms <= 0.0:
		return false
	latency_ms = minf(latency_ms, history_duration * 1000.0)
	var target_time_ms: float = _get_time_ms() - latency_ms
	# Ownership is independent of how many entities have usable history.
	_compensation_active = true
	var shooter: Node = (
		_registry.get_player(shooter_peer_id) if is_instance_valid(_registry) else null
	)
	for entity_id: int in entity_history:
		var entity: Node3D = instance_from_id(entity_id) as Node3D
		if not is_instance_valid(entity) or entity == shooter:
			continue
		var restore_data: Dictionary = rewind_entity_to_time(entity, target_time_ms)
		if not restore_data.is_empty():
			_active_restore_list.append(restore_data)
	return true


func end_compensation() -> void:
	for restore_data: Dictionary in _active_restore_list:
		restore_entity(restore_data)
	_active_restore_list.clear()
	_compensation_active = false


func perform_lag_compensated_hitscan(
	shooter_peer_id: int, ray_origin: Vector3, ray_direction: Vector3, max_distance: float = 1000.0
) -> Dictionary:
	# Disabled compensation still permits an ordinary authoritative query.
	_sync_session()
	if not is_inside_tree() or not _session_authority or _compensation_active:
		return {}
	var owns_session: bool = start_compensation(shooter_peer_id)
	var compensated: bool = owns_session and not _active_restore_list.is_empty()
	var result: Dictionary = _perform_raycast(
		ray_origin, ray_direction, max_distance, shooter_peer_id
	)
	if owns_session:
		end_compensation()
	if not result.is_empty():
		result["lag_compensated"] = compensated
		result["compensation_ms"] = _get_peer_latency(shooter_peer_id) if compensated else 0.0
	return result


func _perform_raycast(
	origin: Vector3, direction: Vector3, max_distance: float, shooter_peer_id: int = 0
) -> Dictionary:
	if not origin.is_finite() or not direction.is_finite() or direction.is_zero_approx():
		return {}
	if not is_finite(max_distance) or max_distance <= 0.0:
		return {}
	var shooter: Node = (
		_registry.get_player(shooter_peer_id) if is_instance_valid(_registry) else null
	)
	var excluded: Array[RID] = []
	if is_instance_valid(shooter):
		_collect_collision_rids(shooter, excluded)
	var world: World3D = (
		shooter.get_world_3d() if shooter is Node3D else get_viewport().get_world_3d()
	)
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction.normalized() * max_distance,
		CollisionLayers.MASK_HITSCAN,
		excluded
	)
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if not result.is_empty():
		result["collider_id"] = result.collider.get_instance_id() if result.collider else 0
		if result.collider is PhysicsBody3D:
			result["rid"] = result.collider.get_rid()
		result["lag_compensated"] = false
	return result


func _collect_collision_rids(node: Node, rids: Array[RID]) -> void:
	if node is CollisionObject3D:
		rids.append(node.get_rid())
	for index: int in node.get_child_count():
		_collect_collision_rids(node.get_child(index), rids)


func _get_peer_latency(peer_id: int) -> float:
	# No guessed latency: unsupported transports and unknown peers remain current.
	if not is_inside_tree() or not multiplayer.has_multiplayer_peer():
		return 0.0
	if (
		peer_id == multiplayer.get_unique_id()
		or multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	):
		return 0.0
	if not multiplayer.is_server() or not peer_id in multiplayer.get_peers():
		return 0.0
	var peer: ENetMultiplayerPeer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if not peer:
		return 0.0
	var packet_peer: ENetPacketPeer = peer.get_peer(peer_id)
	if not packet_peer:
		return 0.0
	var rtt: float = packet_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
	if not is_finite(rtt) or rtt < 0.0 or not is_finite(history_duration):
		return 0.0
	return clampf(rtt * 0.5, 0.0, maxf(history_duration * 1000.0, 0.0))


func _trim_history(history: Array, cutoff_time: float) -> void:
	while (
		not history.is_empty()
		and (history.size() > maxi(max_history_size, 1) or history[0].timestamp_ms < cutoff_time)
	):
		history.pop_front()


func _cleanup_old_history() -> void:
	var cutoff_time: float = _get_time_ms() - history_duration * 1000.0
	# Only keys are copied for safe erasure; retained state arrays stay in place.
	for entity_id: int in entity_history.keys():
		var entity: Node3D = instance_from_id(entity_id) as Node3D
		var history: Array = entity_history[entity_id]
		_trim_history(history, cutoff_time)
		if not is_instance_valid(entity) or not entity.is_inside_tree() or history.is_empty():
			entity_history.erase(entity_id)


func get_diagnostics() -> Dictionary:
	var total_states: int = 0
	for history: Array in entity_history.values():
		total_states += history.size()
	return {
		"enabled": enabled,
		"authoritative": _session_authority,
		"compensation_active": _compensation_active,
		"tracked_entities": entity_history.size(),
		"total_states": total_states,
		"history_duration_ms": history_duration * 1000.0,
		"hitscan_only": hitscan_only,
	}
