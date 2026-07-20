extends Node
class_name SkillTreeController

## Integrates skill tree with player
## Handles skill tree UI toggling and skill effect application

signal skill_tree_opened
signal skill_tree_closed

var player: CharacterBody3D = null
var skill_tree_manager: SkillTreeManager = null
var player_progression: PlayerProgression = null
var skill_tree_ui: SkillTreeUI = null


func _ready() -> void:
	# Skip in editor
	if Engine.is_editor_hint():
		return

	player = get_parent() as CharacterBody3D
	if not player:
		push_error("[SkillTreeController] Must be child of player")
		return

	# Find components
	_find_components()

	# Connect to input
	_connect_input()

	# Find or create UI
	_setup_ui()


func _find_components() -> void:
	## Find skill tree manager and progression
	skill_tree_manager = player.get_node_or_null("SkillTreeManager")
	player_progression = player.get_node_or_null("PlayerProgression")

	if not skill_tree_manager:
		push_warning("[SkillTreeController] No SkillTreeManager found on player")

	if not player_progression:
		push_warning("[SkillTreeController] No PlayerProgression found on player")


func _connect_input() -> void:
	## Connect to player input component
	var input_component := player.get_node_or_null("PlayerInputComponent")
	if input_component and input_component.has_signal("skill_tree_toggled"):
		input_component.skill_tree_toggled.connect(_on_skill_tree_toggled)


func _setup_ui() -> void:
	## Find or create skill tree UI
	# Look for UI in scene tree
	var ui_layer := get_tree().root.find_child("UILayer", true, false)
	if ui_layer:
		skill_tree_ui = ui_layer.find_child("SkillTreeUI", true, false) as SkillTreeUI

	if not skill_tree_ui:
		# Create UI
		var ui_scene := load("res://game/ui/menus/skill_tree_ui.tscn")
		if ui_scene:
			skill_tree_ui = ui_scene.instantiate() as SkillTreeUI

			# Add to UI layer or root
			if ui_layer:
				ui_layer.add_child(skill_tree_ui)
			else:
				get_tree().root.add_child(skill_tree_ui)

	# Initialize UI
	if skill_tree_ui and skill_tree_manager and player_progression:
		skill_tree_ui.initialize(skill_tree_manager, player_progression)
		skill_tree_ui.skill_tree_closed.connect(_on_skill_tree_ui_closed)


func _on_skill_tree_toggled() -> void:
	## Handle skill tree toggle input
	if not skill_tree_ui:
		return

	if skill_tree_ui.visible:
		close_skill_tree()
	else:
		open_skill_tree()


func open_skill_tree() -> void:
	## Open skill tree UI
	if not skill_tree_ui:
		return

	skill_tree_ui.open_skill_tree()
	skill_tree_opened.emit()


func close_skill_tree() -> void:
	## Close skill tree UI
	if not skill_tree_ui:
		return

	skill_tree_ui.close_skill_tree()
	skill_tree_closed.emit()


func _on_skill_tree_ui_closed() -> void:
	## Handle skill tree UI closed
	skill_tree_closed.emit()


# =============================================================================
# SKILL EFFECT APPLICATION
# =============================================================================


func get_skill_multiplier(skill_id: String, effect_key: String, default: float = 1.0) -> float:
	## Get skill effect multiplier
	if not skill_tree_manager:
		return default

	var value = skill_tree_manager.get_skill_effect(skill_id, effect_key)
	if value == null:
		return default

	return float(value)


func has_skill_effect(skill_id: String, effect_key: String) -> bool:
	## Check if skill effect is active
	if not skill_tree_manager:
		return false

	var value = skill_tree_manager.get_skill_effect(skill_id, effect_key)
	return value != null and value


func get_skill_value(skill_id: String, effect_key: String, default: Variant = null) -> Variant:
	## Get skill effect value
	if not skill_tree_manager:
		return default

	var value = skill_tree_manager.get_skill_effect(skill_id, effect_key)
	if value == null:
		return default

	return value


# =============================================================================
# CONVENIENCE METHODS FOR COMMON SKILLS
# =============================================================================


func get_damage_multiplier() -> float:
	## Get total damage multiplier from skills
	var multiplier := 1.0
	multiplier *= get_skill_multiplier("weapon_mastery", "damage_multiplier", 1.0)
	return multiplier


func get_crit_chance() -> float:
	## Get critical hit chance from skills
	return get_skill_multiplier("critical_strike", "crit_chance", 0.0)


func get_fire_rate_multiplier() -> float:
	## Get fire rate multiplier from skills
	return get_skill_multiplier("rapid_fire", "fire_rate_multiplier", 1.0)


func get_sprint_multiplier() -> float:
	## Get sprint speed multiplier from skills
	return get_skill_multiplier("sprint_master", "sprint_multiplier", 1.0)


func can_double_jump() -> bool:
	## Check if double jump is unlocked
	return has_skill_effect("double_jump", "enable_double_jump")


func can_dash() -> bool:
	## Check if dash is unlocked
	return has_skill_effect("dash", "enable_dash")


func get_dash_cooldown() -> float:
	## Get dash cooldown from skills
	return get_skill_value("dash", "dash_cooldown", 5.0)


func get_max_health_bonus() -> int:
	## Get max health bonus from skills
	return int(get_skill_value("tough_skin", "max_health_bonus", 0))


func get_damage_reduction() -> float:
	## Get damage reduction from skills
	return get_skill_multiplier("armor_plating", "damage_reduction", 0.0)


func get_health_regen_per_second() -> float:
	## Get health regeneration from skills
	return get_skill_value("regeneration", "health_regen_per_second", 0.0)


func get_ammo_pickup_multiplier() -> float:
	## Get ammo pickup multiplier from skills
	return get_skill_multiplier("scavenger", "ammo_pickup_multiplier", 1.0)


func get_health_pickup_multiplier() -> float:
	## Get health pickup multiplier from skills
	return get_skill_multiplier("medic", "health_pickup_multiplier", 1.0)
