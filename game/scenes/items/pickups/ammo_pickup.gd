extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name AmmoPickup

@export var ammo_amount: int = 30


func _ready() -> void:
	pickup_name = "pickup_ammo_box"
	description = "+" + str(ammo_amount) + " Ammo"

	# Icon configuration
	use_icon = true
	icon_text = "🔫"
	icon_color = Color.GRAY

	super._ready()

	# Grey ray for consumables
	if vertical_ray:
		_update_ray_color(Color.GRAY, 2.0)
	if base_glow:
		base_glow.light_color = Color.GRAY
		base_glow.light_energy = 0.3


func _on_pickup(player: CharacterBody3D) -> void:
	if player.has_method("refill_ammo"):
		player.refill_ammo()
	elif "weapon_ammo" in player and "current_weapon_index" in player:
		var idx: int = player.current_weapon_index
		if idx < player.weapon_ammo.size():
			player.weapon_ammo[idx][1] += ammo_amount  # Add to reserve

	# Blue screen flash for ammo pickup
	var blood_overlay: Control = player.blood_overlay
	if blood_overlay and blood_overlay.has_method("show_ammo_flash"):
		blood_overlay.show_ammo_flash()
