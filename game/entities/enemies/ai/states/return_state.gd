class_name EnemyReturnState
extends EnemyState

var _stuck_timer: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO


func enter() -> void:
	if controller.movement:
		controller.movement.set_target_position(controller.start_position)
	_last_pos = controller.parent_body.global_position


func physics_update(delta: float) -> void:
	if not controller.movement:
		_finish()
		return

	if controller.movement.nav_agent.is_navigation_finished():
		_finish()
		return

	# Stuck check
	if controller.parent_body.global_position.distance_squared_to(_last_pos) < 0.01:
		_stuck_timer += delta
	else:
		_stuck_timer = 0.0
	_last_pos = controller.parent_body.global_position

	if _stuck_timer > 2.0:
		# Teleport or just give up?
		_finish()


func _finish() -> void:
	if controller.has_node("IdleState"):
		controller.change_state(controller.get_node("IdleState"))
