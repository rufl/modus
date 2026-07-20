class_name EnemyHealthBar
extends Node3D

@export var bar_width: float = 1.0
@export var bar_height: float = 0.1
@export var y_offset: float = 2.2
@export var hide_when_full: bool = true  # Hide when at full health
@export var fade_delay: float = 5.0

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _hp_label: Label3D
var _current_health: float = 1.0
var _max_health: float = 1.0
var _time_since_damage: float = 0.0
var _visible: bool = false


func _ready() -> void:
	_create_bar_mesh()
	_create_hp_label()
	position.y = y_offset
	visible = false  # Hidden by default, shown when damaged/targeted


func _process(delta: float) -> void:
	# Billboard - always face camera
	var camera := get_viewport().get_camera_3d()
	if camera:
		var direction := (camera.global_position - global_position).normalized()
		var up := Vector3.UP

		# Check if direction and up are colinear (parallel)
		if abs(direction.dot(up)) < 0.99:
			look_at(camera.global_position, up)
		else:
			# Use alternative up vector when colinear
			look_at(camera.global_position, Vector3.FORWARD)

	# Auto-hide after delay (only if hide_when_full is true)
	if hide_when_full and _visible:
		_time_since_damage += delta
		if _time_since_damage > fade_delay:
			visible = false
			_visible = false


func _create_bar_mesh() -> void:
	_mesh = MeshInstance3D.new()

	var quad := QuadMesh.new()
	quad.size = Vector2(bar_width, bar_height)
	_mesh.mesh = quad

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color.GREEN
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = _material

	add_child(_mesh)

	# Background bar (dark)
	var bg_mesh := MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(bar_width, bar_height)
	bg_mesh.mesh = bg_quad

	var bg_material := StandardMaterial3D.new()
	bg_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_material.albedo_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg_mesh.material_override = bg_material
	bg_mesh.position.z = 0.01  # Slightly behind

	add_child(bg_mesh)


func _create_hp_label() -> void:
	## Create HP text label below the bar
	_hp_label = Label3D.new()
	_hp_label.name = "HPLabel"
	_hp_label.font_size = 24
	_hp_label.outline_size = 3
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always face camera
	_hp_label.no_depth_test = false
	_hp_label.pixel_size = 0.01
	_hp_label.position = Vector3(0, -0.15, -0.01)  # Below the bar
	_hp_label.modulate = Color.WHITE
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hp_label)


## Update health bar display


func update_health(current: float, max_health: float) -> void:
	call_deferred("_deferred_update_health", current, max_health)


func _deferred_update_health(current: float, max_health: float) -> void:
	if not is_inside_tree():
		return
	if not _mesh or not is_instance_valid(_mesh):
		_create_bar_mesh()
	if not _hp_label or not is_instance_valid(_hp_label):
		_create_hp_label()
	if not _material or max_health <= 0.0:
		return

	_current_health = current
	_max_health = max_health
	_time_since_damage = 0.0

	var health_ratio: float = clamp(current / max_health, 0.0, 1.0)

	# Scale bar width based on health
	_mesh.scale.x = health_ratio
	_mesh.position.x = -(bar_width * (1.0 - health_ratio)) / 2.0

	# Color based on health percentage
	if health_ratio > 0.6:
		_material.albedo_color = Color.GREEN
	elif health_ratio > 0.3:
		_material.albedo_color = Color.YELLOW
	else:
		_material.albedo_color = Color.RED

	# Update HP text [current / max]
	if _hp_label:
		_hp_label.text = "[%d / %d]" % [int(current), int(max_health)]

	# Show bar
	visible = true
	_visible = true
