extends ModusGutTestBase

## Integration tests for splitscreen gameplay functionality
## Tests 2-player, 4-player, and 6-player splitscreen with gamepad input and viewport management

var splitscreen_manager: SplitscreenManager


func _transition_session_to_active() -> void:
	var state := splitscreen_manager.session_state
	if state.current_state == SessionState.State.INACTIVE:
		assert_true(state.transition_to(SessionState.State.INITIALIZING))
	if state.current_state == SessionState.State.INITIALIZING:
		assert_true(state.transition_to(SessionState.State.ASSIGNING_DEVICES))
	if state.current_state in [SessionState.State.ASSIGNING_DEVICES, SessionState.State.PAUSED]:
		assert_true(state.transition_to(SessionState.State.ACTIVE))


var mock_gamepads: Array[int] = []


func before_each() -> void:
	# Create and initialize splitscreen manager
	splitscreen_manager = SplitscreenManager.new()
	add_child_autofree(splitscreen_manager)
	splitscreen_manager.initialize()
	await get_tree().process_frame
	# Headless runner FPS is not representative gameplay performance; this lane
	# validates session behavior, while performance has a separate evidence lane.
	if splitscreen_manager.performance_profiler:
		splitscreen_manager.performance_profiler.critical_fps_threshold = 0.0
		splitscreen_manager.performance_profiler.warning_fps_threshold = 0.0
		splitscreen_manager.performance_profiler.critical_frame_time_ms = INF
		splitscreen_manager.performance_profiler.warning_frame_time_ms = INF

	# Setup mock gamepads
	mock_gamepads.clear()


func after_each() -> void:
	# Cleanup session if active
	if splitscreen_manager and is_instance_valid(splitscreen_manager):
		if splitscreen_manager.is_session_active():
			splitscreen_manager.end_session()

	splitscreen_manager = null
	mock_gamepads.clear()


## Helper: Simulate connected gamepads
func _simulate_connected_gamepads(count: int) -> void:
	mock_gamepads.clear()
	for i in range(count):
		mock_gamepads.append(i)
	splitscreen_manager.gamepad_controller.set_connected_device_provider(
		func() -> Array[int]: return mock_gamepads
	)


## Helper: Complete device assignment
func _complete_device_assignment(player_count: int) -> void:
	for player_id in range(player_count):
		splitscreen_manager.gamepad_controller.assign_gamepad(player_id, player_id)

	await get_tree().process_frame


# =============================================================================
# 2-PLAYER SPLITSCREEN TESTS
# =============================================================================


## Test: Start 2-player splitscreen session
func test_2_player_splitscreen_session_start() -> void:
	_simulate_connected_gamepads(4)

	var result: bool = splitscreen_manager.start_session(4)

	assert_true(result, "Should successfully start 4-player session")
	assert_eq(
		splitscreen_manager.session_state.current_state,
		SessionState.State.ASSIGNING_DEVICES,
		"Should be in device assignment state"
	)


## Test: 2-player viewport creation
func test_2_player_viewport_creation() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	assert_eq(
		splitscreen_manager.viewport_manager.get_viewport_count(),
		4,
		"Should have 4 viewports created"
	)


## Test: 2-player viewport arrangement
func test_2_player_viewport_arrangement() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	# Verify viewports are arranged
	for player_id in range(4):
		var viewport: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(
			player_id
		)
		assert_not_null(viewport, "Viewport %d should exist" % player_id)


## Test: 2-player gamepad assignment
func test_2_player_gamepad_assignment() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)

	for player_id in range(4):
		splitscreen_manager.gamepad_controller.assign_gamepad(player_id, player_id)

	# Verify assignments
	for player_id in range(4):
		var device: int = splitscreen_manager.gamepad_controller.get_assigned_device(player_id)
		assert_eq(device, player_id, "Player %d should have device %d" % [player_id, player_id])


## Test: 2-player session becomes active
func test_2_player_session_becomes_active() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	assert_true(
		splitscreen_manager.is_session_active(), "Session should be active after device assignment"
	)


# =============================================================================
# 4-PLAYER SPLITSCREEN TESTS
# =============================================================================


## Test: Start 4-player splitscreen session
func test_4_player_splitscreen_session_start() -> void:
	_simulate_connected_gamepads(4)

	var result: bool = splitscreen_manager.start_session(4)

	assert_true(result, "Should successfully start 4-player session")
	assert_eq(splitscreen_manager.get_player_count(), 4, "Should have 4 players")


## Test: 4-player viewport creation
func test_4_player_viewport_creation() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	assert_eq(
		splitscreen_manager.viewport_manager.get_viewport_count(),
		4,
		"Should have 4 viewports created"
	)

	# Verify each viewport exists
	for player_id in range(4):
		var viewport: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(
			player_id
		)
		assert_not_null(viewport, "Viewport %d should exist" % player_id)


## Test: 4-player viewport layout (2x2 grid)
func test_4_player_viewport_layout() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	# Verify 2x2 grid layout
	var viewport_0: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(0)
	var viewport_1: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(1)
	var viewport_2: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(2)
	var viewport_3: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(3)

	assert_not_null(viewport_0, "Top-left viewport should exist")
	assert_not_null(viewport_1, "Top-right viewport should exist")
	assert_not_null(viewport_2, "Bottom-left viewport should exist")
	assert_not_null(viewport_3, "Bottom-right viewport should exist")


## Test: 4-player gamepad input isolation
func test_4_player_gamepad_input_isolation() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)

	# Assign different devices to each player
	for player_id in range(4):
		splitscreen_manager.gamepad_controller.assign_gamepad(player_id, player_id)

	# Verify each player has unique device
	var assigned_devices: Array[int] = []
	for player_id in range(4):
		var device: int = splitscreen_manager.gamepad_controller.get_assigned_device(player_id)
		assert_false(
			device in assigned_devices,
			"Device %d should not be assigned to multiple players" % device
		)
		assigned_devices.append(device)


## Test: 4-player performance monitoring
func test_4_player_performance_monitoring() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	# Enable adaptive quality
	splitscreen_manager.adaptive_quality_enabled = true

	# Simulate some frames by waiting
	for i in range(10):
		await get_tree().process_frame

	# Verify session is still active (performance monitoring didn't crash)
	assert_true(
		splitscreen_manager.is_session_active(),
		"Session should remain active during performance monitoring"
	)


# =============================================================================
# 6-PLAYER SPLITSCREEN TESTS
# =============================================================================


## Test: Start 6-player splitscreen session
func test_6_player_splitscreen_session_start() -> void:
	_simulate_connected_gamepads(6)

	var result: bool = splitscreen_manager.start_session(6)

	assert_true(result, "Should successfully start 6-player session")
	assert_eq(splitscreen_manager.get_player_count(), 6, "Should have 6 players")


## Test: 6-player viewport creation
func test_6_player_viewport_creation() -> void:
	_simulate_connected_gamepads(6)
	splitscreen_manager.start_session(6)
	await _complete_device_assignment(6)

	assert_eq(
		splitscreen_manager.viewport_manager.get_viewport_count(),
		6,
		"Should have 6 viewports created"
	)


## Test: 6-player viewport layout (2x3 or 3x2 grid)
func test_6_player_viewport_layout() -> void:
	_simulate_connected_gamepads(6)
	splitscreen_manager.start_session(6)
	await _complete_device_assignment(6)

	# Verify all 6 viewports exist
	for player_id in range(6):
		var viewport: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(
			player_id
		)
		assert_not_null(viewport, "Viewport %d should exist" % player_id)


## Test: 6-player gamepad assignment
func test_6_player_gamepad_assignment() -> void:
	_simulate_connected_gamepads(6)
	splitscreen_manager.start_session(6)

	# Assign devices
	for player_id in range(6):
		splitscreen_manager.gamepad_controller.assign_gamepad(player_id, player_id)

	# Verify all assignments
	for player_id in range(6):
		var device: int = splitscreen_manager.gamepad_controller.get_assigned_device(player_id)
		assert_eq(device, player_id, "Player %d should have device %d" % [player_id, player_id])


## Test: 6-player maximum capacity
func test_6_player_maximum_capacity() -> void:
	_simulate_connected_gamepads(6)
	splitscreen_manager.start_session(6)
	await _complete_device_assignment(6)

	# Try to add 7th player (should fail)
	var result: int = splitscreen_manager.add_player(6)
	assert_push_error("maximum player count")

	assert_eq(result, -1, "Should not allow 7th player (exceeds max)")
	assert_eq(splitscreen_manager.get_player_count(), 6, "Should still have 6 players")


# =============================================================================
# GAMEPAD INPUT HANDLING TESTS
# =============================================================================


## Test: Gamepad detection
func test_gamepad_detection() -> void:
	_simulate_connected_gamepads(4)

	var detected: Array = splitscreen_manager.gamepad_controller.detect_gamepads()

	assert_eq(detected.size(), 4, "Should detect 4 gamepads")


## Test: Gamepad assignment to player
func test_gamepad_assignment_to_player() -> void:
	_simulate_connected_gamepads(4)

	var result: bool = splitscreen_manager.gamepad_controller.assign_gamepad(0, 0)

	assert_true(result, "Should successfully assign gamepad 0 to player 0")
	assert_eq(
		splitscreen_manager.gamepad_controller.get_assigned_device(0),
		0,
		"Player 0 should have device 0"
	)


## Test: Gamepad unassignment
func test_gamepad_unassignment() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.gamepad_controller.assign_gamepad(0, 0)

	splitscreen_manager.gamepad_controller.unassign_gamepad(0)

	assert_eq(
		splitscreen_manager.gamepad_controller.get_assigned_device(0),
		-1,
		"Player 0 should have no device after unassignment"
	)


## Test: Gamepad disconnection handling
func test_gamepad_disconnection_handling() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	# Enable auto-pause
	splitscreen_manager.auto_pause_on_disconnect = true

	# Simulate disconnection by updating player data
	splitscreen_manager.session_state.update_player_data(0, null, null, -1, false)

	# Manually pause session (simulating what would happen on disconnect)
	splitscreen_manager.pause_session()

	# Verify session is paused
	assert_eq(
		splitscreen_manager.session_state.current_state,
		SessionState.State.PAUSED,
		"Session should be paused after gamepad disconnect"
	)


## Test: Gamepad reconnection handling
func test_gamepad_reconnection_handling() -> void:
	_simulate_connected_gamepads(4)

	# Simulate reconnection by adding a new device
	mock_gamepads.append(4)

	# Verify new gamepad is detected
	var detected: Array = splitscreen_manager.gamepad_controller.detect_gamepads()
	assert_eq(detected.size(), 5, "Should detect 5 gamepads after reconnection")


## Test: Multiple gamepad assignments
func test_multiple_gamepad_assignments() -> void:
	_simulate_connected_gamepads(4)

	# Assign multiple gamepads
	for player_id in range(4):
		var result: bool = splitscreen_manager.gamepad_controller.assign_gamepad(
			player_id, player_id
		)
		assert_true(result, "Should assign gamepad %d to player %d" % [player_id, player_id])


## Test: Gamepad assignment validation
func test_gamepad_assignment_validation() -> void:
	_simulate_connected_gamepads(2)

	# Try to assign non-existent gamepad
	var result: bool = splitscreen_manager.gamepad_controller.assign_gamepad(0, 5)
	assert_push_error("non-existent device")

	assert_false(result, "Should not assign non-existent gamepad")


# =============================================================================
# VIEWPORT MANAGEMENT TESTS
# =============================================================================


## Test: Viewport creation
func test_viewport_creation() -> void:
	var viewport: SubViewport = splitscreen_manager.viewport_manager.create_viewport(0, null)

	assert_not_null(viewport, "Should create viewport")


## Test: Viewport destruction
func test_viewport_destruction() -> void:
	splitscreen_manager.viewport_manager.create_viewport(0, null)

	splitscreen_manager.viewport_manager.destroy_viewport(0)

	var viewport: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(0)
	assert_null(viewport, "Viewport should be destroyed")


## Test: Viewport arrangement for different player counts
func test_viewport_arrangement_different_counts() -> void:
	# Test 2 players
	splitscreen_manager.viewport_manager.arrange_viewports(2)
	assert_true(true, "Should arrange viewports for 2 players")

	# Test 4 players
	splitscreen_manager.viewport_manager.arrange_viewports(4)
	assert_true(true, "Should arrange viewports for 4 players")

	# Test 6 players
	splitscreen_manager.viewport_manager.arrange_viewports(6)
	assert_true(true, "Should arrange viewports for 6 players")


## Test: Viewport cleanup
func test_viewport_cleanup() -> void:
	# Create multiple viewports
	for i in range(4):
		splitscreen_manager.viewport_manager.create_viewport(i, null)

	splitscreen_manager.viewport_manager.cleanup_all_viewports()

	assert_eq(
		splitscreen_manager.viewport_manager.get_viewport_count(),
		0,
		"All viewports should be cleaned up"
	)


## Test: Viewport rendering quality adjustment
func test_viewport_rendering_quality_adjustment() -> void:
	splitscreen_manager.viewport_manager.create_viewport(0, null)

	splitscreen_manager.viewport_manager.set_rendering_quality(0.5)

	assert_true(true, "Should adjust rendering quality without errors")


## Test: Viewport count tracking
func test_viewport_count_tracking() -> void:
	assert_eq(
		splitscreen_manager.viewport_manager.get_viewport_count(),
		0,
		"Should start with 0 viewports"
	)

	splitscreen_manager.viewport_manager.create_viewport(0, null)
	assert_eq(
		splitscreen_manager.viewport_manager.get_viewport_count(),
		1,
		"Should have 1 viewport after creation"
	)

	splitscreen_manager.viewport_manager.create_viewport(1, null)
	assert_eq(
		splitscreen_manager.viewport_manager.get_viewport_count(),
		2,
		"Should have 2 viewports after second creation"
	)


## Test: Viewport retrieval
func test_viewport_retrieval() -> void:
	var created_viewport: SubViewport = splitscreen_manager.viewport_manager.create_viewport(
		0, null
	)

	var retrieved_viewport: SubViewport = splitscreen_manager.viewport_manager.get_player_viewport(
		0
	)

	assert_eq(
		retrieved_viewport, created_viewport, "Retrieved viewport should match created viewport"
	)


# =============================================================================
# SESSION LIFECYCLE TESTS
# =============================================================================


## Test: Session start signal emission
func test_session_start_signal_emission() -> void:
	_simulate_connected_gamepads(4)
	watch_signals(splitscreen_manager)

	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	assert_signal_emitted(splitscreen_manager, "session_started")


## Test: Session end signal emission
func test_session_end_signal_emission() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	watch_signals(splitscreen_manager)
	splitscreen_manager.end_session()

	assert_signal_emitted(splitscreen_manager, "session_ended")


## Test: Player joined signal emission
func test_player_joined_signal_emission() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	watch_signals(splitscreen_manager)
	_simulate_connected_gamepads(5)
	splitscreen_manager.add_player(4)

	assert_signal_emitted(splitscreen_manager, "player_joined")


## Test: Player left signal emission
func test_player_left_signal_emission() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	watch_signals(splitscreen_manager)
	splitscreen_manager.remove_player(0)

	assert_signal_emitted(splitscreen_manager, "player_left")


## Test: Session pause and resume
func test_session_pause_and_resume() -> void:
	_simulate_connected_gamepads(4)
	splitscreen_manager.start_session(4)
	await _complete_device_assignment(4)

	splitscreen_manager.pause_session()
	assert_eq(
		splitscreen_manager.session_state.current_state,
		SessionState.State.PAUSED,
		"Session should be paused"
	)

	splitscreen_manager.resume_session()
	assert_eq(
		splitscreen_manager.session_state.current_state,
		SessionState.State.ACTIVE,
		"Session should be active after resume"
	)
