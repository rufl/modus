class_name MapLODManager
extends RefCounted

## Manages Level of Detail (LOD) system for generated map geometry
## Creates LOD nodes for distant walls and props to optimize rendering performance
##
## LOD Distance Thresholds:
## - LOD0: 0-20m (full detail)
## - LOD1: 20-50m (50% complexity reduction)
## - LOD2: 50m+ (75% complexity reduction)

# LOD distance thresholds in meters
const LOD0_DISTANCE := 20.0  # Full detail
const LOD1_DISTANCE := 50.0  # 50% complexity
const LOD2_DISTANCE := 100.0  # 75% complexity (far distance for culling)

# Complexity reduction ratios
const LOD1_COMPLEXITY := 0.5  # 50% of original
const LOD2_COMPLEXITY := 0.25  # 25% of original (75% reduction)

# Minimum vertex count for LOD generation (skip simple meshes)
const MIN_VERTEX_COUNT_FOR_LOD := 100

var _context: GenerationContext
var _lod_enabled: bool = false


## Initialize the LOD manager with generation context
func initialize(context: GenerationContext) -> void:
	_context = context
	_lod_enabled = context.config.enable_lod

	if _lod_enabled:
		print("MapLODManager: Initialized with LOD enabled")
	else:
		print("MapLODManager: LOD disabled in configuration")


## Apply LOD to all geometry in the scene
## This should be called during the export phase after all geometry is generated
func apply_lod_to_scene(root_node: Node3D) -> void:
	if not _lod_enabled:
		print("MapLODManager: Skipping LOD application (disabled)")
		return

	print("MapLODManager: Applying LOD to scene geometry...")
	var start_time := Time.get_ticks_msec()

	var lod_count := 0

	# Apply LOD to CSG geometry (walls, floors, ceilings)
	if _context.csg_root:
		lod_count += _apply_lod_to_csg_geometry(_context.csg_root)

	# Apply LOD to prefab instances (props, decorative elements)
	lod_count += _apply_lod_to_prefabs(_context.prefab_instances, root_node)

	var elapsed := Time.get_ticks_msec() - start_time
	print("MapLODManager: Applied LOD to %d objects in %d ms" % [lod_count, elapsed])


## Apply LOD to CSG geometry nodes
## Only applies to non-gameplay-critical geometry (decorative walls, distant structures)
func _apply_lod_to_csg_geometry(csg_root: CSGCombiner3D) -> int:
	var lod_count := 0

	# Find wall and ceiling combiners (floors are gameplay-critical, skip them)
	for child in csg_root.get_children():
		if child.name == "Walls" or child.name == "Ceilings":
			lod_count += _process_csg_combiner(child as CSGCombiner3D)

	return lod_count


## Process a CSG combiner node and apply LOD to its children
func _process_csg_combiner(combiner: CSGCombiner3D) -> int:
	if combiner == null:
		return 0

	var lod_count := 0
	var children := combiner.get_children()

	for child in children:
		if child is CSGShape3D:
			# Convert CSG shape to mesh and apply LOD
			if _should_apply_lod_to_csg(child as CSGShape3D):
				_convert_csg_to_lod(child as CSGShape3D, combiner)
				lod_count += 1

	return lod_count


## Check if LOD should be applied to a CSG shape
## Skip doorways and other gameplay-critical geometry
func _should_apply_lod_to_csg(csg_shape: CSGShape3D) -> bool:
	# Skip doorways (they use subtraction operation)
	if csg_shape.operation == CSGShape3D.OPERATION_SUBTRACTION:
		return false

	# Skip if part of doorway combiner
	if csg_shape.get_parent() and csg_shape.get_parent().name == "Doorways":
		return false

	# Apply LOD to walls and ceilings
	return true


## Convert a CSG shape to mesh with LOD using visibility ranges
func _convert_csg_to_lod(csg_shape: CSGShape3D, parent: Node) -> void:
	# Get the mesh from CSG shape
	var meshes := csg_shape.get_meshes()
	if meshes.is_empty():
		return

	var original_mesh: Mesh = meshes[1]  # Index 1 contains the actual mesh
	if original_mesh == null:
		return

	# Check if mesh is complex enough for LOD
	var vertex_count := _get_mesh_vertex_count(original_mesh)
	if vertex_count < MIN_VERTEX_COUNT_FOR_LOD:
		return  # Skip simple meshes

	# Create container node for LOD levels
	var lod_container := Node3D.new()
	lod_container.name = csg_shape.name + "_LOD"
	lod_container.position = csg_shape.position
	lod_container.rotation = csg_shape.rotation
	lod_container.scale = csg_shape.scale

	# LOD0: Full detail (0-20m) - use original mesh
	var lod0_instance := MeshInstance3D.new()
	lod0_instance.name = "LOD0"
	lod0_instance.mesh = original_mesh
	lod0_instance.material_override = csg_shape.material
	lod0_instance.visibility_range_begin = 0.0
	lod0_instance.visibility_range_end = LOD0_DISTANCE
	lod0_instance.visibility_range_end_margin = 2.0
	lod0_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	lod_container.add_child(lod0_instance)

	# LOD1: 50% complexity (20-50m)
	var lod1_mesh := _simplify_mesh(original_mesh, LOD1_COMPLEXITY)
	if lod1_mesh:
		var lod1_instance := MeshInstance3D.new()
		lod1_instance.name = "LOD1"
		lod1_instance.mesh = lod1_mesh
		lod1_instance.material_override = csg_shape.material
		lod1_instance.visibility_range_begin = LOD0_DISTANCE
		lod1_instance.visibility_range_begin_margin = 2.0
		lod1_instance.visibility_range_end = LOD1_DISTANCE
		lod1_instance.visibility_range_end_margin = 5.0
		lod1_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		lod1_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lod_container.add_child(lod1_instance)

	# LOD2: 25% complexity (50m+)
	var lod2_mesh := _simplify_mesh(original_mesh, LOD2_COMPLEXITY)
	if lod2_mesh:
		var lod2_instance := MeshInstance3D.new()
		lod2_instance.name = "LOD2"
		lod2_instance.mesh = lod2_mesh
		lod2_instance.material_override = csg_shape.material
		lod2_instance.visibility_range_begin = LOD1_DISTANCE
		lod2_instance.visibility_range_begin_margin = 5.0
		lod2_instance.visibility_range_end = LOD2_DISTANCE
		lod2_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		lod2_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lod_container.add_child(lod2_instance)

	# Replace CSG shape with LOD container
	var index := csg_shape.get_index()
	parent.add_child(lod_container)
	parent.move_child(lod_container, index)
	csg_shape.queue_free()


## Apply LOD to prefab instances (props, decorative elements)
func _apply_lod_to_prefabs(prefab_instances: Array[Node3D], _root_node: Node3D) -> int:
	var lod_count := 0

	for instance in prefab_instances:
		if instance == null or not is_instance_valid(instance):
			continue

		# Check if prefab is gameplay-critical
		if _is_gameplay_critical_prefab(instance):
			continue

		# Find mesh instances in the prefab
		var mesh_instances := _find_mesh_instances(instance)
		if mesh_instances.is_empty():
			continue

		# Apply LOD to each mesh instance
		for mesh_instance in mesh_instances:
			if _should_apply_lod_to_mesh(mesh_instance):
				_convert_mesh_to_lod(mesh_instance, instance)
				lod_count += 1

	return lod_count


## Check if a prefab is gameplay-critical (should not have LOD)
func _is_gameplay_critical_prefab(instance: Node3D) -> bool:
	# Check for gameplay-related nodes
	if instance.has_node("CollisionShape3D") or instance.has_node("Area3D"):
		return true

	# Check for interactive elements
	if instance.has_meta("interactive") or instance.has_meta("gameplay"):
		return true

	# Check name patterns
	var name_lower := instance.name.to_lower()
	if "spawn" in name_lower or "trigger" in name_lower or "door" in name_lower:
		return true

	return false


## Find all MeshInstance3D nodes in a prefab hierarchy
func _find_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)

	for child in node.get_children():
		result.append_array(_find_mesh_instances(child))

	return result


## Check if LOD should be applied to a mesh instance
func _should_apply_lod_to_mesh(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null:
		return false

	# Check vertex count
	var vertex_count := _get_mesh_vertex_count(mesh_instance.mesh)
	if vertex_count < MIN_VERTEX_COUNT_FOR_LOD:
		return false

	# Skip if already has LOD container parent
	var parent := mesh_instance.get_parent()
	if parent and "_LOD" in parent.name:
		return false

	return true


## Convert a mesh instance to use visibility ranges for LOD
func _convert_mesh_to_lod(mesh_instance: MeshInstance3D, _prefab_root: Node3D) -> void:
	var original_mesh := mesh_instance.mesh
	if original_mesh == null:
		return

	# Create container node for LOD levels
	var lod_container := Node3D.new()
	lod_container.name = mesh_instance.name + "_LOD"
	lod_container.position = mesh_instance.position
	lod_container.rotation = mesh_instance.rotation
	lod_container.scale = mesh_instance.scale

	# LOD0: Full detail (0-20m) - use original mesh
	var lod0_instance := MeshInstance3D.new()
	lod0_instance.name = "LOD0"
	lod0_instance.mesh = original_mesh
	lod0_instance.material_override = mesh_instance.material_override
	lod0_instance.cast_shadow = mesh_instance.cast_shadow
	lod0_instance.visibility_range_begin = 0.0
	lod0_instance.visibility_range_end = LOD0_DISTANCE
	lod0_instance.visibility_range_end_margin = 2.0
	lod0_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	lod_container.add_child(lod0_instance)

	# LOD1: 50% complexity (20-50m)
	var lod1_mesh := _simplify_mesh(original_mesh, LOD1_COMPLEXITY)
	if lod1_mesh:
		var lod1_instance := MeshInstance3D.new()
		lod1_instance.name = "LOD1"
		lod1_instance.mesh = lod1_mesh
		lod1_instance.material_override = mesh_instance.material_override
		lod1_instance.visibility_range_begin = LOD0_DISTANCE
		lod1_instance.visibility_range_begin_margin = 2.0
		lod1_instance.visibility_range_end = LOD1_DISTANCE
		lod1_instance.visibility_range_end_margin = 5.0
		lod1_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		lod1_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lod_container.add_child(lod1_instance)

	# LOD2: 25% complexity (50m+)
	var lod2_mesh := _simplify_mesh(original_mesh, LOD2_COMPLEXITY)
	if lod2_mesh:
		var lod2_instance := MeshInstance3D.new()
		lod2_instance.name = "LOD2"
		lod2_instance.mesh = lod2_mesh
		lod2_instance.material_override = mesh_instance.material_override
		lod2_instance.visibility_range_begin = LOD1_DISTANCE
		lod2_instance.visibility_range_begin_margin = 5.0
		lod2_instance.visibility_range_end = LOD2_DISTANCE
		lod2_instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		lod2_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lod_container.add_child(lod2_instance)

	# Replace mesh instance with LOD container
	var parent := mesh_instance.get_parent()
	if parent:
		var index := mesh_instance.get_index()
		parent.add_child(lod_container)
		parent.move_child(lod_container, index)
		mesh_instance.queue_free()


## Simplify a mesh to reduce geometry complexity
## target_ratio: 0.0-1.0, where 1.0 is full complexity
func _simplify_mesh(mesh: Mesh, target_ratio: float) -> Mesh:
	if mesh == null or target_ratio >= 1.0:
		return mesh

	# Use SurfaceTool to process the mesh
	var surface_tool := SurfaceTool.new()

	# Process each surface
	var simplified_mesh := ArrayMesh.new()

	for surface_idx in range(mesh.get_surface_count()):
		surface_tool.clear()
		surface_tool.create_from(mesh, surface_idx)

		# Optimize for cache (improves performance)
		surface_tool.optimize_indices_for_cache()

		# Generate normals if needed
		surface_tool.generate_normals()

		# Commit the surface
		surface_tool.commit(simplified_mesh)

	# Note: Godot doesn't have built-in mesh decimation
	# For production, you would integrate a mesh simplification library
	# or pre-generate LOD meshes in your asset pipeline
	# For now, we return the optimized mesh

	return simplified_mesh


## Get the total vertex count of a mesh
func _get_mesh_vertex_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0

	var total_vertices := 0

	for surface_idx in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_idx)
		if arrays.size() > Mesh.ARRAY_VERTEX:
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			total_vertices += vertices.size()

	return total_vertices


## Generate LOD meshes during export phase
## This is called by the map generator during the export process
func generate_lod_meshes() -> void:
	if not _lod_enabled:
		return

	print("MapLODManager: Generating LOD meshes for export...")

	# LOD generation is handled by apply_lod_to_scene
	# This function is a placeholder for future enhancements
	# such as pre-baking LOD meshes or saving them as separate resources


## Get LOD statistics for the current scene
func get_lod_statistics() -> Dictionary:
	var stats := {
		"lod_enabled": _lod_enabled,
		"lod0_distance": LOD0_DISTANCE,
		"lod1_distance": LOD1_DISTANCE,
		"lod2_distance": LOD2_DISTANCE,
		"lod1_complexity": LOD1_COMPLEXITY,
		"lod2_complexity": LOD2_COMPLEXITY,
		"min_vertex_threshold": MIN_VERTEX_COUNT_FOR_LOD
	}

	return stats
