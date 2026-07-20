@tool
class_name CSGToMeshConverter
extends RefCounted

signal conversion_started(total_nodes: int)
signal node_converted(index: int, node_name: String)
signal conversion_completed(mesh_count: int, error_count: int)


func convert_level(level_root: Node3D, options: Dictionary = {}) -> Dictionary:
	var result := {
		"success": true, "meshes_created": 0, "nodes_converted": 0, "errors": [], "warnings": []
	}

	# Default options
	var keep_originals: bool = options.get("keep_originals", false)
	var generate_collision: bool = options.get("generate_collision", true)
	var merge_by_material: bool = options.get("merge_by_material", false)
	var output_folder: String = options.get("output_folder", "")

	# Find all CSG nodes
	var csg_nodes: Array[CSGShape3D] = []
	_find_csg_nodes(level_root, csg_nodes)

	if csg_nodes.is_empty():
		result.warnings.append("No CSG nodes found in level")
		return result

	conversion_started.emit(csg_nodes.size())

	# Create container for converted meshes
	var mesh_container := Node3D.new()
	mesh_container.name = "ConvertedMeshes"
	level_root.add_child(mesh_container)
	mesh_container.owner = level_root.get_tree().edited_scene_root

	# Convert each CSG node
	var index := 0
	for csg in csg_nodes:
		node_converted.emit(index, csg.name)

		var mesh_result := _convert_csg_node(csg, generate_collision)

		if mesh_result.mesh_instance:
			mesh_container.add_child(mesh_result.mesh_instance)
			mesh_result.mesh_instance.owner = level_root.get_tree().edited_scene_root
			result.meshes_created += 1

			# Add collision body if generated
			if mesh_result.collision_body:
				mesh_result.mesh_instance.add_child(mesh_result.collision_body)
				mesh_result.collision_body.owner = level_root.get_tree().edited_scene_root

			# Remove or hide original
			if not keep_originals:
				csg.queue_free()
			else:
				csg.visible = false

			result.nodes_converted += 1
		else:
			result.errors.append("Failed to convert: %s" % csg.name)

		index += 1

	# Optionally merge meshes by material
	if merge_by_material and result.meshes_created > 1:
		var merge_result := _merge_meshes_by_material(mesh_container)
		result.meshes_created = merge_result.mesh_count
		if not merge_result.errors.is_empty():
			result.errors.append_array(merge_result.errors)

	# Save meshes to resources if output folder specified
	if not output_folder.is_empty():
		_save_meshes_to_folder(mesh_container, output_folder, result)

	conversion_completed.emit(result.meshes_created, result.errors.size())

	return result


func _find_csg_nodes(node: Node, results: Array[CSGShape3D]) -> void:
	if node is CSGShape3D:
		# Only include root CSG nodes (not children of other CSG)
		var parent := node.get_parent()
		if not parent is CSGShape3D:
			results.append(node)

	for child in node.get_children():
		_find_csg_nodes(child, results)


func _convert_csg_node(csg: CSGShape3D, generate_collision: bool) -> Dictionary:
	var result := {"mesh_instance": null, "collision_body": null}

	# Get the generated mesh arrays
	# Note: get_meshes() returns the current CSG mesh data
	var mesh_arrays := csg.get_meshes()

	if mesh_arrays.is_empty():
		return result

	# mesh_arrays format: [Transform3D, Mesh, Transform3D, Mesh, ...]
	# Usually just one mesh for simple CSG
	var combined_mesh := ArrayMesh.new()
	var surface_idx := 0

	var i := 0
	while i < mesh_arrays.size():
		var xform: Transform3D = mesh_arrays[i]
		var mesh: Mesh = mesh_arrays[i + 1] if i + 1 < mesh_arrays.size() else null

		if mesh:
			for s in range(mesh.get_surface_count()):
				var arrays := mesh.surface_get_arrays(s)

				# Transform vertices by the CSG's local transform
				if arrays[Mesh.ARRAY_VERTEX]:
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					for v in range(vertices.size()):
						vertices[v] = xform * vertices[v]
					arrays[Mesh.ARRAY_VERTEX] = vertices

				# Transform normals
				if arrays[Mesh.ARRAY_NORMAL]:
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					for n in range(normals.size()):
						normals[n] = xform.basis * normals[n]
					arrays[Mesh.ARRAY_NORMAL] = normals

				combined_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

				# Copy material
				var mat: Material = mesh.surface_get_material(s)
				if mat:
					combined_mesh.surface_set_material(surface_idx, mat)
				elif csg.material:
					combined_mesh.surface_set_material(surface_idx, csg.material)

				surface_idx += 1

		i += 2

	if combined_mesh.get_surface_count() == 0:
		return result

	# Create MeshInstance3D
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = csg.name + "_Mesh"
	mesh_instance.mesh = combined_mesh
	mesh_instance.transform = csg.global_transform

	# Copy metadata
	for meta_name in csg.get_meta_list():
		mesh_instance.set_meta(meta_name, csg.get_meta(meta_name))

	result.mesh_instance = mesh_instance

	# Generate collision
	if generate_collision:
		var collision_body := _create_collision_body(combined_mesh, csg)
		result.collision_body = collision_body

	return result


func _create_collision_body(mesh: ArrayMesh, original_csg: CSGShape3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "CollisionBody"

	# Create collision shape from mesh
	var shape := mesh.create_trimesh_shape()
	if shape:
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = shape
		collision_shape.name = "CollisionShape"
		body.add_child(collision_shape)

	# Copy collision layers/masks from CSG if it had collision
	if original_csg.use_collision:
		body.collision_layer = original_csg.collision_layer
		body.collision_mask = original_csg.collision_mask

	return body


func _merge_meshes_by_material(container: Node3D) -> Dictionary:
	var result := {"mesh_count": 0, "errors": []}

	# Group meshes by material
	var material_groups: Dictionary = {}  # Material -> Array[MeshInstance3D]

	for child in container.get_children():
		if child is MeshInstance3D and child.mesh:
			for s in range(child.mesh.get_surface_count()):
				var mat: Material = child.mesh.surface_get_material(s)
				var mat_key := mat.resource_path if mat else "no_material"

				if not material_groups.has(mat_key):
					material_groups[mat_key] = {"material": mat, "meshes": []}
				material_groups[mat_key].meshes.append(
					{"mesh": child.mesh, "surface": s, "transform": child.global_transform}
				)

	# Remove old mesh instances
	for child in container.get_children():
		child.queue_free()

	# Create merged meshes
	for mat_key in material_groups:
		var group: Dictionary = material_groups[mat_key]
		var merged_mesh := ArrayMesh.new()

		var all_vertices := PackedVector3Array()
		var all_normals := PackedVector3Array()
		var all_uvs := PackedVector2Array()
		var all_indices := PackedInt32Array()

		var vertex_offset := 0

		for mesh_data in group.meshes:
			var mesh: Mesh = mesh_data.mesh
			var surface: int = mesh_data.surface
			var xform: Transform3D = mesh_data.transform

			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

			# Transform and append vertices
			for v in vertices:
				all_vertices.append(xform * v)

			# Transform and append normals
			if normals:
				for n in normals:
					all_normals.append(xform.basis * n)

			# Append UVs
			if uvs:
				all_uvs.append_array(uvs)

			# Offset and append indices
			if indices:
				for idx in indices:
					all_indices.append(idx + vertex_offset)

			vertex_offset += vertices.size()

		# Create merged surface
		var merged_arrays := []
		merged_arrays.resize(Mesh.ARRAY_MAX)
		merged_arrays[Mesh.ARRAY_VERTEX] = all_vertices
		if not all_normals.is_empty():
			merged_arrays[Mesh.ARRAY_NORMAL] = all_normals
		if not all_uvs.is_empty():
			merged_arrays[Mesh.ARRAY_TEX_UV] = all_uvs
		if not all_indices.is_empty():
			merged_arrays[Mesh.ARRAY_INDEX] = all_indices

		merged_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged_arrays)

		if group.material:
			merged_mesh.surface_set_material(0, group.material)

		# Create mesh instance
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "MergedMesh_" + mat_key.get_file().get_basename()
		mesh_instance.mesh = merged_mesh
		container.add_child(mesh_instance)
		mesh_instance.owner = container.get_tree().edited_scene_root

		result.mesh_count += 1

	return result


func _save_meshes_to_folder(container: Node3D, folder: String, result: Dictionary) -> void:
	# Ensure folder exists
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)

	for child in container.get_children():
		if child is MeshInstance3D and child.mesh:
			var mesh_path := folder.path_join(child.name + ".tres")
			var err := ResourceSaver.save(child.mesh, mesh_path)

			if err != OK:
				result.errors.append("Failed to save mesh: %s" % mesh_path)
			else:
				# Update mesh instance to use saved resource
				child.mesh = load(mesh_path)


## Create a simple UI for the converter (adds to Project menu)


static func create_converter_dialog() -> ConfirmationDialog:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Convert CSG to Mesh"
	dialog.size = Vector2i(400, 300)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	dialog.add_child(vbox)

	# Info label
	var info := Label.new()
	info.text = "Convert all CSG geometry in the current level to static meshes."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info)

	# Options
	var keep_check := CheckBox.new()
	keep_check.text = "Keep original CSG nodes (hidden)"
	keep_check.name = "KeepOriginals"
	vbox.add_child(keep_check)

	var collision_check := CheckBox.new()
	collision_check.text = "Generate collision shapes"
	collision_check.button_pressed = true
	collision_check.name = "GenerateCollision"
	vbox.add_child(collision_check)

	var merge_check := CheckBox.new()
	merge_check.text = "Merge meshes by material (reduces draw calls)"
	merge_check.name = "MergeByMaterial"
	vbox.add_child(merge_check)

	# Output folder
	var folder_hbox := HBoxContainer.new()
	vbox.add_child(folder_hbox)

	var folder_label := Label.new()
	folder_label.text = "Save meshes to:"
	folder_hbox.add_child(folder_label)

	var folder_edit := LineEdit.new()
	folder_edit.placeholder_text = "(optional) res://meshes/level_name/"
	folder_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder_edit.name = "OutputFolder"
	folder_hbox.add_child(folder_edit)

	return dialog
