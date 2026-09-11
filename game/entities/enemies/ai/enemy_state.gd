class_name EnemyState
extends Node

var controller: EnemyAIController


## Lifecycle hooks are intentionally empty; concrete states opt into only the
## callbacks they need.
func enter() -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
