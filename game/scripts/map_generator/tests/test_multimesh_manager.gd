extends GutTest

## Unit tests for MultiMeshManager
## Tests prefab grouping, candidate identification, and MultiMesh batching

const MultiMeshManager = preload("res://game/scripts/map_generator/multimesh_manager.gd")
const GenerationConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const GenerationContext = preload("res://game/scripts/map_generator/generation_context.gd")
const MapPrefabSystem = preload("res://game/scripts/map_generator/prefab_system.gd")

var multimesh_manager: MultiMeshManager
var test_scene_root: Node3D


func before_each() -> void:
	multimesh_manager = MultiMeshManager.new()
	test_scene_root = Node3D.new()
	add_child_autofree(test_scene_root)


func after_each() -> void:
	multimesh_manager = null


## Test: Group prefab instances by scene path
func test_group_prefab_instances() -> void:
	# Create mock placement results
	var placement_results := []

	# Create 3 instances of prefab A
	for i in range(3):
		var result := _create_mock_placement_result("res://prefab_a.tscn")
		placement_results.append(result)

	# Create 2 instances of prefab B
	for i in range(2):
		var result := _create_mock_placement_result("res://prefab_b.tscn")
		placement_results.append(result)

	# Group instances
	var groups := multimesh_manager.group_prefab_instances(placement_results)

	# Verify grouping
	assert_eq(groups.size(), 2, "Should have 2 groups")
	assert_true(groups.has("res://prefab_a.tscn"), "Should have prefab_a group")
	assert_true(groups.has("res://prefab_b.tscn"), "Should have prefab_b group")
	assert_eq(groups["res://prefab_a.tscn"].size(), 3, "Prefab A should have 3 instances")
	assert_eq(groups["res://prefab_b.tscn"].size(), 2, "Prefab B should have 2 instances")


## Test: Identify multimesh candidates (>= 10 instances)
func test_identify_multimesh_candidates() -> void:
	var groups := {
		"res://prefab_a.tscn": _create_instance_array(15),
		"res://prefab_b.tscn": _create_instance_array(5),
		"res://prefab_c.tscn": _create_instance_array(10),
		"res://prefab_d.tscn": _create_instance_array(9)
	}

	var candidates := multimesh_manager.identify_multimesh_candidates(groups)

	# Verify candidates
	assert_eq(candidates.size(), 2, "Should have 2 candidates")
	assert_true(candidates.has("res://prefab_a.tscn"), "Prefab A (15) should be candidate")
	assert_true(candidates.has("res://prefab_c.tscn"), "Prefab C (10) should be candidate")
	assert_false(candidates.has("res://prefab_b.tscn"), "Prefab B (5) should not be candidate")
	assert_false(candidates.has("res://prefab_d.tscn"), "Prefab D (9) should not be candidate")


## Test: Extract mesh from prefab scene
func test_extract_mesh_from_prefab() -> void:
	# Create a simple test scene with a MeshInstance3D
	var test_scene := PackedScene.new()
	var root := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	test_scene.pack(root)

	# Extract mesh
	var extracted_mesh := multimesh_manager.extract_mesh_from_prefab(test_scene)

	# Verify extraction
	assert_not_null(extracted_mesh, "Should extract mesh")
	assert_true(extracted_mesh is BoxMesh, "Should be BoxMesh")

	# Clean up
	root.queue_free()


## Test: Extract mesh returns null for scene without mesh
func test_extract_mesh_no_mesh() -> void:
	# Create a scene without MeshInstance3D
	var test_scene := PackedScene.new()
	var root := Node3D.new()
	test_scene.pack(root)

	# Extract mesh
	var extracted_mesh := multimesh_manager.extract_mesh_from_prefab(test_scene)

	# Verify null return
	assert_null(extracted_mesh, "Should return null when no mesh found")

	# Clean up
	root.queue_free()


## Test: Create MultiMeshInstance3D
func test_create_multimesh_instance() -> void:
	# Create test scene with mesh
	var test_scene := PackedScene.new()
	var root := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = SphereMesh.new()
	root.add_child(mesh_instance)
	mesh_instance.owner = root
	test_scene.pack(root)

	# Create instance data
	var instances := []
	for i in range(5):
		var transform := Transform3D(Basis(), Vector3(i * 2.0, 0.0, 0.0))
		var instance_data := MultiMeshManager.PrefabInstanceData.new(transform, Color.WHITE)
		instances.append(instance_data)

	# Create MultiMeshInstance3D
	var multimesh_instance := multimesh_manager.create_multimesh_instance(
		"res://test.tscn", instances, test_scene
	)

	# Verify creation
	assert_not_null(multimesh_instance, "Should create MultiMeshInstance3D")
	assert_true(multimesh_instance is MultiMeshInstance3D, "Should be MultiMeshInstance3D")
	assert_not_null(multimesh_instance.multimesh, "Should have MultiMesh")
	assert_eq(multimesh_instance.multimesh.instance_count, 5, "Should have 5 instances")
	assert_true(multimesh_instance.multimesh.use_colors, "Should use colors")

	# Clean up
	root.queue_free()
	multimesh_instance.queue_free()


## Test: Batch prefabs with multimesh disabled
func test_batch_prefabs_disabled() -> void:
	var config := GenerationConfig.new()
	config.use_multimesh = false

	var placement_results := []
	for i in range(15):
		placement_results.append(_create_mock_placement_result("res://prefab.tscn"))

	var stats := multimesh_manager.batch_prefabs(placement_results, test_scene_root, config)

	# Verify no batching occurred
	assert_false(stats["enabled"], "Should be disabled")
	assert_eq(stats["batched_count"], 0, "Should not batch any prefabs")
	assert_eq(stats["multimesh_count"], 0, "Should not create any MultiMesh")


## Test: Batch prefabs with no candidates
func test_batch_prefabs_no_candidates() -> void:
	var config := GenerationConfig.new()
	config.use_multimesh = true

	# Create only 5 instances (below threshold)
	var placement_results := []
	for i in range(5):
		placement_results.append(_create_mock_placement_result("res://prefab.tscn"))

	var stats := multimesh_manager.batch_prefabs(placement_results, test_scene_root, config)

	# Verify no batching occurred
	assert_true(stats["enabled"], "Should be enabled")
	assert_eq(stats["batched_count"], 0, "Should not batch any prefabs")
	assert_eq(stats["multimesh_count"], 0, "Should not create any MultiMesh")


## Test: Color variation is applied during grouping
func test_color_variation_applied() -> void:
	# Create mock placement results
	var placement_results := []
	for i in range(3):
		var result := _create_mock_placement_result("res://prefab.tscn")
		placement_results.append(result)

	# Group instances (which applies color variation)
	var groups := multimesh_manager.group_prefab_instances(placement_results)

	# Verify that instance data has colors
	var instances: Array = groups["res://prefab.tscn"]
	for instance_data in instances:
		assert_not_null(instance_data.color, "Should have color")
		assert_true(instance_data.color is Color, "Should be Color type")


## Test: Apply multimesh batching with invalid context
func test_apply_multimesh_batching_invalid_context() -> void:
	var placement_results := []
	var stats := multimesh_manager.apply_multimesh_batching(
		placement_results, test_scene_root, null
	)

	# Verify error handling
	assert_false(stats["enabled"], "Should be disabled due to invalid context")
	assert_true(stats.has("error"), "Should have error message")


## Test: Apply multimesh batching with valid context
func test_apply_multimesh_batching_valid_context() -> void:
	var context := GenerationContext.new()
	context.config = GenerationConfig.new()
	context.config.use_multimesh = true
	context.rng = RandomNumberGenerator.new()

	# Create placement results (below threshold)
	var placement_results := []
	for i in range(5):
		placement_results.append(_create_mock_placement_result("res://prefab.tscn"))

	var stats := multimesh_manager.apply_multimesh_batching(
		placement_results, test_scene_root, context
	)

	# Verify stats
	assert_true(stats["enabled"], "Should be enabled")
	assert_eq(stats["total_instances"], 5, "Should track total instances")


## Helper: Create mock placement result
func _create_mock_placement_result(scene_path: String) -> MapPrefabSystem.PlacementResult:
	var node := Node3D.new()
	test_scene_root.add_child(node)

	# scene and metadata not needed for grouping test
	var entry := MapPrefabSystem.PrefabEntry.new(null, null, scene_path)

	return MapPrefabSystem.PlacementResult.new(node, entry, Vector3.ZERO, 0.0)


## Helper: Create array of instance data
func _create_instance_array(count: int) -> Array:
	var instances := []
	for i in range(count):
		var transform := Transform3D(Basis(), Vector3(i, 0, 0))
		var instance_data := MultiMeshManager.PrefabInstanceData.new(transform)
		instances.append(instance_data)
	return instances
