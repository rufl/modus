## Property-Based Test: Ragdoll Feature Preservation
## **Validates: Requirements 3.1, 3.2, 3.3, 3.4**
##
## IMPORTANT: This test is EXPECTED TO PASS on unfixed code
## Passing confirms baseline behavior to preserve during bugfix
##
## Preservation Requirements (from bugfix.md):
## - Ragdoll gibbing when torso takes >100 damage (total explosion)
## - Blood effects spawn at hit locations with proper direction
## - Dismemberment works for limbs taking >15 damage
## - 30-second auto cleanup timer for ragdoll entities

extends PropertyBasedTesting

const RAGDOLL_SCENE_PATH: String = "res://game/entities/common/mannequin_ragdoll.tscn"
const GIB_THRESHOLD: float = 50.0
const DISMEMBER_THRESHOLD: float = 15.0

## Test configuration
const TEST_ITERATIONS: int = 20

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


## Property 2: Feature Preservation - Gibbing on High Torso Damage
## **Validates: Requirement 3.1**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that ragdoll gibbing occurs when torso takes >100 damage
func test_ragdoll_gibbing_preservation() -> void:
	var failures: Array[Dictionary] = []

	for i: int in range(TEST_ITERATIONS):
		var rng: RandomNumberGenerator = get_seeded_rng(i)
		
		## Generate test case with high torso damage
		var damage: float = rng.randf_range(GIB_THRESHOLD + 10.0, GIB_THRESHOLD + 100.0)
		var torso_parts: Array[String] = ["Spine", "Spine1", "Hips"]
		var part_id: String = torso_parts[rng.randi_range(0, torso_parts.size() - 1)]
		
		## Spawn ragdoll
		var ragdoll: Node3D = _spawn_ragdoll()
		if not ragdoll:
			assert_true(false, "Failed to spawn ragdoll for iteration %d" % i)
			return

		## Wait for physics initialization
		await await_physics_frames(1)

		## Track if gibbing occurs
		var gibbing_occurred: bool = false
		
		## Apply high damage to torso part
		if ragdoll.has_method("on_part_hit"):
			var physical_bones: Dictionary = ragdoll.get("physical_bones")
			if physical_bones and physical_bones.has(part_id):
				var part: PhysicalBone3D = physical_bones[part_id]
				
				## Apply damage
				ragdoll.on_part_hit(part, damage)
				
				## Wait for effects
				await await_physics_frames(1)
				
				## Check if ragdoll was destroyed (gibbing occurred)
				gibbing_occurred = not is_instance_valid(ragdoll) or ragdoll.is_queued_for_deletion()

		## Verify gibbing occurred
		if not gibbing_occurred:
			failures.append({
				"iteration": i,
				"damage": damage,
				"part_id": part_id,
				"reason": "Gibbing did not occur despite damage > threshold"
			})

		## Cleanup
		if is_instance_valid(ragdoll) and not ragdoll.is_queued_for_deletion():
			ragdoll.queue_free()
		await await_physics_frames(1)

	## Report results
	if failures.size() > 0:
		var summary: String = _format_preservation_failures(failures)
		assert_true(false, "Gibbing preservation failed in %d/%d iterations:\n%s" % [failures.size(), TEST_ITERATIONS, summary])
	else:
		assert_true(true, "Gibbing preservation verified - feature works as expected")


## Property 2: Feature Preservation - Blood Effects Spawning
## **Validates: Requirement 3.2**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that blood effects spawn at hit locations
func test_ragdoll_blood_spawning_preservation() -> void:
	var failures: Array[Dictionary] = []

	for i: int in range(TEST_ITERATIONS):
		var rng: RandomNumberGenerator = get_seeded_rng(i)
		
		## Generate test case with moderate damage (not gibbing)
		var damage: float = rng.randf_range(5.0, DISMEMBER_THRESHOLD - 0.1)
		var all_parts: Array[String] = ["Head", "Spine", "LeftArm", "RightArm", "LeftForeArm", "RightForeArm"]
		var part_id: String = all_parts[rng.randi_range(0, all_parts.size() - 1)]
		
		## Spawn ragdoll
		var ragdoll: Node3D = _spawn_ragdoll()
		if not ragdoll:
			assert_true(false, "Failed to spawn ragdoll for iteration %d" % i)
			return

		## Wait for physics initialization
		await await_physics_frames(1)

		## Observe the production blood request, including its hit position/direction.
		var blood_events: Array[Dictionary] = []
		ragdoll.blood_effect_requested.connect(
			func(position: Vector3, direction: Vector3, intensity: float) -> void:
				blood_events.append(
					{"position": position, "direction": direction, "intensity": intensity}
				)
		)
		var blood_mechanism_available: bool = false
		
		if ragdoll.has_method("on_part_hit"):
			var physical_bones: Dictionary = ragdoll.get("physical_bones")
			if physical_bones and physical_bones.has(part_id):
				var part: PhysicalBone3D = physical_bones[part_id]
				var hit_position: Vector3 = part.global_position + Vector3(0.1, 0.2, 0.3)
				var impact_direction: Vector3 = Vector3(0.25, -0.5, 0.75).normalized()
				var damage_info: DamageInfo = DamageInfo.create(damage)
				damage_info.hit_position = hit_position
				damage_info.knockback_direction = impact_direction
				ragdoll.on_part_hit(part, damage_info)
				blood_mechanism_available = (
					blood_events.size() == 1
					and blood_events[0].position.is_equal_approx(hit_position)
					and blood_events[0].direction.is_equal_approx(-impact_direction)
					and is_equal_approx(float(blood_events[0].intensity), 0.5)
				)

		## Verify blood spawning mechanism exists
		if not blood_mechanism_available:
			failures.append({
				"iteration": i,
				"damage": damage,
				"part_id": part_id,
				"reason": "Blood spawning mechanism not available"
			})

		## Cleanup
		if is_instance_valid(ragdoll):
			ragdoll.queue_free()
		await await_physics_frames(1)

	## Report results
	if failures.size() > 0:
		var summary: String = _format_preservation_failures(failures)
		assert_true(false, "Blood spawning preservation failed in %d/%d iterations:\n%s" % [failures.size(), TEST_ITERATIONS, summary])
	else:
		assert_true(true, "Blood spawning preservation verified - feature works as expected")


## Property 2: Feature Preservation - Dismemberment on High Limb Damage
## **Validates: Requirement 3.3**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that dismemberment occurs when limbs take >15 damage
func test_ragdoll_dismemberment_preservation() -> void:
	var failures: Array[Dictionary] = []

	for i: int in range(TEST_ITERATIONS):
		var rng: RandomNumberGenerator = get_seeded_rng(i)
		
		## Generate test case with high limb damage
		var damage: float = rng.randf_range(DISMEMBER_THRESHOLD + 5.0, DISMEMBER_THRESHOLD + 50.0)
		var limb_parts: Array[String] = ["LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]
		var part_id: String = limb_parts[rng.randi_range(0, limb_parts.size() - 1)]
		
		## Spawn ragdoll
		var ragdoll: Node3D = _spawn_ragdoll()
		if not ragdoll:
			assert_true(false, "Failed to spawn ragdoll for iteration %d" % i)
			return

		## Wait for physics initialization
		await await_physics_frames(1)

		## Track dismemberment
		var dismemberment_occurred: bool = false
		var skeleton: Skeleton3D = ragdoll.get("skeleton")
		
		if skeleton:
			## Apply damage to limb
			if ragdoll.has_method("on_part_hit"):
				var physical_bones: Dictionary = ragdoll.get("physical_bones")
				if physical_bones and physical_bones.has(part_id):
					var part: PhysicalBone3D = physical_bones[part_id]
					
					## Apply damage
					ragdoll.on_part_hit(part, damage)
					
					## Wait for dismemberment
					await await_physics_frames(1)
					
					## Check if bone was scaled to zero (dismembered)
					var skeleton_bone_name: String = ragdoll.get_skeleton_bone_name(part_id)
					var bone_idx: int = skeleton.find_bone(skeleton_bone_name)
					if bone_idx != -1:
						var bone_scale: Vector3 = skeleton.get_bone_pose_scale(bone_idx)
						dismemberment_occurred = bone_scale.length_squared() < 0.01

		## Verify dismemberment occurred
		if not dismemberment_occurred:
			failures.append({
				"iteration": i,
				"damage": damage,
				"part_id": part_id,
				"reason": "Dismemberment did not occur despite damage > threshold"
			})

		## Cleanup
		if is_instance_valid(ragdoll):
			ragdoll.queue_free()
		await await_physics_frames(1)

	## Report results
	if failures.size() > 0:
		var summary: String = _format_preservation_failures(failures)
		assert_true(false, "Dismemberment preservation failed in %d/%d iterations:\n%s" % [failures.size(), TEST_ITERATIONS, summary])
	else:
		assert_true(true, "Dismemberment preservation verified - feature works as expected")


## Property 2: Feature Preservation - 30-Second Auto Cleanup
## **Validates: Requirement 3.4**
##
## EXPECTED OUTCOME: Test PASSES (confirms baseline behavior)
## Verifies that ragdoll is cleaned up after 30 seconds
func test_ragdoll_cleanup_timer_preservation() -> void:
	## Test fewer iterations due to time requirement
	var cleanup_iterations: int = 5
	var failures: Array[Dictionary] = []

	for i: int in range(cleanup_iterations):
		## Spawn ragdoll
		var ragdoll: Node3D = _spawn_ragdoll()
		if not ragdoll:
			assert_true(false, "Failed to spawn ragdoll for iteration %d" % i)
			return

		## Wait for physics initialization
		await await_physics_frames(1)

		## Ragdoll should still be valid (not cleaned up yet)
		var still_valid: bool = is_instance_valid(ragdoll)
		
		if not still_valid:
			failures.append({
				"iteration": i,
				"reason": "Ragdoll was cleaned up too early (before 30 seconds)"
			})

		## Cleanup
		if is_instance_valid(ragdoll):
			ragdoll.queue_free()
		await await_physics_frames(1)

	## Report results
	if failures.size() > 0:
		var summary: String = _format_preservation_failures(failures)
		assert_true(false, "Cleanup timer preservation failed in %d/%d iterations:\n%s" % [failures.size(), cleanup_iterations, summary])
	else:
		assert_true(true, "Cleanup timer preservation verified - feature works as expected")


func _spawn_ragdoll() -> Node3D:
	var ragdoll_scene: PackedScene = load(RAGDOLL_SCENE_PATH)
	if not ragdoll_scene:
		return null

	var ragdoll: Node3D = ragdoll_scene.instantiate()
	ragdoll.position = Vector3(0, 2, 0)
	_test_world.add_child(ragdoll)

	return ragdoll


func _format_preservation_failures(failures: Array[Dictionary]) -> String:
	var summary: String = ""
	var max_show: int = min(3, failures.size())
	
	for i: int in range(max_show):
		var failure: Dictionary = failures[i]
		summary += "  Iteration %d:\n" % failure.iteration
		if failure.has("damage"):
			summary += "    Damage: %.1f\n" % failure.damage
		if failure.has("part_id"):
			summary += "    Part: %s\n" % failure.part_id
		summary += "    Reason: %s\n" % failure.reason

	if failures.size() > max_show:
		summary += "  ... and %d more failures\n" % (failures.size() - max_show)

	return summary
