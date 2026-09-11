## DamageCalculator - Handles damage calculation with modifiers
##
## Calculates final damage based on damage type, critical hits,
## armor penetration, and other modifiers.
##
## Requirements: 4.2, 4.3
class_name DamageCalculator
extends Node

## Damage type configurations
var damage_types: Dictionary = {}

## General combat configuration
var combat_config: Dictionary = {}


## Constructor
func _init(damage_type_config: Dictionary = {}, config: Dictionary = {}) -> void:
	damage_types = damage_type_config
	combat_config = config


## Calculate final damage amount with all modifiers applied
func calculate(damage_info: DamageInfo, target: Node3D = null) -> float:
	var base_damage: float = damage_info.base_amount

	# Apply critical hit multiplier
	if damage_info.is_critical:
		var crit_multiplier: float = combat_config.get("critical_multiplier", 2.0)
		base_damage *= crit_multiplier

	# Apply damage type modifiers
	var damage_type_name: String = _get_damage_type_name(damage_info.damage_type)
	if damage_types.has(damage_type_name):
		var type_config: Dictionary = damage_types[damage_type_name]

		# Apply armor penetration (if target has armor)
		var armor_pen: float = type_config.get("armor_penetration", 1.0)
		base_damage = _apply_armor_penetration(base_damage, armor_pen, damage_info)

		# Set knockback multiplier for knockback_system to use
		damage_info.knockback_multiplier = type_config.get("knockback_multiplier", 1.0)

	# Apply hitbox multiplier (headshot, bodyshot, limbshot)
	base_damage = _apply_hitbox_multiplier(base_damage, damage_info, target)

	# Ensure minimum damage
	var min_damage: float = combat_config.get("min_damage", 0.1)
	base_damage = max(base_damage, min_damage)

	return base_damage


## Apply armor penetration and configured damage reduction.
func _apply_armor_penetration(damage: float, armor_pen: float, damage_info: DamageInfo) -> float:
	var armor_config: Dictionary = combat_config.get("armor", {})
	if not armor_config.get("enabled", false):
		return damage

	var penetration := clampf(maxf(armor_pen, damage_info.armor_penetration), 0.0, 1.0)
	var effective_armor := maxf(damage_info.target_armor, 0.0) * (1.0 - penetration)
	if effective_armor <= 0.0:
		return damage

	var max_reduction := clampf(float(armor_config.get("max_reduction", 0.75)), 0.0, 0.95)
	var reduction := 0.0
	match str(armor_config.get("damage_reduction_formula", "linear")).to_lower():
		"exponential":
			reduction = max_reduction * (1.0 - exp(-effective_armor / 100.0))
		"logarithmic":
			reduction = max_reduction * log(1.0 + effective_armor) / log(101.0)
		_:
			reduction = minf(max_reduction, effective_armor / (effective_armor + 100.0))
	return damage * (1.0 - clampf(reduction, 0.0, max_reduction))


## Apply hitbox multiplier based on hit location.
##
## Hit detection supplies a world-space impact point. When a target exposes
## hitbox metadata, use it first; the positional fallback keeps legacy body
## shots working for targets without explicit hitbox nodes.
func _apply_hitbox_multiplier(
	damage: float, damage_info: DamageInfo, target: Node3D = null
) -> float:
	var hitbox_config: Dictionary = combat_config.get("hitboxes", {})
	var multiplier: float = float(hitbox_config.get("bodyshot_multiplier", 1.0))
	if (
		not is_instance_valid(target)
		or damage_info.hit_position == Vector3.ZERO
		or not damage_info.hit_position.is_finite()
	):
		return damage * multiplier

	var location: String = _resolve_hitbox_location(target, damage_info.hit_position)
	match location:
		"head":
			multiplier = float(hitbox_config.get("headshot_multiplier", multiplier))
		"limb", "arm", "leg":
			multiplier = float(hitbox_config.get("limbshot_multiplier", multiplier))

	return damage * multiplier


func _resolve_hitbox_location(target: Node3D, hit_position: Vector3) -> String:
	if target.has_method("get_hitbox_at_position"):
		var resolved: Variant = target.get_hitbox_at_position(hit_position)
		var method_location: String = _hitbox_location_from_value(resolved)
		if not method_location.is_empty():
			return method_location

	var configured_hitboxes: Variant = target.get("hitboxes")
	if configured_hitboxes is Dictionary:
		for key: Variant in configured_hitboxes:
			var hitbox: Variant = configured_hitboxes[key]
			var location: String = _hitbox_location_from_value(hitbox)
			if location.is_empty():
				location = _normalize_hitbox_name(str(key))
			if not location.is_empty() and _hitbox_contains_point(hitbox, target, hit_position):
				return location

	for child: Node in target.find_children("*", "Node3D", true, false):
		var location := _hitbox_location_from_value(child)
		if location.is_empty():
			continue
		var radius: float = float(child.get_meta("hitbox_radius", 0.5))
		if child.global_position.distance_squared_to(hit_position) <= radius * radius:
			return location

	# Last-resort humanoid proportions for legacy targets with no hitbox data.
	var local_hit: Vector3 = target.to_local(hit_position)
	if local_hit.y >= 1.5:
		return "head"
	if local_hit.y <= 0.75 or absf(local_hit.x) >= 0.45:
		return "limb"
	return "body"


func _hitbox_location_from_value(value: Variant) -> String:
	if value is Node:
		var node: Node = value
		for key: String in ["hitbox_type", "hitbox", "body_part", "location"]:
			if node.has_meta(key):
				var metadata_location := _normalize_hitbox_name(str(node.get_meta(key)))
				if not metadata_location.is_empty():
					return metadata_location
		return _normalize_hitbox_name(node.name)
	if value is Dictionary:
		var data: Dictionary = value
		for key: String in ["hitbox_type", "hitbox", "body_part", "location", "type"]:
			if data.has(key):
				var dictionary_location := _normalize_hitbox_name(str(data[key]))
				if not dictionary_location.is_empty():
					return dictionary_location
	return _normalize_hitbox_name(str(value)) if value is String else ""


func _normalize_hitbox_name(value: String) -> String:
	var normalized := value.to_lower().strip_edges()
	if normalized.contains("head"):
		return "head"
	if normalized.contains("limb") or normalized.contains("arm"):
		return "limb"
	if normalized.contains("leg") or normalized.contains("foot") or normalized.contains("hand"):
		return "limb"
	if normalized in ["body", "torso", "chest", "spine", "hips"]:
		return "body"
	return ""


func _hitbox_contains_point(value: Variant, target: Node3D, hit_position: Vector3) -> bool:
	if value is Node3D:
		var node: Node3D = value
		var radius: float = float(node.get_meta("hitbox_radius", 0.5))
		return node.global_position.distance_squared_to(hit_position) <= radius * radius
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	var center: Variant = data.get("center", data.get("position", null))
	if center is Vector3:
		var radius := float(data.get("radius", 0.5))
		var world_center: Vector3 = target.global_transform * center
		return world_center.distance_squared_to(hit_position) <= radius * radius
	return true


## Get damage type name from enum value
func _get_damage_type_name(damage_type: DamageInfo.DamageType) -> String:
	match damage_type:
		DamageInfo.DamageType.MELEE:
			return "melee"
		DamageInfo.DamageType.BULLET:
			return "bullet"
		DamageInfo.DamageType.EXPLOSIVE:
			return "explosive"
		DamageInfo.DamageType.FIRE:
			return "fire"
		DamageInfo.DamageType.POISON:
			return "poison"
		_:
			return "bullet"  # Default


## Calculate critical hit chance
func calculate_critical_chance(damage_info: DamageInfo) -> float:
	var base_chance: float = combat_config.get("critical_chance_base", 0.05)

	# Add damage type bonus
	var damage_type_name: String = _get_damage_type_name(damage_info.damage_type)
	if damage_types.has(damage_type_name):
		var type_config: Dictionary = damage_types[damage_type_name]
		base_chance += type_config.get("critical_bonus", 0.0)

	return base_chance


## Determine if a hit should be critical
func roll_critical_hit(damage_info: DamageInfo) -> bool:
	var crit_chance: float = calculate_critical_chance(damage_info)
	return randf() < crit_chance
