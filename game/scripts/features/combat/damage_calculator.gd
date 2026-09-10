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
func calculate(damage_info: DamageInfo) -> float:
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
	base_damage = _apply_hitbox_multiplier(base_damage, damage_info)

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


## Apply hitbox multiplier based on hit location
func _apply_hitbox_multiplier(damage: float, _damage_info: DamageInfo) -> float:
	var hitbox_config: Dictionary = combat_config.get("hitboxes", {})

	# Check if we have hit location information
	# This would typically come from the hit detection system
	# For now, we'll use a simple approach based on hit_position

	# Default to bodyshot multiplier
	var multiplier: float = hitbox_config.get("bodyshot_multiplier", 1.0)

	# In a full implementation, you would determine the hit location
	# based on the hit_position relative to the target's skeleton/hitboxes

	return damage * multiplier


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
