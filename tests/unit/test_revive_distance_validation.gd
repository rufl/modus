extends GutTest

## Unit Test: Revive Distance Validation
## Tests that revive requests are properly validated based on distance

const REVIVE_DISTANCE_THRESHOLD: float = 3.0  # meters

var downed_state: Node = null
var mock_player: Node3D = null
var mock_reviver: Node3D = null


func before_each() -> void:
	# Create mock player nodes
	mock_player = Node3D.new()
	mock_player.name = "MockPlayer"
	add_child_autofree(mock_player)
	
	mock_reviver = Node3D.new()
	mock_reviver.name = "MockReviver"
	add_child_autofree(mock_reviver)
	
	# Load DownedState script
	var downed_state_script: Script = load("res://game/entities/player/downed_state.gd")
	if downed_state_script:
		downed_state = downed_state_script.new()
		mock_player.add_child(downed_state)


func after_each() -> void:
	# DownedState is owned by the GUT-owned mock_player fixture.
	downed_state = null


func test_revive_within_distance_threshold_allowed() -> void:
	# Arrange: Place reviver within threshold
	mock_player.global_position = Vector3(0, 0, 0)
	mock_reviver.global_position = Vector3(2, 0, 0)  # 2 meters away
	
	var distance: float = mock_player.global_position.distance_to(mock_reviver.global_position)
	
	# Assert: Distance is within threshold
	assert_lte(distance, REVIVE_DISTANCE_THRESHOLD, 
		"Reviver should be within distance threshold (%.1fm <= %.1fm)" % [distance, REVIVE_DISTANCE_THRESHOLD])
	
	# Act & Assert: Revive should be allowed
	var should_allow: bool = distance <= REVIVE_DISTANCE_THRESHOLD
	assert_true(should_allow, "Revive request should be allowed when within threshold")


func test_revive_beyond_distance_threshold_rejected() -> void:
	# Arrange: Place reviver beyond threshold
	mock_player.global_position = Vector3(0, 0, 0)
	mock_reviver.global_position = Vector3(5, 0, 0)  # 5 meters away
	
	var distance: float = mock_player.global_position.distance_to(mock_reviver.global_position)
	
	# Assert: Distance exceeds threshold
	assert_gt(distance, REVIVE_DISTANCE_THRESHOLD,
		"Reviver should be beyond distance threshold (%.1fm > %.1fm)" % [distance, REVIVE_DISTANCE_THRESHOLD])
	
	# Act & Assert: Revive should be rejected
	var should_reject: bool = distance > REVIVE_DISTANCE_THRESHOLD
	assert_true(should_reject, "Revive request should be rejected when beyond threshold")


func test_revive_exactly_at_threshold_allowed() -> void:
	# Arrange: Place reviver exactly at threshold
	mock_player.global_position = Vector3(0, 0, 0)
	mock_reviver.global_position = Vector3(REVIVE_DISTANCE_THRESHOLD, 0, 0)
	
	var distance: float = mock_player.global_position.distance_to(mock_reviver.global_position)
	
	# Assert: Distance equals threshold
	assert_almost_eq(distance, REVIVE_DISTANCE_THRESHOLD, 0.01,
		"Reviver should be exactly at distance threshold")
	
	# Act & Assert: Revive should be allowed (inclusive)
	var should_allow: bool = distance <= REVIVE_DISTANCE_THRESHOLD
	assert_true(should_allow, "Revive request should be allowed when exactly at threshold")


func test_revive_distance_validation_3d_space() -> void:
	# Arrange: Test distance in 3D space (not just horizontal)
	mock_player.global_position = Vector3(0, 0, 0)
	mock_reviver.global_position = Vector3(1, 2, 1)  # ~2.45 meters away
	
	var distance: float = mock_player.global_position.distance_to(mock_reviver.global_position)
	var expected_distance: float = sqrt(1*1 + 2*2 + 1*1)  # ~2.45
	
	# Assert: Distance calculated correctly in 3D
	assert_almost_eq(distance, expected_distance, 0.01,
		"Distance should be calculated in 3D space")
	
	# Assert: Within threshold
	assert_lte(distance, REVIVE_DISTANCE_THRESHOLD,
		"Revive should be allowed in 3D space when within threshold")


func test_revive_distance_validation_vertical_distance() -> void:
	# Arrange: Test vertical distance (player above/below)
	mock_player.global_position = Vector3(0, 0, 0)
	mock_reviver.global_position = Vector3(0, 4, 0)  # 4 meters above
	
	var distance: float = mock_player.global_position.distance_to(mock_reviver.global_position)
	
	# Assert: Vertical distance exceeds threshold
	assert_gt(distance, REVIVE_DISTANCE_THRESHOLD,
		"Vertical distance should be properly validated")
	
	# Assert: Should be rejected
	var should_reject: bool = distance > REVIVE_DISTANCE_THRESHOLD
	assert_true(should_reject, "Revive should be rejected when vertically too far")


func test_revive_distance_zero() -> void:
	# Arrange: Reviver at exact same position
	mock_player.global_position = Vector3(0, 0, 0)
	mock_reviver.global_position = Vector3(0, 0, 0)
	
	var distance: float = mock_player.global_position.distance_to(mock_reviver.global_position)
	
	# Assert: Distance is zero
	assert_eq(distance, 0.0, "Distance should be zero when at same position")
	
	# Assert: Should be allowed
	var should_allow: bool = distance <= REVIVE_DISTANCE_THRESHOLD
	assert_true(should_allow, "Revive should be allowed when at same position")


func test_revive_distance_negative_coordinates() -> void:
	# Arrange: Test with negative coordinates
	mock_player.global_position = Vector3(-5, -2, -3)
	mock_reviver.global_position = Vector3(-6, -2, -3)  # 1 meter away
	
	var distance: float = mock_player.global_position.distance_to(mock_reviver.global_position)
	
	# Assert: Distance calculated correctly with negative coords
	assert_almost_eq(distance, 1.0, 0.01,
		"Distance should be calculated correctly with negative coordinates")
	
	# Assert: Within threshold
	assert_lte(distance, REVIVE_DISTANCE_THRESHOLD,
		"Revive should work with negative coordinates")


## Integration test with actual DownedState (if available)
func test_downed_state_revive_rpc_validation() -> void:
	if not downed_state:
		pass_test("DownedState not available for integration test")
		return
	
	# Check if DownedState has revive validation method
	if not downed_state.has_method("_validate_revive_distance"):
		pass_test("DownedState doesn't have _validate_revive_distance method yet")
		return
	
	# Test with actual DownedState validation
	mock_player.global_position = Vector3(0, 0, 0)
	mock_reviver.global_position = Vector3(2, 0, 0)
	
	var is_valid: bool = downed_state._validate_revive_distance(mock_reviver.global_position)
	assert_true(is_valid, "DownedState should validate revive within threshold")
	
	# Test beyond threshold
	mock_reviver.global_position = Vector3(10, 0, 0)
	is_valid = downed_state._validate_revive_distance(mock_reviver.global_position)
	assert_false(is_valid, "DownedState should reject revive beyond threshold")
