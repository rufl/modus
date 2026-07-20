class_name PassiveEffects
extends Node

var _stat_modifiers: Dictionary = {}
var _active_skills: Array[SkillNode] = []


func _ready() -> void:
	name = "PassiveEffects"
	_initialize_default_modifiers()


## Initialize default modifier values (1.0 for multipliers, 0 for additive)


func _initialize_default_modifiers() -> void:
	# Multiplicative modifiers (default 1.0 = no change)
	_stat_modifiers["weapon_damage_mult"] = 1.0
	_stat_modifiers["movement_speed_mult"] = 1.0
	_stat_modifiers["reload_speed_mult"] = 1.0
	_stat_modifiers["crit_damage_mult"] = 1.5  # Base crit damage
	_stat_modifiers["fire_rate_mult"] = 1.0

	# Additive modifiers (default 0 = no change)
	_stat_modifiers["max_health"] = 0.0
	_stat_modifiers["max_armor"] = 0.0
	_stat_modifiers["crit_chance"] = 0.0
	_stat_modifiers["dodge_cooldown_reduction"] = 0.0
	_stat_modifiers["ammo_capacity"] = 0.0


## Apply effects from a newly unlocked skill


func apply_skill_effects(skill: SkillNode) -> void:
	if skill in _active_skills:
		push_warning("Skill %s already applied" % skill.skill_id)
		return

	_active_skills.append(skill)
	_recalculate_all_stats()


## Remove effects from a skill (for respec functionality)


func remove_skill_effects(skill: SkillNode) -> void:
	var idx: int = _active_skills.find(skill)
	if idx >= 0:
		_active_skills.remove_at(idx)
		_recalculate_all_stats()


## Recalculate all stat modifiers from active skills


func _recalculate_all_stats() -> void:
	# Reset to defaults
	_initialize_default_modifiers()

	# Apply all active skill effects
	for skill: SkillNode in _active_skills:
		for stat_name: String in skill.effects.keys():
			var value: float = float(skill.effects[stat_name])

			# Multiplicative stats stack multiplicatively
			if stat_name.ends_with("_mult"):
				_stat_modifiers[stat_name] *= value
			# Additive stats stack additively
			else:
				_stat_modifiers[stat_name] += value


## Get the current modifier for a stat
## Returns 1.0 for unknown multiplicative stats, 0.0 for additive


func get_stat_modifier(stat_name: String) -> float:
	if stat_name in _stat_modifiers:
		return _stat_modifiers[stat_name]

	# Default: 1.0 for multipliers, 0.0 for additive
	if stat_name.ends_with("_mult"):
		return 1.0
	return 0.0


## Get all active stat modifiers (for debugging/UI)


func get_all_modifiers() -> Dictionary:
	return _stat_modifiers.duplicate()


## Clear all active skills (for reset)


func clear_all_effects() -> void:
	_active_skills.clear()
	_initialize_default_modifiers()


## Get count of active skills


func get_active_skill_count() -> int:
	return _active_skills.size()
