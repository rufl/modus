class_name GamepadController
extends Node

## GamepadController handles gamepad detection, assignment, and input routing
## for splitscreen multiplayer. This component manages the lifecycle of gamepad
## devices, assigns them to players, routes device-specific input, and handles
## disconnect/reconnect scenarios. It provides vibration feedback per device and
## monitors gamepad connections in real-time.

## Signals

## Emitted when a gamepad device is connected
signal gamepad_connected(device_id: int)

## Emitted when a gamepad device is disconnected
signal gamepad_disconnected(device_id: int)

## Emitted when a gamepad is assigned to a player
signal gamepad_assigned(player_id: int, device_id: int)

## Emitted when a gamepad is unassigned from a player
signal gamepad_unassigned(player_id: int, device_id: int)

## Emitted when all players have assigned gamepads
signal assignment_complete

## Configuration
var vibration_enabled: bool = true
var analog_deadzone: float = 0.15
var trigger_threshold: float = 0.1

## Internal state
var _device_to_player: Dictionary = {}  # device_id -> player_id
var _player_to_device: Dictionary = {}  # player_id -> device_id
var _connected_devices: Array[int] = []
var _disconnected_devices: Dictionary = {}  # device_id -> player_id (for reconnection)
var _assignment_ui: Node = null
var _expected_player_count: int = 0
var _connected_device_provider: Callable = Input.get_connected_joypads

## Rate limiting
var _rate_limiters: Dictionary = {}  # signal_name -> RateLimiter


func _ready() -> void:
	# Initial device detection
	_update_connected_devices()

	# Initialize rate limiters for signals
	_rate_limiters["gamepad_connected"] = RateLimiter.new(0.1, 5, 1.0)
	_rate_limiters["gamepad_disconnected"] = RateLimiter.new(0.1, 5, 1.0)
	_rate_limiters["gamepad_assigned"] = RateLimiter.new(0.05, 10, 1.0)
	_rate_limiters["gamepad_unassigned"] = RateLimiter.new(0.05, 10, 1.0)


func _process(_delta: float) -> void:
	# Monitor for device connections/disconnections
	_check_device_changes()


## Detect all currently connected gamepad devices
## Returns an array of device IDs
func detect_gamepads() -> Array[int]:
	_update_connected_devices()
	return _connected_devices.duplicate()


## Update the internal list of connected devices
func _update_connected_devices() -> void:
	var current_devices: Array[int] = []
	for device in _connected_device_provider.call():
		current_devices.append(device as int)
	_connected_devices.clear()
	for device_id in current_devices:
		_connected_devices.append(device_id)


## Check for device connection/disconnection changes
func _check_device_changes() -> void:
	var current_devices: Array[int] = []
	for device in _connected_device_provider.call():
		current_devices.append(device as int)
	var current_set: Dictionary = {}
	for device_id in current_devices:
		current_set[device_id] = true

	# Check for new connections
	for device_id in current_devices:
		if device_id not in _connected_devices:
			_on_device_connected(device_id)

	# Check for disconnections
	for device_id in _connected_devices:
		if not current_set.has(device_id):
			_on_device_disconnected(device_id)

	# Update connected devices list
	_connected_devices.clear()
	for device_id in current_devices:
		_connected_devices.append(device_id)


## Override device discovery for deterministic harnesses or platform adapters.
func set_connected_device_provider(provider: Callable) -> void:
	_connected_device_provider = provider if provider.is_valid() else Input.get_connected_joypads
	_update_connected_devices()


## Handle device connection
func _on_device_connected(device_id: int) -> void:
	# Check if this device was previously assigned (reconnection)
	if _disconnected_devices.has(device_id):
		var player_id: int = _disconnected_devices[device_id]
		_disconnected_devices.erase(device_id)
		# Reassign to the same player
		_device_to_player[device_id] = player_id
		_player_to_device[player_id] = device_id

	# Emit with rate limiting
	if _rate_limiters["gamepad_connected"].should_emit():
		gamepad_connected.emit(device_id)


## Handle device disconnection
func _on_device_disconnected(device_id: int) -> void:
	# Track which player this device was assigned to
	if _device_to_player.has(device_id):
		var player_id: int = _device_to_player[device_id]
		_disconnected_devices[device_id] = player_id
		_device_to_player.erase(device_id)
		_player_to_device.erase(player_id)

	# Emit with rate limiting
	if _rate_limiters["gamepad_disconnected"].should_emit():
		gamepad_disconnected.emit(device_id)


## Assign a gamepad device to a player
## Returns true if assignment was successful
func assign_gamepad(player_id: int, device_id: int) -> bool:
	# Check if device exists
	if device_id not in _connected_devices:
		push_error("Cannot assign non-existent device %d" % device_id)
		return false

	# Check if device is already assigned to another player
	if _device_to_player.has(device_id):
		var existing_player: int = _device_to_player[device_id]
		if existing_player != player_id:
			push_error("Device %d is already assigned to player %d" % [device_id, existing_player])
			return false

	# Unassign any previous device from this player
	if _player_to_device.has(player_id):
		var old_device: int = _player_to_device[player_id]
		_device_to_player.erase(old_device)

	# Assign the device
	_device_to_player[device_id] = player_id
	_player_to_device[player_id] = device_id

	# Emit with rate limiting
	if _rate_limiters["gamepad_assigned"].should_emit():
		gamepad_assigned.emit(player_id, device_id)

	# Check if all players have devices assigned
	if _expected_player_count > 0 and _player_to_device.size() == _expected_player_count:
		assignment_complete.emit()

	return true


## Unassign a gamepad from a player
## Returns true if unassignment was successful
func unassign_gamepad(player_id: int) -> void:
	if not _player_to_device.has(player_id):
		return

	var device_id: int = _player_to_device[player_id]
	_device_to_player.erase(device_id)
	_player_to_device.erase(player_id)

	# Emit with rate limiting
	if _rate_limiters["gamepad_unassigned"].should_emit():
		gamepad_unassigned.emit(player_id, device_id)


## Get the device ID assigned to a player
## Returns the device_id if assigned, -1 otherwise
func get_assigned_device(player_id: int) -> int:
	return _player_to_device.get(player_id, -1)


## Get the player ID assigned to a device
## Returns the player_id if assigned, -1 otherwise
func get_player_for_device(device_id: int) -> int:
	return _device_to_player.get(device_id, -1)


## Check if a device is assigned to any player
## Returns true if the device is assigned
func is_device_assigned(device_id: int) -> bool:
	return _device_to_player.has(device_id)


## Trigger vibration on a player's gamepad
## weak_magnitude and strong_magnitude should be in range [0.0, 1.0]
## duration is in seconds
func trigger_vibration(
	player_id: int, weak_magnitude: float, strong_magnitude: float, duration: float
) -> void:
	if not vibration_enabled:
		return

	var device_id: int = get_assigned_device(player_id)
	if device_id == -1:
		return

	Input.start_joy_vibration(device_id, weak_magnitude, strong_magnitude, duration)


## Get input vector for a player with deadzone applied
## Returns Vector2 with x and y in range [-1.0, 1.0]
func get_input_vector(
	player_id: int, negative_x: String, positive_x: String, negative_y: String, positive_y: String
) -> Vector2:
	var device_id: int = get_assigned_device(player_id)
	if device_id == -1:
		return Vector2.ZERO

	var vector: Vector2 = Input.get_vector(
		negative_x, positive_x, negative_y, positive_y, analog_deadzone
	)

	# Filter by device - check if any of the actions are pressed on this device
	var has_input: bool = false
	if Input.is_action_pressed(positive_x):
		for event in InputMap.action_get_events(positive_x):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				if Input.is_action_pressed(positive_x, device_id):
					has_input = true
					break

	if not has_input:
		# Check other directions
		for action in [negative_x, positive_y, negative_y]:
			if Input.is_action_pressed(action as String, device_id):
				has_input = true
				break

	return vector if has_input else Vector2.ZERO


## Check if an action is currently pressed for a player
func is_action_pressed(player_id: int, action: String) -> bool:
	var device_id: int = get_assigned_device(player_id)
	if device_id == -1:
		return false

	# Check if the action is pressed on the specific device
	return Input.is_action_pressed(action, device_id)


## Check if an action was just pressed for a player
func is_action_just_pressed(player_id: int, action: String) -> bool:
	var device_id: int = get_assigned_device(player_id)
	if device_id == -1:
		return false

	return Input.is_action_just_pressed(action, device_id)


## Check if an action was just released for a player
func is_action_just_released(player_id: int, action: String) -> bool:
	var device_id: int = get_assigned_device(player_id)
	if device_id == -1:
		return false

	return Input.is_action_just_released(action, device_id)


## Show the assignment UI for players to claim their slots
func show_assignment_ui() -> void:
	if _assignment_ui != null:
		return

	# Load and instantiate the assignment UI scene
	var assignment_ui_scene: PackedScene = load(
		"res://game/core/systems/splitscreen/ui/assignment_ui.tscn"
	)
	if assignment_ui_scene == null:
		push_error("Failed to load assignment UI scene")
		return

	_assignment_ui = assignment_ui_scene.instantiate()
	add_child(_assignment_ui)

	# Configure the UI
	if _assignment_ui.has_method("set_expected_player_count"):
		_assignment_ui.set_expected_player_count(_expected_player_count)

	if _assignment_ui.has_method("set_connected_devices"):
		_assignment_ui.set_connected_devices(_connected_devices)

	# Connect to assignment UI if it has the expected interface
	if _assignment_ui.has_signal("device_claimed"):
		var callback := Callable(self, "_on_device_claimed")
		if not _assignment_ui.is_connected("device_claimed", callback):
			_assignment_ui.connect("device_claimed", callback)


## Hide the assignment UI
func hide_assignment_ui() -> void:
	if _assignment_ui == null:
		return

	if _assignment_ui.has_signal("device_claimed"):
		var callback := Callable(self, "_on_device_claimed")
		if _assignment_ui.is_connected("device_claimed", callback):
			_assignment_ui.disconnect("device_claimed", callback)

	_assignment_ui.queue_free()
	_assignment_ui = null


## Handle device claim from assignment UI
func _on_device_claimed(player_slot: int, device_id: int) -> void:
	assign_gamepad(player_slot, device_id)


## Set the expected player count for assignment completion detection
func set_expected_player_count(count: int) -> void:
	_expected_player_count = count


## Check if all expected players have assigned devices
func is_assignment_complete() -> bool:
	if _expected_player_count == 0:
		return false
	return _player_to_device.size() >= _expected_player_count


## Get the number of connected devices
func get_connected_device_count() -> int:
	return _connected_devices.size()


## Get all connected device IDs
func get_connected_devices() -> Array[int]:
	return _connected_devices.duplicate()


## Get all assigned player IDs
func get_assigned_players() -> Array[int]:
	var players: Array[int] = []
	for player_id in _player_to_device.keys():
		players.append(player_id as int)
	return players


## Clear all assignments
func clear_assignments() -> void:
	_device_to_player.clear()
	_player_to_device.clear()
	_disconnected_devices.clear()


## Load configuration from settings
func load_configuration(config: Dictionary) -> void:
	vibration_enabled = config.get("vibration_enabled", true)
	analog_deadzone = config.get("analog_deadzone", 0.15)
	trigger_threshold = config.get("trigger_threshold", 0.1)


## Get rate limiter statistics
func get_rate_limiter_stats() -> Dictionary:
	var stats: Dictionary = {}
	for signal_name in _rate_limiters.keys():
		stats[signal_name] = _rate_limiters[signal_name].get_stats()
	return stats
