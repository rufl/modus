class_name InputCommand
extends RefCounted

var sequence_number: int = 0
var timestamp_ms: float = 0.0
var delta_time: float = 0.0
var move_direction: Vector2 = Vector2.ZERO  # Normalized WASD input
var look_delta: Vector2 = Vector2.ZERO  # Mouse movement this frame
var jump: bool = false
var crouch: bool = false
var sprint: bool = false
var fire: bool = false
var aim: bool = false
var reload: bool = false
var weapon_switch: int = -1  # -1 = no switch, else weapon index


static func create(seq: int, delta: float) -> InputCommand:
	## Factory method for creating new input commands
	var cmd := InputCommand.new()
	cmd.sequence_number = seq
	cmd.timestamp_ms = Time.get_ticks_msec()
	cmd.delta_time = delta
	return cmd


func capture_input() -> void:
	## Capture current input state from Input singleton
	# Movement (WASD)
	move_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")

	# Actions
	jump = Input.is_action_just_pressed("jump")
	crouch = Input.is_action_pressed("crouch")
	sprint = Input.is_action_pressed("sprint")
	fire = Input.is_action_pressed("shoot")
	aim = Input.is_action_pressed("aim") if InputMap.has_action("aim") else false
	reload = Input.is_action_just_pressed("reload")

	# Weapon switching (1-9 keys)
	for i in range(1, 10):
		var action := "weapon_" + str(i)
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			weapon_switch = i - 1
			break


func to_bytes() -> PackedByteArray:
	## Serialize to bytes for network transmission
	## Actions use bit-packing (8 booleans in 1 byte)
	## OPTIMIZATION NOTE: Vector2 could use half-precision floats to reduce size
	var buffer := PackedByteArray()

	# Header: sequence (uint32) + timestamp (float32) + delta (float32)
	buffer.append_array(var_to_bytes(sequence_number))
	buffer.append_array(var_to_bytes(timestamp_ms))
	buffer.append_array(var_to_bytes(delta_time))

	# Movement: move_direction (Vector2) + look_delta (Vector2)
	buffer.append_array(var_to_bytes(move_direction))
	buffer.append_array(var_to_bytes(look_delta))

	# Actions: Pack into single byte (8 booleans)
	var action_byte: int = 0
	if jump:
		action_byte |= 1
	if crouch:
		action_byte |= 2
	if sprint:
		action_byte |= 4
	if fire:
		action_byte |= 8
	if aim:
		action_byte |= 16
	if reload:
		action_byte |= 32
	buffer.append(action_byte)

	# Weapon switch: int8 (-1 to 8)
	buffer.append(weapon_switch + 1)  # Store as 0-9

	return buffer


static func from_bytes(buffer: PackedByteArray) -> InputCommand:
	## Deserialize from bytes
	var cmd := InputCommand.new()
	var offset := 0

	# Read header
	cmd.sequence_number = bytes_to_var(buffer.slice(offset, offset + 4))
	offset += 4
	cmd.timestamp_ms = bytes_to_var(buffer.slice(offset, offset + 4))
	offset += 4
	cmd.delta_time = bytes_to_var(buffer.slice(offset, offset + 4))
	offset += 4

	# Read movement
	cmd.move_direction = bytes_to_var(buffer.slice(offset, offset + 8))
	offset += 8
	cmd.look_delta = bytes_to_var(buffer.slice(offset, offset + 8))
	offset += 8

	# Read actions
	var action_byte: int = buffer[offset]
	offset += 1
	cmd.jump = (action_byte & 1) != 0
	cmd.crouch = (action_byte & 2) != 0
	cmd.sprint = (action_byte & 4) != 0
	cmd.fire = (action_byte & 8) != 0
	cmd.aim = (action_byte & 16) != 0
	cmd.reload = (action_byte & 32) != 0

	# Read weapon switch
	cmd.weapon_switch = buffer[offset] - 1

	return cmd


func get_debug_string() -> String:
	## Returns human-readable debug info
	return (
		"Input[%d] @ %.1fms: move=%s, jump=%s, fire=%s"
		% [sequence_number, timestamp_ms, move_direction, jump, fire]
	)
