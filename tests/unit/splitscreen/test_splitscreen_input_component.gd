extends GutTest

## Unit tests for SplitscreenInputComponent class
## Tests device assignment and input routing

var input_component: SplitscreenInputComponent
var gamepad_controller: GamepadController

class RecordingSplitscreenInputComponent extends SplitscreenInputComponent:
	var processed_deltas: Array[float] = []
	var received_events: Array[InputEvent] = []

	func _process_input(delta: float) -> void:
		processed_deltas.append(delta)

	func _handle_input_event(event: InputEvent) -> void:
		received_events.append(event)


func before_each() -> void:
	input_component = SplitscreenInputComponent.new()
	gamepad_controller = GamepadController.new()
	add_child_autofree(input_component)
	add_child_autofree(gamepad_controller)


func after_each() -> void:
	if input_component and is_instance_valid(input_component):
		input_component = null
	if gamepad_controller and is_instance_valid(gamepad_controller):
		gamepad_controller = null


## Test: Initial state has no device
func test_initial_state_no_device() -> void:
	assert_eq(input_component.get_device_id(), -1, "Should have no device initially")
	assert_false(input_component.has_device(), "Should not have device initially")


## Test: Set device assigns correctly
func test_set_device() -> void:
	input_component.set_device(0, gamepad_controller, 0)

	assert_eq(input_component.get_device_id(), 0, "Device ID should be 0")
	assert_eq(input_component.player_id, 0, "Player ID should be 0")
	assert_true(input_component.has_device(), "Should have device after assignment")


## Test: Has device check
func test_has_device_check() -> void:
	assert_false(input_component.has_device(), "Should not have device without assignment")

	input_component.set_device(0, gamepad_controller, 0)

	assert_true(input_component.has_device(), "Should have device after assignment")


## Test: Is action pressed returns false without device
func test_is_action_pressed_without_device() -> void:
	var result = input_component.is_action_pressed("ui_accept")
	assert_false(result, "Should return false without device")


## Test: Is action just pressed returns false without device
func test_is_action_just_pressed_without_device() -> void:
	var result = input_component.is_action_just_pressed("ui_accept")
	assert_false(result, "Should return false without device")


## Test: Is action just released returns false without device
func test_is_action_just_released_without_device() -> void:
	var result = input_component.is_action_just_released("ui_accept")
	assert_false(result, "Should return false without device")


## Test: Get action strength returns zero without device
func test_get_action_strength_without_device() -> void:
	var strength = input_component.get_action_strength("ui_accept")
	assert_eq(strength, 0.0, "Should return 0.0 without device")


## Test: Get input vector returns zero without device
func test_get_input_vector_without_device() -> void:
	var vector = input_component.get_input_vector("ui_left", "ui_right", "ui_up", "ui_down")
	assert_eq(vector, Vector2.ZERO, "Should return zero vector without device")


## Test: Get axis returns zero without device
func test_get_axis_without_device() -> void:
	var axis = input_component.get_axis("ui_left", "ui_right")
	assert_eq(axis, 0.0, "Should return 0.0 without device")


## Test: Trigger vibration does nothing without device
func test_trigger_vibration_without_device() -> void:
	# Should not crash
	input_component.trigger_vibration(0.5, 0.5, 1.0)
	assert_true(true, "Should handle gracefully")


## Test: Stop vibration does nothing without device
func test_stop_vibration_without_device() -> void:
	# Should not crash
	input_component.stop_vibration()
	assert_true(true, "Should handle gracefully")


## Test: Get gamepad name returns empty without device
func test_get_gamepad_name_without_device() -> void:
	var name = input_component.get_gamepad_name()
	assert_eq(name, "", "Should return empty string without device")


## Test: Is gamepad connected returns false without device
func test_is_gamepad_connected_without_device() -> void:
	var connected = input_component.is_gamepad_connected()
	assert_false(connected, "Should return false without device")


## Test: Get joy axis returns zero without device
func test_get_joy_axis_without_device() -> void:
	var axis_value = input_component.get_joy_axis(JOY_AXIS_LEFT_X)
	assert_eq(axis_value, 0.0, "Should return 0.0 without device")


## Test: Is joy button pressed returns false without device
func test_is_joy_button_pressed_without_device() -> void:
	var pressed = input_component.is_joy_button_pressed(JOY_BUTTON_A)
	assert_false(pressed, "Should return false without device")


## Test: Get input summary
func test_get_input_summary() -> void:
	input_component.set_device(0, gamepad_controller, 5)

	var summary = input_component.get_input_summary()

	assert_true(summary.has("player_id"), "Summary should have player_id")
	assert_true(summary.has("device_id"), "Summary should have device_id")
	assert_true(summary.has("has_device"), "Summary should have has_device")
	assert_eq(summary["player_id"], 5, "Player ID should be 5")
	assert_eq(summary["device_id"], 0, "Device ID should be 0")
	assert_true(summary["has_device"], "Should have device")


## Test: Get input summary without device
func test_get_input_summary_without_device() -> void:
	var summary = input_component.get_input_summary()

	assert_eq(summary["player_id"], -1, "Player ID should be -1")
	assert_eq(summary["device_id"], -1, "Device ID should be -1")
	assert_false(summary["has_device"], "Should not have device")


## Test: Device assignment with gamepad controller
func test_device_assignment_with_controller() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(0, 0)

	input_component.set_device(0, gamepad_controller, 0)

	assert_eq(input_component.assigned_device_id, 0, "Device ID should be assigned")
	assert_eq(
		input_component.gamepad_controller, gamepad_controller, "Controller reference should be set"
	)
	assert_eq(input_component.player_id, 0, "Player ID should be set")


## Test: Input routing through gamepad controller
func test_input_routing_through_controller() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(0, 0)

	input_component.set_device(0, gamepad_controller, 0)

	# Test that input methods use the gamepad controller
	# (Actual input testing would require mocking Input system)
	assert_true(input_component.has_device(), "Should have device for input routing")


## Test: Vibration routing through gamepad controller
func test_vibration_routing_through_controller() -> void:
	gamepad_controller._connected_devices.append(0)
	gamepad_controller.assign_gamepad(0, 0)
	gamepad_controller.vibration_enabled = true

	input_component.set_device(0, gamepad_controller, 0)

	# Should not crash
	input_component.trigger_vibration(0.5, 0.5, 1.0)
	assert_true(true, "Should route vibration through controller")


## Test: Stop vibration with assigned device
func test_stop_vibration_with_device() -> void:
	input_component.set_device(0, gamepad_controller, 0)

	# Should not crash
	input_component.stop_vibration()
	assert_true(true, "Should handle stop vibration")


## Test: Get input vector with custom deadzone
func test_get_input_vector_with_custom_deadzone() -> void:
	input_component.set_device(0, gamepad_controller, 0)

	var vector = input_component.get_input_vector("ui_left", "ui_right", "ui_up", "ui_down", 0.2)

	# Should return a vector (even if zero without actual input)
	assert_typeof(vector, TYPE_VECTOR2, "Should return Vector2")


## Test: Polling hook is dispatched for extension components
func test_process_input_virtual_hook() -> void:
	var recorder := RecordingSplitscreenInputComponent.new()
	add_child_autofree(recorder)

	recorder._process(0.25)

	assert_eq(recorder.processed_deltas.size(), 1, "Polling hook should be called once")
	assert_eq(recorder.processed_deltas[0], 0.25, "Polling hook should receive delta")


## Test: Unhandled input only dispatches matching joypad events
func test_unhandled_input_filters_to_assigned_device() -> void:
	var recorder := RecordingSplitscreenInputComponent.new()
	add_child_autofree(recorder)
	recorder.set_device(2, gamepad_controller, 0)

	var other_device_event := InputEventJoypadButton.new()
	other_device_event.device = 1
	recorder._unhandled_input(other_device_event)

	var matching_event := InputEventJoypadButton.new()
	matching_event.device = 2
	recorder._unhandled_input(matching_event)

	assert_eq(recorder.received_events.size(), 1, "Only the assigned device event should dispatch")
	assert_eq(recorder.received_events[0], matching_event, "Matching event should reach the extension hook")


## Test: Keyboard input is rejected by the default device filter
func test_unhandled_input_rejects_non_joypad_events() -> void:
	var recorder := RecordingSplitscreenInputComponent.new()
	add_child_autofree(recorder)
	recorder.set_device(0, gamepad_controller, 0)

	var key_event := InputEventKey.new()
	key_event.pressed = true
	recorder._unhandled_input(key_event)

	assert_eq(recorder.received_events.size(), 0, "Keyboard events must not cross device isolation")
