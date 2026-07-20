@tool
class_name VegetationTool
extends RefCounted

var editor_state: Node

var _last_paint_pos: Vector3 = Vector3.INF
var _paint_density: float = 0.5  # Min distance between instances


func setup(state: Node) -> void:
	editor_state = state


func apply_tool(ray_result: Dictionary) -> bool:
	if ray_result.is_empty():
		return false

	var hit_pos: Vector3 = ray_result.position
	var hit_normal: Vector3 = ray_result.normal
	var _collider: Node = ray_result.collider

	# Density check
	if _last_paint_pos != Vector3.INF and hit_pos.distance_to(_last_paint_pos) < _paint_density:
		return false

	_last_paint_pos = hit_pos

	# Find or create Vegetation container
	var root: Node = editor_state.get_level_root()
	if not root:
		return false

	var vegetation_node: Node3D = root.get_node_or_null("Vegetation")
	if not vegetation_node:
		vegetation_node = Node3D.new()
		vegetation_node.name = "Vegetation"
		root.add_child(vegetation_node)
		vegetation_node.owner = root.get_tree().edited_scene_root

	# Get active mesh (from selected asset)
	# Assuming selected_asset has 'mesh' or 'scene'
	var mesh: Mesh = null
	var material: Material = null

	if editor_state.selected_asset.has("mesh"):
		mesh = editor_state.selected_asset.mesh
	elif editor_state.selected_asset.has("scene"):
		# Try to extract mesh from scene? Too complex for now.
		pass

	# Fallback to procedural grass for MVP testing if nothing selected
	if not mesh:
		mesh = _get_default_grass_mesh()
		if editor_state.selected_asset.has("material"):
			material = editor_state.selected_asset.material

	if not mesh:
		return false

	# Find MultiMeshInstance for this mesh
	var mm_node: MultiMeshInstance3D = _find_multimesh(vegetation_node, mesh)
	if not mm_node:
		mm_node = _create_multimesh(vegetation_node, mesh, material)

	# Add instance
	_add_instance(mm_node, hit_pos, hit_normal)

	return true


func _find_multimesh(parent: Node, mesh: Mesh) -> MultiMeshInstance3D:
	for child in parent.get_children():
		if child is MultiMeshInstance3D and child.multimesh and child.multimesh.mesh == mesh:
			return child
	return null


func _create_multimesh(parent: Node, mesh: Mesh, material: Material) -> MultiMeshInstance3D:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = "Vegetation_" + str(mesh.get_rid().get_id())
	mmi.multimesh = MultiMesh.new()
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mmi.multimesh.mesh = mesh
	mmi.multimesh.instance_count = 0  # Dynamic? resizing is expensive.
	# Godot MultiMesh resizing: set instance_count allocates.
	# We should probably allocate chunks or just resize.
	# For editor tool, resizing every stroke is okay-ish for small counts, but bad for large.
	# Better: buffer updates. But for MVP, simplistic resize.

	if material:
		mmi.material_override = material

	parent.add_child(mmi)
	mmi.owner = parent.get_tree().edited_scene_root
	return mmi


func _add_instance(mmi: MultiMeshInstance3D, pos: Vector3, normal: Vector3) -> void:
	var mm: MultiMesh = mmi.multimesh
	var count: int = mm.instance_count
	mm.instance_count = count + 1

	# Transform
	var t: Transform3D = Transform3D()
	t.origin = pos

	# Align to normal (y-up to normal)
	if normal != Vector3.UP:
		var axis: Vector3 = Vector3.UP.cross(normal).normalized()
		var angle: float = Vector3.UP.angle_to(normal)
		if axis.is_normalized():
			t = t.rotated(axis, angle)

	# Random Yaw
	t = t.rotated_local(Vector3.UP, randf() * TAU)

	# Random Scale
	var s: float = randf_range(0.8, 1.2)
	t = t.scaled_local(Vector3(s, s, s))

	mm.set_instance_transform(count, t)


func _get_default_grass_mesh() -> Mesh:
	# Simple quad
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = Vector2(0.5, 0.5)
	mesh.orientation = PlaneMesh.FACE_Z
	return mesh
