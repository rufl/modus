class_name PlayerMovementPredictor
extends Node

const InputCommandScript = preload("res://game/core/network/input_command.gd")

var pending_inputs: Array[RefCounted] = []  # Array of InputCommand
var last_server_ack: int = 0
var next_sequence: int = 1
var player: CharacterBody3D = null
var net_config: Resource = null


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("[Predictor] Must be child of CharacterBody3D (Player)")
		return

	# Get network config
	var ns: Node = GameManager.get_core_system("network")
	net_config = ns.network_manager.config if ns and ns.network_manager else null

	# Only run on clients (not server or single-player)
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		set_process(false)
		return

	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.debug(
			"Client-side prediction enabled for player %d" % [multiplayer.get_unique_id()],
			"Predictor"
		)


func _process(delta: float) -> void:
	# Only predict on client
	if not net_config or not net_config.enable_client_prediction:
		return

	# Capture and predict input
	_capture_and_predict_input(delta)

	# Cleanup old acknowledged inputs
	_cleanup_acknowledged_inputs()


func _capture_and_predict_input(delta: float) -> void:
	## Step 1: Create input command
	var input_cmd: RefCounted = InputCommandScript.create(next_sequence, delta)
	next_sequence += 1

	# Capture current input state
	input_cmd.capture_input()

	# Capture look delta from Player (Direct Input)
	if player.has_method("get_command_look_delta"):
		input_cmd.look_delta = player.get_command_look_delta()

	# Store for reconciliation
	pending_inputs.append(input_cmd)

	## Step 2: Apply movement locally (PREDICTION)
	apply_movement(input_cmd)

	## Step 3: Send to server
	_send_input_to_server.rpc_id(1, input_cmd.to_bytes())

	# Log for debugging (disable in production)
	if OS.is_debug_build() and false:
		GameManager.get_core_system("logger").info(
			"[Predictor] Predicted: %s" % input_cmd.get_debug_string(), "Core"
		)


@rpc("any_peer", "unreliable", "call_remote")
func _send_input_to_server(input_bytes: PackedByteArray) -> void:
	## Server receives and processes client input
	if not multiplayer.is_server():
		return  # Only server processes

	var sender_id := multiplayer.get_remote_sender_id()
	var input_cmd: RefCounted = InputCommandScript.from_bytes(input_bytes)

	# Validate input (anti-cheat)
	var ns: Node = GameManager.get_core_system("network")
	if ns and ns.network_manager:
		if not ns.network_manager.validate_rpc(sender_id, "sync_position", []):
			return

	var gs: Node = GameManager.get_core_system("gameplay")
	var sender_player: Node = null
	if gs and gs.entity_registry:
		sender_player = gs.entity_registry.get_player(sender_id)
	if not sender_player or not sender_player is CharacterBody3D:
		return

	# Apply movement on server (authoritative)
	var predictor: Node = sender_player.get_node_or_null("PlayerMovementPredictor")
	if predictor:
		predictor.apply_movement(input_cmd)

	# Send back authoritative state with ack
	_send_state_update.rpc_id(
		sender_id,
		input_cmd.sequence_number,
		sender_player.global_position,
		sender_player.velocity,
		sender_player.rotation.y
	)


@rpc("authority", "unreliable", "call_remote")
func _send_state_update(
	ack_sequence: int, position: Vector3, velocity: Vector3, rotation_y: float
) -> void:
	## Client receives authoritative state from server
	if multiplayer.is_server():
		return  # Only clients receive

	# Update last acknowledged sequence
	last_server_ack = ack_sequence

	# Calculate prediction error
	var prediction_error := player.global_position.distance_to(position)

	# Check if misprediction occurred
	if prediction_error > net_config.prediction_error_threshold:
		# MISPREDICTION! Rewind and replay
		if OS.is_debug_build():
			GameManager.get_core_system("logger").info(
				"[Predictor] Misprediction! Error: %.3fm, rewinding..." % [prediction_error], "Core"
			)

		# Restore server state
		player.global_position = position
		player.velocity = velocity
		player.rotation.y = rotation_y

		# Replay all inputs after the acknowledged one
		for input_cmd: RefCounted in pending_inputs:
			if input_cmd.sequence_number > ack_sequence:
				apply_movement(input_cmd)

	# Optional: Log for debugging
	if OS.is_debug_build() and false:
		GameManager.get_core_system("logger").info(
			"[Predictor] Server ack %d, error: %.3fm" % [ack_sequence, prediction_error], "Core"
		)


func apply_movement(input: RefCounted) -> void:
	## Apply movement from input command (identical on client and server)
	## CRITICAL: This MUST be deterministic!

	if not player:
		return

	# Get movement component if it exists
	var movement_comp: Node = player.get_node_or_null("MovementComponent")

	if movement_comp and movement_comp.has_method("process_input"):
		# Use existing movement component
		movement_comp.process_input(input, input.delta_time)
	else:
		# Fallback: Simple movement implementation
		_simple_movement(input)


func _simple_movement(input: RefCounted) -> void:
	## Simple movement fallback (if no MovementComponent)
	var delta: float = input.delta_time

	# Get speed
	var speed := 5.0  # Default
	if "move_speed" in player:
		speed = player.move_speed

	if input.sprint and "sprint_multiplier" in player:
		speed *= player.sprint_multiplier

	# Calculate movement direction
	var move_dir := Vector3(input.move_direction.x, 0.0, input.move_direction.y)

	# Transform to player's facing direction
	move_dir = move_dir.rotated(Vector3.UP, player.rotation.y)

	# Apply velocity
	player.velocity.x = move_dir.x * speed
	player.velocity.z = move_dir.z * speed

	# Gravity
	if not player.is_on_floor():
		player.velocity.y -= 9.8 * delta

	# Jump
	if input.jump and player.is_on_floor():
		player.velocity.y = 5.0  # Jump strength

	# Move
	player.move_and_slide()


func _cleanup_acknowledged_inputs() -> void:
	## Remove inputs that have been acknowledged by server
	if pending_inputs.is_empty():
		return

	# Remove all inputs up to and including last_server_ack
	pending_inputs = pending_inputs.filter(
		func(i: RefCounted) -> bool: return i.sequence_number > last_server_ack
	)

	# Cap buffer size to prevent memory leak
	var max_inputs: int = net_config.max_pending_inputs if net_config else 30
	if pending_inputs.size() > max_inputs:
		# Keep only the most recent inputs
		pending_inputs = pending_inputs.slice(pending_inputs.size() - max_inputs)
		push_warning("[Predictor] Input buffer overflow, trimming to %d" % [max_inputs])


func get_diagnostics() -> Dictionary:
	## Returns diagnostic info for debugging
	return {
		"pending_inputs": pending_inputs.size(),
		"last_ack": last_server_ack,
		"next_sequence": next_sequence,
		"prediction_enabled": net_config.enable_client_prediction if net_config else false
	}
