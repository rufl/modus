extends Node3D

## Mock target for testing damage application
## Stores the last damage received for verification

var last_damage_info: DamageInfo = null
var total_damage_received: float = 0.0
var damage_count: int = 0


func take_damage(damage_info: DamageInfo) -> void:
	last_damage_info = damage_info
	total_damage_received += damage_info.final_damage
	damage_count += 1


func reset() -> void:
	last_damage_info = null
	total_damage_received = 0.0
	damage_count = 0
