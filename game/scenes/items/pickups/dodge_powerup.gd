extends PickupBase
class_name DodgePowerup


func _ready() -> void:
	pickup_name = "powerup_dodge"
	description = "Grants dash ability! (Shift/Double-tap)"
	use_icon = true
	icon_text = "⚡"  # Zap
	icon_color = Color(1.0, 0.8, 0.2)  # Gold/Orange
	super._ready()


func _on_pickup(player: CharacterBody3D) -> void:
	if "has_dodge" in player and not player.has_dodge:
		player.has_dodge = true
