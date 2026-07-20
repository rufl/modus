@tool
class_name HorizontalLadder
extends StaticBody3D

signal player_entered(player: Node3D)
signal player_exited(player: Node3D)
signal traversal_started(player: Node3D)
signal traversal_ended(player: Node3D)

@export_group("Path Settings")
@export var path_length: float = 5.0
@export var traverse_speed: float = 2.5
@export var auto_create_path: bool = true
@export var path_curve: Curve3D = null
@export_group("Visual Settings")
@export var generate_mesh: bool = true
@export var bar_color: Color = Color(0.5, 0.5, 0.5)
@export var bar_thickness: float = 0.06
@export var rung_spacing: float = 0.5
@export_group("Interaction")
@export var show_interaction_prompt: bool = true
@export var interaction_prompt_text: String = "Press E to grab"
@export var interaction_key: String = "interact"

var player_on_ladder: Node3D = null
var player_in_range: Node3D = null
var player_path_offset: float = 0.0
var is_player_traversing: bool = false

var _interaction_area: Area3D = null
var _path_3d: Path3D = null
var _ladder_mesh: MeshInstance3D = null


func _ready() -> void:
	add_to_group("horizontal_ladders")
	add_to_group("traversable")

	# Setup path
	_setup_path()

	# Setup interaction area
	_setup_interaction_area()

	# Generate mesh if enabled
	if generate_mesh:
		_generate_ladder_mesh()


func _process(_delta: float) -> void:
	# Handle interaction input
	if player_in_range and not is_player_traversing:
		if player_in_range.is_multiplayer_authority():
			if Input.is_action_just_pressed(interaction_key):
				_start_traversal(player_in_range)


func _setup_path() -> void:
	## Setup the Path3D for horizontal ladder traversal
	_path_3d = Path3D.new()
	_path_3d.name = "TraversalPath"
	add_child(_path_3d)

	# If path curve is provided, use it
	if path_curve:
		_path_3d.curve = path_curve
	elif auto_create_path:
		# Create a simple straight path along X axis
		var curve: Curve3D = Curve3D.new()
		curve.add_point(Vector3(-path_length / 2.0, 0, 0))
		curve.add_point(Vector3(path_length / 2.0, 0, 0))
		_path_3d.curve = curve


func _setup_interaction_area() -> void:
	## Create interaction area for detecting players
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	add_child(_interaction_area)

	# Create collision shape covering the path
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(path_length + 1.0, 1.5, 1.5)
	collision.shape = box
	_interaction_area.add_child(collision)

	_interaction_area.body_entered.connect(_on_body_entered)
	_interaction_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	## Handle player entering area
	if body.is_in_group("player"):
		player_in_range = body
		player_entered.emit(body)

		if show_interaction_prompt and body.is_multiplayer_authority():
			_show_interaction_prompt()


func _on_body_exited(body: Node3D) -> void:
	## Handle player exiting area
	if body == player_in_range:
		if show_interaction_prompt and body.is_multiplayer_authority():
			_hide_interaction_prompt()

		player_in_range = null
		player_exited.emit(body)

	if body == player_on_ladder:
		_end_traversal()


func _start_traversal(player: Node3D) -> void:
	## Start horizontal traversal
	if is_player_traversing:
		return

	player_on_ladder = player
	is_player_traversing = true
	player_path_offset = get_closest_path_offset(player.global_position)

	traversal_started.emit(player)

	if player.has_method("start_horizontal_ladder"):
		player.start_horizontal_ladder(self)


func _end_traversal() -> void:
	## End horizontal traversal
	if player_on_ladder and player_on_ladder.has_method("end_horizontal_ladder"):
		player_on_ladder.end_horizontal_ladder()

	traversal_ended.emit(player_on_ladder)
	player_on_ladder = null
	is_player_traversing = false


func _show_interaction_prompt() -> void:
	## Show interaction prompt to player
	var ui_manager: Node = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("show_interaction_prompt"):
		ui_manager.show_interaction_prompt(interaction_prompt_text)


func _hide_interaction_prompt() -> void:
	## Hide interaction prompt
	var ui_manager: Node = get_tree().get_first_node_in_group("ui_manager")
	if ui_manager and ui_manager.has_method("hide_interaction_prompt"):
		ui_manager.hide_interaction_prompt()


func _generate_ladder_mesh() -> void:
	## Generate horizontal ladder/monkey bar mesh
	_ladder_mesh = MeshInstance3D.new()
	_ladder_mesh.name = "LadderMesh"
	add_child(_ladder_mesh)

	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	var half_length: float = path_length / 2.0
	var rail_width: float = 0.8  # Distance between side rails

	# Left side rail
	_add_box_to_mesh(
		vertices,
		normals,
		indices,
		Vector3(0, 0, -rail_width / 2.0),
		Vector3(path_length, bar_thickness, bar_thickness)
	)

	# Right side rail
	_add_box_to_mesh(
		vertices,
		normals,
		indices,
		Vector3(0, 0, rail_width / 2.0),
		Vector3(path_length, bar_thickness, bar_thickness)
	)

	# Rungs
	var num_rungs: int = int(path_length / rung_spacing)
	for i: int in range(num_rungs + 1):
		var x_pos: float = -half_length + (i * rung_spacing)
		_add_box_to_mesh(
			vertices,
			normals,
			indices,
			Vector3(x_pos, 0, 0),
			Vector3(bar_thickness, bar_thickness, rail_width)
		)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ladder_mesh.mesh = mesh

	# Create material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = bar_color
	material.metallic = 0.6
	material.roughness = 0.4

	_ladder_mesh.set_surface_override_material(0, material)


func _add_box_to_mesh(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	center: Vector3,
	size: Vector3
) -> void:
	## Add a box to the mesh arrays
	var half_size: Vector3 = size / 2.0

	# Define 8 corners
	var corners: Array[Vector3] = [
		center + Vector3(-half_size.x, -half_size.y, -half_size.z),
		center + Vector3(half_size.x, -half_size.y, -half_size.z),
		center + Vector3(half_size.x, half_size.y, -half_size.z),
		center + Vector3(-half_size.x, half_size.y, -half_size.z),
		center + Vector3(-half_size.x, -half_size.y, half_size.z),
		center + Vector3(half_size.x, -half_size.y, half_size.z),
		center + Vector3(half_size.x, half_size.y, half_size.z),
		center + Vector3(-half_size.x, half_size.y, half_size.z),
	]

	# Face definitions
	var faces: Array = [
		[0, 2, 1, 0, 3, 2],
		[5, 6, 4, 6, 7, 4],
		[4, 3, 0, 4, 7, 3],
		[1, 6, 5, 1, 2, 6],
		[3, 6, 2, 3, 7, 6],
		[0, 5, 4, 0, 1, 5],
	]

	var face_normals: Array[Vector3] = [
		Vector3(0, 0, -1),
		Vector3(0, 0, 1),
		Vector3(-1, 0, 0),
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(0, -1, 0),
	]

	for face_idx: int in range(faces.size()):
		var face: Array = faces[face_idx]
		var normal: Vector3 = face_normals[face_idx]
		for idx: int in face:
			vertices.append(corners[idx])
			normals.append(normal)
			indices.append(vertices.size() - 1)


# =============================================================================
# PUBLIC API
# =============================================================================


func get_traverse_speed() -> float:
	## Get the traversal speed for this horizontal ladder
	return traverse_speed


func get_path_start_position() -> Vector3:
	## Get the global position of the path start
	if _path_3d and _path_3d.curve and _path_3d.curve.point_count > 0:
		return _path_3d.to_global(_path_3d.curve.get_point_position(0))
	return global_position + Vector3(-path_length / 2.0, 0, 0)


func get_path_end_position() -> Vector3:
	## Get the global position of the path end
	if _path_3d and _path_3d.curve and _path_3d.curve.point_count > 0:
		var last_idx: int = _path_3d.curve.point_count - 1
		return _path_3d.to_global(_path_3d.curve.get_point_position(last_idx))
	return global_position + Vector3(path_length / 2.0, 0, 0)


func get_path_length() -> float:
	## Get the total length of the path
	if _path_3d and _path_3d.curve:
		return _path_3d.curve.get_baked_length()
	return path_length


func get_position_on_path(offset: float) -> Vector3:
	## Get position on path at given offset (0.0 to path_length)
	if _path_3d and _path_3d.curve:
		var clamped_offset: float = clampf(offset, 0.0, get_path_length())
		return _path_3d.to_global(_path_3d.curve.sample_baked(clamped_offset))
	return global_position


func get_closest_path_offset(world_pos: Vector3) -> float:
	## Get the closest offset on the path to a world position
	if not _path_3d or not _path_3d.curve:
		return 0.0

	var local_pos: Vector3 = _path_3d.to_local(world_pos)
	return _path_3d.curve.get_closest_offset(local_pos)


func is_at_start(offset: float, threshold: float = 0.2) -> bool:
	## Check if player is at the start of the path
	return offset <= threshold


func is_at_end(offset: float, threshold: float = 0.2) -> bool:
	## Check if player is at the end of the path
	var path_len: float = get_path_length()
	return offset >= path_len - threshold
