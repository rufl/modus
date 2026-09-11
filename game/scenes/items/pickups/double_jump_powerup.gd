extends PickupBase
class_name DoubleJumpPowerup


func _ready() -> void:
	pickup_name = "powerup_double_jump"
	description = "Grants the ability to double jump until death!"
	# Use icon if desired, or text
	use_icon = true
	icon_text = "🐇"  # Rabbit/Jump icon
	icon_color = Color(0.2, 0.8, 1.0)  # Cyan
	super._ready()


func _on_pickup(player: CharacterBody3D) -> void:
	if "has_double_jump" in player and not player.has_double_jump:
		player.has_double_jump = true
