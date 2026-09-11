class_name EnemyPatrolState
extends EnemyState

@export var patrol_radius: float = 10.0
@export var patrol_hold_time: float = 2.0

var _hold_timer: float = 0.0
var _is_waiting: bool = false
var _start_pos: Vector3 = Vector3.ZERO


func enter() -> void:
	if controller and controller.parent_body:
		_start_pos = controller.start_position

		# Load config from controller/parent if available, or just rely on defaults

	_pick_new_waypoint()


func physics_update(delta: float) -> void:
	if _is_waiting:
		_hold_timer -= delta
		if _hold_timer <= 0:
			_is_waiting = false
			_pick_new_waypoint()
		return

	if not controller.movement:
		# Can't patrol without movement
		if controller.has_node("IdleState"):
			controller.change_state(controller.get_node("IdleState"))
		return

	if controller.movement.nav_agent.is_navigation_finished():
		_is_waiting = true
		_hold_timer = patrol_hold_time


func configure(type: String, radius: float, hold: float) -> void:
	patrol_radius = radius
	patrol_hold_time = hold
	# patrol_type logic handled in _pick_new_waypoint
	# Store type for logic
	set_meta("patrol_type", type)


func _pick_new_waypoint() -> void:
	var type: String = get_meta("patrol_type", "random")

	if type == "static":
		# Stay at start position (Guard mode)
		if controller.movement:
			# If we drifted far, return to start
			if controller.parent_body.global_position.distance_to(_start_pos) > 1.0:
				controller.movement.set_target_position(_start_pos)
			else:
				# Just wait
				_is_waiting = true
				_hold_timer = 999.0  # Wait indefinitely until disturbed
		return

	# Random Roam
	var random_offset: Vector3 = (
		Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * patrol_radius
	)
	# Patrol around initial spawn point
	var target: Vector3 = _start_pos + random_offset

	# Verify point on navmesh (optional but recommended)
	# For now just set it
	if controller.movement:
		controller.movement.set_target_position(target)
