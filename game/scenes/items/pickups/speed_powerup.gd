extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name SpeedPowerup

@export var duration: float = 30.0
@export var speed_mult: float = 2.0


func _ready() -> void:
	pickup_name = "powerup_speed"
	description = str(speed_mult) + "x speed for " + str(int(duration)) + "s"

	use_icon = true
	icon_text = "⚡"
	icon_color = Color(1.0, 0.6, 0.0)

	super._ready()

	if vertical_ray:
		_update_ray_color(Color(1.0, 0.6, 0.0), 3.5)
	if base_glow:
		base_glow.light_color = Color(1.0, 0.6, 0.0)
		base_glow.light_energy = 0.6


func _on_pickup(player: CharacterBody3D) -> void:
	if "speed_multiplier" in player:
		player.speed_multiplier = speed_mult

		# Show powerup flash
		var blood_overlay: Control = player.blood_overlay
		if blood_overlay and blood_overlay.has_method("show_flash"):
			blood_overlay.show_flash(Color(1.0, 0.6, 0.0), 0.3, 0.5)

		# Reset after duration
		var timer: SceneTreeTimer = get_tree().create_timer(duration)
		timer.timeout.connect(
			func() -> void:
				if is_instance_valid(player):
					player.speed_multiplier = 1.0
		)
