extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name QuadDamagePowerup

@export var duration: float = 30.0
@export var damage_mult: float = 4.0


func _ready() -> void:
	pickup_name = "powerup_quad"
	description = str(int(damage_mult)) + "x damage for " + str(duration) + "s"

	use_icon = true
	icon_text = "Q"
	icon_color = Color(0.3, 0.3, 1.0)

	super._ready()

	if vertical_ray:
		_update_ray_color(Color(0.3, 0.3, 1.0), 5.0)
	if base_glow:
		base_glow.light_color = Color(0.3, 0.3, 1.0)
		base_glow.light_energy = 1.0


func _on_pickup(player: CharacterBody3D) -> void:
	if "damage_multiplier" in player:
		player.damage_multiplier = damage_mult

	# Show powerup flash - iconic blue
	var blood_overlay: Control = player.blood_overlay
	if blood_overlay and blood_overlay.has_method("show_flash"):
		blood_overlay.show_flash(Color(0.3, 0.3, 1.0), 0.5, 0.7)

	# Service-based screen flash
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.effects and gs.effects.has_method("screen_flash"):
		gs.effects.screen_flash(Color(0.2, 0.2, 1.0, 0.5), 0.4)

	# Reset after duration
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(
		func() -> void:
			if is_instance_valid(player):
				if "damage_multiplier" in player:
					player.damage_multiplier = 1.0
	)
