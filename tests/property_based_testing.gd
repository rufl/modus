# PropertyBasedTesting - Base class for property-based tests in MODUS
# Extends GutTest to provide PBT utilities with full GUT integration
# Updated: 2026-03-05 - Added SamplingStrategy enum and helper methods
extends GutTest
class_name PropertyBasedTesting

# =============================================================================
# SAMPLING STRATEGIES
# =============================================================================

enum SamplingStrategy { MIXED, EDGE_CASE, RANDOM, BOUNDARY_VALUES }

# =============================================================================
# PROPERTY-BASED TESTING CORE
# =============================================================================


## Generate a random Vector3 within specified range
func generate_vector3(rng: RandomNumberGenerator, min_val: float, max_val: float) -> Vector3:
	return Vector3(
		rng.randf_range(min_val, max_val),
		rng.randf_range(min_val, max_val),
		rng.randf_range(min_val, max_val)
	)


## Run an enhanced property test with sampling strategy
func run_enhanced_property_test(
	test_name: String,
	test_func: Callable,
	iterations: int,
	strategy: SamplingStrategy,
	description: String = ""
) -> void:
	var requested_iterations: int = int(OS.get_environment("MODUS_PROPERTY_ITERATIONS"))
	var effective_iterations: int = iterations
	if requested_iterations > 0:
		effective_iterations = mini(iterations, requested_iterations)
	var passed: int = 0
	var failed: int = 0
	var errors: Array[String] = []

	for i: int in range(effective_iterations):
		var test_data: Dictionary = {
			"iteration": i, "strategy": strategy, "total_iterations": effective_iterations
		}

		var result: bool = false
		var error_message: String = ""

		# Run the test function
		if test_func.is_valid():
			result = await test_func.call(test_data)
		else:
			error_message = "Invalid test function"
			failed += 1
			errors.append("Iteration %d: %s" % [i, error_message])
			continue

		if result:
			passed += 1
		else:
			failed += 1
			errors.append("Iteration %d: Test returned false" % i)

	# Report results
	var success_rate: float = float(passed) / float(effective_iterations) * 100.0
	var message: String = (
		"%s: %d/%d passed (%.1f%%)" % [test_name, passed, effective_iterations, success_rate]
	)

	if description != "":
		message += " - %s" % description

	# Assert all tests passed
	assert_eq(failed, 0, message)

	# Print errors if any
	if failed > 0:
		for error: String in errors:
			push_error(error)


## Consume only the new push_error diagnostics emitted by one property iteration.
## GUT's built-in count assertions inspect the whole enclosing test, while this
## helper preserves per-iteration accounting for async property loops.
func assert_property_push_error_count(expected_count: int, message: String = "") -> void:
	var unhandled_errors: Array = []
	for error in get_errors():
		if error.is_push_error() and not error.handled:
			unhandled_errors.append(error)
			error.handled = true
	assert_eq(unhandled_errors.size(), expected_count, message)


func assert_property_push_error(text: String, message: String = "") -> void:
	var matched := false
	for error in get_errors():
		if error.is_push_error() and not error.handled and error.contains_text(text):
			error.handled = true
			matched = true
			break
	assert_true(matched, message)


## Consume deferred engine diagnostics after a property iteration has asserted
## its observable result. Parser errors can arrive one frame after the call.
func consume_property_push_errors() -> void:
	await get_tree().process_frame
	for error in get_errors():
		if error.is_push_error() and not error.handled:
			error.handled = true


## Get a seeded random number generator for deterministic tests
func get_seeded_rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# =============================================================================
# PHYSICS TEST HELPERS
# =============================================================================


## Create a minimal 3D test environment with ground plane
func create_test_environment_3d() -> Node3D:
	var world: Node3D = Node3D.new()
	world.name = "TestWorld"
	add_child_autofree(world)

	# Ground plane
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(100, 0.1, 100)
	ground.add_child(shape)
	ground.position = Vector3(0, 0, 0)
	world.add_child(ground)

	return world


## Wait for physics to process
func await_physics_frames(frames: int = 1) -> void:
	for i: int in range(frames):
		await get_tree().physics_frame
		await get_tree().process_frame


## Wait for timer
func await_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# =============================================================================
# ASSERTION HELPERS FOR PHYSICS
# =============================================================================


## Assert velocity is within expected range
func assert_velocity_in_range(
	actual: Vector3,
	expected_direction: Vector3,
	tolerance: float = 0.5,
	custom_message: String = ""
) -> void:
	var message: String = (
		custom_message if custom_message != "" else "Velocity should be in expected direction"
	)
	var dot_product: float = actual.normalized().dot(expected_direction.normalized())
	assert_true(dot_product > tolerance, message)


## Assert position change is within range
func assert_position_changed(
	before: Vector3, after: Vector3, min_distance: float = 0.01, custom_message: String = ""
) -> void:
	var message: String = custom_message if custom_message != "" else "Position should have changed"
	var distance: float = before.distance_to(after)
	assert_true(distance >= min_distance, message + " (changed by %.3fm)" % distance)


## Assert node is inside tree and ready
func assert_node_ready(node: Node, custom_message: String = "") -> void:
	var message: String = (
		custom_message if custom_message != "" else "Node should be ready and in tree"
	)
	assert_not_null(node, message)
	if node:
		assert_true(is_instance_valid(node), message + " - instance is valid")
		assert_true(node.is_inside_tree(), message + " - is inside tree")

# Force LSP reload - 2026-03-05
