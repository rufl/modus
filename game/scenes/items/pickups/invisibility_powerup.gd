extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name InvisibilityPowerup

@export var duration: float = 30.0


func _ready() -> void:
	pickup_name = "powerup_invisibility"
	description = "Invisibility for " + str(duration) + "s"

	use_icon = true
	icon_text = "👁️"
	icon_color = Color(0.5, 0.3, 0.8)

	super._ready()

	if vertical_ray:
		_update_ray_color(Color(0.5, 0.3, 0.8), 3.5)
	if base_glow:
		base_glow.light_color = Color(0.5, 0.3, 0.8)
		base_glow.light_energy = 0.6


func _on_pickup(player: CharacterBody3D) -> void:
	# Enable invisibility
	if "is_invisible" in player:
		player.is_invisible = true

	# Make player semi-transparent visually
	var mesh: MeshInstance3D = player.get_node_or_null("MeshInstance3D")
	var original_transparency: float = 1.0
	if mesh:
		original_transparency = mesh.transparency
		mesh.transparency = 0.8  # Very transparent

	# Show powerup flash
	var blood_overlay: Control = player.blood_overlay
	if blood_overlay and blood_overlay.has_method("show_flash"):
		blood_overlay.show_flash(Color(0.5, 0.3, 0.8), 0.3, 0.5)

	# Reset after duration
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(
		func() -> void:
			if is_instance_valid(player):
				if "is_invisible" in player:
					player.is_invisible = false
				if is_instance_valid(mesh):
					mesh.transparency = original_transparency
	)
