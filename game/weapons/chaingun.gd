class_name Chaingun
extends Node3D

@export_group("Visuals")
@export var barrel_mesh: Node3D
@export var max_rotation_speed: float = 20.0  # radians per second

var _current_spin_speed: float = 0.0


func _ready() -> void:
	# Try to find barrel if not assigned
	if not barrel_mesh:
		barrel_mesh = get_node_or_null("Model")


func _process(delta: float) -> void:
	if _current_spin_speed > 0.0 and barrel_mesh:
		barrel_mesh.rotate_z(_current_spin_speed * max_rotation_speed * delta)


# Called by WeaponManager via signal or direct call if implemented


func on_barrel_spin(speed_percent: float) -> void:
	_current_spin_speed = speed_percent
