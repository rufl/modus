extends ModusGutTestBase

const LagCompScript = preload("res://game/core/network/lag_compensation_system.gd")
const ORIGIN := Vector3(4000.0, 4000.0, 4000.0)
const HISTORICAL_POSITION := ORIGIN + Vector3(10.0, 0.0, 0.0)
const CURRENT_POSITION := HISTORICAL_POSITION + Vector3(0.0, 0.0, 5.0)


class MeasuredLatencyRewind:
	extends "res://game/core/network/lag_compensation_system.gd"

	# Only the server's latency measurement is controlled; all history, session,
	# transform restoration and physics queries use the production implementation.
	func _get_peer_latency(_peer_id: int) -> float:
		return 100.0

	func _get_time_ms() -> float:
		return 1000.0


class Victim:
	extends CharacterBody3D
	var damage_received: float = 0.0

	func take_damage(info: DamageInfo) -> void:
		damage_received += info.base_amount


var feature: CombatFeature
var rewind: Node
var original_rewind: Node
var combat: Node
var registry: Node
var shooter: CharacterBody3D
var victim: Victim
var fixture: Node3D
var shooter_id: int
var weapon: WeaponData


func before_each() -> void:
	await modus_setup()
	var gameplay: GameplaySvc = GameplaySvc.get_service()
	combat = gameplay.combat
	registry = GameManager.get_core_system("entities")
	original_rewind = combat.lag_compensation
	fixture = Node3D.new()
	add_child(fixture)
	rewind = MeasuredLatencyRewind.new()
	fixture.add_child(rewind)
	rewind.enabled = true
	rewind.history_duration = 1.0
	combat.lag_compensation = rewind

	shooter_id = 71001
	while registry.get_player(shooter_id) != null:
		shooter_id += 1
	shooter = CharacterBody3D.new()
	shooter.set_multiplayer_authority(shooter_id)
	fixture.add_child(shooter)
	shooter.global_position = ORIGIN
	_add_shape(shooter, CollisionLayers.LAYER_PLAYERS)
	registry.register_player(shooter_id, shooter)

	victim = Victim.new()
	fixture.add_child(victim)
	victim.global_position = CURRENT_POSITION
	_add_shape(victim, CollisionLayers.LAYER_ENEMIES)
	registry.register_enemy(victim)

	feature = CombatFeature.new()
	feature.config = {
		"hit_validation": {"enabled": true},
		"lag_compensation": {"enabled": true},
		"knockback": {"enabled": false}
	}
	fixture.add_child(feature)
	feature.initialize()
	weapon = WeaponData.new()
	weapon.damage = 10
	weapon.pellet_count = 3
	weapon.spread_angle = 0.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_seed_history()


func after_each() -> void:
	if is_instance_valid(rewind):
		rewind.end_compensation()
	if is_instance_valid(combat):
		combat.lag_compensation = original_rewind
	if is_instance_valid(feature):
		feature.shutdown()
	if is_instance_valid(registry):
		registry.unregister_player(shooter_id)
		if is_instance_valid(victim):
			registry.unregister_enemy(victim)
	if is_instance_valid(original_rewind):
		if is_instance_valid(shooter):
			original_rewind.entity_history.erase(shooter.get_instance_id())
		if is_instance_valid(victim):
			original_rewind.entity_history.erase(victim.get_instance_id())
	if is_instance_valid(fixture):
		fixture.free()


func test_feature_hits_historical_victim_and_restores_live_transform() -> void:
	var before: Transform3D = victim.global_transform
	feature.apply_damage(victim, _damage(HISTORICAL_POSITION))
	assert_eq(victim.damage_received, 10.0, "Canonical rewind must reach the historical victim")
	assert_eq(victim.global_transform, before, "Damage must not leave the victim rewound")
	feature.lag_compensation_enabled = false
	feature.apply_damage(victim, _damage(HISTORICAL_POSITION))
	assert_eq(victim.damage_received, 10.0, "A completed rewind leaves no historical query body")
	feature.apply_damage(victim, _damage(CURRENT_POSITION))
	assert_eq(victim.damage_received, 20.0, "Current collision geometry and layers are restored")


func test_feature_lag_disabled_uses_current_geometry() -> void:
	feature.lag_compensation_enabled = false
	feature.apply_damage(victim, _damage(HISTORICAL_POSITION))
	assert_eq(victim.damage_received, 0.0, "Disabled rewind must not hit historical geometry")
	feature.apply_damage(victim, _damage(CURRENT_POSITION))
	assert_eq(victim.damage_received, 10.0, "Ordinary validation must still hit live geometry")


func test_global_lag_disabled_falls_back_without_rewinding() -> void:
	rewind.enabled = false
	feature.apply_damage(victim, _damage(CURRENT_POSITION))
	assert_eq(victim.damage_received, 10.0)
	assert_eq(victim.global_position, CURRENT_POSITION)


func test_projectile_bullet_and_melee_use_live_geometry() -> void:
	var projectile := WeaponData.new()
	projectile.projectile_scene = PackedScene.new()
	var info: DamageInfo = _damage(CURRENT_POSITION)
	info.weapon_source = projectile
	feature.apply_damage(victim, info)
	assert_eq(victim.damage_received, 10.0, "BULLET projectiles must not rewind their victim")
	info.weapon_source = weapon
	info.damage_type = DamageInfo.DamageType.MELEE
	feature.apply_damage(victim, info)
	assert_eq(victim.damage_received, 20.0, "Melee must keep ordinary validation")


func test_nonplayer_hitscan_does_not_borrow_player_rewind() -> void:
	registry.unregister_player(shooter_id)
	shooter.set_multiplayer_authority(1)
	feature.apply_damage(victim, _damage(CURRENT_POSITION))
	assert_eq(victim.damage_received, 10.0, "Server-owned nonplayers validate live geometry")
	assert_eq(victim.global_position, CURRENT_POSITION)


func test_compensated_wall_hit_cannot_damage_intended_victim() -> void:
	var wall := StaticBody3D.new()
	fixture.add_child(wall)
	wall.global_position = ORIGIN + Vector3(5.0, 0.0, 0.0)
	_add_shape(wall, CollisionLayers.LAYER_WORLD)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_seed_history()
	feature.apply_damage(victim, _damage(HISTORICAL_POSITION))
	assert_eq(victim.damage_received, 0.0, "A wall intersection is not a hit on the victim")
	assert_eq(victim.global_position, CURRENT_POSITION)


func test_claimed_endpoint_range_is_checked_before_nearby_collision() -> void:
	feature.apply_damage(victim, _damage(ORIGIN + Vector3(2000.0, 0.0, 0.0)))
	assert_eq(
		victim.damage_received, 0.0, "A nearby victim cannot legitimize an out-of-range endpoint"
	)


func test_multi_ray_fire_restores_owned_session_after_all_pellets() -> void:
	var manager: WeaponManager = _weapon_manager()
	manager._fire_hitscan_server(weapon, ORIGIN, Vector3.RIGHT)
	assert_eq(victim.damage_received, 30.0, "All three real rays must see the historical victim")
	assert_eq(victim.global_position, CURRENT_POSITION, "The owned multi-ray session must restore")


func test_hitscan_world_origin_is_not_missing_position_bypass() -> void:
	feature.apply_damage(victim, _damage(Vector3.ZERO))
	assert_eq(victim.damage_received, 0.0, "Hitscan must validate a zero-valued impact point")


func test_nested_multi_ray_fire_does_not_close_callers_session() -> void:
	assert_true(rewind.start_compensation(shooter_id))
	var rewound: Transform3D = victim.global_transform
	var manager: WeaponManager = _weapon_manager()
	manager._fire_hitscan_server(weapon, ORIGIN, Vector3.RIGHT)
	assert_eq(victim.damage_received, 30.0)
	assert_eq(
		victim.global_transform, rewound, "A nested caller must not restore the owner's world"
	)
	rewind.end_compensation()
	assert_eq(victim.global_position, CURRENT_POSITION, "The original owner can still restore")


func _damage(impact: Vector3) -> DamageInfo:
	var info := DamageInfo.create(10.0, DamageInfo.DamageType.BULLET, shooter)
	info.weapon_source = weapon
	info.hit_position = impact
	# CombatSvc may use an instance ID here; peer identity must come from source.
	info.source_id = shooter.get_instance_id()
	return info


func _seed_history() -> void:
	var now: float = 1000.0
	rewind.entity_history[victim.get_instance_id()] = [
		LagCompScript.HistoricalState.new(now - 500.0, HISTORICAL_POSITION),
		LagCompScript.HistoricalState.new(now - 20.0, HISTORICAL_POSITION)
	]


func _weapon_manager() -> WeaponManager:
	var manager := WeaponManager.new()
	fixture.add_child(manager)
	manager.player = shooter
	manager.hit_detector = WeaponHitDetector.new()
	manager.add_child(manager.hit_detector)
	manager.hit_detector.setup(shooter, null)
	return manager


func _add_shape(body: CollisionObject3D, layer: int) -> void:
	body.collision_layer = layer
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE
	shape.shape = box
	body.add_child(shape)
	body.force_update_transform()
	shape.force_update_transform()
