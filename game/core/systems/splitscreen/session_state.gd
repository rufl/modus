class_name SessionState
extends RefCounted

## SessionState manages the state and data for a splitscreen multiplayer session.
##
## This class maintains the current session state, player data, gamepad assignments,
## and performance metrics for a local splitscreen multiplayer session.
## It provides methods for state transitions and validation to ensure valid state changes.

## State enum representing the lifecycle of a splitscreen session
# No session is active, being set up, assigning devices, running, paused, or ending
enum State { INACTIVE, INITIALIZING, ASSIGNING_DEVICES, ACTIVE, PAUSED, ENDING }


## Inner class containing data for a single player in the session
class PlayerData:
	var player_id: int = -1
	var player_instance: Node = null
	var viewport: SubViewport = null
	var gamepad_device: int = -1
	var connected: bool = false

	func _init(
		p_player_id: int = -1,
		p_player_instance: Node = null,
		p_viewport: SubViewport = null,
		p_gamepad_device: int = -1,
		p_connected: bool = false
	) -> void:
		player_id = p_player_id
		player_instance = p_player_instance
		viewport = p_viewport
		gamepad_device = p_gamepad_device
		connected = p_connected

	func duplicate() -> PlayerData:
		var copy: PlayerData = PlayerData.new()
		copy.player_id = player_id
		copy.player_instance = player_instance
		copy.viewport = viewport
		copy.gamepad_device = gamepad_device
		copy.connected = connected
		return copy


## Current state of the session
var current_state: SessionState.State = SessionState.State.INACTIVE

## Number of players in the session
var player_count: int = 0

## Dictionary mapping player_id (int) to PlayerData
var active_players: Dictionary = {}

## Dictionary mapping player_id (int) to gamepad device_id (int)
var gamepad_assignments: Dictionary = {}

## Timestamp when the session started (Unix time in milliseconds)
var session_start_time: int = 0

## Total time the session has been active (in seconds)
var total_session_time: float = 0.0

## Dictionary containing performance metrics (fps, frame_time, etc.)
var performance_metrics: Dictionary = {}


## Initialize a new session state
func _init() -> void:
	reset()


## Reset the session state to initial values
func reset() -> void:
	current_state = State.INACTIVE
	player_count = 0
	active_players.clear()
	gamepad_assignments.clear()
	session_start_time = 0
	total_session_time = 0.0
	performance_metrics.clear()


## Transition to a new state with validation
## Returns true if the transition is valid and successful, false otherwise
func transition_to(new_state: SessionState.State) -> bool:
	if not is_valid_transition(current_state, new_state):
		push_error(
			(
				"Invalid state transition from %s to %s"
				% [SessionState.State.keys()[current_state], SessionState.State.keys()[new_state]]
			)
		)
		return false

	current_state = new_state
	return true


## Check if a state transition is valid
## Returns true if the transition from old_state to new_state is allowed
func is_valid_transition(old_state: SessionState.State, new_state: SessionState.State) -> bool:
	# Define valid state transitions
	match old_state:
		State.INACTIVE:
			return new_state == State.INITIALIZING

		State.INITIALIZING:
			return new_state in [State.ASSIGNING_DEVICES, State.INACTIVE]

		State.ASSIGNING_DEVICES:
			return new_state in [State.ACTIVE, State.INACTIVE]

		State.ACTIVE:
			return new_state in [State.PAUSED, State.ENDING]

		State.PAUSED:
			return new_state in [State.ACTIVE, State.ENDING]

		State.ENDING:
			return new_state == State.INACTIVE

	return false


## Add a player to the session
## Returns true if the player was added successfully
func add_player(
	player_id: int,
	player_instance: Node = null,
	viewport: SubViewport = null,
	gamepad_device: int = -1
) -> bool:
	if active_players.has(player_id):
		push_error("Player %d already exists in session" % player_id)
		return false

	var player_data = PlayerData.new(
		player_id, player_instance, viewport, gamepad_device, gamepad_device != -1
	)
	active_players[player_id] = player_data
	player_count = active_players.size()

	if gamepad_device != -1:
		gamepad_assignments[player_id] = gamepad_device

	return true


## Remove a player from the session
## Returns true if the player was removed successfully
func remove_player(player_id: int) -> bool:
	if not active_players.has(player_id):
		push_error("Player %d does not exist in session" % player_id)
		return false

	active_players.erase(player_id)
	gamepad_assignments.erase(player_id)
	player_count = active_players.size()

	return true


## Get player data for a specific player
## Returns PlayerData if found, null otherwise
func get_player_data(player_id: int) -> PlayerData:
	return active_players.get(player_id, null)


## Update player data for a specific player
## Returns true if the update was successful
func update_player_data(
	player_id: int,
	player_instance: Node = null,
	viewport: SubViewport = null,
	gamepad_device: int = -1,
	p_connected: bool = true
) -> bool:
	if not active_players.has(player_id):
		push_error("Player %d does not exist in session" % player_id)
		return false

	var player_data: PlayerData = active_players[player_id]

	if player_instance != null:
		player_data.player_instance = player_instance
	if viewport != null:
		player_data.viewport = viewport
	if gamepad_device != -1:
		player_data.gamepad_device = gamepad_device
		gamepad_assignments[player_id] = gamepad_device

	player_data.connected = p_connected

	return true


## Assign a gamepad device to a player
## Returns true if the assignment was successful
func assign_gamepad(player_id: int, device_id: int) -> bool:
	if not active_players.has(player_id):
		push_error("Player %d does not exist in session" % player_id)
		return false

	# Check if device is already assigned to another player
	for pid in gamepad_assignments:
		if gamepad_assignments[pid] == device_id and pid != player_id:
			push_error("Gamepad device %d is already assigned to player %d" % [device_id, pid])
			return false

	gamepad_assignments[player_id] = device_id
	var player_data: PlayerData = active_players[player_id]
	player_data.gamepad_device = device_id
	player_data.connected = true

	return true


## Unassign a gamepad device from a player
## Returns true if the unassignment was successful
func unassign_gamepad(player_id: int) -> bool:
	if not active_players.has(player_id):
		push_error("Player %d does not exist in session" % player_id)
		return false

	gamepad_assignments.erase(player_id)
	var player_data: PlayerData = active_players[player_id]
	player_data.gamepad_device = -1
	player_data.connected = false

	return true


## Get the gamepad device assigned to a player
## Returns the device_id if assigned, -1 otherwise
func get_assigned_gamepad(player_id: int) -> int:
	return gamepad_assignments.get(player_id, -1)


## Get the player assigned to a gamepad device
## Returns the player_id if found, -1 otherwise
func get_player_for_gamepad(device_id: int) -> int:
	for player_id in gamepad_assignments:
		if gamepad_assignments[player_id] == device_id:
			return player_id
	return -1


## Check if all players have assigned gamepads
## Returns true if all players have gamepad assignments
func all_gamepads_assigned() -> bool:
	if player_count == 0:
		return false

	return gamepad_assignments.size() == player_count


## Start the session timer
func start_timer() -> void:
	session_start_time = Time.get_ticks_msec()
	total_session_time = 0.0


## Update the session timer
## Call this regularly (e.g., in _process) to track session time
func update_timer(delta: float) -> void:
	if current_state == State.ACTIVE:
		total_session_time += delta


## Get the current session duration in seconds
func get_session_duration() -> float:
	if session_start_time == 0:
		return 0.0

	return total_session_time


## Update performance metrics
func update_performance_metrics(fps: float, frame_time: float, memory_usage: int = 0) -> void:
	performance_metrics["fps"] = fps
	performance_metrics["frame_time"] = frame_time
	performance_metrics["memory_usage"] = memory_usage
	performance_metrics["last_update"] = Time.get_ticks_msec()


## Get a performance metric value
func get_performance_metric(metric_name: String) -> Variant:
	return performance_metrics.get(metric_name, null)


## Check if the session is in a valid state
## Returns true if the session state is consistent
func validate() -> bool:
	# Check player count matches active players
	if player_count != active_players.size():
		push_error("Player count mismatch: %d != %d" % [player_count, active_players.size()])
		return false

	# Check gamepad assignments are valid
	for player_id in gamepad_assignments:
		if not active_players.has(player_id):
			push_error("Gamepad assigned to non-existent player %d" % player_id)
			return false

	# Check for duplicate gamepad assignments
	var assigned_devices: Array[int] = []
	for device_id in gamepad_assignments.values():
		if device_id in assigned_devices:
			push_error("Duplicate gamepad assignment: device %d" % device_id)
			return false
		assigned_devices.append(device_id)

	return true


## Get a string representation of the current state
func get_state_string() -> String:
	return SessionState.State.keys()[current_state]


## Get a dictionary representation of the session state (for debugging/serialization)
func to_dict() -> Dictionary:
	var players_dict: Dictionary = {}
	for player_id in active_players:
		var pd: PlayerData = active_players[player_id]
		players_dict[player_id] = {
			"player_id": pd.player_id,
			"gamepad_device": pd.gamepad_device,
			"connected": pd.connected,
			"has_instance": pd.player_instance != null,
			"has_viewport": pd.viewport != null
		}

	return {
		"current_state": get_state_string(),
		"player_count": player_count,
		"active_players": players_dict,
		"gamepad_assignments": gamepad_assignments,
		"session_start_time": session_start_time,
		"total_session_time": total_session_time,
		"performance_metrics": performance_metrics
	}
