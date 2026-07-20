extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name FlightPowerup

@export var duration: float = 30.0


func _ready() -> void:
	pickup_name = "powerup_flight"
	description = "Flight for " + str(duration) + "s"

	use_icon = true
	icon_text = "🪽"
	icon_color = Color(0.6, 0.9, 1.0)

	super._ready()

	if vertical_ray:
		_update_ray_color(Color(0.6, 0.9, 1.0), 4.0)
	if base_glow:
		base_glow.light_color = Color(0.6, 0.9, 1.0)
		base_glow.light_energy = 0.7


func _on_pickup(player: CharacterBody3D) -> void:
	# Enable flying
	if "can_fly" in player:
		player.can_fly = true

	# Show powerup flash
	var blood_overlay: Control = player.blood_overlay
	if blood_overlay and blood_overlay.has_method("show_flash"):
		blood_overlay.show_flash(Color(0.6, 0.9, 1.0), 0.3, 0.5)

	# Reset after duration
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(
		func() -> void:
			if is_instance_valid(player):
				if "can_fly" in player:
					# Only disable if flymode cheat isn't active
					var gs := GameManager.get_core_system("gameplay") as GameplaySvc
					if gs and gs.match_service and not gs.match_service.flymode:
						player.can_fly = false
	)
