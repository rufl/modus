@tool
class_name MovingPlatform
extends AnimatableBody3D

@export_group("Path Settings")
@export var waypoints: Array[Vector3] = []  # Local coordinates relative to start position
@export var speed: float = 2.0
@export var wait_time: float = 1.0  # Wait time at each waypoint
@export var loop: bool = true
@export var ping_pong: bool = false

var _start_position: Vector3
var _target_point_index: int = 1
var _is_waiting: bool = false
var _wait_timer: float = 0.0
var _moving_forward: bool = true
var _target_position: Vector3


func _ready() -> void:
	_start_position = global_position

	# Needs at least one waypoint (plus start point which is implicit 0)
	if waypoints.size() == 0:
		set_physics_process(false)
		return

	# Add start position as first point (0,0,0 local) if not present,
	# or handle logic relative to start pos.
	# Simpler: convert local waypoints to global targets
	var global_waypoints: Array[Vector3] = []
	global_waypoints.append(_start_position)
	for p in waypoints:
		global_waypoints.append(_to_global(p))

	# Store waypoints globally for simpler logic
	waypoints = global_waypoints  # Reusing variable, now global

	# Configure synchronizer
	var sync_node: MultiplayerSynchronizer = get_node_or_null("MultiplayerSynchronizer")
	if sync_node:
		var config: SceneReplicationConfig = SceneReplicationConfig.new()
		config.add_property(":global_position")
		sync_node.replication_config = config

	_target_position = _start_position


func _physics_process(delta: float) -> void:
	# Only server controls movement logic
	if multiplayer.is_server():
		_process_server_movement(delta)
		# Sync position to clients
		# Use a simplified sync or standard MultiplayerSynchronizer
		# For simplicity in this template, we assume a Synchronizer is attached,
		# or we manually RPC periodically if network bandwidth is a concern.
		# But for smooth platform, Synchronizer on 'position' is best.
	else:
		# Clients rely on Synchronizer for position updates
		# If no synchronizer, we might need manual lerp here, but AnimatableBody3D
		# works best with physics sync.
		pass


func _process_server_movement(delta: float) -> void:
	if _is_waiting:
		_wait_timer -= delta
		if _wait_timer <= 0:
			_is_waiting = false
			_advance_target()
		return

	var target: Vector3 = waypoints[_target_point_index]
	var dist: float = global_position.distance_to(target)

	if dist < 0.1:
		# Reached target
		global_position = target
		_is_waiting = true
		_wait_timer = wait_time
	else:
		var dir: Vector3 = (target - global_position).normalized()
		# Move using move_and_collide to carry riders?
		# AnimatableBody is designed to be moved via position setting for kinematic bodies
		# to ride it.
		# However, for correct physics interaction (pushing bodies), we should update position.
		# But constant linear velocity is also good for riders.

		var move_amount: Vector3 = dir * speed * delta

		# Don't overshoot
		if move_amount.length() > dist:
			move_amount = dir * dist

		global_position += move_amount


func _advance_target() -> void:
	if ping_pong:
		if _moving_forward:
			_target_point_index += 1
			if _target_point_index >= waypoints.size():
				_target_point_index = waypoints.size() - 2
				_moving_forward = false
		else:
			_target_point_index -= 1
			if _target_point_index < 0:
				_target_point_index = 1
				_moving_forward = true
	else:
		_target_point_index += 1
		if _target_point_index >= waypoints.size():
			if loop:
				_target_point_index = 0
			else:
				_target_point_index = waypoints.size() - 1  # Stop


func _to_global(local_point: Vector3) -> Vector3:
	return _start_position + local_point
