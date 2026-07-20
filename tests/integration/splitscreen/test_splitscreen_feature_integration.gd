extends ModusGutTestBase

## Integration tests for SplitscreenManager with GameManager
## Tests feature loading, unloading, and toggle configuration

var splitscreen_manager: SplitscreenManager


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


func after_each() -> void:
	if splitscreen_manager and is_instance_valid(splitscreen_manager):
		if splitscreen_manager.is_session_active():
			splitscreen_manager.end_session()
	splitscreen_manager = null


## Test: Feature can be initialized
func test_feature_initialization() -> void:
	splitscreen_manager.initialize()
	
	assert_not_null(splitscreen_manager.viewport_manager,
		"ViewportManager should be created")
	assert_not_null(splitscreen_manager.gamepad_controller,
		"GamepadController should be created")
	assert_not_null(splitscreen_manager.session_state,
		"SessionState should be created")


## Test: Feature loading creates SplitscreenManager
func test_feature_loading() -> void:
	# This test simulates GameManager loading the feature
	splitscreen_manager.initialize()
	
	assert_true(is_instance_valid(splitscreen_manager),
		"SplitscreenManager should be valid after loading")


## Test: Feature unloading cleans up resources
func test_feature_unloading() -> void:
	splitscreen_manager.initialize()
	_transition_session_to_active()
	
	# Simulate unloading
	splitscreen_manager.end_session()
	
	assert_false(splitscreen_manager.is_session_active(),
		"Session should not be active after unloading")


## Test: Feature toggle configuration is respected
func test_feature_toggle_configuration() -> void:
	# Test that configuration is loaded
	splitscreen_manager.initialize()
	
	assert_ge(splitscreen_manager.min_players, 4,
		"Min players should be configured")
	assert_le(splitscreen_manager.max_players, 6,
		"Max players should be configured")


## Test: Feature isolation when disabled
func test_feature_isolation_when_disabled() -> void:
	splitscreen_manager.set_hot_reload_supported(false)
	assert_true(splitscreen_manager.disable_feature())
	
	assert_null(splitscreen_manager.viewport_manager,
		"ViewportManager should not exist when disabled")
	assert_null(splitscreen_manager.gamepad_controller,
		"GamepadController should not exist when disabled")


## Test: Multiple feature load/unload cycles
func test_multiple_load_unload_cycles() -> void:
	for i in range(3):
		splitscreen_manager.initialize()
		assert_not_null(splitscreen_manager.session_state,
			"Should initialize on cycle %d" % i)
		
		splitscreen_manager._cleanup_components()


## Test: Configuration loading from file
func test_configuration_loading_from_file() -> void:
	splitscreen_manager.initialize()
	
	# Configuration should be loaded
	assert_true(splitscreen_manager.config.size() > 0,
		"Configuration should be loaded")


## Test: Default configuration when file missing
func test_default_configuration_when_file_missing() -> void:
	# Even if file is missing, should use defaults
	splitscreen_manager._use_default_configuration()
	
	assert_eq(splitscreen_manager.min_players, 4,
		"Should use default min_players")
	assert_eq(splitscreen_manager.max_players, 6,
		"Should use default max_players")


## Test: Feature dependencies are met
func test_feature_dependencies() -> void:
	splitscreen_manager.initialize()
	
	# Verify all required components exist
	assert_not_null(splitscreen_manager.viewport_manager,
		"ViewportManager dependency should be met")
	assert_not_null(splitscreen_manager.gamepad_controller,
		"GamepadController dependency should be met")


## Test: Feature can be reinitialized
func test_feature_reinitialization() -> void:
	splitscreen_manager.initialize()
	var first_viewport_manager: ViewportManager = splitscreen_manager.viewport_manager
	
	# Cleanup through the manager so its initialization state remains coherent.
	splitscreen_manager._cleanup_components()
	
	# Reinitialize
	splitscreen_manager.initialize()
	
	assert_not_null(splitscreen_manager.viewport_manager,
		"Should create new ViewportManager")
	assert_ne(splitscreen_manager.viewport_manager, first_viewport_manager,
		"Should be a new instance")
