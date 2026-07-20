@tool
class_name Crusher
extends AnimatableBody3D

enum Phase { IDLE_TOP, CRUSHING, IDLE_BOTTOM, RETRACTING }

@export var target_position_offset: Vector3 = Vector3(0, -5, 0)
@export var crush_speed: float = 15.0
@export var retract_speed: float = 2.0
@export var wait_time_top: float = 2.0
@export var wait_time_bottom: float = 1.0
@export var damage: float = 1000.0  # Instant kill usually

var current_phase: Phase = Phase.IDLE_TOP

@onready var kill_zone: Area3D = $KillZone  # Expected child Area3D
@onready var mesh: MeshInstance3D = $MeshInstance3D  # For optional effects

var _start_pos: Vector3
var _target_pos: Vector3
var _timer: float = 0.0


func _ready() -> void:
	_start_pos = global_position
	_target_pos = _start_pos + target_position_offset
	_timer = wait_time_top

	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_entered)


func _physics_process(delta: float) -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return  # Server authority for physics

	match current_phase:
		Phase.IDLE_TOP:
			_timer -= delta
			if _timer <= 0:
				_start_crush()

		Phase.CRUSHING:
			var dist: float = global_position.distance_to(_target_pos)
			var move: float = crush_speed * delta

			if dist <= move:
				global_position = _target_pos
				_impact()
			else:
				var dir: Vector3 = (_target_pos - global_position).normalized()
				global_position += dir * move

		Phase.IDLE_BOTTOM:
			_timer -= delta
			if _timer <= 0:
				current_phase = Phase.RETRACTING

		Phase.RETRACTING:
			var dist: float = global_position.distance_to(_start_pos)
			var move: float = retract_speed * delta

			if dist <= move:
				global_position = _start_pos
				current_phase = Phase.IDLE_TOP
				_timer = wait_time_top
			else:
				var dir: Vector3 = (_start_pos - global_position).normalized()
				global_position += dir * move


func _start_crush() -> void:
	current_phase = Phase.CRUSHING
	# Play warning sound?


func _impact() -> void:
	current_phase = Phase.IDLE_BOTTOM
	_timer = wait_time_bottom
	# Play impact sound / shake
	_play_impact_effects.rpc()
	# Check for immediate kills if logic missed enter
	if kill_zone:
		for body in kill_zone.get_overlapping_bodies():
			_try_kill(body)


func _on_kill_zone_entered(body: Node) -> void:
	# Only kill during crushing phase or at bottom
	if current_phase == Phase.CRUSHING or current_phase == Phase.IDLE_BOTTOM:
		_try_kill(body)


func _try_kill(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, 0)  # 0 = environment


@rpc("authority", "call_local", "reliable")
func _play_impact_effects() -> void:
	# Client side effects
	# Spawn particles, play sound
	pass
