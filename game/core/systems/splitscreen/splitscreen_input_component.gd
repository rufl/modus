class_name SplitscreenInputComponent
extends Node

## SplitscreenInputComponent provides device-specific input handling for splitscreen players.
##
## This component extends the standard input handling to route input from a specific
## gamepad device, ensuring input isolation between players in splitscreen mode.
## It maintains compatibility with the existing InputComponent interface while adding
## device-specific filtering.

## The assigned gamepad device ID (-1 if not assigned)
var assigned_device_id: int = -1

## Reference to the GamepadController for input queries
var gamepad_controller: GamepadController = null

## Player ID this component belongs to
var player_id: int = -1


## Set the device and controller for this input component
func set_device(device_id: int, controller: GamepadController, p_player_id: int = -1) -> void:
	assigned_device_id = device_id
	gamepad_controller = controller
	player_id = p_player_id


## Get the assigned device ID
func get_device_id() -> int:
	return assigned_device_id


## Check if a device is assigned
func has_device() -> bool:
	return assigned_device_id != -1 and gamepad_controller != null


## Check if an action is currently pressed
func is_action_pressed(action: String) -> bool:
	if not has_device():
		return false

	if gamepad_controller != null and player_id != -1:
		return gamepad_controller.is_action_pressed(player_id, action)

	# Fallback to direct device query
	return Input.is_action_pressed(action, assigned_device_id)


## Check if an action was just pressed this frame
func is_action_just_pressed(action: String) -> bool:
	if not has_device():
		return false

	if gamepad_controller != null and player_id != -1:
		return gamepad_controller.is_action_just_pressed(player_id, action)

	# Fallback to direct device query
	return Input.is_action_just_pressed(action, assigned_device_id)


## Check if an action was just released this frame
func is_action_just_released(action: String) -> bool:
	if not has_device():
		return false

	if gamepad_controller != null and player_id != -1:
		return gamepad_controller.is_action_just_released(player_id, action)

	# Fallback to direct device query
	return Input.is_action_just_released(action, assigned_device_id)


## Get action strength (for analog inputs like triggers)
func get_action_strength(action: String) -> float:
	if not has_device():
		return 0.0

	return Input.get_action_strength(action, assigned_device_id)


## Get input vector for movement (with deadzone)
func get_input_vector(
	negative_x: String,
	positive_x: String,
	negative_y: String,
	positive_y: String,
	deadzone: float = -1.0
) -> Vector2:
	if not has_device():
		return Vector2.ZERO

	if gamepad_controller != null and player_id != -1:
		return gamepad_controller.get_input_vector(
			player_id, negative_x, positive_x, negative_y, positive_y
		)

	# Fallback to direct input query
	var dz: float = (
		deadzone
		if deadzone >= 0.0
		else (gamepad_controller.analog_deadzone if gamepad_controller else 0.15)
	)
	return Input.get_vector(negative_x, positive_x, negative_y, positive_y, dz)


## Get a device-scoped axis value for two actions.
##
## Input.get_axis() does not accept a device ID, so using it here would allow
## keyboard or another gamepad's action state to leak into this player.
func get_axis(negative_action: String, positive_action: String) -> float:
	if not has_device():
		return 0.0

	var negative_strength := Input.get_action_strength(negative_action, assigned_device_id)
	var positive_strength := Input.get_action_strength(positive_action, assigned_device_id)
	return positive_strength - negative_strength


## Process the polling hook once per frame.
##
## The base component deliberately does not invent gameplay actions. Derived
## components may override _process_input() to translate this player's
## device-scoped queries into gameplay behavior.
func _process(delta: float) -> void:
	_process_input(delta)


## Extension hook for polling-based input behavior.
##
## This default is intentional: SplitscreenInputComponent only owns device
## assignment, filtering, and input queries. A concrete player input component
## must override this hook to implement gameplay behavior.
func _process_input(_delta: float) -> void:
	return


## Handle input events
func _unhandled_input(event: InputEvent) -> void:
	if not has_device() or not _is_assigned_device_event(event):
		return

	_handle_input_event(event)


## Return whether an event is a raw joypad event from this component's device.
##
## Keyboard, mouse, window, and action events do not identify a gamepad device,
## so they are rejected by default to preserve splitscreen input isolation.
func _is_assigned_device_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).device == assigned_device_id
	if event is InputEventJoypadMotion:
		return (event as InputEventJoypadMotion).device == assigned_device_id
	return false


## Extension hook for a filtered raw joypad event.
##
## This default is intentional: the base component filters and exposes events
## but does not choose gameplay actions. Derived components may override this
## hook when they need event-driven behavior.
func _handle_input_event(_event: InputEvent) -> void:
	return


## Trigger vibration on this player's gamepad
func trigger_vibration(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	if not has_device():
		return

	if gamepad_controller != null and player_id != -1:
		gamepad_controller.trigger_vibration(player_id, weak_magnitude, strong_magnitude, duration)
	else:
		Input.start_joy_vibration(assigned_device_id, weak_magnitude, strong_magnitude, duration)


## Stop vibration on this player's gamepad
func stop_vibration() -> void:
	if not has_device():
		return

	Input.stop_joy_vibration(assigned_device_id)


## Get the gamepad name
func get_gamepad_name() -> String:
	if not has_device():
		return ""

	return Input.get_joy_name(assigned_device_id)


## Check if the gamepad is connected
func is_gamepad_connected() -> bool:
	if not has_device():
		return false

	return assigned_device_id in Input.get_connected_joypads()


## Get raw joy axis value
func get_joy_axis(axis: JoyAxis) -> float:
	if not has_device():
		return 0.0

	return Input.get_joy_axis(assigned_device_id, axis)


## Check if a joy button is pressed
func is_joy_button_pressed(button: JoyButton) -> bool:
	if not has_device():
		return false

	return Input.is_joy_button_pressed(assigned_device_id, button)


## Get input summary for debugging
func get_input_summary() -> Dictionary:
	return {
		"player_id": player_id,
		"device_id": assigned_device_id,
		"has_device": has_device(),
		"is_connected": is_gamepad_connected(),
		"gamepad_name": get_gamepad_name()
	}
