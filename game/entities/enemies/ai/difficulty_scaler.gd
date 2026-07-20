extends Node
class_name DifficultyScaler

signal difficulty_scaled(scale_factor: float)
signal elite_status_changed(is_elite: bool)

const TIER_COLORS: Dictionary = {
	0: Color(0.8, 0.8, 0.8),  # Normal - Gray
	1: Color(0.2, 0.8, 0.2),  # Veteran - Green
	2: Color(0.2, 0.4, 1.0),  # Elite - Blue
	3: Color(1.0, 0.6, 0.0)  # Boss - Orange
}
const TIER_NAMES: Dictionary = {0: "Normal", 1: "Veteran", 2: "Elite", 3: "Boss"}

@export_group("Scaling Settings")
@export var enable_scaling: bool = true
@export var base_level: int = 1
@export var elite_chance: float = 0.1
@export var elite_stat_multiplier: float = 1.5
@export_group("Tier System")
@export var use_tier_colors: bool = true
@export var tier_level: int = 0  # 0=Normal, 1=Veteran, 2=Elite, 3=Boss
@export_group("Scaling Multipliers")
@export var health_per_level: float = 0.1
@export var damage_per_level: float = 0.08
@export var speed_per_level: float = 0.05

var is_elite: bool = false
var current_level: int = 1
var scale_factor: float = 1.0


func _ready() -> void:
	# Only determine elite status on server
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Determine if this enemy should be elite (if tier not manually set)
	if tier_level == 0 and randf() < elite_chance:
		tier_level = 2  # Elite tier
		is_elite = true
		elite_status_changed.emit(true)
	elif tier_level >= 2:
		is_elite = true


func calculate_scaling(player_level: int) -> Dictionary:
	## Calculate stat multipliers based on player level
	if not enable_scaling:
		return {"health": 1.0, "damage": 1.0, "speed": 1.0, "level": base_level}

	# Calculate level difference
	var level_diff: int = player_level - base_level
	current_level = max(1, base_level + level_diff)

	# Calculate multipliers
	var health_mult: float = 1.0 + (level_diff * health_per_level)
	var damage_mult: float = 1.0 + (level_diff * damage_per_level)
	var speed_mult: float = 1.0 + (level_diff * speed_per_level)

	# Apply elite multiplier if elite
	if is_elite:
		health_mult *= elite_stat_multiplier
		damage_mult *= elite_stat_multiplier
		speed_mult *= 1.2  # Elite enemies are slightly faster

	# Clamp multipliers to reasonable ranges
	health_mult = clamp(health_mult, 0.5, 5.0)
	damage_mult = clamp(damage_mult, 0.5, 3.0)
	speed_mult = clamp(speed_mult, 0.8, 2.0)

	scale_factor = (health_mult + damage_mult + speed_mult) / 3.0
	difficulty_scaled.emit(scale_factor)

	return {
		"health": health_mult, "damage": damage_mult, "speed": speed_mult, "level": current_level
	}


func get_tier_color() -> Color:
	## Get color based on enemy tier
	if not use_tier_colors:
		return Color.WHITE

	return TIER_COLORS.get(tier_level, Color.WHITE)


func get_tier_name() -> String:
	## Get tier name for display
	return TIER_NAMES.get(tier_level, "Normal")


func get_elite_glow_color() -> Color:
	## Get glow color for elite enemies
	if not is_elite:
		return Color.TRANSPARENT

	# Elite enemies have a golden glow
	return Color(1.0, 0.8, 0.2, 0.5)


func get_level() -> int:
	## Get current enemy level
	return current_level


func is_elite_enemy() -> bool:
	## Check if this enemy is elite
	return is_elite


func get_difficulty_info() -> Dictionary:
	## Get difficulty scaling information
	return {
		"is_elite": is_elite,
		"level": current_level,
		"scale_factor": scale_factor,
		"base_level": base_level,
		"tier": tier_level,
		"tier_name": get_tier_name()
	}
