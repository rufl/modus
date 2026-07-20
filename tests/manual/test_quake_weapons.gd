extends Node3D

var rocket_scene: PackedScene = preload("res://game/entities/projectiles/rocket.tscn")
var grenade_scene: PackedScene = preload("res://game/entities/projectiles/grenade.tscn")
var last_fire_time: float = 0.0

@onready var camera: Camera3D = $Camera3D


func _process(delta: float) -> void:
	# Camera Movement
	var dir: Vector3 = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir += -camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir += -camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_SHIFT):
		dir += Vector3.DOWN

	camera.global_position += dir * 10.0 * delta

	# Firing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Simple debounce
		if not should_fire(0.5):
			return
		fire_rocket()

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if not should_fire(0.6):
			return
		fire_grenade()


func should_fire(rate: float) -> bool:
	var t: float = Time.get_unix_time_from_system()
	if t - last_fire_time > rate:
		last_fire_time = t
		return true
	return false


func fire_rocket() -> void:
	if not rocket_scene:
		return
	var rocket: Node3D = rocket_scene.instantiate()
	add_child(rocket)
	# Authentic slight offset
	var spawn_pos: Vector3 = (
		camera.global_position
		+ -camera.global_transform.basis.z * 1.0
		+ camera.global_transform.basis.x * 0.2
		+ Vector3.DOWN * 0.1
	)
	if rocket.has_method("launch"):
		rocket.launch(spawn_pos, -camera.global_transform.basis.z, self)


func fire_grenade() -> void:
	if not grenade_scene:
		return
	var grenade: Node3D = grenade_scene.instantiate()
	add_child(grenade)
	var spawn_pos: Vector3 = camera.global_position + -camera.global_transform.basis.z * 0.5
	if grenade.has_method("launch"):
		grenade.launch(spawn_pos, -camera.global_transform.basis.z, self)
