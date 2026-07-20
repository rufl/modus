@tool
class_name Spikes
extends Area3D

@export var damage: int = 25
@export var extend_time: float = 1.0
@export var retract_time: float = 2.0
@export var offset_time: float = 0.0  # Phase offset

@onready var mesh: Node3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D

var _timer: float = 0.0
var _is_extended: bool = false


func _ready() -> void:
	_timer = offset_time

	# Disable initially?
	if collision:
		collision.disabled = true

	_update_visuals()


func _physics_process(delta: float) -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return

	_timer += delta

	if _is_extended:
		if _timer >= extend_time:
			_set_extended(false)
			_timer = 0.0
	else:
		if _timer >= retract_time:
			_set_extended(true)
			_timer = 0.0


func _set_extended(state: bool) -> void:
	if _is_extended == state:
		return
	_is_extended = state

	_sync_state.rpc(state)

	if state:
		# Check for immediate overlap damage
		for body in get_overlapping_bodies():
			_try_damage(body)


@rpc("authority", "call_local", "reliable")
func _sync_state(extended: bool) -> void:
	_is_extended = extended
	if collision:
		collision.set_deferred("disabled", not extended)
	_update_visuals()


func _update_visuals() -> void:
	if not mesh:
		return

	if _is_extended:
		var tween: Tween = create_tween()
		tween.tween_property(mesh, "position:y", 0.0, 0.1)  # Pop up
	else:
		var tween: Tween = create_tween()
		tween.tween_property(mesh, "position:y", -0.5, 0.5)  # Retract slow


func _on_body_entered(body: Node) -> void:
	# In single-player (no peer), we ARE the server
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return
	if _is_extended:
		_try_damage(body)


func _try_damage(body: Node) -> void:
	if body.has_method("take_damage"):
		# Server deals damage
		# Assuming body has take_damage(amount, source_id)
		# 0 as source_id for 'World'
		body.take_damage(damage, 0)  # 0 = World/Environment
