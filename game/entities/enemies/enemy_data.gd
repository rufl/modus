@tool
class_name EnemyData
extends Resource

const JSONHelperClass = preload("res://game/core/json_helper.gd")

@export var tier: int = 1
@export var enemy_name: String = "Grunt"
@export var health: int = 3
@export var damage: int = 1
@export var speed: float = 4.0
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var color: Color = Color(0.8, 0.15, 0.15, 1.0)
@export var loot_chance: float = 0.5
@export var can_infight: bool = true
@export var aggression: float = 0.5
@export var attack_type: String = "melee"
@export var projectile_speed: float = 20.0
@export var can_fly: bool = false
@export var hover_height: float = 3.0
@export var can_jump: bool = false
@export var jump_height: float = 2.0
@export var can_dash: bool = false
@export var dash_speed: float = 10.0
@export var dash_cooldown: float = 3.0
@export var patrol_type: String = "random"  # random, static, circuit
@export var patrol_radius: float = 10.0
@export var patrol_hold_time: float = 2.0
@export var sight_range: float = 15.0
@export var sight_fov: float = 90.0
@export var is_blind: bool = false
@export var is_deaf: bool = false
@export var role: String = "basic"
@export var flee_threshold: float = 0.0
@export var uses_cover: bool = false
@export var scale_multiplier: float = 1.0
@export var summon_scene_path: String = ""
@export var summon_cooldown: float = 10.0
@export var max_summons: int = 3
@export var heal_amount: int = 1
@export var heal_range: float = 8.0
@export var heal_cooldown: float = 3.0
@export var rally_range: float = 10.0
@export var rally_damage_boost: float = 1.5
@export var rally_speed_boost: float = 1.3
@export var accuracy: float = 1.0
@export var reaction_time: float = 0.0
@export var combat_style: String = "balanced"
@export var weapon_preference: String = "any"


func export_to_json5() -> String:
	var data := {
		"name": enemy_name,
		"tier": tier,
		"role": role,
		"stats":
		{
			"health": health,
			"damage": damage,
			"move_speed": speed,
			"attack_range": attack_range,
			"attack_cooldown": attack_cooldown,
			"aggression": aggression
		},
		"movement":
		{
			"can_fly": can_fly,
			"hover_height": hover_height,
			"can_jump": can_jump,
			"jump_height": jump_height,
			"can_dash": can_dash,
			"dash_speed": dash_speed,
			"dash_cooldown": dash_cooldown
		},
		"patrol": {"type": patrol_type, "radius": patrol_radius, "hold_time": patrol_hold_time},
		"perception": {"sight_range": sight_range, "fov": sight_fov},
		"ai_config":
		{
			"behavior": "aggressive",  # Default, could be expanded
			"flee_threshold": flee_threshold,
			"uses_cover": uses_cover,
			"accuracy": accuracy,
			"reaction_time": reaction_time,
			"combat_style": combat_style,
			"weapon_preference": weapon_preference
		},
		"visuals": {"color": "#" + color.to_html(false), "scale": scale_multiplier},
		"loot": {"loot_chance": loot_chance}
	}

	# Add abilities if present
	if role == "healer" or role == "summoner" or role == "rally":
		data.abilities = {}
		if role == "healer":
			data.abilities.heal_allies = true
			data.abilities.heal_radius = heal_range
			data.abilities.heal_amount = heal_amount
		if role == "summoner":
			data.abilities.summon = true
			data.abilities.summon_scene = summon_scene_path
			data.abilities.max_summons = max_summons

	return JSONHelperClass.safe_stringify(data, "\t")


## Import from JSON dictionary


static func from_json(json_data: Dictionary) -> EnemyData:
	var enemy := EnemyData.new()

	enemy.enemy_name = json_data.get("name", "Unknown")
	enemy.tier = json_data.get("tier", 1)
	enemy.role = json_data.get("role", "basic")

	if "stats" in json_data:
		var stats: Dictionary = json_data.stats
		enemy.health = stats.get("health", 3)
		enemy.damage = stats.get("damage", 1)
		enemy.speed = stats.get("move_speed", 4.0)
		enemy.attack_range = stats.get("attack_range", 2.0)
		enemy.attack_cooldown = stats.get("attack_cooldown", 1.5)
		enemy.aggression = stats.get("aggression", 0.5)

	if "movement" in json_data:
		var mov: Dictionary = json_data.movement
		enemy.can_fly = mov.get("can_fly", false)
		enemy.hover_height = mov.get("hover_height", 3.0)
		enemy.can_jump = mov.get("can_jump", false)
		enemy.jump_height = mov.get("jump_height", 2.0)
		enemy.can_dash = mov.get("can_dash", false)
		enemy.dash_speed = mov.get("dash_speed", 10.0)
		enemy.dash_cooldown = mov.get("dash_cooldown", 3.0)

	if "patrol" in json_data:
		var pat: Dictionary = json_data.patrol
		enemy.patrol_type = pat.get("type", "random")
		enemy.patrol_radius = pat.get("radius", 10.0)
		enemy.patrol_hold_time = pat.get("hold_time", 2.0)

	if "perception" in json_data:
		var per: Dictionary = json_data.perception
		enemy.sight_range = per.get("sight_range", 15.0)
		enemy.sight_fov = per.get("fov", 90.0)
		enemy.is_blind = per.get("is_blind", false)
		enemy.is_deaf = per.get("is_deaf", false)

	if "ai_config" in json_data:
		var ai: Dictionary = json_data.ai_config
		enemy.flee_threshold = ai.get("flee_threshold", 0.0)
		enemy.uses_cover = ai.get("uses_cover", false)
		enemy.accuracy = ai.get("accuracy", 1.0)
		enemy.reaction_time = ai.get("reaction_time", 0.0)
		enemy.combat_style = ai.get("combat_style", "balanced")
		enemy.weapon_preference = ai.get("weapon_preference", "any")

	if "visuals" in json_data:
		var visuals: Dictionary = json_data.visuals
		if "color" in visuals:
			enemy.color = Color(visuals.color)
		enemy.scale_multiplier = visuals.get("scale", 1.0)

	if "loot" in json_data:
		enemy.loot_chance = json_data.loot.get("loot_chance", 0.5)

	return enemy
