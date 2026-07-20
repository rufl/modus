class_name MultiMeshManager
extends RefCounted

## Manager for batching repeated prefabs into MultiMeshInstance3D nodes
## Provides significant performance benefits for prefabs used more than 10 times
## Supports per-instance transforms and color variation

## Threshold for considering a prefab as a multimesh candidate
const MULTIMESH_THRESHOLD := 10


## Data structure for tracking prefab instances
class PrefabInstanceData:
	var transform: Transform3D
	var color: Color

	func _init(p_transform: Transform3D, p_color: Color = Color.WHITE) -> void:
		transform = p_transform
		color = p_color


## Groups prefab instances by scene file path
## Returns: Dictionary[String, Array[PrefabInstanceData]]
func group_prefab_instances(placement_results: Array) -> Dictionary:
	var groups: Dictionary = {}

	for result in placement_results:
		if result == null or result.node == null or result.entry == null:
			continue

		var scene_path: String = result.entry.file_path

		if not groups.has(scene_path):
			groups[scene_path] = []

		# Create instance data with transform and random color variation
		var instance_data := PrefabInstanceData.new(
			result.node.global_transform, _generate_color_variation()
		)

		groups[scene_path].append(instance_data)

	return groups


## Identifies prefabs used more than MULTIMESH_THRESHOLD times
## Returns: Array[String] of scene paths that are multimesh candidates
func identify_multimesh_candidates(groups: Dictionary) -> Array[String]:
	var candidates: Array[String] = []

	for scene_path: String in groups.keys():
		var instances: Array = groups[scene_path]
		if instances.size() >= MULTIMESH_THRESHOLD:
			candidates.append(scene_path)

	return candidates


## Extracts mesh from a prefab PackedScene
## Returns the first MeshInstance3D mesh found in the scene hierarchy
func extract_mesh_from_prefab(prefab_scene: PackedScene) -> Mesh:
	if prefab_scene == null:
		push_error("MultiMeshManager: Cannot extract mesh from null scene")
		return null

	# Instantiate the scene temporarily
	var instance := prefab_scene.instantiate()
	if instance == null:
		push_error("MultiMeshManager: Failed to instantiate prefab scene")
		return null

	# Find the first MeshInstance3D
	var mesh := _find_mesh_in_node(instance)

	# Clean up temporary instance
	instance.queue_free()

	return mesh


## Recursively searches for MeshInstance3D in node hierarchy
func _find_mesh_in_node(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return node.mesh

	for child in node.get_children():
		var mesh := _find_mesh_in_node(child)
		if mesh != null:
			return mesh

	return null


## Creates a MultiMeshInstance3D for a group of prefab instances
## Returns the created MultiMeshInstance3D node
func create_multimesh_instance(
	scene_path: String, instances: Array, prefab_scene: PackedScene
) -> MultiMeshInstance3D:
	if instances.is_empty():
		push_warning("MultiMeshManager: No instances to batch for %s" % scene_path)
		return null

	# Extract mesh from prefab
	var mesh := extract_mesh_from_prefab(prefab_scene)
	if mesh == null:
		push_warning("MultiMeshManager: Could not extract mesh from prefab: %s" % scene_path)
		return null

	# Create MultiMesh
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true  # Enable per-instance colors
	multimesh.instance_count = instances.size()
	multimesh.mesh = mesh

	# Set per-instance transforms and colors
	for i in range(instances.size()):
		var instance_data: PrefabInstanceData = instances[i]
		multimesh.set_instance_transform(i, instance_data.transform)
		multimesh.set_instance_color(i, instance_data.color)

	# Create MultiMeshInstance3D
	var multimesh_instance := MultiMeshInstance3D.new()
	multimesh_instance.multimesh = multimesh
	multimesh_instance.name = "MultiMesh_%s" % scene_path.get_file().get_basename()

	return multimesh_instance


## Batches prefab instances into MultiMeshInstance3D nodes
## Removes individual instances and replaces them with batched MultiMesh nodes
## Returns: Dictionary with statistics about the batching operation
func batch_prefabs(
	placement_results: Array, parent_node: Node3D, config: GenerationConfig
) -> Dictionary:
	# Check if multimesh is enabled
	if not config.use_multimesh:
		return {"enabled": false, "batched_count": 0, "multimesh_count": 0, "total_instances": 0}

	# Group instances by prefab
	var groups := group_prefab_instances(placement_results)

	# Identify multimesh candidates
	var candidates := identify_multimesh_candidates(groups)

	if candidates.is_empty():
		return {
			"enabled": true,
			"batched_count": 0,
			"multimesh_count": 0,
			"total_instances": placement_results.size()
		}

	var batched_count := 0
	var multimesh_count := 0
	var nodes_to_remove: Array[Node3D] = []

	# Create MultiMesh for each candidate
	for scene_path: String in candidates:
		var instances: Array = groups[scene_path]

		# Load the prefab scene
		var prefab_scene := load(scene_path) as PackedScene
		if prefab_scene == null:
			push_warning("MultiMeshManager: Failed to load prefab scene: %s" % scene_path)
			continue

		# Create MultiMeshInstance3D
		var multimesh_instance := create_multimesh_instance(scene_path, instances, prefab_scene)
		if multimesh_instance == null:
			continue

		# Add to parent
		parent_node.add_child(multimesh_instance)

		# Mark individual instances for removal
		for result in placement_results:
			if result != null and result.entry != null and result.entry.file_path == scene_path:
				if result.node != null and is_instance_valid(result.node):
					nodes_to_remove.append(result.node)

		batched_count += instances.size()
		multimesh_count += 1

	# Remove individual instances
	for node in nodes_to_remove:
		if is_instance_valid(node):
			node.queue_free()

	return {
		"enabled": true,
		"batched_count": batched_count,
		"multimesh_count": multimesh_count,
		"total_instances": placement_results.size(),
		"candidates": candidates
	}


## Generates a random color variation for visual diversity
## Returns a color with slight variation from white
func _generate_color_variation() -> Color:
	# Generate subtle color variation (0.9 to 1.1 range for each channel)
	var variation := 0.1
	var r := randf_range(1.0 - variation, 1.0 + variation)
	var g := randf_range(1.0 - variation, 1.0 + variation)
	var b := randf_range(1.0 - variation, 1.0 + variation)

	return Color(clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(b, 0.0, 1.0), 1.0)


## Applies MultiMesh batching to a set of placement results
## This is the main entry point for the batching system
## Returns statistics about the batching operation
func apply_multimesh_batching(
	placement_results: Array, parent_node: Node3D, context: GenerationContext
) -> Dictionary:
	if context == null or context.config == null:
		push_error("MultiMeshManager: Invalid generation context")
		return {
			"enabled": false,
			"batched_count": 0,
			"multimesh_count": 0,
			"total_instances": 0,
			"error": "Invalid context"
		}

	return batch_prefabs(placement_results, parent_node, context.config)
