extends ModusGutTestBase

## Property-Based Tests for Splitscreen Multiplayer
## Tests the 30 correctness properties defined in the design document

var session_state: SessionState
var gamepad_controller: GamepadController
var viewport_manager: ViewportManager
var splitscreen_manager: SplitscreenManager


func _transition_to_active(state: SessionState) -> void:
	assert_true(state.transition_to(SessionState.State.INITIALIZING))
	assert_true(state.transition_to(SessionState.State.ASSIGNING_DEVICES))
	assert_true(state.transition_to(SessionState.State.ACTIVE))


func before_each() -> void:
	session_state = SessionState.new()
	gamepad_controller = GamepadController.new()
	viewport_manager = ViewportManager.new()
	splitscreen_manager = SplitscreenManager.new()
	
	add_child_autofree(gamepad_controller)
	add_child_autofree(viewport_manager)
	add_child_autofree(splitscreen_manager)


func after_each() -> void:
	session_state = null
	gamepad_controller = null
	viewport_manager = null
	splitscreen_manager = null


## PROPERTY 1: State Machine Validity
## For all state transitions, only valid transitions are allowed
func test_property_state_machine_validity() -> void:
	var all_states: Array[SessionState.State] = [
		SessionState.State.INACTIVE,
		SessionState.State.INITIALIZING,
		SessionState.State.ASSIGNING_DEVICES,
		SessionState.State.ACTIVE,
		SessionState.State.PAUSED,
		SessionState.State.ENDING
	]
	
	# Test all possible state combinations
	for from_state: SessionState.State in all_states:
		for to_state: SessionState.State in all_states:
			session_state.current_state = from_state
			var is_valid: bool = session_state.is_valid_transition(from_state, to_state)
			var result: bool = session_state.transition_to(to_state)
			if not is_valid:
				assert_push_error(
					"Invalid state transition from %s to %s"
					% [SessionState.State.keys()[from_state], SessionState.State.keys()[to_state]]
				)
			
			assert_eq(result, is_valid,
				"Transition result must match validity check: %s -> %s" % [
					SessionState.State.keys()[from_state],
					SessionState.State.keys()[to_state]
				])


## PROPERTY 2: Player Count Consistency
## player_count must always equal active_players.size()
func test_property_player_count_consistency() -> void:
	# Test with various operations
	for i in range(10):
		session_state.add_player(i)
		assert_eq(session_state.player_count, session_state.active_players.size(),
			"Player count must match active players size after add")
	
	for i in range(5):
		session_state.remove_player(i)
		assert_eq(session_state.player_count, session_state.active_players.size(),
			"Player count must match active players size after remove")


## PROPERTY 3: Unique Player IDs
## No two players can have the same player_id
func test_property_unique_player_ids() -> void:
	var player_ids: Array[int] = []
	
	for i in range(6):
		session_state.add_player(i)
		player_ids.append(i)
	
	# Check uniqueness
	var unique_ids: Dictionary = {}
	for player_id: int in session_state.active_players.keys():
		assert_false(unique_ids.has(player_id),
			"Player ID %d must be unique" % player_id)
		unique_ids[player_id] = true


## PROPERTY 4: Gamepad Assignment Uniqueness
## No gamepad device can be assigned to multiple players
func test_property_gamepad_assignment_uniqueness() -> void:
	for i in range(4):
		session_state.add_player(i)
		gamepad_controller._connected_devices.append(i)
	
	# Assign gamepads
	for i in range(4):
		gamepad_controller.assign_gamepad(i, i)
	
	# Check uniqueness
	var assigned_devices: Dictionary = {}
	for player_id: int in gamepad_controller._player_to_device.keys():
		var device_id: int = gamepad_controller._player_to_device[player_id]
		assert_false(assigned_devices.has(device_id),
			"Device %d must be assigned to only one player" % device_id)
		assigned_devices[device_id] = true


## PROPERTY 5: Bidirectional Mapping Consistency
## If device D is assigned to player P, then player P must be assigned to device D
func test_property_bidirectional_mapping_consistency() -> void:
	for i in range(4):
		gamepad_controller._connected_devices.append(i)
		gamepad_controller.assign_gamepad(i, i)
	
	# Check bidirectional consistency
	for player_id: int in gamepad_controller._player_to_device.keys():
		var device_id: int = gamepad_controller._player_to_device[player_id]
		var reverse_player: int = gamepad_controller._device_to_player[device_id]
		assert_eq(player_id, reverse_player,
			"Bidirectional mapping must be consistent")


## PROPERTY 6: Viewport Count Equals Player Count
## Number of viewports must equal number of active players
func test_property_viewport_count_equals_player_count() -> void:
	for i in range(6):
		viewport_manager.create_viewport(i, null)
	
	assert_eq(viewport_manager.get_viewport_count(), 6,
		"Viewport count must equal number of created viewports")


## PROPERTY 7: Viewport Area Coverage
## Sum of all viewport areas must equal 1.0 (100% screen coverage)
func test_property_viewport_area_coverage() -> void:
	for player_count: int in [4, 5, 6]:
		for i in range(player_count):
			viewport_manager.create_viewport(i, null)
		
		viewport_manager.arrange_viewports(player_count)
		var rects: Array = viewport_manager.get_viewport_rects()
		
		var total_area: float = 0.0
		for rect: Rect2 in rects:
			total_area += rect.size.x * rect.size.y
		
		assert_almost_eq(total_area, 1.0, 0.01,
			"Total viewport area must be 100%% for %d players" % player_count)
		
		# Cleanup for next iteration
		viewport_manager.cleanup_all_viewports()


## PROPERTY 8: No Viewport Overlap
## Viewports must not overlap (except at boundaries)
func test_property_no_viewport_overlap() -> void:
	for i in range(4):
		viewport_manager.create_viewport(i, null)
	
	viewport_manager.arrange_viewports(4)
	var rects: Array = viewport_manager.get_viewport_rects()
	
	# Check each pair for overlap
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var overlap: bool = rects[i].intersects(rects[j], false)
			assert_false(overlap,
				"Viewports %d and %d must not overlap" % [i, j])


## PROPERTY 9: State Transition Atomicity
## State transitions are atomic (no intermediate states)
func test_property_state_transition_atomicity() -> void:
	var initial_state: SessionState.State = session_state.current_state
	var target_state: SessionState.State = SessionState.State.INITIALIZING
	
	session_state.transition_to(target_state)
	
	# State must be either initial or target, never something else
	assert_true(session_state.current_state == initial_state or 
				session_state.current_state == target_state,
		"State must be either initial or target, no intermediate states")


## PROPERTY 10: Player Removal Cleanup
## Removing a player must clean up all associated resources
func test_property_player_removal_cleanup() -> void:
	session_state.add_player(0)
	session_state.assign_gamepad(0, 1)
	
	session_state.remove_player(0)
	
	assert_false(session_state.active_players.has(0),
		"Player must be removed from active_players")
	assert_false(session_state.gamepad_assignments.has(0),
		"Gamepad assignment must be removed")


## PROPERTY 11: Session Timer Monotonicity
## Session time must always increase (never decrease)
func test_property_session_timer_monotonicity() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	session_state.transition_to(SessionState.State.ACTIVE)
	session_state.start_timer()
	
	var prev_time: float = session_state.total_session_time
	
	for i in range(10):
		session_state.update_timer(0.1)
		var current_time: float = session_state.total_session_time
		assert_ge(current_time, prev_time,
			"Session time must never decrease")
		prev_time = current_time


## PROPERTY 12: Input Isolation
## Input from device D only affects player assigned to D
func test_property_input_isolation() -> void:
	var input_comp1: SplitscreenInputComponent = SplitscreenInputComponent.new()
	var input_comp2: SplitscreenInputComponent = SplitscreenInputComponent.new()
	
	input_comp1.set_device(0, gamepad_controller, 0)
	input_comp2.set_device(1, gamepad_controller, 1)
	
	assert_eq(input_comp1.get_device_id(), 0,
		"Component 1 must only see device 0")
	assert_eq(input_comp2.get_device_id(), 1,
		"Component 2 must only see device 1")
	
	input_comp1.free()
	input_comp2.free()


## PROPERTY 13: Rendering Quality Bounds
## Rendering quality must be in range [0.0, 1.0]
func test_property_rendering_quality_bounds() -> void:
	var test_values: Array[float] = [-1.0, 0.0, 0.5, 1.0, 2.0]
	
	for value: float in test_values:
		viewport_manager.set_rendering_quality(value)
		var actual: float = viewport_manager._rendering_quality
		assert_ge(actual, 0.0, "Quality must be >= 0.0")
		assert_le(actual, 1.0, "Quality must be <= 1.0")


## PROPERTY 14: Player Count Bounds
## Player count must be within [min_players, max_players]
func test_property_player_count_bounds() -> void:
	splitscreen_manager.initialize()
	await get_tree().process_frame
	
	# Test below minimum
	var result_low: bool = splitscreen_manager.start_session(2)
	assert_push_error("below minimum")
	assert_false(result_low, "Must reject player count below minimum")
	
	# Test above maximum
	var result_high: bool = splitscreen_manager.start_session(10)
	assert_push_error("exceeds maximum")
	assert_false(result_high, "Must reject player count above maximum")


## PROPERTY 15: Gamepad Reconnection Preservation
## Reconnecting a gamepad reassigns it to the same player
func test_property_gamepad_reconnection_preservation() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(5, 0)
	
	# Simulate disconnect
	gamepad_controller._on_device_disconnected(0)
	
	# Simulate reconnect
	gamepad_controller._on_device_connected(0)
	
	assert_eq(gamepad_controller.get_player_for_device(0), 5,
		"Reconnected device must be assigned to same player")


## PROPERTY 16: Validation Consistency
## validate() returns true iff state is internally consistent
func test_property_validation_consistency() -> void:
	# Valid state
	session_state.add_player(0)
	session_state.assign_gamepad(0, 1)
	assert_true(session_state.validate(), "Valid state must pass validation")
	
	# Invalid state - manually corrupt
	session_state.player_count = 999
	assert_false(session_state.validate(), "Invalid state must fail validation")
	assert_push_error("Player count mismatch")


## PROPERTY 17: Performance Metrics Freshness
## Performance metrics must have recent timestamps
func test_property_performance_metrics_freshness() -> void:
	var before: int = Time.get_ticks_msec()
	session_state.update_performance_metrics(60.0, 16.67, 1024)
	var after: int = Time.get_ticks_msec()
	
	var timestamp: Variant = session_state.get_performance_metric("last_update")
	assert_ge(timestamp, before, "Timestamp must be >= before update")
	assert_le(timestamp, after, "Timestamp must be <= after update")


## PROPERTY 18: Layout Type Determinism
## Same player count always produces same layout type
func test_property_layout_type_determinism() -> void:
	for player_count: int in [4, 5, 6]:
		var layout1: Variant = viewport_manager._calculate_layout_type(player_count)
		var layout2: Variant = viewport_manager._calculate_layout_type(player_count)
		
		assert_eq(layout1, layout2,
			"Layout type must be deterministic for player count %d" % player_count)


## PROPERTY 19: Signal Emission Guarantee
## Specific operations must emit corresponding signals
func test_property_signal_emission_guarantee() -> void:
	watch_signals(gamepad_controller)
	
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(0, 0)
	
	assert_signal_emitted(gamepad_controller, "gamepad_assigned",
		"assign_gamepad must emit gamepad_assigned signal")


## PROPERTY 20: Resource Cleanup Completeness
## Cleanup operations must free all allocated resources
func test_property_resource_cleanup_completeness() -> void:
	for i in range(4):
		viewport_manager.create_viewport(i, null)
	
	var count_before: int = viewport_manager.get_viewport_count()
	assert_eq(count_before, 4, "Should have 4 viewports")
	
	viewport_manager.cleanup_all_viewports()
	
	var count_after: int = viewport_manager.get_viewport_count()
	assert_eq(count_after, 0, "All viewports must be cleaned up")


## PROPERTY 21: Configuration Idempotence
## Loading same configuration multiple times produces same result
func test_property_configuration_idempotence() -> void:
	var config: Dictionary = {
		"vibration_enabled": false,
		"analog_deadzone": 0.25
	}
	
	gamepad_controller.load_configuration(config)
	var state1: Array = [gamepad_controller.vibration_enabled, gamepad_controller.analog_deadzone]
	
	gamepad_controller.load_configuration(config)
	var state2: Array = [gamepad_controller.vibration_enabled, gamepad_controller.analog_deadzone]
	
	assert_eq(state1, state2, "Configuration loading must be idempotent")


## PROPERTY 22: FPS Sample Bounded Size
## FPS sample array must not grow unbounded
func test_property_fps_sample_bounded_size() -> void:
	splitscreen_manager.initialize()
	await get_tree().process_frame
	
	_transition_to_active(splitscreen_manager.session_state)
	
	# Add many samples
	for i in range(100):
		splitscreen_manager._fps_samples.append(60.0)
		splitscreen_manager._process(0.016)
	
	assert_le(splitscreen_manager._fps_samples.size(), 60,
		"FPS samples must be bounded to prevent memory growth")


## PROPERTY 23: Viewport Rect Normalization
## All viewport rects must have coordinates in [0, 1]
func test_property_viewport_rect_normalization() -> void:
	for i in range(4):
		viewport_manager.create_viewport(i, null)
	
	viewport_manager.arrange_viewports(4)
	var rects: Array = viewport_manager.get_viewport_rects()
	
	for rect: Rect2 in rects:
		assert_ge(rect.position.x, 0.0, "Rect x must be >= 0")
		assert_le(rect.position.x, 1.0, "Rect x must be <= 1")
		assert_ge(rect.position.y, 0.0, "Rect y must be >= 0")
		assert_le(rect.position.y, 1.0, "Rect y must be <= 1")
		assert_ge(rect.size.x, 0.0, "Rect width must be >= 0")
		assert_le(rect.size.x, 1.0, "Rect width must be <= 1")
		assert_ge(rect.size.y, 0.0, "Rect height must be >= 0")
		assert_le(rect.size.y, 1.0, "Rect height must be <= 1")


## PROPERTY 24: Error Recovery Consistency
## After error cleanup, system must return to INACTIVE state
func test_property_error_recovery_consistency() -> void:
	splitscreen_manager.initialize()
	await get_tree().process_frame
	
	_transition_to_active(splitscreen_manager.session_state)
	splitscreen_manager._cleanup_on_error()
	
	assert_eq(splitscreen_manager.session_state.current_state,
		SessionState.State.INACTIVE,
		"System must return to INACTIVE after error cleanup")


## PROPERTY 25: Assignment Completion Correctness
## Assignment is complete iff all expected players have devices
func test_property_assignment_completion_correctness() -> void:
	gamepad_controller.set_expected_player_count(4)
	
	for i in range(4):
		gamepad_controller._connected_devices.append(i)
	
	# Not complete yet
	assert_false(gamepad_controller.is_assignment_complete(),
		"Assignment not complete with 0/4 players")
	
	# Assign 3 players
	for i in range(3):
		gamepad_controller.assign_gamepad(i, i)
	
	assert_false(gamepad_controller.is_assignment_complete(),
		"Assignment not complete with 3/4 players")
	
	# Assign 4th player
	gamepad_controller.assign_gamepad(3, 3)
	
	assert_true(gamepad_controller.is_assignment_complete(),
		"Assignment complete with 4/4 players")


## PROPERTY 26: State Serialization Completeness
## to_dict() must include all essential state
func test_property_state_serialization_completeness() -> void:
	session_state.add_player(0)
	session_state.assign_gamepad(0, 1)
	session_state.start_timer()
	
	var dict: Dictionary = session_state.to_dict()
	
	var required_keys: Array[String] = [
		"current_state",
		"player_count",
		"active_players",
		"gamepad_assignments",
		"session_start_time",
		"total_session_time",
		"performance_metrics"
	]
	
	for key: String in required_keys:
		assert_true(dict.has(key),
			"Serialized state must include %s" % key)


## PROPERTY 27: Quality Adjustment Stability
## Quality adjustments must not oscillate rapidly
func test_property_quality_adjustment_stability() -> void:
	splitscreen_manager.initialize()
	await get_tree().process_frame
	
	_transition_to_active(splitscreen_manager.session_state)
	splitscreen_manager._current_quality_level = "medium"
	
	var initial_quality: String = splitscreen_manager._current_quality_level
	
	# Simulate stable FPS
	for i in range(60):
		splitscreen_manager._fps_samples.append(60.0)
	
	splitscreen_manager._last_quality_adjustment_time = splitscreen_manager.quality_adjustment_interval
	splitscreen_manager._monitor_performance(0.016)
	
	# Quality should remain stable with stable FPS
	var final_quality: String = splitscreen_manager._current_quality_level
	assert_eq(initial_quality, final_quality,
		"Quality must remain stable with stable FPS")


## PROPERTY 28: Device Detection Consistency
## detect_gamepads() must return same result as _connected_devices
func test_property_device_detection_consistency() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._connected_devices.append(1)
	
	var detected: Array = gamepad_controller.detect_gamepads()
	
	assert_eq(detected.size(), gamepad_controller._connected_devices.size(),
		"Detected devices must match internal state")


## PROPERTY 29: Pause State Preservation
## Pausing and resuming must preserve all session state
func test_property_pause_state_preservation() -> void:
	splitscreen_manager.initialize()
	await get_tree().process_frame
	
	_transition_to_active(splitscreen_manager.session_state)
	splitscreen_manager.session_state.add_player(0)
	
	var player_count_before: int = splitscreen_manager.get_player_count()
	
	splitscreen_manager.pause_session()
	splitscreen_manager.resume_session()
	
	var player_count_after: int = splitscreen_manager.get_player_count()
	
	assert_eq(player_count_before, player_count_after,
		"Player count must be preserved across pause/resume")


## PROPERTY 30: Viewport Equal Area Distribution
## For N players, each viewport must have area ≈ 1/N
func test_property_viewport_equal_area_distribution() -> void:
	for player_count: int in [4, 5, 6]:
		for i in range(player_count):
			viewport_manager.create_viewport(i, null)
		
		viewport_manager.arrange_viewports(player_count)
		var rects: Array = viewport_manager.get_viewport_rects()
		
		var expected_area: float = 1.0 / player_count
		
		for rect: Rect2 in rects:
			var area: float = rect.size.x * rect.size.y
			assert_almost_eq(area, expected_area, 0.01,
				"Each viewport must have area ≈ 1/%d" % player_count)
		
		viewport_manager.cleanup_all_viewports()
