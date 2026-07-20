class_name SkillNode
extends RefCounted

## Represents a single skill in the skill tree

var skill_id: String = ""
var skill_name: String = ""
var description: String = ""
var icon_path: String = ""
var tree_name: String = ""  # combat, survival, utility
var max_level: int = 1
var current_level: int = 0
var cost_per_level: int = 1
var prerequisites: Array[String] = []
var required_player_level: int = 1
var effects: Dictionary = {}  # level -> {effect_key: value}


func _init(
	p_id: String = "", p_name: String = "", p_desc: String = "", p_tree: String = "combat"
) -> void:
	skill_id = p_id
	skill_name = p_name
	description = p_desc
	tree_name = p_tree


static func from_dict(data: Dictionary) -> SkillNode:
	## Create SkillNode from dictionary
	var skill := SkillNode.new()

	skill.skill_id = data.get("id", "")
	skill.skill_name = data.get("name", "")
	skill.description = data.get("description", "")
	skill.icon_path = data.get("icon", "")
	skill.tree_name = data.get("tree", "combat")
	skill.max_level = data.get("max_level", 1)
	skill.cost_per_level = data.get("cost", 1)
	skill.required_player_level = data.get("required_level", 1)

	if "prerequisites" in data:
		var prereqs: Array = data["prerequisites"]
		for prereq in prereqs:
			skill.prerequisites.append(str(prereq))

	if "effects" in data:
		skill.effects = data["effects"].duplicate(true)

	return skill


func to_dict() -> Dictionary:
	## Convert SkillNode to dictionary for saving
	return {
		"id": skill_id,
		"name": skill_name,
		"description": description,
		"icon": icon_path,
		"tree": tree_name,
		"max_level": max_level,
		"current_level": current_level,
		"cost": cost_per_level,
		"required_level": required_player_level,
		"prerequisites": prerequisites.duplicate(),
		"effects": effects.duplicate(true),
	}


func get_effect_value(effect_key: String, level: int = -1) -> Variant:
	## Get effect value for a specific level (or current level if -1)
	var check_level := level if level >= 0 else current_level

	if check_level <= 0 or check_level > max_level:
		return null

	var level_effects: Dictionary = effects.get(str(check_level), {})
	return level_effects.get(effect_key, null)


func is_unlocked() -> bool:
	return current_level > 0


func is_maxed() -> bool:
	return current_level >= max_level


func can_upgrade() -> bool:
	return current_level < max_level
