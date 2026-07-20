class_name EnemyIdleState
extends EnemyState

@export var idle_duration: float = 2.0
@export var can_patrol: bool = false

var _timer: float = 0.0


func enter() -> void:
	if controller.movement:
		controller.movement.stop()
	_timer = idle_duration


func physics_update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		if can_patrol and controller.has_node("PatrolState"):
			controller.change_state(controller.get_node("PatrolState"))
