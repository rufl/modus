class_name Elevator
extends AnimatableBody3D

signal arrived_at_top
signal arrived_at_bottom

enum ElevatorState { IDLE_BOTTOM, MOVING_UP, IDLE_TOP, MOVING_DOWN }

@export_category("Elevator Settings")
@export var lift_height: float = 5.0
@export var speed: float = 2.0
@export var wait_time: float = 2.0
@export var auto_return: bool = true
@export var trigger_on_touch: bool = true
@export_category("Audio")
@export var start_sound: AudioStream
@export var stop_sound: AudioStream
@export var loop_sound: AudioStream

var _start_pos: Vector3
var _target_pos: Vector3
var _current_state: ElevatorState = ElevatorState.IDLE_BOTTOM
var _wait_timer: float = 0.0
var _audio_player: AudioStreamPlayer3D


func _ready() -> void:
	_start_pos = global_position
	_target_pos = _start_pos + Vector3(0, lift_height, 0)

	# Setup Audio Component
	_audio_player = AudioStreamPlayer3D.new()
	add_child(_audio_player)
	_audio_player.bus = "SFX"

	# Setup Trigger Area
	var area: Area3D = Area3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	# Assume 2x2 platform, trigger strictly above
	(shape.shape as BoxShape3D).size = Vector3(1.8, 0.5, 1.8)
	area.add_child(shape)
	area.position.y = 0.5  # Slightly above floor
	add_child(area)

	area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	match _current_state:
		ElevatorState.MOVING_UP:
			_process_movement(delta, _target_pos, ElevatorState.IDLE_TOP)
		ElevatorState.MOVING_DOWN:
			_process_movement(delta, _start_pos, ElevatorState.IDLE_BOTTOM)
		ElevatorState.IDLE_TOP:
			if auto_return:
				_wait_timer -= delta
				if _wait_timer <= 0:
					call_elevator_down()
		ElevatorState.IDLE_BOTTOM:
			if _wait_timer > 0:
				_wait_timer -= delta


func _process_movement(delta: float, target: Vector3, next_state: ElevatorState) -> void:
	var diff: Vector3 = target - global_position
	var dist: float = diff.length()
	var move_step: float = speed * delta

	if dist <= move_step:
		global_position = target
		_current_state = next_state
		_on_arrived(next_state)
	else:
		global_position += diff.normalized() * move_step


func _on_arrived(state: ElevatorState) -> void:
	if state == ElevatorState.IDLE_TOP:
		arrived_at_top.emit()
		_wait_timer = wait_time
	else:
		arrived_at_bottom.emit()
		_wait_timer = 0.0  # Ready to go up again immediately if triggered

	if stop_sound:
		_audio_player.stream = stop_sound
		_audio_player.play()
	else:
		_audio_player.stop()


func _on_body_entered(body: Node3D) -> void:
	if not trigger_on_touch:
		return

	if body is CharacterBody3D:  # Only players/enemies trigger it
		if _current_state == ElevatorState.IDLE_BOTTOM and _wait_timer <= 0:
			call_elevator_up()
		elif _current_state == ElevatorState.IDLE_TOP and _wait_timer <= 0:
			# Optionally trigger down if player steps on it at top?
			# Usually better to rely on auto-return or explicit interact for down
			# to avoid accidental falling
			pass


func call_elevator_up() -> void:
	if _current_state == ElevatorState.IDLE_BOTTOM or _current_state == ElevatorState.MOVING_DOWN:
		_current_state = ElevatorState.MOVING_UP
		if start_sound:
			_audio_player.stream = start_sound
			_audio_player.play()


func call_elevator_down() -> void:
	if _current_state == ElevatorState.IDLE_TOP or _current_state == ElevatorState.MOVING_UP:
		_current_state = ElevatorState.MOVING_DOWN
		if start_sound:
			_audio_player.stream = start_sound
			_audio_player.play()


## Editor Helper to visualize height


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		if Engine.is_editor_hint():
			pass  # Could draw debug lines here
