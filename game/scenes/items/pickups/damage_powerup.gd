extends "res://game/scenes/items/pickups/pickup_base.gd"
class_name DamagePowerup

@export var duration: float = 10.0
@export var damage_mult: float = 2.0


func _ready() -> void:
	pickup_name = "powerup_damage"
	description = str(damage_mult) + "x damage for " + str(duration) + "s"
	super._ready()


func _on_pickup(player: CharacterBody3D) -> void:
	# Store damage multiplier on player
	player.set("damage_multiplier", damage_mult)

	# Reset after duration
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	timer.timeout.connect(
		func() -> void:
			if is_instance_valid(player):
				player.set("damage_multiplier", 1.0)
	)
