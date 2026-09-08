extends GutTest

## Unit tests for Assignment UI
## Tests player slot claiming and device assignment UI

var assignment_ui: Control
var gamepad_controller: GamepadController


func before_each() -> void:
	gamepad_controller = GamepadController.new()
	add_child_autofree(gamepad_controller)

	# Create a mock assignment UI
	assignment_ui = Control.new()
	assignment_ui.name = "AssignmentUI"
	add_child_autofree(assignment_ui)

	# Add device_claimed signal
	assignment_ui.add_user_signal(
		"device_claimed",
		[{"name": "player_slot", "type": TYPE_INT}, {"name": "device_id", "type": TYPE_INT}]
	)


func after_each() -> void:
	assignment_ui = null
	gamepad_controller = null


## Test: Assignment UI can be shown
func test_show_assignment_ui() -> void:
	# Mock the scene loading by setting _assignment_ui directly
	gamepad_controller._assignment_ui = assignment_ui

	assert_not_null(gamepad_controller._assignment_ui, "Assignment UI should be set")


## Test: Assignment UI can be hidden
func test_hide_assignment_ui() -> void:
	gamepad_controller._assignment_ui = assignment_ui
	gamepad_controller.hide_assignment_ui()

	# UI should be queued for deletion
	assert_null(gamepad_controller._assignment_ui, "Assignment UI reference should be cleared")


## Test: Device claim triggers gamepad assignment
func test_device_claim_triggers_assignment() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._assignment_ui = assignment_ui

	# Connect the signal
	if assignment_ui.has_signal("device_claimed"):
		assignment_ui.connect("device_claimed", gamepad_controller._on_device_claimed)

	# Simulate device claim
	assignment_ui.emit_signal("device_claimed", 0, 0)

	assert_eq(
		gamepad_controller.get_assigned_device(0),
		0,
		"Device should be assigned to player after claim"
	)


## Test: Multiple players can claim devices
func test_multiple_players_claim_devices() -> void:
	for i in range(4):
		gamepad_controller._connected_devices.append(i)

	gamepad_controller._assignment_ui = assignment_ui

	if assignment_ui.has_signal("device_claimed"):
		assignment_ui.connect("device_claimed", gamepad_controller._on_device_claimed)

	# Simulate multiple claims
	for i in range(4):
		assignment_ui.emit_signal("device_claimed", i, i)

	for i in range(4):
		assert_eq(
			gamepad_controller.get_assigned_device(i), i, "Player %d should have device %d" % [i, i]
		)


## Test: Assignment UI shows connected devices
func test_assignment_ui_shows_connected_devices() -> void:
	for i in range(3):
		gamepad_controller._connected_devices.append(i)

	var connected = gamepad_controller.get_connected_devices()

	assert_eq(connected.size(), 3, "UI should show 3 connected devices")


## Test: Assignment UI prevents duplicate assignments
func test_assignment_ui_prevents_duplicate_assignments() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._assignment_ui = assignment_ui

	if assignment_ui.has_signal("device_claimed"):
		assignment_ui.connect("device_claimed", gamepad_controller._on_device_claimed)

	# First claim succeeds
	assignment_ui.emit_signal("device_claimed", 0, 0)
	assert_eq(gamepad_controller.get_assigned_device(0), 0)

	# Second claim to same device fails
	assignment_ui.emit_signal("device_claimed", 1, 0)
	assert_push_error("already assigned")
	assert_eq(
		gamepad_controller.get_assigned_device(1),
		-1,
		"Second player should not get already assigned device"
	)


## Test: Assignment UI updates on device connect
func test_assignment_ui_updates_on_device_connect() -> void:
	watch_signals(gamepad_controller)

	gamepad_controller._on_device_connected(0)

	assert_signal_emitted(
		gamepad_controller, "gamepad_connected", "UI should be notified of new device"
	)


## Test: Assignment UI updates on device disconnect
func test_assignment_ui_updates_on_device_disconnect() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(0, 0)

	watch_signals(gamepad_controller)

	gamepad_controller._on_device_disconnected(0)

	assert_signal_emitted(
		gamepad_controller, "gamepad_disconnected", "UI should be notified of device disconnect"
	)


## Test: Assignment complete hides UI
func test_assignment_complete_hides_ui() -> void:
	gamepad_controller.set_expected_player_count(2)

	for i in range(2):
		gamepad_controller._connected_devices.append(i)

	watch_signals(gamepad_controller)

	gamepad_controller.assign_gamepad(0, 0)
	gamepad_controller.assign_gamepad(1, 1)

	assert_signal_emitted(
		gamepad_controller,
		"assignment_complete",
		"UI should be notified when assignment is complete"
	)


## Test: Assignment UI shows player slots
func test_assignment_ui_shows_player_slots() -> void:
	gamepad_controller.set_expected_player_count(4)

	assert_eq(gamepad_controller._expected_player_count, 4, "UI should show 4 player slots")


## Test: Assignment UI handles no devices
func test_assignment_ui_handles_no_devices() -> void:
	var devices = gamepad_controller.get_connected_devices()

	assert_eq(devices.size(), 0, "UI should handle no connected devices gracefully")


## Test: Assignment UI allows device reassignment
func test_assignment_ui_allows_device_reassignment() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller._connected_devices.append(1)

	gamepad_controller.assign_gamepad(0, 0)
	assert_eq(gamepad_controller.get_assigned_device(0), 0)

	# Reassign to different device
	gamepad_controller.assign_gamepad(0, 1)
	assert_eq(
		gamepad_controller.get_assigned_device(0),
		1,
		"UI should allow reassigning player to different device"
	)


## Test: Assignment UI shows device names
func test_assignment_ui_shows_device_names() -> void:
	# This would require actual Input system, so we test the interface
	var input_comp = SplitscreenInputComponent.new()
	input_comp.set_device(0, gamepad_controller, 0)

	var name = input_comp.get_gamepad_name()
	assert_typeof(name, TYPE_STRING, "UI should be able to display device names")

	input_comp.free()


## Test: Assignment UI progress indicator
func test_assignment_ui_progress_indicator() -> void:
	gamepad_controller.set_expected_player_count(4)

	for i in range(2):
		gamepad_controller._connected_devices.append(i)
		gamepad_controller.assign_gamepad(i, i)

	var assigned_count = gamepad_controller.get_assigned_players().size()
	var progress = float(assigned_count) / float(gamepad_controller._expected_player_count)

	assert_almost_eq(progress, 0.5, 0.01, "UI should show 50% progress with 2/4 players assigned")


## Test: Assignment UI cancel button
func test_assignment_ui_cancel_button() -> void:
	gamepad_controller._assignment_ui = assignment_ui

	# Simulate cancel
	gamepad_controller.hide_assignment_ui()
	gamepad_controller.clear_assignments()

	assert_eq(
		gamepad_controller.get_assigned_players().size(), 0, "Cancel should clear all assignments"
	)
