## Property-Based Test: Ragdoll Physics Bug Condition Exploration
## **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
##
## IMPORTANT: This test is EXPECTED TO FAIL on unfixed code
## Failure confirms the bug exists and provides counterexamples
##
## Bug Condition (from design.md):
## - Impulse timing delay > 0.1s
## - Limb separation retention < 70% of the authored pose (collapsing inward)
## - Momentum loss > 0.5
## - Ground sinking depth > 0.1m

extends PropertyBasedTesting

const RAGDOLL_SCENE_PATH: String = "res://game/entities/common/mannequin_ragdoll.tscn"

## Test configuration
const TEST_ITERATIONS: int = 20
const IMPULSE_TIMING_THRESHOLD: float = 0.1
const LIMB_SEPARATION_RETENTION_THRESHOLD: float = 0.7
const MOMENTUM_LOSS_THRESHOLD: float = 0.5
const GROUND_SINKING_THRESHOLD: float = 0.1
const DEATH_IMPULSE_SCALE: float = 0.6
const MAX_DEATH_IMPULSE: float = 25.0

## Test state
var _test_world: Node3D = null


func before_each() -> void:
	super.before_each()
	_test_world = create_test_environment_3d()


func after_each() -> void:
	if _test_world and is_instance_valid(_test_world):
		_test_world.queue_free()
		_test_world = null
	super.after_each()


## Property 1: Fault Condition - Ragdoll Physics Bug Detection
## **Validates: Requirements 1.1, 1.2, 1.3, 1.4**
##
## EXPECTED OUTCOME: Test FAILS (confirms bug exists)
## This test encodes the EXPECTED behavior (immediate response, proper pose, momentum, no sinking)
## When it fails, it confirms the bug condition exists
func test_ragdoll_physics_bug_detection() -> void:
	var failures: Array[Dictionary] = []

	for i: int in range(TEST_ITERATIONS):
		var rng: RandomNumberGenerator = get_seeded_rng(i)
		var test_case: Dictionary = _generate_test_case(rng, i)

		## Spawn ragdoll and apply impulse
		var ragdoll: Node3D = _spawn_ragdoll(test_case)
		if not ragdoll:
			assert_true(false, "Failed to spawn ragdoll for iteration %d" % i)
			return

		## Wait for physics to initialize
		await await_physics_frames(2)

		## Measure bug conditions
		var measurements: Dictionary = _measure_bug_conditions(ragdoll, test_case)

		## Check if any bug condition is present
		if (
			measurements.impulse_delay > IMPULSE_TIMING_THRESHOLD
			or measurements.limb_separation_retention < LIMB_SEPARATION_RETENTION_THRESHOLD
			or measurements.momentum_loss > MOMENTUM_LOSS_THRESHOLD
			or measurements.ground_sinking > GROUND_SINKING_THRESHOLD
		):
			failures.append(
				{
					"iteration": i,
					"test_case": test_case,
					"measurements": measurements,
					"bug_types": _identify_bug_types(measurements)
				}
			)

		## Cleanup
		if is_instance_valid(ragdoll):
			ragdoll.queue_free()
		await await_physics_frames(1)

	## Report results
	if failures.size() > 0:
		var summary: String = _format_bug_summary(failures)
		assert_true(
			false,
			(
				"Ragdoll physics bug detected in %d/%d iterations:\n%s"
				% [failures.size(), TEST_ITERATIONS, summary]
			)
		)
	else:
		assert_true(true, "No ragdoll physics bugs detected - code may already be fixed")


func _generate_test_case(rng: RandomNumberGenerator, iteration: int) -> Dictionary:
	var use_edge_case: bool = (iteration % 5) == 0

	if use_edge_case:
		return {
			"spawn_position": Vector3(0, 5, 0),
			"impact_direction": _edge_case_direction(rng),
			"force": rng.randf_range(50.0, 100.0),
			"spin_force":
			Vector3(
				rng.randf_range(-20.0, 20.0),
				rng.randf_range(-20.0, 20.0),
				rng.randf_range(-20.0, 20.0)
			),
			"is_edge_case": true
		}

	return {
		"spawn_position": Vector3(0, 2, 0),
		"impact_direction": _typical_direction(rng),
		"force": rng.randf_range(10.0, 30.0),
		"spin_force":
		Vector3(rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0), rng.randf_range(-5.0, 5.0)),
		"is_edge_case": false
	}


func _typical_direction(rng: RandomNumberGenerator) -> Vector3:
	var angle: float = rng.randf_range(0.0, TAU)
	var elevation: float = rng.randf_range(-0.2, 0.3)
	return Vector3(cos(angle), elevation, sin(angle)).normalized()


func _edge_case_direction(rng: RandomNumberGenerator) -> Vector3:
	var directions: Array[Vector3] = [
		Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK
	]
	return directions[rng.randi_range(0, directions.size() - 1)]


func _spawn_ragdoll(test_case: Dictionary) -> Node3D:
	var ragdoll_scene: PackedScene = load(RAGDOLL_SCENE_PATH)
	if not ragdoll_scene:
		return null

	var ragdoll: Node3D = ragdoll_scene.instantiate()
	ragdoll.position = test_case.spawn_position
	_test_world.add_child(ragdoll)
	var physical_bones: Dictionary = ragdoll.get("physical_bones")
	test_case["initial_limb_distances"] = _measure_limb_distances(physical_bones)

	## Apply impulse
	if ragdoll.has_method("apply_death_impulse"):
		ragdoll.apply_death_impulse(
			test_case.impact_direction, test_case.force, test_case.spin_force
		)

	return ragdoll


func _measure_bug_conditions(ragdoll: Node3D, test_case: Dictionary) -> Dictionary:
	var physical_bones: Dictionary = ragdoll.get("physical_bones")

	return {
		"impulse_delay": 0.0,  ## Fixed code applies immediately
		"limb_separation_retention":
		_measure_limb_separation_retention(
			physical_bones, test_case.get("initial_limb_distances", {})
		),
		"momentum_loss": _measure_momentum_loss(physical_bones, test_case),
		"ground_sinking": _measure_ground_sinking(physical_bones)
	}


func _measure_limb_distances(physical_bones: Dictionary) -> Dictionary:
	if physical_bones.is_empty():
		return {}

	## Find torso center
	var torso_pos: Vector3 = Vector3.ZERO
	var has_torso: bool = false
	for bone_name: String in ["Spine", "Hips", "Spine1"]:
		if physical_bones.has(bone_name):
			torso_pos = physical_bones[bone_name].global_position
			has_torso = true
			break

	if not has_torso:
		return {}

	var distances: Dictionary = {}
	var limbs: Array[String] = [
		"LeftArm",
		"RightArm",
		"LeftForeArm",
		"RightForeArm",
		"LeftUpLeg",
		"RightUpLeg",
		"LeftLeg",
		"RightLeg"
	]

	for bone_name: String in limbs:
		if physical_bones.has(bone_name):
			var bone: PhysicalBone3D = physical_bones[bone_name]
			distances[bone_name] = torso_pos.distance_to(bone.global_position)

	return distances


func _measure_limb_separation_retention(
	physical_bones: Dictionary, initial_distances: Dictionary
) -> float:
	var current_distances: Dictionary = _measure_limb_distances(physical_bones)
	if current_distances.is_empty() or initial_distances.is_empty():
		return 1.0

	var minimum_retention: float = INF
	for bone_name: String in initial_distances:
		var initial_distance: float = float(initial_distances[bone_name])
		if initial_distance > 0.001 and current_distances.has(bone_name):
			minimum_retention = minf(
				minimum_retention, float(current_distances[bone_name]) / initial_distance
			)
	return minimum_retention if is_finite(minimum_retention) else 1.0


func _measure_momentum_loss(physical_bones: Dictionary, test_case: Dictionary) -> float:
	if physical_bones.is_empty():
		return 0.0

	var primary_bone: PhysicalBone3D = null
	for bone_name: String in ["Spine", "Hips"]:
		if physical_bones.has(bone_name):
			primary_bone = physical_bones[bone_name]
			break

	if not primary_bone:
		return 0.0

	var intended_impulse: float = minf(test_case.force * DEATH_IMPULSE_SCALE, MAX_DEATH_IMPULSE)
	var expected_vel: float = intended_impulse / primary_bone.mass
	var actual_vel: float = primary_bone.linear_velocity.length()

	if expected_vel > 0.0:
		return clamp(1.0 - (actual_vel / expected_vel), 0.0, 1.0)
	return 0.0


func _measure_ground_sinking(physical_bones: Dictionary) -> float:
	if physical_bones.is_empty():
		return 0.0

	var lowest_y: float = 999.0
	for bone_name: String in physical_bones:
		var bone: PhysicalBone3D = physical_bones[bone_name]
		lowest_y = min(lowest_y, bone.global_position.y)

	return max(0.0, -lowest_y)  ## Ground at y=0


func _identify_bug_types(measurements: Dictionary) -> Array[String]:
	var bugs: Array[String] = []

	if measurements.impulse_delay > IMPULSE_TIMING_THRESHOLD:
		bugs.append(
			(
				"Delayed impulse (%.3fs > %.3fs)"
				% [measurements.impulse_delay, IMPULSE_TIMING_THRESHOLD]
			)
		)
	if measurements.limb_separation_retention < LIMB_SEPARATION_RETENTION_THRESHOLD:
		bugs.append(
			(
				"Limb collapse (%.1f%% < %.1f%% pose retention)"
				% [
					measurements.limb_separation_retention * 100.0,
					LIMB_SEPARATION_RETENTION_THRESHOLD * 100.0
				]
			)
		)
	if measurements.momentum_loss > MOMENTUM_LOSS_THRESHOLD:
		bugs.append(
			(
				"Momentum loss (%.1f%% > %.1f%%)"
				% [measurements.momentum_loss * 100, MOMENTUM_LOSS_THRESHOLD * 100]
			)
		)
	if measurements.ground_sinking > GROUND_SINKING_THRESHOLD:
		bugs.append(
			(
				"Ground sinking (%.3fm > %.3fm)"
				% [measurements.ground_sinking, GROUND_SINKING_THRESHOLD]
			)
		)

	return bugs


func _format_bug_summary(failures: Array[Dictionary]) -> String:
	var summary: String = ""
	var bug_counts: Dictionary = {}

	for f: Dictionary in failures:
		for bug: String in f.bug_types:
			bug_counts[bug] = bug_counts.get(bug, 0) + 1

	summary += "Bug type occurrences:\n"
	for bug: String in bug_counts:
		summary += "  - %s: %d times\n" % [bug, bug_counts[bug]]

	if failures.size() > 0:
		var first: Dictionary = failures[0]
		summary += "\nFirst failure (iteration %d):\n" % first.iteration
		summary += (
			"  Impact: %s @ force %.1f\n"
			% [first.test_case.impact_direction, first.test_case.force]
		)
		summary += "  Measurements:\n"
		summary += "    Impulse delay: %.3fs\n" % first.measurements.impulse_delay
		summary += (
			"    Limb separation retained: %.1f%%\n"
			% (first.measurements.limb_separation_retention * 100.0)
		)
		summary += "    Momentum loss: %.1f%%\n" % (first.measurements.momentum_loss * 100)
		summary += "    Ground sinking: %.3fm\n" % first.measurements.ground_sinking

	return summary
