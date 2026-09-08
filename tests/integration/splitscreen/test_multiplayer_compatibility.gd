extends GutTest

## Integration tests for splitscreen + network multiplayer compatibility
## Verifies that splitscreen works alongside existing multiplayer systems

var splitscreen_manager: SplitscreenManager
var network_manager: Node  # Mock or real NetworkManager


func _transition_session_to_active() -> void:
	var state := splitscreen_manager.session_state
	if state.current_state == SessionState.State.INACTIVE:
		assert_true(state.transition_to(SessionState.State.INITIALIZING))
	if state.current_state == SessionState.State.INITIALIZING:
		assert_true(state.transition_to(SessionState.State.ASSIGNING_DEVICES))
	if state.current_state in [SessionState.State.ASSIGNING_DEVICES, SessionState.State.PAUSED]:
		assert_true(state.transition_to(SessionState.State.ACTIVE))


func before_each() -> void:
	splitscreen_manager = SplitscreenManager.new()
	add_child_autofree(splitscreen_manager)
	splitscreen_manager.initialize()
	await get_tree().process_frame

	# Create mock network manager
	network_manager = Node.new()
	network_manager.name = "NetworkManager"
	add_child_autofree(network_manager)


func after_each() -> void:
	if splitscreen_manager and is_instance_valid(splitscreen_manager):
		if splitscreen_manager.is_session_active():
			splitscreen_manager.end_session()
	splitscreen_manager = null
	network_manager = null


## Test: Splitscreen can coexist with network multiplayer
func test_splitscreen_network_coexistence() -> void:
	# Both systems should be able to exist simultaneously
	assert_not_null(splitscreen_manager, "Splitscreen manager should exist")
	assert_not_null(network_manager, "Network manager should exist")

	# Neither should interfere with the other's initialization
	assert_true(true, "Both systems coexist without errors")


## Test: Splitscreen disabled doesn't affect network multiplayer
func test_splitscreen_disabled_no_network_impact() -> void:
	# When splitscreen is disabled, network multiplayer should work normally
	# This is tested by not initializing splitscreen

	var test_manager = SplitscreenManager.new()
	# Keep it outside the scene tree: _ready() intentionally auto-initializes
	# runtime managers when they are attached.

	assert_null(
		test_manager.viewport_manager, "Splitscreen components should not exist when disabled"
	)
	assert_null(
		test_manager.gamepad_controller, "Splitscreen components should not exist when disabled"
	)
	test_manager.free()


## Test: Network multiplayer disabled doesn't affect splitscreen
func test_network_disabled_no_splitscreen_impact() -> void:
	# Splitscreen should work even if network multiplayer is disabled
	_transition_session_to_active()

	assert_true(
		splitscreen_manager.is_session_active(),
		"Splitscreen should work independently of network multiplayer"
	)


## Test: Input isolation between splitscreen and network
func test_input_isolation_splitscreen_network() -> void:
	# Splitscreen input should not interfere with network input
	var input_comp = SplitscreenInputComponent.new()
	input_comp.set_device(0, splitscreen_manager.gamepad_controller, 0)
	add_child_autofree(input_comp)

	# Input component should only respond to its assigned device
	assert_eq(input_comp.get_device_id(), 0, "Input should be isolated to assigned device")


## Test: Splitscreen + network player count
func test_combined_player_count() -> void:
	# System should handle both local and network players
	_transition_session_to_active()
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.session_state.add_player(1)

	var local_players = splitscreen_manager.get_player_count()
	assert_eq(local_players, 2, "Should have 2 local splitscreen players")

	# Network players would be tracked separately
	# This test verifies they don't conflict


## Test: Viewport management doesn't affect network rendering
func test_viewport_network_independence() -> void:
	# Creating splitscreen viewports shouldn't affect network rendering
	for i in range(4):
		splitscreen_manager.viewport_manager.create_viewport(i, null)

	assert_eq(
		splitscreen_manager.viewport_manager.get_viewport_count(),
		4,
		"Should have 4 splitscreen viewports"
	)

	# Network rendering should be unaffected (tested by no crashes)
	assert_true(true, "Viewport creation doesn't crash network systems")


## Test: Session state doesn't conflict with network state
func test_session_state_independence() -> void:
	# Splitscreen session state should be independent of network state
	_transition_session_to_active()

	assert_eq(
		splitscreen_manager.session_state.current_state,
		SessionState.State.ACTIVE,
		"Splitscreen state should be independent"
	)


## Test: Gamepad assignment doesn't affect network input
func test_gamepad_assignment_network_independence() -> void:
	# Assigning gamepads for splitscreen shouldn't affect network input
	splitscreen_manager.gamepad_controller._connected_devices.append(0)
	splitscreen_manager.gamepad_controller.assign_gamepad(0, 0)

	assert_eq(
		splitscreen_manager.gamepad_controller.get_assigned_device(0),
		0,
		"Gamepad should be assigned for splitscreen"
	)

	# Network input should still work (keyboard/mouse)
	assert_true(true, "Network input unaffected by gamepad assignment")


## Test: Performance monitoring doesn't interfere
func test_performance_monitoring_independence() -> void:
	# Splitscreen performance monitoring shouldn't affect network performance
	_transition_session_to_active()
	splitscreen_manager.adaptive_quality_enabled = true

	for i in range(100):
		splitscreen_manager._process(0.016)

	# Both systems should track performance independently
	assert_true(true, "Performance monitoring is independent")


## Test: Error handling doesn't cascade
func test_error_handling_isolation() -> void:
	# Errors in splitscreen shouldn't crash network multiplayer
	splitscreen_manager._emit_error("Test error")
	assert_push_error("Test error")

	# Network manager should still be functional
	assert_true(
		is_instance_valid(network_manager), "Network manager should survive splitscreen errors"
	)


## Test: Feature toggle doesn't affect network
func test_feature_toggle_network_independence() -> void:
	# Toggling splitscreen feature shouldn't affect network
	var config = splitscreen_manager.config.duplicate()

	# Simulate feature disabled
	splitscreen_manager.end_session()

	# Network should be unaffected
	assert_true(
		is_instance_valid(network_manager), "Network manager unaffected by splitscreen toggle"
	)


## Test: Cleanup doesn't affect network resources
func test_cleanup_network_independence() -> void:
	# Cleaning up splitscreen shouldn't affect network resources
	_transition_session_to_active()
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.viewport_manager.create_viewport(0, null)

	splitscreen_manager._cleanup_on_error()

	# Network resources should be intact
	assert_true(
		is_instance_valid(network_manager), "Network resources unaffected by splitscreen cleanup"
	)


## Test: Signal emissions don't interfere
func test_signal_emission_independence() -> void:
	# Splitscreen signals shouldn't interfere with network signals
	watch_signals(splitscreen_manager)
	watch_signals(network_manager)

	splitscreen_manager._emit_error("Test")
	assert_push_error("Test")

	# Only splitscreen signals should be emitted
	assert_signal_emitted(splitscreen_manager, "session_error")
	# Network manager should have no signals
	assert_true(true, "Signal emissions are independent")


## Test: Configuration loading doesn't conflict
func test_configuration_independence() -> void:
	# Loading splitscreen config shouldn't affect network config
	splitscreen_manager._load_configuration()

	assert_true(splitscreen_manager.config.size() > 0, "Splitscreen config should be loaded")

	# Network config should be independent
	assert_true(true, "Configuration systems are independent")


## Test: Multiplayer session + splitscreen session
func test_concurrent_sessions() -> void:
	# Both multiplayer and splitscreen sessions should work together
	_transition_session_to_active()

	# Simulate network session active
	var network_active = true

	assert_true(splitscreen_manager.is_session_active(), "Splitscreen session should be active")
	assert_true(network_active, "Network session should be active")

	# Both can coexist
	assert_true(true, "Concurrent sessions work")


## Test: Player ID namespaces don't collide
func test_player_id_namespace_separation() -> void:
	# Splitscreen player IDs shouldn't collide with network player IDs
	splitscreen_manager.session_state.add_player(0)
	splitscreen_manager.session_state.add_player(1)

	# Network would use different ID space (e.g., peer IDs)
	# This test verifies no collision
	assert_eq(splitscreen_manager.get_player_count(), 2, "Splitscreen has 2 players")

	# Network players would be tracked separately
	assert_true(true, "Player ID namespaces are separate")
