class_name CombatCalculator
extends RefCounted

const ARMOR_ABSORPTION_RATE: float = 0.5  ## 50% of damage absorbed by armor (Quake/HL style)
const HEADSHOT_MULTIPLIER: float = 2.0
const MIN_DAMAGE: float = 1.0


static func calculate_final_damage(
	damage_info: DamageInfo, current_armor: float, _max_armor: float
) -> Dictionary:
	## Calculates final health/armor damage split.
	## Returns specific dictionary with { health_damage: float, armor_damage: float }
	var base_dmg: float = damage_info.base_amount

	# Apply passive skill effects from attacker (if player with PassiveEffects)
	if damage_info.source and damage_info.source.has_node("PassiveEffects"):
		var effects: PassiveEffects = damage_info.source.get_node("PassiveEffects")
		base_dmg = apply_passive_damage_modifiers(base_dmg, effects, damage_info)

	# Apply critical hit
	if damage_info.is_critical:
		base_dmg *= damage_info.critical_multiplier

	# Calculate armor absorption
	var armor_dmg: float = 0.0
	var health_dmg: float = base_dmg
	var bypass_armor: bool = (
		damage_info.damage_type == DamageInfo.DamageType.FALL
		or damage_info.damage_type == DamageInfo.DamageType.VOID
		or damage_info.damage_type == DamageInfo.DamageType.POISON
	)

	if current_armor > 0 and not bypass_armor:
		# Apply armor penetration (if any)
		var absorption_rate: float = ARMOR_ABSORPTION_RATE * (1.0 - damage_info.armor_penetration)
		armor_dmg = base_dmg * absorption_rate

		# Clamp armor damage to available armor
		if armor_dmg > current_armor:
			armor_dmg = current_armor

		# Remaining flows to health
		health_dmg = base_dmg - armor_dmg

	# Ensure minimum damage rules (optional, can remove if 0 damage is valid)
	# For VOID damage (kill volumes), it bypasses everything usually, but here handled by type check

	return {
		"health_damage": health_dmg,
		"armor_damage": armor_dmg,
		"final_total": health_dmg + armor_dmg
	}


## Apply passive damage modifiers from player skills


static func apply_passive_damage_modifiers(
	base_damage: float, effects: PassiveEffects, damage_info: DamageInfo
) -> float:
	var damage: float = base_damage

	# Apply weapon damage multiplier
	damage *= effects.get_stat_modifier("weapon_damage_mult")

	# Check for critical hit from skills (in addition to weapon crits)
	var crit_chance: float = effects.get_stat_modifier("crit_chance")
	if crit_chance > 0 and not damage_info.is_critical and randf() < crit_chance:
		var crit_mult: float = effects.get_stat_modifier("crit_damage_mult")
		damage *= crit_mult
		# Mark as critical for feedback
		damage_info.is_critical = true

	return damage


static func calculate_knockback(damage_info: DamageInfo, target_mass: float = 1.0) -> Vector3:
	if damage_info.knockback_force <= 0:
		return Vector3.ZERO

	var direction: Vector3 = damage_info.knockback_direction
	if direction == Vector3.ZERO and damage_info.source:
		# Calculate direction from source to hit position
		direction = (damage_info.hit_position - damage_info.source.global_position).normalized()

	return direction * (damage_info.knockback_force / target_mass)
