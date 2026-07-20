class_name EnemyFleeState
extends EnemyState

@export var flee_distance: float = 15.0
@export var flee_speed_multiplier: float = 1.5
@export var safe_duration: float = 2.0  # How long to stay safe before returning to normal

var _timer: float = 0.0


func enter() -> void:
	if controller.movement:
		# Speed up
		controller.movement.speed_multiplier = flee_speed_multiplier


func exit() -> void:
	if controller.movement:
		# Reset speed
		controller.movement.speed_multiplier = 1.0


func physics_update(_delta: float) -> void:
	if not controller.target or not is_instance_valid(controller.target):
		_return_to_normal()
		return

	var my_pos: Vector3 = controller.parent_body.global_position
	var target_pos: Vector3 = controller.target.global_position
	var dist: float = my_pos.distance_to(target_pos)

	if dist > flee_distance:
		# We are safe
		if _timer <= 0.0:
			_timer = safe_duration
		else:
			_timer -= _delta
			if _timer <= 0.0:
				_return_to_normal()

		# Stop moving while waiting? Or patrol?
		# For now, just stop
		controller.movement.stop()
	else:
		# Run away
		_timer = 0.0  # Reset safety timer
		var dir: Vector3 = (my_pos - target_pos).normalized()
		var flee_dest: Vector3 = my_pos + dir * 10.0
		controller.movement.set_target_position(flee_dest)


func _return_to_normal() -> void:
	# Try to find Attack or Chase state
	if controller.has_node("ChaseState"):
		controller.change_state(controller.get_node("ChaseState"))
	elif controller.has_node("IdleState"):
		controller.change_state(controller.get_node("IdleState"))
