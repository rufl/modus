@tool
extends AnimatableBody3D
class_name WaypointElevator

signal arrived_at_waypoint(index: int)
signal player_entered
signal player_exited

enum ElevatorState { IDLE, MOVING, WAITING }

@export var waypoints: Array[Vector3] = []
@export var speed: float = 3.0
@export var wait_time: float = 2.0  ## Time to wait at each waypoint
@export var auto_return: bool = true  ## Return to start after reaching end
@export var loop: bool = false  ## Continuously travel between waypoints
@export var start_waypoint: int = 0
@export var require_activation: bool = false  ## Needs button press to move
@export_category("Audio")
@export var move_sound: AudioStream = null
@export var arrive_sound: AudioStream = null

var _current_waypoint: int = 0
var _target_waypoint: int = 0
var _state: ElevatorState = ElevatorState.IDLE
var _direction: int = 1  ## 1 = forward, -1 = backward
var _player_on_platform: bool = false
var _audio_player: AudioStreamPlayer3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Setup detection area
	var area := Area3D.new()
	area.name = "PlatformArea"
	var collision := CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(3.0, 1.0, 3.0)  # Adjust based on platform size
	collision.position = Vector3(0, 0.5, 0)
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

	# Audio player
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "ElevatorAudio"
	add_child(_audio_player)

	# Initialize position
	if not waypoints.is_empty():
		_current_waypoint = clampi(start_waypoint, 0, waypoints.size() - 1)
		global_position = waypoints[_current_waypoint]

	# Start moving if auto and has waypoints
	if not require_activation and waypoints.size() > 1:
		call_deferred("_start_movement")


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _state != ElevatorState.MOVING:
		return

	if waypoints.is_empty() or _target_waypoint >= waypoints.size():
		_state = ElevatorState.IDLE
		return

	var target_pos: Vector3 = waypoints[_target_waypoint]
	var distance: float = global_position.distance_to(target_pos)

	if distance < 0.05:
		# Arrived at waypoint
		global_position = target_pos
		_current_waypoint = _target_waypoint
		_on_arrived_at_waypoint()
	else:
		# Move toward target
		var direction: Vector3 = (target_pos - global_position).normalized()
		var move_distance: float = speed * delta
		if move_distance > distance:
			move_distance = distance
		global_position += direction * move_distance


func _on_arrived_at_waypoint() -> void:
	_state = ElevatorState.WAITING
	arrived_at_waypoint.emit(_current_waypoint)

	# Play arrive sound
	if arrive_sound and _audio_player:
		_audio_player.stream = arrive_sound
		_audio_player.play()

	# Wait then continue if loop/auto_return
	await get_tree().create_timer(wait_time).timeout

	if loop:
		_advance_waypoint()
	elif auto_return:
		if _current_waypoint >= waypoints.size() - 1:
			_direction = -1
		elif _current_waypoint <= 0:
			_direction = 1
		_advance_waypoint()
	else:
		_state = ElevatorState.IDLE


func _advance_waypoint() -> void:
	var next_waypoint: int = _current_waypoint + _direction

	if loop:
		next_waypoint = wrapi(next_waypoint, 0, waypoints.size())
	else:
		next_waypoint = clampi(next_waypoint, 0, waypoints.size() - 1)

	if next_waypoint != _current_waypoint:
		_target_waypoint = next_waypoint
		_start_movement()


func _start_movement() -> void:
	if waypoints.size() < 2:
		return

	_state = ElevatorState.MOVING

	# Play move sound
	if move_sound and _audio_player:
		_audio_player.stream = move_sound
		_audio_player.play()


## Call elevator to a specific waypoint (for call buttons)


func call_to_waypoint(waypoint_index: int) -> void:
	if waypoint_index < 0 or waypoint_index >= waypoints.size():
		return

	if waypoint_index == _current_waypoint and _state == ElevatorState.IDLE:
		return  # Already there

	_target_waypoint = waypoint_index
	_direction = 1 if waypoint_index > _current_waypoint else -1
	_start_movement()


## Activate elevator (for require_activation mode)


func activate() -> void:
	if _state != ElevatorState.IDLE:
		return

	if _current_waypoint >= waypoints.size() - 1:
		_direction = -1
	else:
		_direction = 1

	_advance_waypoint()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_on_platform = true
		player_entered.emit()

		if require_activation:
			activate()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_on_platform = false
		player_exited.emit()


## Editor helper to visualize waypoints


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if waypoints.size() < 2:
		warnings.append("Elevator needs at least 2 waypoints to function")
	return warnings
