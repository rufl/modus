class_name SkillTreeManager
extends Node

signal skill_unlocked(skill_id: String)
signal skill_unlock_failed(skill_id: String, reason: String)
signal skill_points_changed(new_amount: int)

var _skill_trees: Dictionary = {}
var _skills_by_id: Dictionary = {}
var _unlocked_skills: Array[String] = []
var _passive_effects: PassiveEffects = null
var _available_skill_points: int = 0


func _ready() -> void:
	name = "SkillTreeManager"
	_skill_trees["combat"] = [] as Array[SkillNode]
	_skill_trees["survival"] = [] as Array[SkillNode]
	_skill_trees["utility"] = [] as Array[SkillNode]

	# Initialize default skills
	_initialize_default_skills()


## Load skill data from JSON file


func load_skill_data(config_path: String) -> bool:
	if not FileAccess.file_exists(config_path):
		push_error("Skill config file not found: %s" % config_path)
		return false

	var file: FileAccess = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error("Failed to open skill config: %s" % config_path)
		return false

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result: Error = json.parse(json_text)

	if parse_result != OK:
		push_error("Failed to parse skill JSON: %s" % json.get_error_message())
		return false

	var data: Dictionary = json.data

	# Load skill trees
	if "skill_trees" in data:
		var trees: Dictionary = data["skill_trees"]

		for tree_name: String in trees.keys():
			if tree_name not in _skill_trees:
				push_warning("Unknown skill tree: %s" % tree_name)
				continue

			var skills_data: Array = trees[tree_name]
			for skill_dict: Dictionary in skills_data:
				var skill: SkillNode = SkillNode.from_dict(skill_dict)
				_skill_trees[tree_name].append(skill)
				_skills_by_id[skill.skill_id] = skill

	GameManager.get_core_system("logger").info(
		"Loaded %d skills across %d trees" % [_skills_by_id.size(), _skill_trees.size()], "Player"
	)
	return true


## Set reference to PassiveEffects component


func set_passive_effects(effects: PassiveEffects) -> void:
	_passive_effects = effects


## Check if a skill is unlocked


func is_skill_unlocked(skill_id: String) -> bool:
	return skill_id in _unlocked_skills


## Get skill by ID


func get_skill(skill_id: String) -> SkillNode:
	return _skills_by_id.get(skill_id, null)


## Get all skills in a tree


func get_skill_tree(tree_name: String) -> Array[SkillNode]:
	if tree_name in _skill_trees:
		return _skill_trees[tree_name]
	return []


## Get all tree names


func get_tree_names() -> Array[String]:
	return ["combat", "survival", "utility"]


## Validate if prerequisites are met for a skill


func validate_prerequisites(skill_id: String) -> bool:
	var skill: SkillNode = get_skill(skill_id)
	if not skill:
		return false

	# Check all prerequisites are unlocked
	for prereq_id: String in skill.prerequisites:
		if not is_skill_unlocked(prereq_id):
			return false

	return true


## Check if a skill can be unlocked (prerequisites + not already unlocked)


func can_unlock_skill(skill_id: String) -> bool:
	# Already unlocked?
	if is_skill_unlocked(skill_id):
		return false

	# Skill exists?
	if not get_skill(skill_id):
		return false

	# Prerequisites met?
	return validate_prerequisites(skill_id)


## Unlock a skill (returns true if successful)


func unlock_skill(skill_id: String) -> bool:
	if not can_unlock_skill(skill_id):
		skill_unlock_failed.emit(skill_id, "Prerequisites not met or already unlocked")
		return false

	var skill: SkillNode = get_skill(skill_id)
	if not skill:
		skill_unlock_failed.emit(skill_id, "Skill not found")
		return false

	# Add to unlocked list
	_unlocked_skills.append(skill_id)

	# Apply passive effects
	if _passive_effects:
		_passive_effects.apply_skill_effects(skill)

	skill_unlocked.emit(skill_id)
	return true


## Get list of unlocked skill IDs


func get_unlocked_skills() -> Array[String]:
	return _unlocked_skills.duplicate()


## Load unlocked skills from save data


func load_unlocked_skills(skill_ids: Array[String]) -> void:
	_unlocked_skills.clear()

	for skill_id: String in skill_ids:
		var skill: SkillNode = get_skill(skill_id)
		if skill:
			_unlocked_skills.append(skill_id)

			# Reapply passive effects
			if _passive_effects:
				_passive_effects.apply_skill_effects(skill)


## Reset all unlocked skills (for respec)


func reset_all_skills() -> void:
	_unlocked_skills.clear()

	if _passive_effects:
		_passive_effects.clear_all_effects()


## Get count of unlocked skills in a tree


func get_unlocked_count_in_tree(tree_name: String) -> int:
	var count: int = 0
	var tree: Array[SkillNode] = get_skill_tree(tree_name)

	for skill: SkillNode in tree:
		if is_skill_unlocked(skill.skill_id):
			count += 1

	return count


## Initialize default skill definitions
func _initialize_default_skills() -> void:
	## Register built-in skills
	_register_combat_skills()
	_register_survival_skills()
	_register_utility_skills()


func _register_combat_skills() -> void:
	## Register combat tree skills
	var weapon_mastery := SkillNode.new(
		"weapon_mastery", "Weapon Mastery", "Increases weapon damage", "combat"
	)
	weapon_mastery.max_level = 5
	weapon_mastery.effects = {
		"1": {"damage_multiplier": 1.05},
		"2": {"damage_multiplier": 1.10},
		"3": {"damage_multiplier": 1.15},
		"4": {"damage_multiplier": 1.20},
		"5": {"damage_multiplier": 1.25},
	}
	_add_skill(weapon_mastery)

	var crit_strike := SkillNode.new(
		"critical_strike", "Critical Strike", "Increases critical hit chance", "combat"
	)
	crit_strike.max_level = 5
	crit_strike.prerequisites = ["weapon_mastery"]
	crit_strike.required_player_level = 3
	crit_strike.effects = {
		"1": {"crit_chance": 0.05},
		"2": {"crit_chance": 0.10},
		"3": {"crit_chance": 0.15},
		"4": {"crit_chance": 0.20},
		"5": {"crit_chance": 0.25},
	}
	_add_skill(crit_strike)

	var rapid_fire := SkillNode.new(
		"rapid_fire", "Rapid Fire", "Reduces weapon fire delay", "combat"
	)
	rapid_fire.max_level = 5
	rapid_fire.prerequisites = ["weapon_mastery"]
	rapid_fire.required_player_level = 4
	rapid_fire.effects = {
		"1": {"fire_rate_multiplier": 0.95},
		"2": {"fire_rate_multiplier": 0.90},
		"3": {"fire_rate_multiplier": 0.85},
		"4": {"fire_rate_multiplier": 0.80},
		"5": {"fire_rate_multiplier": 0.75},
	}
	_add_skill(rapid_fire)


func _register_survival_skills() -> void:
	## Register survival tree skills
	var tough_skin := SkillNode.new(
		"tough_skin", "Tough Skin", "Increases maximum health", "survival"
	)
	tough_skin.max_level = 5
	tough_skin.effects = {
		"1": {"max_health_bonus": 10},
		"2": {"max_health_bonus": 20},
		"3": {"max_health_bonus": 30},
		"4": {"max_health_bonus": 40},
		"5": {"max_health_bonus": 50},
	}
	_add_skill(tough_skin)

	var armor_plating := SkillNode.new(
		"armor_plating", "Armor Plating", "Reduces incoming damage", "survival"
	)
	armor_plating.max_level = 5
	armor_plating.prerequisites = ["tough_skin"]
	armor_plating.required_player_level = 4
	armor_plating.effects = {
		"1": {"damage_reduction": 0.05},
		"2": {"damage_reduction": 0.10},
		"3": {"damage_reduction": 0.15},
		"4": {"damage_reduction": 0.20},
		"5": {"damage_reduction": 0.25},
	}
	_add_skill(armor_plating)

	var regeneration := SkillNode.new(
		"regeneration", "Regeneration", "Regenerate health over time", "survival"
	)
	regeneration.max_level = 3
	regeneration.prerequisites = ["tough_skin"]
	regeneration.required_player_level = 6
	regeneration.cost_per_level = 2
	regeneration.effects = {
		"1": {"health_regen_per_second": 1.0},
		"2": {"health_regen_per_second": 2.0},
		"3": {"health_regen_per_second": 3.0},
	}
	_add_skill(regeneration)


func _register_utility_skills() -> void:
	## Register utility tree skills
	var sprint_master := SkillNode.new(
		"sprint_master", "Sprint Master", "Increases sprint speed", "utility"
	)
	sprint_master.max_level = 5
	sprint_master.effects = {
		"1": {"sprint_multiplier": 1.05},
		"2": {"sprint_multiplier": 1.10},
		"3": {"sprint_multiplier": 1.15},
		"4": {"sprint_multiplier": 1.20},
		"5": {"sprint_multiplier": 1.25},
	}
	_add_skill(sprint_master)

	var scavenger := SkillNode.new(
		"scavenger", "Scavenger", "Increases ammo pickup amount", "utility"
	)
	scavenger.max_level = 5
	scavenger.effects = {
		"1": {"ammo_pickup_multiplier": 1.10},
		"2": {"ammo_pickup_multiplier": 1.20},
		"3": {"ammo_pickup_multiplier": 1.30},
		"4": {"ammo_pickup_multiplier": 1.40},
		"5": {"ammo_pickup_multiplier": 1.50},
	}
	_add_skill(scavenger)

	var medic := SkillNode.new("medic", "Medic", "Increases health pickup effectiveness", "utility")
	medic.max_level = 5
	medic.effects = {
		"1": {"health_pickup_multiplier": 1.15},
		"2": {"health_pickup_multiplier": 1.30},
		"3": {"health_pickup_multiplier": 1.45},
		"4": {"health_pickup_multiplier": 1.60},
		"5": {"health_pickup_multiplier": 1.75},
	}
	_add_skill(medic)


func _add_skill(skill: SkillNode) -> void:
	## Add skill to tree and index
	if skill.tree_name in _skill_trees:
		_skill_trees[skill.tree_name].append(skill)
	_skills_by_id[skill.skill_id] = skill


## Skill point management
func add_skill_points(amount: int) -> void:
	_available_skill_points += amount
	skill_points_changed.emit(_available_skill_points)


func get_available_skill_points() -> int:
	return _available_skill_points


func spend_skill_point() -> bool:
	if _available_skill_points <= 0:
		return false
	_available_skill_points -= 1
	skill_points_changed.emit(_available_skill_points)
	return true


func refund_skill_point() -> void:
	_available_skill_points += 1
	skill_points_changed.emit(_available_skill_points)


## Enhanced unlock with skill point cost
func unlock_skill_with_points(skill_id: String, player_level: int = 1) -> bool:
	var skill: SkillNode = get_skill(skill_id)
	if not skill:
		skill_unlock_failed.emit(skill_id, "Skill not found")
		return false

	# Check player level requirement
	if player_level < skill.required_player_level:
		skill_unlock_failed.emit(skill_id, "Requires player level %d" % skill.required_player_level)
		return false

	# Check if already maxed
	if skill.is_maxed():
		skill_unlock_failed.emit(skill_id, "Skill already maxed")
		return false

	# Check skill points
	if _available_skill_points < skill.cost_per_level:
		skill_unlock_failed.emit(skill_id, "Not enough skill points")
		return false

	# Check prerequisites
	if not can_unlock_skill(skill_id):
		skill_unlock_failed.emit(skill_id, "Prerequisites not met")
		return false

	# Spend skill point
	if not spend_skill_point():
		return false

	# Upgrade skill
	skill.current_level += 1

	# Add to unlocked list if first level
	if skill.current_level == 1:
		_unlocked_skills.append(skill_id)

	# Apply passive effects
	if _passive_effects:
		_passive_effects.apply_skill_effects(skill)

	skill_unlocked.emit(skill_id)
	return true


## Get skill effect value
func get_skill_effect(skill_id: String, effect_key: String) -> Variant:
	var skill: SkillNode = get_skill(skill_id)
	if not skill or skill.current_level == 0:
		return null
	return skill.get_effect_value(effect_key)


## Save/Load with skill points
func get_save_data() -> Dictionary:
	var skill_levels := {}
	for skill_id: String in _skills_by_id:
		var skill: SkillNode = _skills_by_id[skill_id]
		if skill.current_level > 0:
			skill_levels[skill_id] = skill.current_level

	return {
		"available_skill_points": _available_skill_points,
		"skill_levels": skill_levels,
		"unlocked_skills": _unlocked_skills.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_available_skill_points = data.get("available_skill_points", 0)

	var skill_levels: Dictionary = data.get("skill_levels", {})
	for skill_id: String in skill_levels:
		var skill: SkillNode = get_skill(skill_id)
		if skill:
			skill.current_level = skill_levels[skill_id]

	_unlocked_skills = data.get("unlocked_skills", [])

	# Reapply passive effects
	if _passive_effects:
		for skill_id: String in _unlocked_skills:
			var skill: SkillNode = get_skill(skill_id)
			if skill:
				_passive_effects.apply_skill_effects(skill)

	skill_points_changed.emit(_available_skill_points)
