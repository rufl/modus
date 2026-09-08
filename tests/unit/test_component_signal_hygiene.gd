extends ModusGutTestBase

## Test suite for verifying signal hygiene in converted components


func test_health_component_extends_game_component() -> void:
	var health_comp := HealthComponent.new()
	add_child_autofree(health_comp)

	# Verify it extends GameComponent
	assert_true(
		health_comp.has_method("safe_connect"), "HealthComponent should have safe_connect method"
	)
	assert_true(
		health_comp.has_method("get_tracked_connection_count"),
		"HealthComponent should have tracking method"
	)


func test_downed_state_signal_cleanup() -> void:
	var downed_state := DownedStateHandler.new()
	add_child_autofree(downed_state)

	# Mock GameCore config service
	var mock_config := Node.new()
	mock_config.name = "MockConfig"

	# Add a signal to mock config
	if not mock_config.has_signal("config_reloaded"):
		mock_config.add_user_signal("config_reloaded")

	add_child_autofree(mock_config)
	var config_reloaded := Signal(mock_config, "config_reloaded")

	# Simulate the component connecting to config
	var callback := func() -> void: pass

	var initial_connections := downed_state.get_tracked_connection_count()
	downed_state.safe_connect(config_reloaded, callback)

	# Verify connection exists
	assert_true(config_reloaded.is_connected(callback), "Config signal should be connected")
	assert_eq(
		downed_state.get_tracked_connection_count(),
		initial_connections + 1,
		"Should track the added connection"
	)

	# Remove component (triggers cleanup)
	remove_child(downed_state)
	await get_tree().process_frame

	# Verify cleanup happened
	assert_false(config_reloaded.is_connected(callback), "Config signal should be disconnected")


func test_status_effect_manager_signal_cleanup() -> void:
	var status_mgr := StatusEffectManager.new()
	add_child_autofree(status_mgr)

	# Verify it extends GameComponent
	assert_true(
		status_mgr.has_method("safe_connect"), "StatusEffectManager should have safe_connect method"
	)
	assert_true(
		status_mgr.has_method("get_tracked_connection_count"),
		"StatusEffectManager should have tracking method"
	)

	# Test that effect_removed signal connections are tracked
	var callback := func(_effect_name: String) -> void: pass

	status_mgr.safe_connect(status_mgr.effect_removed, callback)

	assert_eq(status_mgr.get_tracked_connection_count(), 1, "Should track 1 connection")

	# Remove component
	remove_child(status_mgr)
	await get_tree().process_frame

	# Verify cleanup
	assert_false(status_mgr.effect_removed.is_connected(callback), "Signal should be disconnected")


func test_weapon_feedback_system_extends_game_component_3d() -> void:
	var weapon_feedback := WeaponFeedbackSystem.new()
	add_child_autofree(weapon_feedback)

	# Verify it extends GameComponent3D (which has the same methods)
	assert_true(
		weapon_feedback.has_method("safe_connect"),
		"WeaponFeedbackSystem should have safe_connect method"
	)
	assert_true(
		weapon_feedback.has_method("get_tracked_connection_count"),
		"WeaponFeedbackSystem should have tracking method"
	)


func test_component_removal_prevents_memory_leaks() -> void:
	# Create multiple components and verify they all clean up properly
	var components: Array[Node] = []

	components.append(HealthComponent.new())
	components.append(DownedStateHandler.new())
	components.append(StatusEffectManager.new())

	for comp in components:
		add_child_autofree(comp)

	# Create a mock signal source
	var signal_source := Node.new()
	signal_source.add_user_signal("test_signal")
	add_child_autofree(signal_source)
	var test_signal := Signal(signal_source, "test_signal")

	# Connect all components to the signal
	for comp in components:
		var callback := func() -> void: pass
		comp.safe_connect(test_signal, callback)

	# Verify all connections exist
	var connection_count: int = test_signal.get_connections().size()
	assert_eq(connection_count, 3, "Should have 3 connections")

	# Remove all components
	for comp in components:
		remove_child(comp)

	await get_tree().process_frame

	# Verify all connections are cleaned up
	connection_count = test_signal.get_connections().size()
	assert_eq(connection_count, 0, "All connections should be cleaned up")
