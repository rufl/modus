extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name ArmorPickup

enum ArmorTier { SHARD, SMALL, MEDIUM, LARGE, MEGA, SUPER }

const TIER_CONFIG: Dictionary = {
	ArmorTier.SHARD: [5, "Armor Shard", "🛡", Color(0.2, 0.8, 0.2), false, 100],
	ArmorTier.SMALL: [10, "Armor Bonus", "🛡", Color(0.3, 0.9, 0.3), false, 100],
	ArmorTier.MEDIUM: [25, "Security Armor", "🛡", Color(0.2, 0.7, 0.2), false, 100],
	ArmorTier.LARGE: [50, "Combat Armor", "🛡", Color(0.8, 0.8, 0.2), false, 100],
	ArmorTier.MEGA: [100, "Red Armor", "🛡", Color(1.0, 0.2, 0.2), true, 150],
	ArmorTier.SUPER: [200, "Super Armor", "🛡", Color(1.0, 0.8, 0.0), true, 200],
}

@export var tier: ArmorTier = ArmorTier.MEDIUM


func _ready() -> void:
	var config: Array = TIER_CONFIG[tier]
	var armor_amount: int = config[0]

	pickup_name = config[1]
	description = "+" + str(armor_amount) + " Armor"

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
	if not ("armor" in player and "max_armor" in player):
		return

	var config: Array = TIER_CONFIG[tier]
	var armor_amount: int = config[0]
	var can_overarmor: bool = config[4]
	var max_percent: int = config[5]

	var max_armor: int = player.max_armor
	var overarmor_cap: int = int(max_armor * max_percent / 100.0)

	if can_overarmor:
		# Red/Super armor can go over max
		player.armor = mini(player.armor + armor_amount, overarmor_cap)
	else:
		# Normal armor capped at max
		player.armor = mini(player.armor + armor_amount, max_armor)

	# Gold screen flash (more intense for bigger armor)
	var blood_overlay: Control = player.blood_overlay
	if blood_overlay and blood_overlay.has_method("show_powerup_flash"):
		var intensity: float = 0.15 + (tier * 0.05)
		blood_overlay.show_powerup_flash(intensity)


## Factory methods for spawning specific tiers


static func create_shard() -> ArmorPickup:
	var pickup: ArmorPickup = ArmorPickup.new()
	pickup.tier = ArmorTier.SHARD
	return pickup


static func create_combat_armor() -> ArmorPickup:
	var pickup: ArmorPickup = ArmorPickup.new()
	pickup.tier = ArmorTier.LARGE
	return pickup


static func create_red_armor() -> ArmorPickup:
	var pickup: ArmorPickup = ArmorPickup.new()
	pickup.tier = ArmorTier.MEGA
	return pickup


static func create_super_armor() -> ArmorPickup:
	var pickup: ArmorPickup = ArmorPickup.new()
	pickup.tier = ArmorTier.SUPER
	return pickup
