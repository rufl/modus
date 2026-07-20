@tool
extends Node3D
class_name VegetationPlacer

enum VegetationType { ROCKS, TREES, GRASS, MIXED }

@export var vegetation_type: VegetationType = VegetationType.ROCKS
@export_category("Placement")
@export var scatter_radius: float = 20.0
@export var instance_count: int = 50
@export var min_scale: float = 0.8
@export var max_scale: float = 1.2
@export var random_rotation: bool = true
@export var align_to_ground: bool = true
@export_category("Scenes")
@export var rock_scenes: Array[PackedScene] = []
@export var tree_scenes: Array[PackedScene] = []
@export var grass_scene: PackedScene = null
@export_category("Ground Detection")
@export var raycast_height: float = 50.0
@export var ground_mask: int = 1  ## Collision layer for ground

var _instances: Array[Node3D] = []
var _is_generated: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		_draw_editor_bounds()
		return

	# Generate at runtime if not in editor
	if not _is_generated:
		generate()


## Generate vegetation instances


func generate() -> void:
	# Clear existing
	clear()

	for i in range(instance_count):
		var instance: Node3D = _create_instance()
		if not instance:
			continue

		# Random position within radius
		var angle: float = randf() * TAU
		var distance: float = randf() * scatter_radius
		var offset: Vector3 = Vector3(cos(angle) * distance, 0, sin(angle) * distance)

		# Find ground position
		var ground_pos: Vector3 = _find_ground_position(global_position + offset)
		if ground_pos == Vector3.INF:
			instance.queue_free()
			continue

		# Configure instance
		add_child(instance)
		instance.global_position = ground_pos

		# Random scale
		var scale_factor: float = randf_range(min_scale, max_scale)
		instance.scale = Vector3.ONE * scale_factor

		# Random rotation
		if random_rotation:
			instance.rotation_degrees.y = randf() * 360.0

		_instances.append(instance)

	_is_generated = true
	GameManager.get_core_system("logger").info(
		"[VegetationPlacer] Generated %d instances" % _instances.size(), "World"
	)


func _create_instance() -> Node3D:
	var scene: PackedScene = null

	match vegetation_type:
		VegetationType.ROCKS:
			if rock_scenes.is_empty():
				return _create_procedural_rock()
			scene = rock_scenes.pick_random()
		VegetationType.TREES:
			if tree_scenes.is_empty():
				return _create_procedural_tree()
			scene = tree_scenes.pick_random()
		VegetationType.GRASS:
			if not grass_scene:
				return _create_procedural_grass()
			scene = grass_scene
		VegetationType.MIXED:
			var type: int = randi_range(0, 2)
			match type:
				0:
					return _create_instance_of_type(VegetationType.ROCKS)
				1:
					return _create_instance_of_type(VegetationType.TREES)
				2:
					return _create_instance_of_type(VegetationType.GRASS)

	if scene:
		return scene.instantiate()
	return null


func _create_instance_of_type(type: VegetationType) -> Node3D:
	var old_type: VegetationType = vegetation_type
	vegetation_type = type
	var instance: Node3D = _create_instance()
	vegetation_type = old_type
	return instance


func _create_procedural_rock() -> Node3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "ProceduralRock"

	# Use a sphere mesh deformed by scale for rock-like shape
	var mesh := SphereMesh.new()
	mesh.radius = randf_range(0.3, 0.8)
	mesh.height = mesh.radius * randf_range(1.2, 2.0)
	mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(
		randf_range(0.3, 0.5), randf_range(0.3, 0.45), randf_range(0.25, 0.4)
	)
	material.roughness = randf_range(0.7, 1.0)
	mesh_instance.set_surface_override_material(0, material)

	return mesh_instance


func _create_procedural_tree() -> Node3D:
	var tree := Node3D.new()
	tree.name = "ProceduralTree"

	# Trunk
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.15
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = randf_range(2.5, 4.0)
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_mesh.height / 2

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.25, 0.15)
	trunk_mat.roughness = 0.9
	trunk.set_surface_override_material(0, trunk_mat)
	tree.add_child(trunk)

	# Foliage
	var foliage := MeshInstance3D.new()
	foliage.name = "Foliage"
	var foliage_mesh := SphereMesh.new()
	foliage_mesh.radius = randf_range(1.0, 2.0)
	foliage_mesh.height = foliage_mesh.radius * 1.5
	foliage.mesh = foliage_mesh
	foliage.position.y = trunk_mesh.height + foliage_mesh.radius * 0.5

	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(
		randf_range(0.1, 0.3), randf_range(0.4, 0.7), randf_range(0.1, 0.25)
	)
	foliage_mat.roughness = 0.8
	foliage.set_surface_override_material(0, foliage_mat)
	tree.add_child(foliage)

	return tree


func _create_procedural_grass() -> Node3D:
	var grass := MeshInstance3D.new()
	grass.name = "ProceduralGrass"

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(0.3, 0.5)
	grass.mesh = mesh
	grass.rotation_degrees.x = -90  # Stand upright
	grass.position.y = 0.25

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, randf_range(0.5, 0.7), 0.1)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	grass.set_surface_override_material(0, material)

	return grass


func _find_ground_position(pos: Vector3) -> Vector3:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return pos

	var from: Vector3 = Vector3(pos.x, pos.y + raycast_height, pos.z)
	var to: Vector3 = Vector3(pos.x, pos.y - raycast_height, pos.z)

	var query := PhysicsRayQueryParameters3D.create(from, to, ground_mask)
	var result: Dictionary = space_state.intersect_ray(query)

	if result.is_empty():
		return Vector3.INF

	return result.position


## Clear all generated instances


func clear() -> void:
	for instance: Node3D in _instances:
		if is_instance_valid(instance):
			instance.queue_free()
	_instances.clear()
	_is_generated = false


## Regenerate vegetation


func regenerate() -> void:
	clear()
	generate()


func _draw_editor_bounds() -> void:
	# Simple visual in editor
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "EditorBounds"

	var mesh := CylinderMesh.new()
	mesh.top_radius = scatter_radius
	mesh.bottom_radius = scatter_radius
	mesh.height = 0.1
	mesh_instance.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.8, 0.2, 0.2)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.set_surface_override_material(0, material)

	add_child(mesh_instance)
