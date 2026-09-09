## Server-owned hit validation against the intended geometry and victim.
class_name HitValidator
extends Node

var config: Dictionary = {}
var lag_compensation: Node = null


func _init(validation_config: Dictionary = {}) -> void:
	config = validation_config


func initialize(lag_comp_system: Node = null) -> void:
	lag_compensation = lag_comp_system


func validate(damage_info: DamageInfo, target: Node = null) -> bool:
	if not damage_info or not _is_server():
		return false
	if not config.get("enabled", true):
		return true

	var weapon_id: String = damage_info.weapon_id
	var weapon: WeaponData = damage_info.weapon_source as WeaponData
	if weapon and weapon_id.is_empty():
		weapon_id = weapon.id if not weapon.id.is_empty() else weapon.weapon_id
	var weapon_data: Dictionary = _get_weapon_data(weapon_id)
	var hitscan: bool = _is_hitscan(damage_info, weapon, weapon_data)
	var target_pos: Vector3 = damage_info.hit_position
	# Environmental damage and legacy melee without an impact point need no ray.
	# A hitscan impact at world origin is still a real position, never a bypass.
	if not hitscan and target_pos == Vector3.ZERO:
		return true
	if not is_instance_valid(damage_info.source):
		return false

	var source: Node3D = damage_info.source
	var attacker_pos: Vector3 = source.global_position
	if hitscan:
		var camera: Camera3D = source.get_node_or_null("Camera3D") as Camera3D
		if camera:
			attacker_pos = camera.global_position
		if not is_instance_valid(target):
			return false
		var gm: Node = get_node_or_null("/root/GameManager")
		var registry: Node = gm.get_core_system("entities") if gm else null
		var peer_id: int = source.get_multiplayer_authority()
		if registry and registry.get_player(peer_id) == source:
			return validate_hit_with_lag_compensation(
				peer_id, attacker_pos, target_pos, weapon_id, target, source
			)
	return validate_hit(attacker_pos, target_pos, weapon_id, target, source)


func validate_hit(
	attacker_pos: Vector3,
	target_pos: Vector3,
	weapon_id: String,
	target: Node = null,
	source: Node3D = null
) -> bool:
	if not _is_server() or not _valid_segment(attacker_pos, target_pos, weapon_id):
		return false
	var world: World3D = (
		source.get_world_3d() if is_instance_valid(source) else get_viewport().find_world_3d()
	)
	if not world:
		return false
	var query := PhysicsRayQueryParameters3D.create(
		attacker_pos, target_pos, CollisionLayers.MASK_HITSCAN
	)
	if source is CollisionObject3D:
		query.exclude = [source.get_rid()]
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	return _matches_target(result, target_pos, target)


func validate_hit_with_lag_compensation(
	shooter_peer_id: int,
	attacker_pos: Vector3,
	target_pos: Vector3,
	weapon_id: String,
	target: Node = null,
	source: Node3D = null
) -> bool:
	if not _is_server() or not _valid_segment(attacker_pos, target_pos, weapon_id):
		return false
	if not is_instance_valid(lag_compensation) or not lag_compensation.enabled:
		return validate_hit(attacker_pos, target_pos, weapon_id, target, source)
	var direction: Vector3 = (target_pos - attacker_pos).normalized()
	var result: Dictionary = lag_compensation.perform_lag_compensated_hitscan(
		shooter_peer_id, attacker_pos, direction, attacker_pos.distance_to(target_pos)
	)
	return _matches_target(result, target_pos, target)


func _is_server() -> bool:
	return is_inside_tree() and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server())


func _is_hitscan(info: DamageInfo, weapon: WeaponData, data: Dictionary) -> bool:
	# BULLET also describes plasma projectiles; ENERGY also describes BFG.
	# Classify the weapon, not its damage enum alone, and exclude secondary DOT/AOE.
	if (
		info.damage_type
		not in [
			DamageInfo.DamageType.BULLET,
			DamageInfo.DamageType.SHOTGUN,
			DamageInfo.DamageType.ENERGY,
			DamageInfo.DamageType.CRITICAL,
			DamageInfo.DamageType.GENERIC
		]
	):
		return false
	if weapon:
		return weapon.projectile_scene == null and weapon.damage_type != DamageInfo.DamageType.MELEE
	return data.get("type", "") == "hitscan"


func _valid_segment(origin: Vector3, impact: Vector3, weapon_id: String) -> bool:
	if not origin.is_finite() or not impact.is_finite():
		return false
	var distance: float = origin.distance_to(impact)
	if not is_finite(distance) or distance <= 0.0:
		return false
	var data: Dictionary = _get_weapon_data(weapon_id)
	# Live WeaponHitDetector rays extend 1000m; attack_range is melee-only.
	var max_range: float = float(data.get("max_range", data.get("stats", {}).get("range", 1000.0)))
	var tolerance: float = float(config.get("max_range_tolerance", 1.15))
	return (
		is_finite(max_range)
		and max_range > 0.0
		and is_finite(tolerance)
		and tolerance > 0.0
		and distance <= max_range * tolerance
	)


func _matches_target(result: Dictionary, impact: Vector3, target: Node) -> bool:
	if result.is_empty():
		return false
	var collider: Node = result.get("collider") as Node
	if not is_instance_valid(collider):
		return false
	if is_instance_valid(target):
		# Hitboxes can be children of the damage recipient, never arbitrary blockers.
		return collider == target or target.is_ancestor_of(collider)
	# Position-only callers must actually reach the claimed impact, not any wall.
	var hit_position: Vector3 = result.get("position", Vector3.INF)
	return hit_position.is_finite() and hit_position.distance_to(impact) <= 0.1


func _get_weapon_data(weapon_id: String) -> Dictionary:
	var gm: Node = get_node_or_null("/root/GameManager")
	var data_service: Node = gm.get_core_system("data") if gm else null
	if data_service and "weapons" in data_service:
		return data_service.weapons.get(weapon_id, {})
	return {}
