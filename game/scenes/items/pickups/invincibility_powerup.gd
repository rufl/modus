extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name InvincibilityPowerup

@export var duration: float = 30.0


func _ready() -> void:
	pickup_name = "powerup_invincibility"
	description = "Invincibility for " + str(duration) + "s"

	use_icon = true
	icon_text = "⭐"
	icon_color = Color(1.0, 0.8, 0.0)

	super._ready()

	if vertical_ray:
		_update_ray_color(Color.GOLD, 4.0)
	if base_glow:
		base_glow.light_color = Color.GOLD
		base_glow.light_energy = 0.8


func _on_pickup(player: CharacterBody3D) -> void:
	# Enable invincibility via HealthComponent
	var health_comp: Node = player.get_node_or_null("HealthComponent")
	if health_comp and "invincible" in health_comp:
		health_comp.invincible = true

		# Show powerup flash
		var blood_overlay: Control = player.blood_overlay
		if blood_overlay and blood_overlay.has_method("show_flash"):
			blood_overlay.show_flash(Color.GOLD, 0.4, 0.6)

		# Service-based screen flash
		var g_svc := GameManager.get_core_system("gameplay") as GameplaySvc
		if g_svc and g_svc.effects and g_svc.effects.has_method("screen_flash"):
			g_svc.effects.screen_flash(Color(1.0, 0.9, 0.2, 0.4), 0.3)

		# Reset after duration
		var timer: SceneTreeTimer = get_tree().create_timer(duration)
		timer.timeout.connect(
			func() -> void:
				if is_instance_valid(player) and is_instance_valid(health_comp):
					# Only disable if godmode isn't active
					var g_svc_inner := GameManager.get_core_system("gameplay") as GameplaySvc
					if (
						g_svc_inner
						and g_svc_inner.match_service
						and not g_svc_inner.match_service.godmode
					):
						health_comp.invincible = false
		)
