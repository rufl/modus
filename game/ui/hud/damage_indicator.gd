extends Control

@onready var arrow: TextureRect = $Arrow

var _source_pos: Vector3
var _fade_time: float = 2.0
var _timer: float = 0.0


func _ready() -> void:
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	_timer = _fade_time


func setup(pos: Vector3) -> void:
	_source_pos = pos


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0:
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.tween_callback(queue_free)
		set_process(false)
		return

	_update_rotation()


func _update_rotation() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return

	var forward: Vector3 = -camera.global_transform.basis.z

	var dir_to_source: Vector3 = (
		(
			Vector3(_source_pos.x, 0, _source_pos.z)
			- Vector3(camera.global_position.x, 0, camera.global_position.z)
		)
		. normalized()
	)

	# Project direction onto camera plane
	var flat_forward: Vector2 = Vector2(forward.x, forward.z).normalized()
	var flat_dir: Vector2 = Vector2(dir_to_source.x, dir_to_source.z).normalized()

	var angle: float = flat_forward.angle_to(flat_dir)
	rotation = -angle  # Adjust based on arrow texture default orientation
