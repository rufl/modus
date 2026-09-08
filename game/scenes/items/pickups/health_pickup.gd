extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name HealthPickup

enum HealthTier { SHARD, SMALL, MEDIUM, LARGE, MEGA, SUPER }

const TIER_CONFIG: Dictionary = {
	HealthTier.SHARD: [5, "Health Shard", "+", Color(0.2, 0.8, 0.2), false, 100],
	HealthTier.SMALL: [10, "Stimpack", "+", Color(0.3, 0.9, 0.3), false, 100],
	HealthTier.MEDIUM: [25, "Medkit", "+", Color(0.2, 0.7, 0.2), false, 100],
	HealthTier.LARGE: [50, "Large Medkit", "+", Color(0.8, 0.8, 0.2), false, 100],
	HealthTier.MEGA: [100, "Megahealth", "+", Color(0.2, 0.5, 1.0), true, 150],
	HealthTier.SUPER: [200, "Super Health", "+", Color(1.0, 0.8, 0.0), true, 200],
}

@export var tier: HealthTier = HealthTier.MEDIUM


func _extend_synchronizer_config(config: SceneReplicationConfig) -> void:
	super._extend_synchronizer_config(config)
	config.add_property(".:tier")


func _ready() -> void:
	var config: Array = TIER_CONFIG[tier]
	var heal_amount: int = config[0]

	pickup_name = config[1]
	description = "+" + str(heal_amount) + " HP"

	# Icon configuration
	use_icon = true
	icon_text = config[2]
	icon_color = config[3]

	super._ready()

	# Visual scaling based on tier (bigger = more valuable)
	var scale_factor: float = 0.8 + (tier * 0.15)
	if icon_node:
		icon_node.font_size = int(48 * scale_factor)

	# Ray color based on tier
	var ray_height: float = 1.5 + (tier * 0.5)
	if vertical_ray:
		_update_ray_color(config[3], ray_height)
	if base_glow:
		base_glow.light_color = config[3]
		base_glow.light_energy = 0.3 + (tier * 0.1)


func _on_pickup(player: CharacterBody3D) -> void:
	if not "health" in player:
		return

	var config: Array = TIER_CONFIG[tier]
	var heal_amount: int = config[0]
	var can_overheal: bool = config[4]
	var max_overheal_percent: int = config[5]

	var max_hp: int = player.max_health if "max_health" in player else 100
	var overheal_cap: int = int(max_hp * max_overheal_percent / 100.0)

	if can_overheal:
		# Megahealth/Super can go over max
		player.health = mini(player.health + heal_amount, overheal_cap)
	else:
		# Normal healing capped at max
		player.health = mini(player.health + heal_amount, max_hp)

	# Green screen flash (more intense for bigger heals)
	var blood_overlay: Control = player.blood_overlay
	if blood_overlay and blood_overlay.has_method("show_health_flash"):
		var intensity: float = 0.15 + (tier * 0.05)
		blood_overlay.show_health_flash(intensity)


## Factory methods for spawning specific tiers


static func create_shard() -> HealthPickup:
	var pickup: HealthPickup = HealthPickup.new()
	pickup.tier = HealthTier.SHARD
	return pickup


static func create_stimpack() -> HealthPickup:
	var pickup: HealthPickup = HealthPickup.new()
	pickup.tier = HealthTier.SMALL
	return pickup


static func create_medkit() -> HealthPickup:
	var pickup: HealthPickup = HealthPickup.new()
	pickup.tier = HealthTier.MEDIUM
	return pickup


static func create_megahealth() -> HealthPickup:
	var pickup: HealthPickup = HealthPickup.new()
	pickup.tier = HealthTier.MEGA
	return pickup
