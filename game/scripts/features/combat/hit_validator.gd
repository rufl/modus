## HitValidator - Handles hit validation with anti-cheat measures
##
## Validates hits using raycast, distance checks, and lag compensation.
## Ensures server-authoritative hit detection to prevent cheating.
##
## Requirements: 4.2, 4.3
class_name HitValidator
extends Node

## Hit validation configuration
var config: Dictionary = {}

## Lag compensation system reference
var lag_compensation: Node = null


## Constructor
func _init(validation_config: Dictionary = {}) -> void:
	config = validation_config


## Initialize the validator with lag compensation system
func initialize(lag_comp_system: Node = null) -> void:
	lag_compensation = lag_comp_system


## Validate a hit using raycast and distance checks
## Returns true if the hit is valid, false otherwise
func validate(damage_info: DamageInfo) -> bool:
	if not damage_info:
		return false

	# Get attacker and target positions
	var attacker_pos: Vector3 = (
		damage_info.source.global_position if damage_info.source else Vector3.ZERO
	)
	var target_pos: Vector3 = damage_info.hit_position

	# If no hit position specified, cannot validate
	if target_pos == Vector3.ZERO:
		return true  # Allow damage without position validation

	# Validate using raycast and distance
	return validate_hit(attacker_pos, target_pos, damage_info.weapon_id)


## Validate hit with raycast and distance checks
func validate_hit(attacker_pos: Vector3, target_pos: Vector3, weapon_id: String) -> bool:
	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.trace(
			(
				"Validating hit: Attacker=%v Target=%v Weapon=%s"
				% [attacker_pos, target_pos, weapon_id]
			),
			"Combat"
		)

	# Server-side raycast validation for hit detection
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if not tree:
		return false

	var root: Node = tree.root
	if not root:
		return false

	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	if not space:
		if logger:
			logger.trace("Validation failed: No space state", "Combat")
		return false

	# Create raycast query
	var query := PhysicsRayQueryParameters3D.create(attacker_pos, target_pos)
	query.collision_mask = CollisionLayers.MASK_HITSCAN  # World + Players + Enemies

	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		if logger:
			logger.trace("Validation failed: No raycast hit", "Combat")
		return false  # No hit detected

	# Validate distance (anti-cheat: prevent shooting through walls or too far)
	var distance: float = attacker_pos.distance_to(target_pos)
	var weapon_data: Dictionary = _get_weapon_data(weapon_id)

	if weapon_data.has("max_range"):
		var max_range: float = weapon_data.max_range
		if distance > max_range * 1.15:  # 15% tolerance for latency
			if logger:
				logger.warning(
					(
						"[Combat] Hit rejected: distance %.1fm exceeds max range %.1fm"
						% [distance, max_range]
					),
					"Combat"
				)
			return false

	# Check if raycast hit the target (not a wall)
	var hit_collider: Object = result.get("collider", null)
	if not hit_collider:
		if logger:
			logger.trace("Validation failed: Hit nothing (null collider)", "Combat")
		return false

	# Valid hit
	if logger:
		logger.trace("Hit validated successfully against %s" % hit_collider.name, "Combat")
	return true


## Validate hit with lag compensation
## Used for hitscan weapons to account for network latency
func validate_hit_with_lag_compensation(
	shooter_peer_id: int, attacker_pos: Vector3, target_pos: Vector3, weapon_id: String
) -> bool:
	# If lag compensation is not available or disabled, use standard validation
	if not lag_compensation or not lag_compensation.enabled:
		return validate_hit(attacker_pos, target_pos, weapon_id)

	# Use lag compensation for hitscan validation
	var direction: Vector3 = (target_pos - attacker_pos).normalized()
	var max_distance: float = attacker_pos.distance_to(target_pos)

	var hit_result: Dictionary = lag_compensation.perform_lag_compensated_hitscan(
		shooter_peer_id, attacker_pos, direction, max_distance
	)

	if hit_result.is_empty():
		return false

	# Validate distance with weapon range
	var weapon_data: Dictionary = _get_weapon_data(weapon_id)
	if weapon_data.has("max_range"):
		var max_range: float = weapon_data.max_range
		var distance: float = attacker_pos.distance_to(hit_result.get("position", target_pos))

		if distance > max_range * 1.15:  # 15% tolerance for latency
			var gm: Node = get_node_or_null("/root/GameManager")
			var logger: Node = gm.get_core_system("logger") if gm else null
			if logger:
				logger.warning(
					(
						"[Combat] Lag-compensated hit rejected: "
						+ "distance %.1fm exceeds max range %.1fm"
						% [distance, max_range]
					),
					"Combat"
				)
			return false

	return true


## Get weapon data from database
func _get_weapon_data(weapon_id: String) -> Dictionary:
	var gm: Node = get_node_or_null("/root/GameManager")
	var data_service: Node = gm.get_core_system("data") if gm else null
	if data_service and "weapons" in data_service:
		return data_service.weapons.get(weapon_id, {})
	return {}


## Get GameCore autoload safely
func _get_game_core() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("GameManager")
	return null
