extends ModusGutTestBase

const SHOOTER_ID: int = 70001


class RewindClock:
	extends "res://game/core/network/lag_compensation_system.gd"

	var now_ms: float = 10000.0

	func _get_time_ms() -> float:
		return now_ms

	func _get_peer_latency(peer_id: int) -> float:
		# A deterministic server latency sample; physics queries remain real.
		return 100.0 if peer_id == 70001 else super._get_peer_latency(peer_id)


var _viewport: SubViewport
var _world: Node3D
var _api: SceneMultiplayer
var _lag: RewindClock
var _registry: Node
var _registered_enemies: Array[Node] = []
var _registered_shooter: bool = false
var _client: ENetMultiplayerPeer


func before_each() -> void:
	await modus_setup()
	_registry = GameManager.get_core_system("entities")  # Borrow; never free the service.
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	_api = SceneMultiplayer.new()
	get_tree().set_multiplayer(_api, _world.get_path())
	_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	_lag = RewindClock.new()
	_world.add_child(_lag)
	_lag.history_duration = 1.0
	_lag.max_history_size = 128
	_lag.enabled = true


func after_each() -> void:
	_lag.end_compensation()
	if _registered_shooter:
		_registry.unregister_player(SHOOTER_ID)
		_registered_shooter = false
	for enemy: Node in _registered_enemies:
		if is_instance_valid(enemy):
			_registry.unregister_enemy(enemy)
	_registered_enemies.clear()
	var path: NodePath = _world.get_path()
	_viewport.free()
	get_tree().set_multiplayer(null, path)
	_api.multiplayer_peer = null
	if _client:
		_client.close()
		_client = null
	modus_teardown()


func _body(position: Vector3, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	_world.add_child(body)
	body.global_position = position
	body.force_update_transform()
	return body


func _enemy(position: Vector3) -> StaticBody3D:
	var enemy := _body(position, CollisionLayers.LAYER_ENEMIES)
	_registry.register_enemy(enemy)
	_registered_enemies.append(enemy)
	return enemy


func _shooter() -> StaticBody3D:
	var shooter := _body(Vector3(0, 0, -2), CollisionLayers.LAYER_PLAYERS)
	shooter.name = "NonNumericShooter"
	shooter.set_multiplayer_authority(SHOOTER_ID)
	_registry.register_player(SHOOTER_ID, shooter)
	_registered_shooter = true
	return shooter


func test_interpolates_shortest_angle_and_restores_exact_parented_transform() -> void:
	var parent := Node3D.new()
	_world.add_child(parent)
	parent.transform = Transform3D(Basis(Vector3.UP, 0.3), Vector3(4, 2, 1))
	var entity := Node3D.new()
	parent.add_child(entity)
	entity.global_position = Vector3(0, 0, -5)
	entity.global_rotation = Vector3(0, deg_to_rad(170.0), 0)
	_lag.now_ms = 9800.0
	_lag.record_entity_state(entity)
	entity.global_position = Vector3(4, 0, -5)
	entity.global_rotation = Vector3(0, deg_to_rad(-170.0), 0)
	_lag.now_ms = 10000.0
	_lag.record_entity_state(entity)
	entity.transform = Transform3D(
		Basis(Vector3.RIGHT, 0.4).scaled(Vector3(2, 3, 4)), Vector3(7, 8, 9)
	)
	var original: Transform3D = entity.global_transform
	var restore: Dictionary = _lag.rewind_entity_to_time(entity, 9900.0)
	assert_false(restore.is_empty())
	assert_true(entity.global_position.is_equal_approx(Vector3(2, 0, -5)))
	assert_almost_eq(
		absf(entity.global_rotation.y), PI, 0.001, "Crossing +/- PI must not turn through zero"
	)
	_lag.restore_entity(restore)
	assert_eq(
		entity.global_transform,
		original,
		"Restoration preserves scale, parent space and exact basis"
	)


func test_rejects_nonfinite_future_expired_and_unbracketed_times() -> void:
	var entity := _enemy(Vector3(0, 0, -5))
	_lag.now_ms = 9000.0
	_lag.record_entity_state(entity)
	_lag.now_ms = 10000.0
	entity.position.x = 4.0
	_lag.record_entity_state(entity)
	var current: Transform3D = entity.global_transform
	var boundary: Dictionary = _lag.rewind_entity_to_time(entity, 9000.0)
	assert_eq(entity.global_position.x, 0.0, "The exact window boundary is usable")
	_lag.restore_entity(boundary)
	for timestamp: float in [8999.0, 10001.0, NAN, INF, -INF]:
		assert_true(_lag.rewind_entity_to_time(entity, timestamp).is_empty())
		assert_eq(entity.global_transform, current)
	_lag.entity_history.clear()
	_lag.now_ms = 9500.0
	_lag.record_entity_state(entity)
	_lag.now_ms = 9900.0
	_lag.record_entity_state(entity)
	_lag.now_ms = 10000.0
	assert_true(
		_lag.rewind_entity_to_time(entity, 9400.0).is_empty(), "Do not clamp to oldest history"
	)
	assert_true(
		_lag.rewind_entity_to_time(entity, 9950.0).is_empty(),
		"Do not extrapolate beyond newest history"
	)


func test_sample_cap_and_age_pruning_remove_unusable_rewinds() -> void:
	var entity := _enemy(Vector3.ZERO)
	_lag.max_history_size = 2
	for timestamp: float in [9700.0, 9800.0, 9900.0]:
		_lag.now_ms = timestamp
		entity.position.x += 1.0
		_lag.record_entity_state(entity)
	assert_true(
		_lag.rewind_entity_to_time(entity, 9700.0).is_empty(), "Sample cap evicts the oldest sample"
	)
	var restore: Dictionary = _lag.rewind_entity_to_time(entity, 9850.0)
	assert_almost_eq(entity.position.x, 2.5, 0.001)
	_lag.restore_entity(restore)
	_lag.now_ms = 11000.0
	_lag._cleanup_old_history()
	assert_true(
		_lag.rewind_entity_to_time(entity, 9900.0).is_empty(), "Aged snapshots cannot be revived"
	)
	assert_eq(_lag.get_diagnostics().total_states, 0)


func test_authority_and_transport_changes_cannot_reuse_history() -> void:
	var entity := _enemy(Vector3.ZERO)
	_lag.now_ms = 9900.0
	_lag.record_entity_state(entity)
	_lag.now_ms = 10000.0
	entity.position.x = 4.0
	_lag.record_entity_state(entity)
	assert_true(_lag.start_compensation(SHOOTER_ID))
	assert_eq(entity.position.x, 0.0)
	_client = ENetMultiplayerPeer.new()
	assert_eq(_client.create_client("127.0.0.1", 9), OK)
	_api.multiplayer_peer = _client
	assert_true(
		_lag.rewind_entity_to_time(entity, 10000.0).is_empty(), "A live client cannot rewind"
	)
	assert_eq(
		entity.position.x, 4.0, "Authority loss restores an open rewind before discarding history"
	)
	_lag.record_entity_state(entity)
	assert_eq(_lag.get_diagnostics().total_states, 0, "Clients cannot capture server history")
	_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	assert_true(
		_lag.rewind_entity_to_time(entity, 10000.0).is_empty(), "New server sessions start empty"
	)
	_lag.record_entity_state(entity)
	entity.position.x = 8.0
	var restore: Dictionary = _lag.rewind_entity_to_time(entity, 10000.0)
	assert_eq(entity.position.x, 4.0, "Capture resumes after becoming authoritative")
	_lag.restore_entity(restore)
	_api.peer_disconnected.emit(SHOOTER_ID)
	assert_true(
		_lag.rewind_entity_to_time(entity, 10000.0).is_empty(),
		"A reused peer cannot inherit old snapshots"
	)


func test_local_unknown_and_disabled_requests_do_not_rewind() -> void:
	var entity := _enemy(Vector3.ZERO)
	_lag.record_entity_state(entity)
	entity.position.x = 8.0
	assert_eq(_lag._get_peer_latency(1), 0.0)
	assert_eq(_lag._get_peer_latency(999999), 0.0)
	assert_false(_lag.start_compensation(1))
	assert_false(_lag.start_compensation(999999))
	_lag.enabled = false
	assert_false(_lag.start_compensation(SHOOTER_ID))
	assert_eq(entity.position.x, 8.0)


func test_empty_rewind_session_still_has_exclusive_ownership() -> void:
	assert_true(_lag.start_compensation(SHOOTER_ID))
	assert_false(
		_lag.start_compensation(SHOOTER_ID), "Empty restore sets still belong to their caller"
	)
	assert_true(
		_lag.perform_lag_compensated_hitscan(SHOOTER_ID, Vector3.ZERO, Vector3.FORWARD).is_empty()
	)
	assert_false(
		_lag.start_compensation(SHOOTER_ID),
		"A nested convenience query must not close its caller's session"
	)
	_lag.end_compensation()
	assert_true(_lag.start_compensation(SHOOTER_ID))
	_lag.end_compensation()


func test_server_tick_rewinds_enemy_collision_for_real_ray_and_restores_on_hit_and_miss() -> void:
	_shooter()
	var enemy := _enemy(Vector3(0, 0, -5))
	# Let the private physics world register its shapes before querying it.
	await get_tree().physics_frame
	_lag.now_ms = 9800.0
	_lag._on_server_tick()
	_lag.now_ms = 9950.0
	_lag._on_server_tick()
	_lag.now_ms = 10000.0
	enemy.position.x = 5.0
	enemy.force_update_transform()
	var current: Transform3D = enemy.global_transform
	assert_true(_lag._perform_raycast(Vector3.ZERO, Vector3.FORWARD, 20.0, SHOOTER_ID).is_empty())
	var hit: Dictionary = _lag.perform_lag_compensated_hitscan(
		SHOOTER_ID, Vector3.ZERO, Vector3.FORWARD, 20.0
	)
	assert_eq(
		hit.get("collider"),
		enemy,
		"Ray sees rewound enemy layer and excludes the registered shooter"
	)
	assert_eq(hit.get("rid"), enemy.get_rid(), "Returned RID remains valid after proxy removal")
	assert_true(hit.get("lag_compensated", false))
	assert_eq(enemy.global_transform, current)
	assert_true(
		_lag._perform_raycast(Vector3.ZERO, Vector3.FORWARD, 20.0, SHOOTER_ID).is_empty(),
		"Physics restoration is immediate, not just the visible transform"
	)
	var miss: Dictionary = _lag.perform_lag_compensated_hitscan(
		SHOOTER_ID, Vector3(10, 0, 0), Vector3.FORWARD, 20.0
	)
	assert_true(miss.is_empty())
	assert_eq(enemy.global_transform, current, "Misses also restore the world")
