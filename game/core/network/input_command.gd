class_name InputCommand
extends RefCounted

const WIRE_SIZE: int = 30

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
	move_direction = Input.get_vector("left", "right", "up", "down")

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
	var buffer := PackedByteArray()
	buffer.resize(WIRE_SIZE)
	buffer.encode_u32(0, sequence_number)
	buffer.encode_float(4, timestamp_ms)
	buffer.encode_float(8, delta_time)
	buffer.encode_float(12, move_direction.x)
	buffer.encode_float(16, move_direction.y)
	buffer.encode_float(20, look_delta.x)
	buffer.encode_float(24, look_delta.y)
	buffer[28] = (
		int(jump)
		| (int(crouch) << 1)
		| (int(sprint) << 2)
		| (int(fire) << 3)
		| (int(aim) << 4)
		| (int(reload) << 5)
	)
	buffer[29] = weapon_switch + 1
	return buffer


static func from_bytes(buffer: PackedByteArray) -> InputCommand:
	if buffer.size() != WIRE_SIZE or buffer[28] > 63 or buffer[29] > 9:
		return null
	var cmd := InputCommand.new()
	cmd.sequence_number = buffer.decode_u32(0)
	cmd.timestamp_ms = buffer.decode_float(4)
	cmd.delta_time = buffer.decode_float(8)
	cmd.move_direction = Vector2(buffer.decode_float(12), buffer.decode_float(16))
	cmd.look_delta = Vector2(buffer.decode_float(20), buffer.decode_float(24))
	if (
		cmd.sequence_number == 0
		or not is_finite(cmd.timestamp_ms)
		or not is_finite(cmd.delta_time)
		or cmd.delta_time <= 0.0
		or cmd.delta_time > 0.25
		or not cmd.move_direction.is_finite()
		or cmd.move_direction.length_squared() > 1.001
		or not cmd.look_delta.is_finite()
	):
		return null
	var actions: int = buffer[28]
	cmd.jump = (actions & 1) != 0
	cmd.crouch = (actions & 2) != 0
	cmd.sprint = (actions & 4) != 0
	cmd.fire = (actions & 8) != 0
	cmd.aim = (actions & 16) != 0
	cmd.reload = (actions & 32) != 0
	cmd.weapon_switch = buffer[29] - 1
	return cmd


func get_debug_string() -> String:
	## Returns human-readable debug info
	return (
		"Input[%d] @ %.1fms: move=%s, jump=%s, fire=%s"
		% [sequence_number, timestamp_ms, move_direction, jump, fire]
	)
