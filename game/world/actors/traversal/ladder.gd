@tool
class_name Ladder
extends Area3D

signal player_entered(player: Node3D)
signal player_exited(player: Node3D)
signal climbing_started(player: Node3D)
signal climbing_stopped(player: Node3D)

@export_group("Ladder Dimensions")
@export var height: float = 4.0
@export var width: float = 0.5
@export var climb_speed: float = 3.0
@export var rung_count: int = 8
@export_group("Visual Settings")
@export var generate_mesh: bool = true
@export var ladder_color: Color = Color(0.4, 0.3, 0.2)
@export var ladder_material_type: String = "wood"  # "wood" or "metal"
@export var rail_thickness: float = 0.08
@export_group("Audio Settings")
@export var enable_climb_sounds: bool = true
@export var climb_sound_interval: float = 0.4

var player_on_ladder: Node3D = null
var is_player_climbing: bool = false

@onready var top_marker: Marker3D = $TopMarker
@onready var bottom_marker: Marker3D = $BottomMarker

var _climb_sound_timer: float = 0.0
var _ladder_mesh: MeshInstance3D = null


func _ready() -> void:
	# Ensure proper collision layer
	monitoring = true
	monitorable = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create markers if they don't exist
	_setup_markers()

	# Generate mesh if enabled
	if generate_mesh:
		_generate_ladder_mesh()

	add_to_group("ladders")


func _process(delta: float) -> void:
	## Handle per-frame updates for audio
	if is_player_climbing and enable_climb_sounds:
		_climb_sound_timer -= delta
		if _climb_sound_timer <= 0.0:
			_play_climb_sound()
			_climb_sound_timer = climb_sound_interval


func _setup_markers() -> void:
	## Create top and bottom markers
	if not top_marker:
		top_marker = Marker3D.new()
		top_marker.name = "TopMarker"
		add_child(top_marker)
	top_marker.position = Vector3(0, height, 0)

	if not bottom_marker:
		bottom_marker = Marker3D.new()
		bottom_marker.name = "BottomMarker"
		add_child(bottom_marker)
	bottom_marker.position = Vector3(0, 0, 0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_on_ladder = body
		player_entered.emit(body)

		if body.has_method("enter_ladder"):
			body.enter_ladder(self)
			start_climbing(body)


func _on_body_exited(body: Node) -> void:
	if body == player_on_ladder:
		stop_climbing()
		player_exited.emit(body)

		if body.has_method("exit_ladder"):
			body.exit_ladder(self)

		player_on_ladder = null


func start_climbing(player: Node3D) -> void:
	## Called when player starts climbing
	is_player_climbing = true
	player_on_ladder = player
	_climb_sound_timer = 0.0
	climbing_started.emit(player)


func stop_climbing() -> void:
	## Called when player stops climbing
	is_player_climbing = false
	if player_on_ladder:
		climbing_stopped.emit(player_on_ladder)


func get_climb_speed() -> float:
	## Get the climbing speed for this ladder
	return climb_speed


func get_top_position() -> Vector3:
	## Get the global position of the ladder top
	if top_marker:
		return top_marker.global_position
	return global_position + Vector3(0, height, 0)


func get_bottom_position() -> Vector3:
	## Get the global position of the ladder bottom
	if bottom_marker:
		return bottom_marker.global_position
	return global_position


func is_at_top(player_pos: Vector3, threshold: float = 0.5) -> bool:
	## Check if player is at the top of the ladder
	var top_pos: Vector3 = get_top_position()
	return player_pos.y >= top_pos.y - threshold


func is_at_bottom(player_pos: Vector3, threshold: float = 0.5) -> bool:
	## Check if player is at the bottom of the ladder
	var bottom_pos: Vector3 = get_bottom_position()
	return player_pos.y <= bottom_pos.y + threshold


func _play_climb_sound() -> void:
	## Play climbing sound effect
	if not is_player_climbing:
		return

	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.name = "ClimbSound"
	audio.bus = "SFX"
	audio.pitch_scale = randf_range(0.9, 1.1)

	# Try to load appropriate sound
	var sound_path: String
	if ladder_material_type == "metal":
		sound_path = "res://game/assets/audio/sfx/ladder_metal.ogg"
	else:
		sound_path = "res://game/assets/audio/sfx/ladder_wood.ogg"

	if ResourceLoader.exists(sound_path):
		audio.stream = load(sound_path)

	add_child(audio)
	if player_on_ladder:
		audio.global_position = player_on_ladder.global_position
	else:
		audio.global_position = global_position

	if audio.stream:
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		get_tree().create_timer(0.1).timeout.connect(audio.queue_free)


func _generate_ladder_mesh() -> void:
	## Generate a detailed ladder mesh with rungs
	_ladder_mesh = MeshInstance3D.new()
	_ladder_mesh.name = "LadderMesh"
	add_child(_ladder_mesh)

	var mesh: ArrayMesh = ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	var rail_depth: float = rail_thickness

	# Left rail
	_add_box_to_mesh(
		vertices,
		normals,
		indices,
		Vector3(-width / 2.0, height / 2.0, 0),
		Vector3(rail_thickness, height, rail_depth)
	)

	# Right rail
	_add_box_to_mesh(
		vertices,
		normals,
		indices,
		Vector3(width / 2.0, height / 2.0, 0),
		Vector3(rail_thickness, height, rail_depth)
	)

	# Rungs
	var rung_spacing: float = height / float(rung_count)
	var rung_height: float = 0.05
	var rung_depth: float = 0.05

	for i: int in range(rung_count + 1):
		var y_pos: float = i * rung_spacing
		_add_box_to_mesh(
			vertices,
			normals,
			indices,
			Vector3(0, y_pos, 0),
			Vector3(width + rail_thickness, rung_height, rung_depth)
		)

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_ladder_mesh.mesh = mesh

	# Create material
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = ladder_color

	if ladder_material_type == "metal":
		material.metallic = 0.7
		material.roughness = 0.4
	else:
		material.metallic = 0.0
		material.roughness = 0.8

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

	# Face definitions (vertex indices for each face, 2 triangles per face)
	var faces: Array = [
		# Front face (-Z)
		[0, 2, 1, 0, 3, 2],
		# Back face (+Z)
		[5, 6, 4, 6, 7, 4],
		# Left face (-X)
		[4, 3, 0, 4, 7, 3],
		# Right face (+X)
		[1, 6, 5, 1, 2, 6],
		# Top face (+Y)
		[3, 6, 2, 3, 7, 6],
		# Bottom face (-Y)
		[0, 5, 4, 0, 1, 5],
	]

	# Face normals
	var face_normals: Array[Vector3] = [
		Vector3(0, 0, -1),
		Vector3(0, 0, 1),
		Vector3(-1, 0, 0),
		Vector3(1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(0, -1, 0),
	]

	# Add vertices and indices for each face
	for face_idx: int in range(faces.size()):
		var face: Array = faces[face_idx]
		var normal: Vector3 = face_normals[face_idx]
		for idx: int in face:
			vertices.append(corners[idx])
			normals.append(normal)
			indices.append(vertices.size() - 1)


## Get ladder height


func get_height() -> float:
	return height


## Get ladder width


func get_width() -> float:
	return width
