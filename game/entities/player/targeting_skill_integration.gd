extends Node
class_name TargetingSkillIntegration

signal target_info_updated(target_count: int, has_crosshair_target: bool)
signal smart_target_selected(target: Node3D)
signal aoe_targets_updated(targets: Array[Node3D])

@export_group("Smart Targeting")
@export var enable_smart_targeting: bool = true
@export var prefer_closer_enemies: bool = true
@export var prefer_lower_health: bool = true
@export var smart_weight_distance: float = 0.6
@export var smart_weight_health: float = 0.4
@export_group("Debug")
@export var debug_logging: bool = false

var player: CharacterBody3D = null
var targeting_system: Node = null
var aoe_system: Node = null
var current_active_skill: Node = null
var is_skill_targeting_active: bool = false
var aoe_targets: Array[Node3D] = []


func _exit_tree() -> void:
	# === SIGNAL HYGIENE: Disconnect signals to prevent memory leaks ===
	if targeting_system:
		if (
			targeting_system.has_signal("target_acquired")
			and targeting_system.target_acquired.is_connected(_on_crosshair_target_acquired)
		):
			targeting_system.target_acquired.disconnect(_on_crosshair_target_acquired)
		if (
			targeting_system.has_signal("target_lost")
			and targeting_system.target_lost.is_connected(_on_crosshair_target_lost)
		):
			targeting_system.target_lost.disconnect(_on_crosshair_target_lost)

	if (
		aoe_system
		and aoe_system.has_signal("targets_updated")
		and aoe_system.targets_updated.is_connected(_on_aoe_targets_updated)
	):
		aoe_system.targets_updated.disconnect(_on_aoe_targets_updated)


func _ready() -> void:
	# Get player reference
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("[TargetingSkillIntegration] Must be child of player")
		return

	# Find targeting systems
	_find_targeting_systems()

	_log("Integration initialized")


func _find_targeting_systems() -> void:
	## Find and connect to targeting systems
	# Look for TargetingSystem
	targeting_system = player.get_node_or_null("TargetingSystem")
	if targeting_system:
		if targeting_system.has_signal("target_acquired"):
			targeting_system.target_acquired.connect(_on_crosshair_target_acquired)
		if targeting_system.has_signal("target_lost"):
			targeting_system.target_lost.connect(_on_crosshair_target_lost)

	# Look for AoE system
	aoe_system = player.get_node_or_null("AoETargetingSystem")
	if aoe_system:
		if aoe_system.has_signal("targets_updated"):
			aoe_system.targets_updated.connect(_on_aoe_targets_updated)


func _process(_delta: float) -> void:
	if not is_skill_targeting_active:
		return

	# Update target info for UI
	_update_target_info()


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================


func _on_crosshair_target_acquired(enemy: Node3D) -> void:
	## Handle crosshair target acquired
	if not enemy:
		return

	# Apply crosshair highlight (highest priority - red)
	if enemy.has_node("HighlightComponent"):
		var hc: Node = enemy.get_node("HighlightComponent")
		if hc.has_method("set_crosshair_highlight"):
			hc.set_crosshair_highlight(true)
	elif enemy.has_method("set_crosshair_highlight"):
		enemy.set_crosshair_highlight(true)

	_update_target_info()


func _on_crosshair_target_lost(previous_enemy: Node3D) -> void:
	## Handle crosshair target lost
	if not previous_enemy:
		return

	# Remove crosshair highlight
	if previous_enemy.has_node("HighlightComponent"):
		var hc: Node = previous_enemy.get_node("HighlightComponent")
		if hc.has_method("set_crosshair_highlight"):
			hc.set_crosshair_highlight(false)
	elif previous_enemy.has_method("set_crosshair_highlight"):
		previous_enemy.set_crosshair_highlight(false)

	_update_target_info()


func _on_aoe_targets_updated(enemies: Array) -> void:
	## Handle AoE targets updated
	if not is_skill_targeting_active:
		return

	aoe_targets.clear()

	for enemy: Node in enemies:
		if not enemy:
			continue

		var enemy_node: Node3D = enemy as Node3D
		if not enemy_node:
			continue

		aoe_targets.append(enemy_node)

		# Only apply AoE highlight if not already crosshair target
		var is_crosshair_target: bool = _is_crosshair_target(enemy_node)

		if not is_crosshair_target:
			if enemy_node.has_node("HighlightComponent"):
				var hc: Node = enemy_node.get_node("HighlightComponent")
				if hc.has_method("set_aoe_highlight"):
					hc.set_aoe_highlight(true)
			elif enemy_node.has_method("set_aoe_highlight"):
				enemy_node.set_aoe_highlight(true)

	aoe_targets_updated.emit(aoe_targets)
	_update_target_info()


# =============================================================================
# PUBLIC API
# =============================================================================


func activate_skill_targeting(skill: Node, shape: int = 0, params: Dictionary = {}) -> void:
	## Activate skill targeting mode with optional AoE
	current_active_skill = skill
	is_skill_targeting_active = true

	# Enable AoE if available
	if aoe_system and aoe_system.has_method("enable_aoe"):
		aoe_system.enable_aoe(shape, params)

	_log("Skill targeting activated")


func deactivate_skill_targeting() -> void:
	## Deactivate skill targeting mode
	current_active_skill = null
	is_skill_targeting_active = false

	# Clear AoE highlights from previous targets
	for enemy: Node3D in aoe_targets:
		if is_instance_valid(enemy):
			if enemy.has_node("HighlightComponent"):
				var hc: Node = enemy.get_node("HighlightComponent")
				if hc.has_method("set_aoe_highlight"):
					hc.set_aoe_highlight(false)
			elif enemy.has_method("set_aoe_highlight"):
				enemy.set_aoe_highlight(false)

	aoe_targets.clear()

	# Disable AoE if available
	if aoe_system and aoe_system.has_method("disable_aoe"):
		aoe_system.disable_aoe()

	_log("Skill targeting deactivated")


func get_all_targets() -> Array[Node3D]:
	## Get all current targets (crosshair + AoE)
	var targets: Array[Node3D] = []

	# Add crosshair target if exists
	var crosshair_target: Node3D = get_crosshair_target()
	if crosshair_target:
		targets.append(crosshair_target)

	# Add AoE targets
	for target: Node3D in aoe_targets:
		if is_instance_valid(target) and not targets.has(target):
			targets.append(target)

	return targets


func get_target_count() -> int:
	## Get total number of targets
	return get_all_targets().size()


func has_crosshair_target() -> bool:
	## Check if crosshair is targeting an enemy
	if targeting_system and targeting_system.has_method("has_target"):
		return targeting_system.has_target()
	return false


func get_crosshair_target() -> Node3D:
	## Get current crosshair target
	if targeting_system and targeting_system.has_method("get_current_target"):
		return targeting_system.get_current_target()
	return null


func get_aoe_targets() -> Array[Node3D]:
	## Get current AoE targets
	return aoe_targets


func get_smart_target() -> Node3D:
	## Get best target using smart targeting algorithm
	if not enable_smart_targeting:
		return get_crosshair_target()

	var all_targets: Array[Node3D] = get_all_targets()
	if all_targets.is_empty():
		return null

	if all_targets.size() == 1:
		return all_targets[0]

	# Calculate scores for each target
	var best_target: Node3D = null
	var best_score: float = -INF

	for target: Node3D in all_targets:
		var score: float = _calculate_target_score(target)
		if score > best_score:
			best_score = score
			best_target = target

	if best_target:
		smart_target_selected.emit(best_target)

	return best_target


func update_aoe_params(params: Dictionary) -> void:
	## Update AoE parameters for active skill
	if not is_skill_targeting_active or not aoe_system:
		return

	if aoe_system.has_method("update_shape_params"):
		aoe_system.update_shape_params(params)


func set_aoe_preview_position(position: Vector3) -> void:
	## Update AoE preview position (for ground-targeted skills)
	if not is_skill_targeting_active or not aoe_system:
		return

	if aoe_system.has_method("set_preview_position"):
		aoe_system.set_preview_position(position)


func is_targeting_active() -> bool:
	## Check if skill targeting is currently active
	return is_skill_targeting_active


func get_active_skill() -> Node:
	## Get currently active skill
	return current_active_skill


func get_target_info_text() -> String:
	## Get formatted target info text for UI
	var target_count: int = get_target_count()
	var has_crosshair: bool = has_crosshair_target()

	if target_count == 0:
		return "No Targets"

	var text: String = "Enemies: %d" % target_count

	if has_crosshair:
		var crosshair_target: Node3D = get_crosshair_target()
		if crosshair_target and crosshair_target.has_method("get_health_percentage"):
			var health_pct: float = crosshair_target.get_health_percentage() * 100.0
			text += " | Target: %.0f%% HP" % health_pct

	return text


# =============================================================================
# PRIVATE METHODS
# =============================================================================


func _is_crosshair_target(enemy: Node3D) -> bool:
	## Check if enemy is the current crosshair target
	var crosshair: Node3D = get_crosshair_target()
	return crosshair == enemy


func _update_target_info() -> void:
	## Update and emit target information for UI
	var target_count: int = get_target_count()
	var has_crosshair: bool = has_crosshair_target()

	target_info_updated.emit(target_count, has_crosshair)


func _calculate_target_score(target: Node3D) -> float:
	## Calculate targeting priority score for an enemy
	if not target or not player:
		return -INF

	var score: float = 0.0

	# Distance score (closer is better)
	if prefer_closer_enemies:
		var distance: float = player.global_position.distance_to(target.global_position)
		var max_distance: float = 50.0
		var distance_score: float = 1.0 - clamp(distance / max_distance, 0.0, 1.0)
		score += distance_score * smart_weight_distance

	# Health score (lower health is better)
	if prefer_lower_health and target.has_method("get_health_percentage"):
		var health_pct: float = target.get_health_percentage()
		var health_score: float = 1.0 - health_pct
		score += health_score * smart_weight_health

	# Bonus for crosshair target
	if _is_crosshair_target(target):
		score += 0.5

	return score


func _log(message: String) -> void:
	## Debug logging
	if debug_logging:
		GameManager.get_core_system("logger").debug(
			"[TargetingSkillIntegration] %s" % message, "TargetingSkill"
		)
