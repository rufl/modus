extends ModusGutTestBase

## Unit tests for MapGenerator threaded generation pipeline
## Tests Requirements 29.3, 29.4, 29.5

const MapGeneratorScript: GDScript = preload("res://game/scripts/map_generator/map_generator.gd")
var map_generator: Node


func before_each() -> void:
	map_generator = MapGeneratorScript.new()
	add_child_autofree(map_generator)


func after_each() -> void:
	if map_generator:
		map_generator.cancel_generation()
		map_generator = null


## Test that threaded generation starts and completes
func test_threaded_generation_completes() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(128, 128)

	var signals_received := {"started": false, "completed": false, "scene": null}

	map_generator.generation_started.connect(func() -> void: signals_received["started"] = true)

	map_generator.generation_completed.connect(
		func(scene: PackedScene, _metadata: Dictionary) -> void:
			signals_received["completed"] = true
			signals_received["scene"] = scene
	)

	map_generator.generate_map("test_thread", config)

	# Wait for generation to complete (with timeout)
	var timeout := 20.0
	var elapsed := 0.0
	while not signals_received["completed"] and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	assert_true(signals_received["started"], "Generation should have started")
	assert_true(signals_received["completed"], "Generation should have completed")
	var packed_scene: PackedScene = signals_received["scene"]
	assert_not_null(packed_scene, "Generation should return a packed scene")
	var generated_map := packed_scene.instantiate()
	assert_not_null(generated_map, "Generated scene should instantiate after source cleanup")
	assert_not_null(
		generated_map.get_node_or_null("MapGeometry/Floors"),
		"Generated scene should retain recursively owned geometry"
	)
	assert_eq(
		generated_map.find_children("*", "NavigationRegion3D", true, false).size(),
		1,
		"Generated scene should retain one navigation region"
	)
	generated_map.free()


## Test that phase profiling tracks time for each phase
func test_phase_profiling_tracks_times() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(128, 128)

	var result := {"metadata": {}}

	map_generator.generation_completed.connect(
		func(_scene: PackedScene, meta: Dictionary) -> void: result["metadata"] = meta
	)

	map_generator.generate_map("test_profiling", config)

	# Wait for generation to complete
	var timeout := 20.0
	var elapsed := 0.0
	while result["metadata"].is_empty() and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	var metadata: Dictionary = result["metadata"]
	assert_true(metadata.has("phase_times"), "Metadata should contain phase_times")
	assert_true(metadata.has("generation_time"), "Metadata should contain generation_time")

	var phase_times: Dictionary = metadata.get("phase_times", {})
	assert_true(phase_times.has("grid_layout"), "Should track grid_layout phase time")
	assert_true(phase_times.has("shape_grammar"), "Should track shape_grammar phase time")
	assert_true(phase_times.has("hallway_generation"), "Should track hallway_generation phase time")
	assert_true(phase_times.has("cave_generation"), "Should track cave_generation phase time")


## Test that generation can be cancelled
func test_generation_can_be_cancelled() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(256, 256)

	var signals_received := {"cancelled": false}

	map_generator.generation_cancelled.connect(func() -> void: signals_received["cancelled"] = true)

	map_generator.generate_map("test_cancel", config)

	# Wait a bit then cancel
	await get_tree().create_timer(0.05).timeout
	map_generator.cancel_generation()

	# Wait for cancellation to process
	await get_tree().create_timer(0.2).timeout

	assert_true(signals_received["cancelled"], "Generation should have been cancelled")
	assert_false(map_generator.is_generating, "Should not be generating after cancel")


## Test that generation progress signals are emitted
func test_generation_progress_signals() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(128, 128)

	var result := {"phases": []}

	map_generator.generation_progress.connect(
		func(phase: String, _progress: float) -> void:
			var phases: Array = result["phases"]
			if phase not in phases:
				phases.append(phase)
	)

	map_generator.generate_map("test_progress", config)

	# Wait for generation to complete
	var timeout := 20.0
	var elapsed := 0.0
	while map_generator.is_generating and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	var progress_phases: Array = result["phases"]
	assert_gt(progress_phases.size(), 0, "Should have emitted progress for at least one phase")
	assert_true("grid_layout" in progress_phases, "Should have emitted progress for grid_layout")


## Test that metadata includes map size and seed hash
func test_metadata_includes_config_info() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(128, 128)

	var result := {"metadata": {}}

	map_generator.generation_completed.connect(
		func(_scene: PackedScene, meta: Dictionary) -> void: result["metadata"] = meta
	)

	map_generator.generate_map("test_metadata", config)

	# Wait for generation to complete
	var timeout := 20.0
	var elapsed := 0.0
	while result["metadata"].is_empty() and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	var metadata: Dictionary = result["metadata"]
	assert_true(metadata.has("map_size"), "Metadata should contain map_size")
	assert_true(metadata.has("seed_hash"), "Metadata should contain seed_hash")

	var map_size: Array = metadata.get("map_size", [])
	assert_eq(map_size[0], 128, "Map size X should be 128")
	assert_eq(map_size[1], 128, "Map size Y should be 128")


## Test that generation doesn't start if already generating
func test_prevents_concurrent_generation() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(128, 128)

	map_generator.generate_map("test_concurrent_1", config)

	# Try to start another generation immediately
	var initial_context: Variant = map_generator.generation_context
	map_generator.generate_map("test_concurrent_2", config)

	# Context should not have changed
	assert_eq(
		map_generator.generation_context,
		initial_context,
		"Should not start new generation while one is in progress"
	)

	# Wait for first generation to complete
	var timeout := 20.0
	var elapsed := 0.0
	while map_generator.is_generating and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1


## Test that total generation time is tracked
func test_total_generation_time_tracked() -> void:
	var config := GenerationConfig.new()
	config.map_size = Vector2i(128, 128)

	var result := {"metadata": {}}

	map_generator.generation_completed.connect(
		func(_scene: PackedScene, meta: Dictionary) -> void: result["metadata"] = meta
	)

	map_generator.generate_map("test_total_time", config)

	# Wait for generation to complete
	var timeout := 20.0
	var elapsed := 0.0
	while result["metadata"].is_empty() and elapsed < timeout:
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

	var metadata: Dictionary = result["metadata"]
	assert_true(metadata.has("generation_time"), "Should track total generation time")
	var total_time: float = metadata.get("generation_time", 0.0)
	assert_gt(total_time, 0, "Total generation time should be greater than 0")

	# Total time should be at least the sum of phase times
	var phase_times: Dictionary = metadata.get("phase_times", {})
	var phase_sum := 0
	for phase_name: String in phase_times:
		phase_sum += phase_times[phase_name]

	assert_ge(total_time, phase_sum, "Total time should be at least the sum of phase times")


## Test performance target helper methods


func test_performance_target_helpers() -> void:
	# Test map size targets
	var target_128: int = map_generator.get_performance_target(Vector2i(128, 128))
	assert_eq(target_128, 15000, "128x128 target should be 15000ms")

	var target_256: int = map_generator.get_performance_target(Vector2i(256, 256))
	assert_eq(target_256, 30000, "256x256 target should be 30000ms")

	# Test phase targets
	var grid_target: int = map_generator.get_phase_target("grid_layout")
	assert_eq(grid_target, 500, "Grid layout target should be 500ms")

	var cave_target: int = map_generator.get_phase_target("cave_generation")
	assert_eq(cave_target, 3000, "Cave generation target should be 3000ms")

	# Test within target check
	assert_true(
		map_generator.is_within_performance_target(Vector2i(128, 128), 10000),
		"10s should be within 15s target"
	)
	assert_false(
		map_generator.is_within_performance_target(Vector2i(128, 128), 20000),
		"20s should exceed 15s target"
	)
