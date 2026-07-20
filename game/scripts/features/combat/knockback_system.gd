## KnockbackSystem - Handles knockback calculation and application
##
## Calculates and applies knockback forces to entities based on
## damage dealt, damage type, and knockback configuration.
##
## Requirements: 4.2, 4.3
class_name KnockbackSystem
extends Node

## Knockback configuration
var config: Dictionary = {}


## Constructor
func _init(knockback_config: Dictionary = {}) -> void:
	config = knockback_config


## Apply knockback to a target entity
func apply_knockback(target: Node, damage_info: DamageInfo, damage_amount: float) -> void:
	if not config.get("enabled", true):
		return  # Knockback disabled

	if not target or not is_instance_valid(target):
		return

	# Calculate knockback force
	var force: float = calculate_knockback_force(damage_info, damage_amount)

	# Get knockback direction
	var direction: Vector3 = _get_knockback_direction(target, damage_info)

	# Apply vertical multiplier
	var vertical_mult: float = config.get("vertical_multiplier", 0.5)
	direction.y *= vertical_mult
	direction = direction.normalized()

	# Apply knockback to target
	_apply_force_to_target(target, direction * force, damage_info)


## Calculate knockback force based on damage and modifiers
func calculate_knockback_force(damage_info: DamageInfo, damage_amount: float) -> float:
	var base_force: float = config.get("base_force", 5.0)
	var damage_mult: float = config.get("damage_multiplier", 0.1)

	# Calculate force from damage
	var force: float = base_force + (damage_amount * damage_mult)

	# Apply damage type multiplier from damage_info if available
	# Otherwise use default of 1.0
	var type_mult: float = 1.0
	if "knockback_multiplier" in damage_info and damage_info.knockback_multiplier > 0:
		type_mult = damage_info.knockback_multiplier
	force *= type_mult

	# Cap at maximum force
	var max_force: float = config.get("max_force", 20.0)
	force = min(force, max_force)

	return force


## Get knockback direction
func _get_knockback_direction(target: Node, damage_info: DamageInfo) -> Vector3:
	# Use pre-calculated direction if available
	if damage_info.knockback_direction != Vector3.ZERO:
		return damage_info.knockback_direction

	# Calculate from source to target
	if damage_info.source and is_instance_valid(damage_info.source):
		var source_pos: Vector3 = damage_info.source.global_position
		var target_pos: Vector3 = target.global_position
		return (target_pos - source_pos).normalized()

	# Fallback: use hit normal if available
	if damage_info.hit_normal != Vector3.ZERO:
		return damage_info.hit_normal

	# Last resort: push away from hit position
	if damage_info.hit_position != Vector3.ZERO:
		return (target.global_position - damage_info.hit_position).normalized()

	# Default: push backward
	return -target.global_transform.basis.z


## Apply force to target entity
func _apply_force_to_target(target: Node, force_vector: Vector3, damage_info: DamageInfo) -> void:
	# Try different methods to apply knockback based on target type

	# Method 1: CharacterBody3D with velocity
	if target is CharacterBody3D:
		if "velocity" in target:
			target.velocity += force_vector

	# Method 2: RigidBody3D with apply_impulse
	elif target is RigidBody3D:
		var impulse_point: Vector3 = damage_info.hit_position
		if impulse_point == Vector3.ZERO:
			impulse_point = target.global_position
		target.apply_impulse(force_vector, impulse_point - target.global_position)

	# Method 3: Custom knockback method
	elif target.has_method("apply_knockback"):
		var duration: float = config.get("duration", 0.3)
		target.apply_knockback(force_vector, duration)

	# Method 4: Custom push method
	elif target.has_method("push"):
		target.push(force_vector)


## Get knockback duration
func get_knockback_duration() -> float:
	return config.get("duration", 0.3)


## Get recovery time after knockback
func get_recovery_time() -> float:
	return config.get("recovery_time", 0.5)
