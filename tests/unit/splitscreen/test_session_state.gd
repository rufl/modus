extends GutTest

## Unit tests for SessionState class
## Tests state transitions, player management, and gamepad assignments

var session_state: SessionState


func before_each() -> void:
	session_state = SessionState.new()


func after_each() -> void:
	session_state = null


## Test: Initial state should be INACTIVE
func test_initial_state_is_inactive() -> void:
	assert_eq(
		session_state.current_state, SessionState.State.INACTIVE, "Initial state should be INACTIVE"
	)
	assert_eq(session_state.player_count, 0, "Initial player count should be 0")
	assert_eq(session_state.active_players.size(), 0, "Initial active players should be empty")


## Test: Valid state transition from INACTIVE to INITIALIZING
func test_valid_transition_inactive_to_initializing() -> void:
	var result = session_state.transition_to(SessionState.State.INITIALIZING)
	assert_true(result, "Transition should succeed")
	assert_eq(
		session_state.current_state, SessionState.State.INITIALIZING, "State should be INITIALIZING"
	)


## Test: Valid state transition from INITIALIZING to ASSIGNING_DEVICES
func test_valid_transition_initializing_to_assigning_devices() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	var result = session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	assert_true(result, "Transition should succeed")
	assert_eq(
		session_state.current_state,
		SessionState.State.ASSIGNING_DEVICES,
		"State should be ASSIGNING_DEVICES"
	)


## Test: Valid state transition from ASSIGNING_DEVICES to ACTIVE
func test_valid_transition_assigning_devices_to_active() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	var result = session_state.transition_to(SessionState.State.ACTIVE)
	assert_true(result, "Transition should succeed")
	assert_eq(session_state.current_state, SessionState.State.ACTIVE, "State should be ACTIVE")


## Test: Valid state transition from ACTIVE to PAUSED
func test_valid_transition_active_to_paused() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	session_state.transition_to(SessionState.State.ACTIVE)
	var result = session_state.transition_to(SessionState.State.PAUSED)
	assert_true(result, "Transition should succeed")
	assert_eq(session_state.current_state, SessionState.State.PAUSED, "State should be PAUSED")


## Test: Valid state transition from PAUSED to ACTIVE
func test_valid_transition_paused_to_active() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	session_state.transition_to(SessionState.State.ACTIVE)
	session_state.transition_to(SessionState.State.PAUSED)
	var result = session_state.transition_to(SessionState.State.ACTIVE)
	assert_true(result, "Transition should succeed")
	assert_eq(session_state.current_state, SessionState.State.ACTIVE, "State should be ACTIVE")


## Test: Valid state transition from ACTIVE to ENDING
func test_valid_transition_active_to_ending() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	session_state.transition_to(SessionState.State.ACTIVE)
	var result = session_state.transition_to(SessionState.State.ENDING)
	assert_true(result, "Transition should succeed")
	assert_eq(session_state.current_state, SessionState.State.ENDING, "State should be ENDING")


## Test: Valid state transition from ENDING to INACTIVE
func test_valid_transition_ending_to_inactive() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	session_state.transition_to(SessionState.State.ACTIVE)
	session_state.transition_to(SessionState.State.ENDING)
	var result = session_state.transition_to(SessionState.State.INACTIVE)
	assert_true(result, "Transition should succeed")
	assert_eq(session_state.current_state, SessionState.State.INACTIVE, "State should be INACTIVE")


## Test: Invalid state transition from INACTIVE to ACTIVE
func test_invalid_transition_inactive_to_active() -> void:
	var result = session_state.transition_to(SessionState.State.ACTIVE)
	assert_push_error("Invalid state transition from INACTIVE to ACTIVE")
	assert_false(result, "Transition should fail")
	assert_eq(
		session_state.current_state, SessionState.State.INACTIVE, "State should remain INACTIVE"
	)


## Test: Invalid state transition from INITIALIZING to ACTIVE
func test_invalid_transition_initializing_to_active() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	var result = session_state.transition_to(SessionState.State.ACTIVE)
	assert_push_error("Invalid state transition from INITIALIZING to ACTIVE")
	assert_false(result, "Transition should fail")
	assert_eq(
		session_state.current_state,
		SessionState.State.INITIALIZING,
		"State should remain INITIALIZING"
	)


## Test: Invalid state transition from ACTIVE to INITIALIZING
func test_invalid_transition_active_to_initializing() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	session_state.transition_to(SessionState.State.ACTIVE)
	var result = session_state.transition_to(SessionState.State.INITIALIZING)
	assert_push_error("Invalid state transition from ACTIVE to INITIALIZING")
	assert_false(result, "Transition should fail")
	assert_eq(session_state.current_state, SessionState.State.ACTIVE, "State should remain ACTIVE")


## Test: Add player successfully
func test_add_player_success() -> void:
	var result = session_state.add_player(0)
	assert_true(result, "Adding player should succeed")
	assert_eq(session_state.player_count, 1, "Player count should be 1")
	assert_true(session_state.active_players.has(0), "Player 0 should exist")


## Test: Add multiple players
func test_add_multiple_players() -> void:
	session_state.add_player(0)
	session_state.add_player(1)
	session_state.add_player(2)
	session_state.add_player(3)

	assert_eq(session_state.player_count, 4, "Player count should be 4")
	assert_eq(session_state.active_players.size(), 4, "Should have 4 active players")


## Test: Add duplicate player fails
func test_add_duplicate_player_fails() -> void:
	session_state.add_player(0)
	var result = session_state.add_player(0)
	assert_push_error("Player 0 already exists in session")
	assert_false(result, "Adding duplicate player should fail")
	assert_eq(session_state.player_count, 1, "Player count should remain 1")


## Test: Remove player successfully
func test_remove_player_success() -> void:
	session_state.add_player(0)
	var result = session_state.remove_player(0)
	assert_true(result, "Removing player should succeed")
	assert_eq(session_state.player_count, 0, "Player count should be 0")
	assert_false(session_state.active_players.has(0), "Player 0 should not exist")


## Test: Remove non-existent player fails
func test_remove_nonexistent_player_fails() -> void:
	var result = session_state.remove_player(99)
	assert_push_error("Player 99 does not exist in session")
	assert_false(result, "Removing non-existent player should fail")


## Test: Get player data
func test_get_player_data() -> void:
	session_state.add_player(0)
	var player_data = session_state.get_player_data(0)
	assert_not_null(player_data, "Player data should not be null")
	assert_eq(player_data.player_id, 0, "Player ID should be 0")


## Test: Get non-existent player data returns null
func test_get_nonexistent_player_data_returns_null() -> void:
	var player_data = session_state.get_player_data(99)
	assert_null(player_data, "Non-existent player data should be null")


## Test: Update player data
func test_update_player_data() -> void:
	session_state.add_player(0)
	var result = session_state.update_player_data(0, null, null, 2, true)
	assert_true(result, "Updating player data should succeed")

	var player_data = session_state.get_player_data(0)
	assert_eq(player_data.gamepad_device, 2, "Gamepad device should be 2")
	assert_true(player_data.connected, "Player should be connected")


## Test: Assign gamepad to player
func test_assign_gamepad_success() -> void:
	session_state.add_player(0)
	var result = session_state.assign_gamepad(0, 1)
	assert_true(result, "Assigning gamepad should succeed")
	assert_eq(session_state.get_assigned_gamepad(0), 1, "Player 0 should have gamepad 1")


## Test: Assign duplicate gamepad fails
func test_assign_duplicate_gamepad_fails() -> void:
	session_state.add_player(0)
	session_state.add_player(1)
	session_state.assign_gamepad(0, 1)
	var result = session_state.assign_gamepad(1, 1)
	assert_push_error("Gamepad device 1 is already assigned to player 0")
	assert_false(result, "Assigning duplicate gamepad should fail")


## Test: Unassign gamepad from player
func test_unassign_gamepad_success() -> void:
	session_state.add_player(0)
	session_state.assign_gamepad(0, 1)
	var result = session_state.unassign_gamepad(0)
	assert_true(result, "Unassigning gamepad should succeed")
	assert_eq(session_state.get_assigned_gamepad(0), -1, "Player 0 should have no gamepad")


## Test: Get player for gamepad device
func test_get_player_for_gamepad() -> void:
	session_state.add_player(0)
	session_state.assign_gamepad(0, 1)
	var player_id = session_state.get_player_for_gamepad(1)
	assert_eq(player_id, 0, "Gamepad 1 should be assigned to player 0")


## Test: Get player for unassigned gamepad returns -1
func test_get_player_for_unassigned_gamepad_returns_minus_one() -> void:
	var player_id = session_state.get_player_for_gamepad(99)
	assert_eq(player_id, -1, "Unassigned gamepad should return -1")


## Test: All gamepads assigned check
func test_all_gamepads_assigned() -> void:
	session_state.add_player(0)
	session_state.add_player(1)
	session_state.assign_gamepad(0, 0)
	assert_false(session_state.all_gamepads_assigned(), "Not all gamepads assigned yet")

	session_state.assign_gamepad(1, 1)
	assert_true(session_state.all_gamepads_assigned(), "All gamepads should be assigned")


## Test: Session timer starts correctly
func test_session_timer_start() -> void:
	session_state.start_timer()
	assert_gt(session_state.session_start_time, 0, "Session start time should be set")
	assert_eq(session_state.total_session_time, 0.0, "Total session time should be 0")


## Test: Session timer updates
func test_session_timer_update() -> void:
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.transition_to(SessionState.State.ASSIGNING_DEVICES)
	session_state.transition_to(SessionState.State.ACTIVE)
	session_state.start_timer()

	session_state.update_timer(1.0)
	assert_almost_eq(
		session_state.total_session_time, 1.0, 0.01, "Total session time should be ~1.0 seconds"
	)


## Test: Performance metrics update
func test_performance_metrics_update() -> void:
	session_state.update_performance_metrics(60.0, 16.67, 1024)
	assert_eq(session_state.get_performance_metric("fps"), 60.0, "FPS should be 60.0")
	assert_almost_eq(
		session_state.get_performance_metric("frame_time"),
		16.67,
		0.01,
		"Frame time should be ~16.67"
	)
	assert_eq(
		session_state.get_performance_metric("memory_usage"), 1024, "Memory usage should be 1024"
	)


## Test: Validate session state
func test_validate_session_state() -> void:
	session_state.add_player(0)
	session_state.add_player(1)
	session_state.assign_gamepad(0, 0)
	session_state.assign_gamepad(1, 1)

	assert_true(session_state.validate(), "Session state should be valid")


## Test: Reset clears all data
func test_reset_clears_all_data() -> void:
	session_state.add_player(0)
	session_state.assign_gamepad(0, 1)
	session_state.transition_to(SessionState.State.INITIALIZING)
	session_state.start_timer()

	session_state.reset()

	assert_eq(session_state.current_state, SessionState.State.INACTIVE, "State should be INACTIVE")
	assert_eq(session_state.player_count, 0, "Player count should be 0")
	assert_eq(session_state.active_players.size(), 0, "Active players should be empty")
	assert_eq(session_state.gamepad_assignments.size(), 0, "Gamepad assignments should be empty")
	assert_eq(session_state.session_start_time, 0, "Session start time should be 0")


## Test: to_dict returns valid dictionary
func test_to_dict_returns_valid_dictionary() -> void:
	session_state.add_player(0)
	session_state.assign_gamepad(0, 1)

	var dict = session_state.to_dict()
	assert_true(dict.has("current_state"), "Dict should have current_state")
	assert_true(dict.has("player_count"), "Dict should have player_count")
	assert_true(dict.has("active_players"), "Dict should have active_players")
	assert_eq(dict["player_count"], 1, "Player count should be 1")
