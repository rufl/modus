@tool
class_name PaintBrush
extends RefCounted

signal painted(node: Node, material: Material)

enum ProjectionMode { BOX, PLANAR, WORLD_XZ, WORLD_XY, WORLD_YZ }  # Box UV mapping  # Planar projection based on face normal  # World-aligned XZ  # World-aligned XY  # World-aligned YZ

var grid_system: Node = null
var editor_state: Node = null
var current_material: Material = null
var projection_mode: ProjectionMode = ProjectionMode.BOX
var texture_scale: float = 1.0
var is_painting: bool = false
var painted_nodes: Array[Node] = []


func setup(grid: Node, state: Node) -> void:
	grid_system = grid
	editor_state = state


## Set the material to paint with


func set_material(material: Material) -> void:
	current_material = material


## Set projection mode


func set_projection_mode(mode: ProjectionMode) -> void:
	projection_mode = mode


## Start painting stroke


func start_painting() -> void:
	is_painting = true
	painted_nodes.clear()


## End painting stroke


func end_painting() -> void:
	is_painting = false
	painted_nodes.clear()


## Paint at raycast hit position


func paint_at_raycast(hit_result: Dictionary) -> bool:
	if hit_result.is_empty() or not current_material:
		return false

	var collider: Node = hit_result.get("collider")
	if not collider:
		return false

	# Find paintable node
	var target := _find_paintable_node(collider)
	if not target:
		return false

	# Don't repaint same node in same stroke
	if is_painting and target in painted_nodes:
		return false

	# Apply material
	_apply_material(target, hit_result.get("normal", Vector3.UP))
	painted_nodes.append(target)
	painted.emit(target, current_material)

	return true


func _find_paintable_node(node: Node) -> Node:
	var current := node
	while current:
		# CSG shapes can have materials
		if current is CSGShape3D:
			return current
		# MeshInstance3D
		if current is MeshInstance3D:
			return current
		current = current.get_parent()
	return null


func _apply_material(node: Node, hit_normal: Vector3) -> void:
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Paint Material")

	if node is CSGShape3D:
		var old_material: Material = node.material
		var new_material := _prepare_material(hit_normal)

		undo.add_do_property(node, "material", new_material)
		undo.add_undo_property(node, "material", old_material)

	elif node is MeshInstance3D:
		# Paint first surface
		var old_material: Material = node.get_surface_override_material(0)
		var new_material := _prepare_material(hit_normal)

		undo.add_do_method(node, "set_surface_override_material", 0, new_material)
		undo.add_undo_method(node, "set_surface_override_material", 0, old_material)

	undo.commit_action()


func _prepare_material(normal: Vector3) -> Material:
	if not current_material:
		return null

	# Clone material if we need to modify UV settings
	var mat := current_material.duplicate() as Material

	if mat is StandardMaterial3D:
		var std_mat := mat as StandardMaterial3D

		# Apply texture scale
		std_mat.uv1_scale = Vector3(texture_scale, texture_scale, texture_scale)

		# Apply triplanar mapping for box projection
		if projection_mode == ProjectionMode.BOX:
			std_mat.uv1_triplanar = true
			std_mat.uv1_triplanar_sharpness = 1.0
		else:
			std_mat.uv1_triplanar = false

	return mat


## Get available projection mode names


static func get_projection_mode_names() -> Array[String]:
	return ["Box", "Planar", "World XZ", "World XY", "World YZ"]


## Create a solid color material


static func create_color_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat


## Create a material from texture


static func create_texture_material(texture: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # Retro look
	return mat
