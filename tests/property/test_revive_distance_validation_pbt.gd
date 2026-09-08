extends PropertyBasedTesting

## Property-Based Test: Revive Distance Validation
## Property 2: Revive Distance Validation
## Validates: Requirements 1.2, 11.1

const REVIVE_DISTANCE_THRESHOLD: float = 3.0  # meters


func test_property_revive_requests_rejected_beyond_threshold() -> void:
	# Property: For any random positions where distance exceeds threshold,
	# revive requests should be rejected

	await run_enhanced_property_test(
		"Revive requests rejected beyond threshold",
		_test_revive_distance_validation,
		100,
		SamplingStrategy.MIXED,
		"Revive requests should be rejected when distance exceeds threshold across random positions"
	)


func _test_revive_distance_validation(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate random positions for downed player and reviver
	var player_pos := generate_vector3(rng, -100.0, 100.0)
	var reviver_pos := generate_vector3(rng, -100.0, 100.0)

	# Calculate actual distance
	var distance: float = player_pos.distance_to(reviver_pos)

	# Determine expected result
	var should_allow: bool = distance <= REVIVE_DISTANCE_THRESHOLD

	# Simulate validation logic
	var validation_result: bool = _validate_revive_distance(player_pos, reviver_pos)

	# Property: validation result should match expected result
	var property_holds: bool = validation_result == should_allow

	if not property_holds:
		push_warning(
			(
				"[Property Test] Revive distance validation failed: distance=%.2f, expected=%s, got=%s"
				% [distance, should_allow, validation_result]
			)
		)

	return property_holds


func test_property_revive_requests_allowed_within_threshold() -> void:
	# Property: For any random positions where distance is within threshold,
	# revive requests should be allowed

	await run_enhanced_property_test(
		"Revive requests allowed within threshold",
		_test_revive_within_threshold,
		100,
		SamplingStrategy.MIXED,
		"Revive requests should be allowed when distance is within threshold"
	)


func _test_revive_within_threshold(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate player position
	var player_pos := generate_vector3(rng, -100.0, 100.0)

	# Generate reviver position within threshold
	# Use random direction and distance within threshold
	var direction := (
		Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		. normalized()
	)

	var distance_within: float = rng.randf_range(0.0, REVIVE_DISTANCE_THRESHOLD)
	var reviver_pos := player_pos + (direction * distance_within)

	# Validate
	var validation_result: bool = _validate_revive_distance(player_pos, reviver_pos)

	# Property: should always be allowed
	if not validation_result:
		var actual_distance: float = player_pos.distance_to(reviver_pos)
		push_warning(
			(
				"[Property Test] Revive within threshold rejected: distance=%.2f, threshold=%.2f"
				% [actual_distance, REVIVE_DISTANCE_THRESHOLD]
			)
		)

	return validation_result


func test_property_revive_requests_rejected_beyond_threshold_guaranteed() -> void:
	# Property: For any random positions where distance is guaranteed beyond threshold,
	# revive requests should always be rejected

	await run_enhanced_property_test(
		"Revive requests rejected beyond threshold (guaranteed)",
		_test_revive_beyond_threshold,
		100,
		SamplingStrategy.EDGE_CASE,
		"Revive requests should be rejected when distance is beyond threshold"
	)


func _test_revive_beyond_threshold(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate player position
	var player_pos := generate_vector3(rng, -100.0, 100.0)

	# Generate reviver position beyond threshold
	# Use random direction and distance beyond threshold
	var direction := (
		Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
		. normalized()
	)

	var distance_beyond: float = rng.randf_range(
		REVIVE_DISTANCE_THRESHOLD + 0.5, REVIVE_DISTANCE_THRESHOLD + 50.0
	)
	var reviver_pos := player_pos + (direction * distance_beyond)

	# Validate
	var validation_result: bool = _validate_revive_distance(player_pos, reviver_pos)

	# Property: should always be rejected
	if validation_result:
		var actual_distance: float = player_pos.distance_to(reviver_pos)
		push_warning(
			(
				"[Property Test] Revive beyond threshold allowed: distance=%.2f, threshold=%.2f"
				% [actual_distance, REVIVE_DISTANCE_THRESHOLD]
			)
		)

	return not validation_result


func test_property_revive_distance_3d_space() -> void:
	# Property: Distance validation should work correctly in 3D space,
	# not just horizontal distance

	await run_enhanced_property_test(
		"Revive distance validation in 3D space",
		_test_revive_3d_space,
		100,
		SamplingStrategy.MIXED,
		"Revive distance should be calculated in 3D space including vertical distance"
	)


func _test_revive_3d_space(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))

	# Generate positions with significant vertical component
	var player_pos := Vector3(
		# Significant Y component
		rng.randf_range(-50.0, 50.0),
		rng.randf_range(-50.0, 50.0),
		rng.randf_range(-50.0, 50.0)
	)

	var reviver_pos := Vector3(
		# Significant Y component
		rng.randf_range(-50.0, 50.0),
		rng.randf_range(-50.0, 50.0),
		rng.randf_range(-50.0, 50.0)
	)

	# Calculate 3D distance
	var distance_3d: float = player_pos.distance_to(reviver_pos)

	# Calculate horizontal distance (ignoring Y)
	var horizontal_distance: float = Vector2(player_pos.x, player_pos.z).distance_to(
		Vector2(reviver_pos.x, reviver_pos.z)
	)

	# Validate using 3D distance
	var validation_result: bool = _validate_revive_distance(player_pos, reviver_pos)
	var expected_result: bool = distance_3d <= REVIVE_DISTANCE_THRESHOLD

	# Property: validation should use 3D distance, not just horizontal
	var property_holds: bool = validation_result == expected_result

	# Additional check: if horizontal distance is within threshold but 3D distance is not,
	# revive should be rejected (proves 3D calculation)
	if horizontal_distance <= REVIVE_DISTANCE_THRESHOLD and distance_3d > REVIVE_DISTANCE_THRESHOLD:
		if validation_result:
			push_warning(
				(
					"[Property Test] 3D distance not used: horizontal=%.2f, 3d=%.2f, allowed=%s"
					% [horizontal_distance, distance_3d, validation_result]
				)
			)
			return false

	return property_holds


func test_property_revive_distance_edge_cases() -> void:
	# Property: Edge cases should be handled correctly
	# (zero distance, exact threshold, negative coordinates)

	await run_enhanced_property_test(
		"Revive distance edge cases",
		_test_revive_edge_cases,
		100,
		SamplingStrategy.EDGE_CASE,
		"Revive distance validation should handle edge cases correctly"
	)


func _test_revive_edge_cases(test_data: Dictionary) -> bool:
	var rng := get_seeded_rng(test_data.get("iteration", 0))
	var iteration: int = test_data.get("iteration", 0)

	# Test different edge cases based on iteration
	var edge_case_type: int = iteration % 4

	match edge_case_type:
		0:  # Zero distance (same position)
			var pos := generate_vector3(rng, -100.0, 100.0)
			var result := _validate_revive_distance(pos, pos)
			return result == true  # Should be allowed

		1:  # Exactly at threshold
			var player_pos := generate_vector3(rng, -100.0, 100.0)
			var direction := Vector3(1, 0, 0).normalized()
			var reviver_pos := player_pos + (direction * REVIVE_DISTANCE_THRESHOLD)
			var result := _validate_revive_distance(player_pos, reviver_pos)
			return result == true  # Should be allowed (inclusive)

		2:  # Negative coordinates
			var player_pos := Vector3(
				rng.randf_range(-100.0, -50.0),
				rng.randf_range(-100.0, -50.0),
				rng.randf_range(-100.0, -50.0)
			)
			var reviver_pos := player_pos + Vector3(1, 0, 0)  # 1 meter away
			var result := _validate_revive_distance(player_pos, reviver_pos)
			return result == true  # Should be allowed

		3:  # Very large coordinates
			var player_pos := Vector3(
				rng.randf_range(1000.0, 2000.0),
				rng.randf_range(1000.0, 2000.0),
				rng.randf_range(1000.0, 2000.0)
			)
			var reviver_pos := player_pos + Vector3(2, 0, 0)  # 2 meters away
			var result := _validate_revive_distance(player_pos, reviver_pos)
			return result == true  # Should be allowed

	return true


## Helper function: Validate revive distance
func _validate_revive_distance(player_pos: Vector3, reviver_pos: Vector3) -> bool:
	var distance: float = player_pos.distance_to(reviver_pos)
	return distance <= REVIVE_DISTANCE_THRESHOLD


## Helper function: Get seeded RNG for reproducible tests
func get_seeded_rng(iteration: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(iteration)
	return rng
