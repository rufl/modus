extends ModusGutTestBase

const MapLODManagerScript := preload("res://game/scripts/map_generator/lod_manager.gd")


func test_mesh_without_imported_lods_is_not_replaced() -> void:
	var manager := MapLODManagerScript.new()
	var mesh := _mesh_with_optional_lods(false)
	var parent := Node3D.new()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	parent.add_child(instance)
	add_child_autofree(parent)

	assert_false(manager._convert_mesh_to_lod(instance, parent))
	assert_eq(parent.get_child_count(), 1)
	assert_eq(parent.get_child(0), instance)


func test_imported_lod_indices_create_real_reduced_levels() -> void:
	var manager := MapLODManagerScript.new()
	var mesh := _mesh_with_optional_lods(true)
	var reduced: Mesh = manager._simplify_mesh(mesh, 0.5)

	assert_not_null(reduced)
	var original_indices: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	var reduced_indices: PackedInt32Array = reduced.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	assert_lt(reduced_indices.size(), original_indices.size())
	assert_eq(reduced_indices.size() % 3, 0)


func _mesh_with_optional_lods(include_lods: bool) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
		[
			Vector3(0, 0, 0),
			Vector3(1, 0, 0),
			Vector3(1, 1, 0),
			Vector3(0, 1, 0),
		]
	)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var lods := {}
	if include_lods:
		lods[25.0] = PackedInt32Array([0, 1, 2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	return mesh
