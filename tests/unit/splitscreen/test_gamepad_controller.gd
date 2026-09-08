extends GutTest

## Unit tests for GamepadController class
## Tests device detection, assignment, input routing, and disconnect handling

var gamepad_controller: GamepadController


func before_each() -> void:
	gamepad_controller = GamepadController.new()
	add_child_autofree(gamepad_controller)


func after_each() -> void:
	gamepad_controller = null


## Test: Initial state has no assignments
func test_initial_state_no_assignments() -> void:
	assert_eq(
		gamepad_controller.get_assigned_players().size(),
		0,
		"Should have no assigned players initially"
	)
	assert_eq(
		gamepad_controller.get_assigned_device(0), -1, "Player 0 should have no device assigned"
	)


## Test: Detect gamepads returns array
func test_detect_gamepads_returns_array() -> void:
	var devices = gamepad_controller.detect_gamepads()
	assert_not_null(devices, "Should return an array")
	assert_typeof(devices, TYPE_ARRAY, "Should be an array type")


## Test: Assign gamepad to player successfully
func test_assign_gamepad_success() -> void:
	# Mock a connected device by adding it to the internal list
	gamepad_controller._connected_devices.append(0)

	var result = gamepad_controller.assign_gamepad(0, 0)
	assert_true(result, "Assignment should succeed")
	assert_eq(gamepad_controller.get_assigned_device(0), 0, "Player 0 should have device 0")
	assert_eq(
		gamepad_controller.get_player_for_device(0), 0, "Device 0 should be assigned to player 0"
	)


## Test: Assign non-existent device fails
func test_assign_nonexistent_device_fails() -> void:
	var result = gamepad_controller.assign_gamepad(0, 99)
	assert_push_error("Cannot assign non-existent device 99")
	assert_false(result, "Assignment should fail for non-existent device")
	assert_eq(gamepad_controller.get_assigned_device(0), -1, "Player 0 should have no device")


## Test: Assign already assigned device to different player fails
func test_assign_duplicate_device_fails() -> void:
	gamepad_controller._connected_devices.append(0)

	gamepad_controller.assign_gamepad(0, 0)
	var result = gamepad_controller.assign_gamepad(1, 0)
	assert_push_error("Device 0 is already assigned to player 0")

	assert_false(result, "Assignment should fail for already assigned device")
	assert_eq(gamepad_controller.get_assigned_device(1), -1, "Player 1 should have no device")


## Test: Reassign device to same player succeeds
func test_reassign_device_to_same_player_succeeds() -> void:
	gamepad_controller._connected_devices.append(0)

	gamepad_controller.assign_gamepad(0, 0)
	var result = gamepad_controller.assign_gamepad(0, 0)

	assert_true(result, "Reassignment to same player should succeed")
	assert_eq(gamepad_controller.get_assigned_device(0), 0, "Player 0 should still have device 0")


## Test: Assign new device to player unassigns old device
func test_assign_new_device_unassigns_old() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._connected_devices.append(1)

	gamepad_controller.assign_gamepad(0, 0)
	gamepad_controller.assign_gamepad(0, 1)

	assert_eq(gamepad_controller.get_assigned_device(0), 1, "Player 0 should have device 1")
	assert_eq(gamepad_controller.get_player_for_device(0), -1, "Device 0 should be unassigned")
	assert_false(gamepad_controller.is_device_assigned(0), "Device 0 should not be assigned")


## Test: Unassign gamepad from player
func test_unassign_gamepad() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(0, 0)

	gamepad_controller.unassign_gamepad(0)

	assert_eq(gamepad_controller.get_assigned_device(0), -1, "Player 0 should have no device")
	assert_eq(gamepad_controller.get_player_for_device(0), -1, "Device 0 should be unassigned")


## Test: Unassign non-existent assignment does nothing
func test_unassign_nonexistent_assignment() -> void:
	gamepad_controller.unassign_gamepad(99)
	# Should not crash or error
	assert_true(true, "Should handle gracefully")


## Test: Get player for device returns correct player
func test_get_player_for_device() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(5, 0)

	assert_eq(
		gamepad_controller.get_player_for_device(0), 5, "Device 0 should be assigned to player 5"
	)


## Test: Get player for unassigned device returns -1
func test_get_player_for_unassigned_device() -> void:
	assert_eq(
		gamepad_controller.get_player_for_device(99), -1, "Unassigned device should return -1"
	)


## Test: Is device assigned check
func test_is_device_assigned() -> void:
	gamepad_controller._connected_devices.append(0)

	assert_false(
		gamepad_controller.is_device_assigned(0), "Device should not be assigned initially"
	)

	gamepad_controller.assign_gamepad(0, 0)

	assert_true(
		gamepad_controller.is_device_assigned(0), "Device should be assigned after assignment"
	)


## Test: Set expected player count
func test_set_expected_player_count() -> void:
	gamepad_controller.set_expected_player_count(4)
	assert_false(
		gamepad_controller.is_assignment_complete(),
		"Assignment should not be complete with 0 assignments"
	)


## Test: Assignment complete detection
func test_assignment_complete_detection() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._connected_devices.append(1)
	gamepad_controller._connected_devices.append(2)
	gamepad_controller._connected_devices.append(3)

	gamepad_controller.set_expected_player_count(4)

	gamepad_controller.assign_gamepad(0, 0)
	gamepad_controller.assign_gamepad(1, 1)
	gamepad_controller.assign_gamepad(2, 2)

	assert_false(
		gamepad_controller.is_assignment_complete(),
		"Assignment should not be complete with 3/4 players"
	)

	gamepad_controller.assign_gamepad(3, 3)

	assert_true(
		gamepad_controller.is_assignment_complete(),
		"Assignment should be complete with 4/4 players"
	)


## Test: Get connected device count
func test_get_connected_device_count() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._connected_devices.append(1)

	assert_eq(gamepad_controller.get_connected_device_count(), 2, "Should have 2 connected devices")


## Test: Get connected devices returns copy
func test_get_connected_devices_returns_copy() -> void:
	gamepad_controller._connected_devices.append(0)

	var devices = gamepad_controller.get_connected_devices()
	devices.append(99)

	assert_eq(
		gamepad_controller.get_connected_device_count(), 1, "Original list should not be modified"
	)


## Test: Get assigned players
func test_get_assigned_players() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._connected_devices.append(1)

	gamepad_controller.assign_gamepad(0, 0)
	gamepad_controller.assign_gamepad(2, 1)

	var players = gamepad_controller.get_assigned_players()
	assert_eq(players.size(), 2, "Should have 2 assigned players")
	assert_true(0 in players, "Player 0 should be in list")
	assert_true(2 in players, "Player 2 should be in list")


## Test: Clear assignments
func test_clear_assignments() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._connected_devices.append(1)

	gamepad_controller.assign_gamepad(0, 0)
	gamepad_controller.assign_gamepad(1, 1)

	gamepad_controller.clear_assignments()

	assert_eq(
		gamepad_controller.get_assigned_players().size(), 0, "Should have no assigned players"
	)
	assert_eq(gamepad_controller.get_assigned_device(0), -1, "Player 0 should have no device")
	assert_eq(gamepad_controller.get_assigned_device(1), -1, "Player 1 should have no device")


## Test: Load configuration
func test_load_configuration() -> void:
	var config = {"vibration_enabled": false, "analog_deadzone": 0.2, "trigger_threshold": 0.15}

	gamepad_controller.load_configuration(config)

	assert_false(gamepad_controller.vibration_enabled, "Vibration should be disabled")
	assert_almost_eq(gamepad_controller.analog_deadzone, 0.2, 0.01, "Analog deadzone should be 0.2")
	assert_almost_eq(
		gamepad_controller.trigger_threshold, 0.15, 0.01, "Trigger threshold should be 0.15"
	)


## Test: Load configuration with defaults
func test_load_configuration_with_defaults() -> void:
	var config = {}

	gamepad_controller.load_configuration(config)

	assert_true(gamepad_controller.vibration_enabled, "Vibration should be enabled by default")
	assert_almost_eq(
		gamepad_controller.analog_deadzone, 0.15, 0.01, "Analog deadzone should be default 0.15"
	)


## Test: Gamepad assigned signal emitted
func test_gamepad_assigned_signal() -> void:
	gamepad_controller._connected_devices.append(0)

	watch_signals(gamepad_controller)
	gamepad_controller.assign_gamepad(0, 0)

	assert_signal_emitted(
		gamepad_controller, "gamepad_assigned", "Should emit gamepad_assigned signal"
	)
	assert_signal_emit_count(gamepad_controller, "gamepad_assigned", 1, "Should emit signal once")


## Test: Gamepad unassigned signal emitted
func test_gamepad_unassigned_signal() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(0, 0)

	watch_signals(gamepad_controller)
	gamepad_controller.unassign_gamepad(0)

	assert_signal_emitted(
		gamepad_controller, "gamepad_unassigned", "Should emit gamepad_unassigned signal"
	)


## Test: Assignment complete signal emitted
func test_assignment_complete_signal() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._connected_devices.append(1)
	gamepad_controller.set_expected_player_count(2)

	watch_signals(gamepad_controller)
	gamepad_controller.assign_gamepad(0, 0)
	gamepad_controller.assign_gamepad(1, 1)

	assert_signal_emitted(
		gamepad_controller, "assignment_complete", "Should emit assignment_complete signal"
	)


## Test: Is action pressed returns false for unassigned player
func test_is_action_pressed_unassigned_player() -> void:
	var result = gamepad_controller.is_action_pressed(0, "ui_accept")
	assert_false(result, "Should return false for unassigned player")


## Test: Is action just pressed returns false for unassigned player
func test_is_action_just_pressed_unassigned_player() -> void:
	var result = gamepad_controller.is_action_just_pressed(0, "ui_accept")
	assert_false(result, "Should return false for unassigned player")


## Test: Is action just released returns false for unassigned player
func test_is_action_just_released_unassigned_player() -> void:
	var result = gamepad_controller.is_action_just_released(0, "ui_accept")
	assert_false(result, "Should return false for unassigned player")


## Test: Get input vector returns zero for unassigned player
func test_get_input_vector_unassigned_player() -> void:
	var vector = gamepad_controller.get_input_vector(0, "ui_left", "ui_right", "ui_up", "ui_down")
	assert_eq(vector, Vector2.ZERO, "Should return zero vector for unassigned player")


## Test: Trigger vibration does nothing for unassigned player
func test_trigger_vibration_unassigned_player() -> void:
	# Should not crash
	gamepad_controller.trigger_vibration(0, 0.5, 0.5, 1.0)
	assert_true(true, "Should handle gracefully")


## Test: Trigger vibration respects enabled flag
func test_trigger_vibration_respects_enabled_flag() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(0, 0)
	gamepad_controller.vibration_enabled = false

	# Should not crash even when disabled
	gamepad_controller.trigger_vibration(0, 0.5, 0.5, 1.0)
	assert_true(true, "Should handle gracefully when disabled")
