extends GutTest


func test_json_numeric_player_counts_are_valid() -> void:
	var manager := SplitscreenManager.new()
	var json_shaped_config := {
		"enabled": true,
		"min_players": 4.0,
		"max_players": 6.0,
		"default_player_count": 4.0,
	}

	assert_true(manager._validate_configuration(json_shaped_config))
	manager.free()


func test_fractional_player_counts_are_rejected() -> void:
	var manager := SplitscreenManager.new()
	var invalid_config := {
		"enabled": true,
		"min_players": 4.5,
		"max_players": 6.0,
		"default_player_count": 5.0,
	}

	assert_false(manager._validate_configuration(invalid_config))
	assert_push_error("Invalid min_players")
	manager.free()


func test_initialize_is_idempotent_and_normalizes_fields() -> void:
	var manager := SplitscreenManager.new()
	add_child_autofree(manager)
	await get_tree().process_frame

	var viewport_manager := manager.viewport_manager
	var gamepad_controller := manager.gamepad_controller
	var child_count := manager.get_child_count()
	manager.initialize()

	assert_eq(manager.min_players, 4)
	assert_eq(manager.max_players, 6)
	assert_eq(manager.default_player_count, 4)
	assert_same(manager.viewport_manager, viewport_manager)
	assert_same(manager.gamepad_controller, gamepad_controller)
	assert_eq(manager.get_child_count(), child_count)
