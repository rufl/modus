extends Node3D

@export var rocket_scene: PackedScene = preload("res://game/entities/projectiles/rocket.tscn")
@export var grenade_scene: PackedScene = preload("res://game/entities/projectiles/grenade.tscn")

@onready var camera: Camera3D = $Camera3D
@onready var label: Label = $UI/Label


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):  # Space - Fire Rocket
		fire_projectile(rocket_scene, 20.0)

	if Input.is_action_just_pressed("ui_focus_next"):  # Tab (or G) - Fire Grenade
		fire_projectile(grenade_scene, 0.0)  # Grenade handles its own speed

	if Input.is_key_pressed(KEY_1):
		fire_projectile(rocket_scene, 20.0)
	if Input.is_key_pressed(KEY_2):
		fire_projectile(grenade_scene, 0.0)


func fire_projectile(scene: PackedScene, _speed_override: float) -> void:
	if not scene:
		return

	var proj: Node3D = scene.instantiate()
	get_parent().add_child(proj)

	# Launch from camera
	var launch_pos: Vector3 = camera.global_position - Vector3(0, 0.5, 0)
	var dir: Vector3 = -camera.global_transform.basis.z

	if proj.has_method("launch"):
		proj.launch(launch_pos, dir, self)
