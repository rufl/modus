extends ModusGutTestBase

## Unit tests for SplitscreenManager class
## Tests session lifecycle, player management, and error handling

var splitscreen_manager: SplitscreenManager


func _transition_session_to_active() -> void:
	var state := splitscreen_manager.session_state
	if state.current_state == SessionState.State.INACTIVE:
		assert_true(state.transition_to(SessionState.State.INITIALIZING))
	if state.current_state == SessionState.State.INITIALIZING:
		assert_true(state.transition_to(SessionState.State.ASSIGNING_DEVICES))
	if state.current_state in [SessionState.State.ASSIGNING_DEVICES, SessionState.State.PAUSED]:
		assert_true(state.transition_to(SessionState.State.ACTIVE))


func before_each() -> void:
	splitscreen_manager = SplitscreenManager.new()
	add_child_autofree(splitscreen_manager)
	splitscreen_manager.initialize()
	await get_tree().process_frame


func after_each() -> void:
	if splitscreen_manager and is_instance_valid(splitscreen_manager):
		if splitscreen_manager.is_session_active():
			splitscreen_manager.end_session()
	splitscreen_manager = null


## Test: Initialization creates components
func test_initialization_creates_components() -> void:
	assert_not_null(splitscreen_manager.viewport_manager,
		"Should create ViewportManager")
	assert_not_null(splitscreen_manager.gamepad_controller,
		"Should create GamepadController")
	assert_not_null(splitscreen_manager.session_state,
		"Should create SessionState")


## Test: Initial state is inactive
func test_initial_state_inactive() -> void:
	assert_false(splitscreen_manager.is_session_active(),
		"Session should not be active initially")
	assert_eq(splitscreen_manager.get_player_count(), 0,
		"Player count should be 0 initially")


## Test: Start session with invalid player count (too low)
func test_start_session_player_count_too_low() -> void:
	var result: bool = splitscreen_manager.start_session(2)
	assert_push_error("below minimum")
	assert_false(result, "Should fail with player count below minimum")
	assert_false(splitscreen_manager.is_session_active(),
		"Session should not be active")


## Test: Start session with invalid player count (too high)
func test_start_session_player_count_too_high() -> void:
	var result: bool = splitscreen_manager.start_session(10)
	assert_push_error("exceeds maximum")
	assert_false(result, "Should fail with player count above maximum")
	assert_false(splitscreen_manager.is_session_active(),
		"Session should not be active")


## Test: Start session with insufficient gamepads
func test_start_session_insufficient_gamepads() -> void:
	# No gamepads connected by default
	var result: bool = splitscreen_manager.start_session(4)
	assert_push_error("Insufficient controllers")
	assert_false(result, "Should fail with insufficient gamepads")


## Test: Session started signal emitted
func test_session_started_signal() -> void:
	# Mock connected gamepads
	watch_signals(splitscreen_manager)
	splitscreen_manager.gamepad_controller.set_expected_player_count(4)
	splitscreen_manager.session_state.transition_to(SessionState.State.INITIALIZING)
	splitscreen_manager.session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	for i in range(4):
		splitscreen_manager.gamepad_controller._connected_devices.append(i)
		splitscreen_manager.session_state.add_player(i)
		splitscreen_manager.gamepad_controller.assign_gamepad(i, i)
	
	assert_signal_emitted(splitscreen_manager, "session_started",
		"Should emit session_started signal")


## Test: End session cleans up resources
func test_end_session_cleanup() -> void:
	# Mock a session
	_transition_session_to_active()
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.viewport_manager.create_viewport(0, null)
	
	splitscreen_manager.end_session()
	
	assert_false(splitscreen_manager.is_session_active(),
		"Session should not be active after end")
	assert_eq(splitscreen_manager.get_player_count(), 0,
		"Player count should be 0 after end")


## Test: Session ended signal emitted
func test_session_ended_signal() -> void:
	_transition_session_to_active()
	
	watch_signals(splitscreen_manager)
	splitscreen_manager.end_session()
	
	assert_signal_emitted(splitscreen_manager, "session_ended",
		"Should emit session_ended signal")


## Test: Pause session
func test_pause_session() -> void:
	_transition_session_to_active()
	
	splitscreen_manager.pause_session()
	
	assert_eq(splitscreen_manager.session_state.current_state, 
		SessionState.State.PAUSED,
		"Session should be paused")


## Test: Resume session
func test_resume_session() -> void:
	_transition_session_to_active()
	splitscreen_manager.session_state.transition_to(SessionState.State.PAUSED)
	
	splitscreen_manager.resume_session()
	
	assert_eq(splitscreen_manager.session_state.current_state,
		SessionState.State.ACTIVE,
		"Session should be active after resume")


## Test: Add player to session
func test_add_player() -> void:
	_transition_session_to_active()
	splitscreen_manager.gamepad_controller._connected_devices.append(0)
	
	var player_id: int = splitscreen_manager.add_player(0)
	
	assert_ge(player_id, 0, "Should return valid player ID")
	assert_eq(splitscreen_manager.get_player_count(), 1,
		"Player count should be 1")


## Test: Add player when at max capacity
func test_add_player_at_max_capacity() -> void:
	_transition_session_to_active()
	
	# Add max players
	for i in range(splitscreen_manager.max_players):
		splitscreen_manager.session_state.add_player(i)
	
	var player_id: int = splitscreen_manager.add_player(99)
	assert_push_error("maximum player count")
	
	assert_eq(player_id, -1, "Should fail when at max capacity")


## Test: Player joined signal emitted
func test_player_joined_signal() -> void:
	_transition_session_to_active()
	splitscreen_manager.gamepad_controller._connected_devices.append(0)
	
	watch_signals(splitscreen_manager)
	splitscreen_manager.add_player(0)
	
	assert_signal_emitted(splitscreen_manager, "player_joined",
		"Should emit player_joined signal")


## Test: Remove player from session
func test_remove_player() -> void:
	_transition_session_to_active()
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.viewport_manager.create_viewport(0, null)
	
	splitscreen_manager.remove_player(0)
	
	assert_eq(splitscreen_manager.get_player_count(), 0,
		"Player count should be 0 after removal")


## Test: Player left signal emitted
func test_player_left_signal() -> void:
	_transition_session_to_active()
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.viewport_manager.create_viewport(0, null)
	
	watch_signals(splitscreen_manager)
	splitscreen_manager.remove_player(0)
	
	assert_signal_emitted(splitscreen_manager, "player_left",
		"Should emit player_left signal")


## Test: Get session state
func test_get_session_state() -> void:
	var state: SessionState = splitscreen_manager.get_session_state()
	assert_not_null(state, "Should return session state")
	assert_eq(state, splitscreen_manager.session_state,
		"Should return the correct session state instance")


## Test: Is session active check
func test_is_session_active() -> void:
	assert_false(splitscreen_manager.is_session_active(),
		"Should not be active initially")
	
	_transition_session_to_active()
	
	assert_true(splitscreen_manager.is_session_active(),
		"Should be active after transition")


## Test: Get player count
func test_get_player_count() -> void:
	assert_eq(splitscreen_manager.get_player_count(), 0,
		"Should be 0 initially")
	
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.session_state.add_player(1)
	
	assert_eq(splitscreen_manager.get_player_count(), 2,
		"Should be 2 after adding players")


## Test: Gamepad disconnection triggers pause
func test_gamepad_disconnection_triggers_pause() -> void:
	_transition_session_to_active()
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.gamepad_controller._connected_devices.append(0)
	splitscreen_manager.gamepad_controller.assign_gamepad(0, 0)
	splitscreen_manager.auto_pause_on_disconnect = true
	
	splitscreen_manager._on_gamepad_disconnected(0)
	
	assert_eq(splitscreen_manager.session_state.current_state,
		SessionState.State.PAUSED,
		"Session should be paused after disconnect")


## Test: Gamepad disconnection updates player status
func test_gamepad_disconnection_updates_player_status() -> void:
	_transition_session_to_active()
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.gamepad_controller._connected_devices.append(0)
	splitscreen_manager.gamepad_controller.assign_gamepad(0, 0)
	
	splitscreen_manager._on_gamepad_disconnected(0)
	
	var player_data: Variant = splitscreen_manager.session_state.get_player_data(0)
	assert_false(player_data.connected,
		"Player should be marked as disconnected")


## Test: Session error signal emitted
func test_session_error_signal() -> void:
	watch_signals(splitscreen_manager)
	splitscreen_manager._emit_error("Test error")
	assert_push_error("Test error")
	
	assert_signal_emitted(splitscreen_manager, "session_error",
		"Should emit session_error signal")


## Test: Cleanup on error
func test_cleanup_on_error() -> void:
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.viewport_manager.create_viewport(0, null)
	splitscreen_manager.gamepad_controller._connected_devices.append(0)
	splitscreen_manager.gamepad_controller.assign_gamepad(0, 0)
	
	splitscreen_manager._cleanup_on_error()
	
	assert_eq(splitscreen_manager.viewport_manager.get_viewport_count(), 0,
		"Should cleanup viewports")
	assert_eq(splitscreen_manager.gamepad_controller.get_assigned_players().size(), 0,
		"Should clear gamepad assignments")
	assert_eq(splitscreen_manager.session_state.player_count, 0,
		"Should reset session state")


## Test: Set player scene
func test_set_player_scene() -> void:
	var mock_scene: PackedScene = PackedScene.new()
	splitscreen_manager.set_player_scene(mock_scene)
	
	assert_eq(splitscreen_manager.player_scene, mock_scene,
		"Should set player scene")


## Test: Configuration loading
func test_configuration_loading() -> void:
	# Configuration should be loaded during initialize()
	assert_eq(splitscreen_manager.min_players, 4,
		"Should load min_players from config")
	assert_eq(splitscreen_manager.max_players, 6,
		"Should load max_players from config")
	assert_eq(splitscreen_manager.default_player_count, 4,
		"Should normalize JSON numeric values to integer fields")


## Test: repeated initialization must not duplicate owned components
func test_initialization_is_idempotent() -> void:
	var original_viewport_manager := splitscreen_manager.viewport_manager
	var original_gamepad_controller := splitscreen_manager.gamepad_controller
	var original_child_count := splitscreen_manager.get_child_count()

	splitscreen_manager.initialize()

	assert_same(splitscreen_manager.viewport_manager, original_viewport_manager)
	assert_same(splitscreen_manager.gamepad_controller, original_gamepad_controller)
	assert_eq(splitscreen_manager.get_child_count(), original_child_count)


## Test: Performance monitoring updates metrics
func test_performance_monitoring() -> void:
	_transition_session_to_active()
	splitscreen_manager.adaptive_quality_enabled = true
	
	# Simulate a frame
	splitscreen_manager._process(0.016)
	
	# FPS samples should be collected
	assert_gt(splitscreen_manager._fps_samples.size(), 0,
		"Should collect FPS samples")


## Test: Quality adjustment on low FPS
func test_quality_adjustment_on_low_fps() -> void:
	_transition_session_to_active()
	splitscreen_manager.adaptive_quality_enabled = true
	splitscreen_manager._current_quality_level = "high"
	
	# Simulate low FPS
	for i in range(60):
		splitscreen_manager._fps_samples.append(30.0)  # Half of target FPS
	
	splitscreen_manager._last_quality_adjustment_time = splitscreen_manager.quality_adjustment_interval
	splitscreen_manager._monitor_performance(0.016)
	
	# Quality should be adjusted down
	assert_ne(splitscreen_manager._current_quality_level, "high",
		"Quality should be reduced on low FPS")


## Test: Remove player below minimum shows warning
func test_remove_player_below_minimum() -> void:
	_transition_session_to_active()
	
	# Add minimum players
	for i in range(splitscreen_manager.min_players):
		splitscreen_manager.session_state.add_player(i)
		splitscreen_manager.viewport_manager.create_viewport(i, null)
	
	# Remove one player (drops below minimum)
	splitscreen_manager.remove_player(0)
	
	# Session should continue but with warning
	assert_eq(splitscreen_manager.session_state.current_state,
		SessionState.State.ACTIVE,
		"Session should continue despite being below minimum")
