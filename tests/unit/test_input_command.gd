extends GutTest


func test_commands_round_trip_the_wire_without_variant_header_corruption() -> void:
	var command := InputCommand.create(257, 1.0 / 60.0)
	command.timestamp_ms = 1250.0
	command.move_direction = Vector2(0.6, -0.8)
	command.look_delta = Vector2(-12.5, 3.25)
	command.jump = true
	command.sprint = true
	command.reload = true
	command.weapon_switch = 8
	var decoded := InputCommand.from_bytes(command.to_bytes())
	assert_not_null(decoded)
	if not decoded:
		return
	assert_eq(decoded.sequence_number, 257)
	assert_almost_eq(decoded.delta_time, 1.0 / 60.0, 0.000001)
	assert_true(decoded.move_direction.is_equal_approx(Vector2(0.6, -0.8)))
	assert_eq(decoded.look_delta, Vector2(-12.5, 3.25))
	assert_true(decoded.jump and decoded.sprint and decoded.reload)
	assert_false(decoded.crouch or decoded.fire or decoded.aim)
	assert_eq(decoded.weapon_switch, 8)


func test_malformed_and_nonfinite_commands_cannot_enter_simulation() -> void:
	var command := InputCommand.create(1, 1.0 / 60.0)
	var packet := command.to_bytes()
	assert_null(InputCommand.from_bytes(packet.slice(0, packet.size() - 1)))
	packet.append(0)
	assert_null(InputCommand.from_bytes(packet))
	command.delta_time = NAN
	assert_null(InputCommand.from_bytes(command.to_bytes()))
	command.delta_time = -0.1
	assert_null(InputCommand.from_bytes(command.to_bytes()))
	command.delta_time = 1.0 / 60.0
	command.move_direction = Vector2(2, 0)
	assert_null(InputCommand.from_bytes(command.to_bytes()))
	command.move_direction = Vector2.ZERO
	command.look_delta = Vector2(INF, 0)
	assert_null(InputCommand.from_bytes(command.to_bytes()))


func test_capture_uses_the_players_configured_movement_actions() -> void:
	Input.action_press("right")
	Input.action_press("up")
	var command := InputCommand.create(1, 1.0 / 60.0)
	command.capture_input()
	Input.action_release("right")
	Input.action_release("up")
	assert_true(command.move_direction.is_equal_approx(Vector2(1, -1).normalized()))
