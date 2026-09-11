class_name SplitscreenManager
extends Node

## SplitscreenManager orchestrates the local splitscreen multiplayer feature.
##
## This is the central component that coordinates ViewportManager and GamepadController,
## manages session lifecycle, synchronizes game state, handles errors, and monitors performance.
## It provides the main API for starting, pausing, and ending splitscreen sessions.

## Signals

## Emitted when a splitscreen session starts
signal session_started(player_count: int)

## Emitted when a splitscreen session ends
signal session_ended

## Emitted when a player joins the session
signal player_joined(player_id: int, gamepad_device: int)

## Emitted when a player leaves the session
signal player_left(player_id: int)

## Emitted when a session error occurs
signal session_error(error_message: String)

## Component references
var viewport_manager: ViewportManager = null
var gamepad_controller: GamepadController = null
var session_state: SessionState = null
var performance_profiler: Node = null  # PerformanceProfiler

## Configuration
var config: Dictionary = {}
var min_players: int = 4
var max_players: int = 6
var default_player_count: int = 4
var session_timeout_seconds: int = 300
var auto_pause_on_disconnect: bool = true
var target_fps: float = 60.0
var fps_variance_threshold: float = 0.1
var adaptive_quality_enabled: bool = true
var quality_adjustment_interval: float = 5.0

## Performance monitoring
var _fps_samples: Array[float] = []
var _last_quality_adjustment_time: float = 0.0
var _current_quality_level: String = "high"

## Error recovery
var _error_recovery_enabled: bool = true
var _max_retry_attempts: int = 3
var _retry_delay_seconds: float = 1.0
var _circuit_breaker_threshold: int = 5
var _circuit_breaker_reset_time: float = 30.0
var _failed_operations: Dictionary = {}  # operation_name -> failure_count
var _circuit_breaker_open_time: Dictionary = {}  # operation_name -> timestamp

## Player scene reference
var player_scene: PackedScene = null

## Feature toggle state
var _feature_enabled: bool = true
var _hot_reload_supported: bool = true
var _initialized: bool = false


## Helper function to safely get logger
func _get_logger() -> Node:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		return gm.get_core_system("logger")
	return null


func _ready() -> void:
	# Auto-initialize if not in editor
	# This ensures splitscreen works without manual initialization
	if not Engine.is_editor_hint():
		initialize()


func _process(delta: float) -> void:
	if session_state == null:
		return

	# Update session timer
	if session_state.current_state == SessionState.State.ACTIVE:
		session_state.update_timer(delta)

		# Monitor performance
		if adaptive_quality_enabled:
			_monitor_performance(delta)


## Initialize the splitscreen system
func initialize() -> void:
	if _initialized:
		return

	# Load configuration
	_load_configuration()

	# Create session state
	session_state = SessionState.new()

	# Create viewport manager
	viewport_manager = ViewportManager.new()
	viewport_manager.name = "ViewportManager"
	viewport_manager.load_configuration(config)
	add_child(viewport_manager)

	# Create gamepad controller
	gamepad_controller = GamepadController.new()
	gamepad_controller.name = "GamepadController"
	gamepad_controller.load_configuration(config.get("input", {}))
	add_child(gamepad_controller)

	# Create performance profiler
	var profiler_script: Script = load(
		"res://game/core/systems/splitscreen/performance_profiler.gd"
	)
	if profiler_script:
		performance_profiler = profiler_script.new()
		performance_profiler.name = "PerformanceProfiler"
		add_child(performance_profiler)

		# Connect profiler signals
		if performance_profiler.has_signal("performance_warning"):
			performance_profiler.performance_warning.connect(_on_performance_warning)
		if performance_profiler.has_signal("performance_critical"):
			performance_profiler.performance_critical.connect(_on_performance_critical)

	# Connect signals
	gamepad_controller.gamepad_disconnected.connect(_on_gamepad_disconnected)
	gamepad_controller.gamepad_connected.connect(_on_gamepad_connected)
	gamepad_controller.assignment_complete.connect(_on_assignment_complete)
	_initialized = true

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info("Initialized successfully", "Splitscreen")


## Load configuration from file
func _load_configuration() -> void:
	var config_path: String = "res://game/config/features/splitscreen.json5"

	if FileAccess.file_exists(config_path):
		# Use JSON5Loader to properly parse JSON5 files
		var data: Variant = JSON5Loader.load_file(config_path)

		if data != null and typeof(data) == TYPE_DICTIONARY:
			config = data

			# Validate configuration
			if _validate_configuration(config):
				_apply_configuration()
			else:
				push_error("[SplitscreenManager] Configuration validation failed, using defaults")
				_use_default_configuration()
		else:
			push_error("[SplitscreenManager] Failed to parse configuration file")
			_use_default_configuration()
	else:
		push_warning("[SplitscreenManager] Configuration file not found, using defaults")
		_use_default_configuration()


## Validate configuration structure and values
func _validate_configuration(cfg: Dictionary) -> bool:
	var valid: bool = true

	# Check required fields
	if not cfg.has("enabled"):
		push_error("[SplitscreenManager] Missing required field: enabled")
		valid = false

	# Validate player count settings
	if cfg.has("min_players"):
		if not _is_integer_number(cfg["min_players"]) or cfg["min_players"] < 2:
			push_error("[SplitscreenManager] Invalid min_players: must be integer >= 2")
			valid = false

	if cfg.has("max_players"):
		if (
			not _is_integer_number(cfg["max_players"])
			or cfg["max_players"] < 2
			or cfg["max_players"] > 8
		):
			push_error("[SplitscreenManager] Invalid max_players: must be integer between 2 and 8")
			valid = false

	if cfg.has("min_players") and cfg.has("max_players"):
		if cfg["min_players"] > cfg["max_players"]:
			push_error("[SplitscreenManager] Invalid config: min_players > max_players")
			valid = false

	if cfg.has("default_player_count"):
		if not _is_integer_number(cfg["default_player_count"]):
			push_error("[SplitscreenManager] Invalid default_player_count: must be integer")
			valid = false
		elif (
			cfg.has("min_players")
			and cfg.has("max_players")
			and (
				cfg["default_player_count"] < cfg["min_players"]
				or cfg["default_player_count"] > cfg["max_players"]
			)
		):
			push_error("[SplitscreenManager] Invalid default_player_count: outside player bounds")
			valid = false

	# Validate performance settings
	if cfg.has("performance"):
		var perf: Dictionary = cfg["performance"]

		if perf.has("target_fps"):
			if (
				not (perf["target_fps"] is float or perf["target_fps"] is int)
				or perf["target_fps"] <= 0
			):
				push_error("[SplitscreenManager] Invalid target_fps: must be positive number")
				valid = false

		if perf.has("fps_variance_threshold"):
			if (
				not (perf["fps_variance_threshold"] is float)
				or perf["fps_variance_threshold"] < 0
				or perf["fps_variance_threshold"] > 1
			):
				push_error(
					(
						"[SplitscreenManager] Invalid fps_variance_threshold: "
						+ "must be between 0 and 1"
					)
				)
				valid = false

	# Validate viewport settings
	if cfg.has("viewport"):
		var vp: Dictionary = cfg["viewport"]

		if vp.has("default_layout"):
			var valid_layouts: Array = ["auto", "2x2", "2x3", "3x2"]
			if not vp["default_layout"] in valid_layouts:
				push_error(
					(
						"[SplitscreenManager] Invalid default_layout: must be one of %s"
						% str(valid_layouts)
					)
				)
				valid = false

		if vp.has("msaa"):
			var valid_msaa: Array = ["disabled", "2x", "4x", "8x"]
			if not vp["msaa"] in valid_msaa:
				push_error("[SplitscreenManager] Invalid msaa: must be one of %s" % str(valid_msaa))
				valid = false

	# Validate input settings
	if cfg.has("input"):
		var inp: Dictionary = cfg["input"]

		if inp.has("analog_deadzone"):
			if (
				not (inp["analog_deadzone"] is float)
				or inp["analog_deadzone"] < 0
				or inp["analog_deadzone"] > 1
			):
				push_error("[SplitscreenManager] Invalid analog_deadzone: must be between 0 and 1")
				valid = false

		if inp.has("trigger_threshold"):
			if (
				not (inp["trigger_threshold"] is float)
				or inp["trigger_threshold"] < 0
				or inp["trigger_threshold"] > 1
			):
				push_error(
					"[SplitscreenManager] Invalid trigger_threshold: must be between 0 and 1"
				)
				valid = false

	return valid


## JSON.parse_string represents all JSON numbers as floats. Accept values such
## as 4.0 for integer configuration fields while still rejecting fractions.
func _is_integer_number(value: Variant) -> bool:
	return value is int or (value is float and is_equal_approx(value, round(value)))


## Apply loaded configuration
func _apply_configuration() -> void:
	min_players = int(config.get("min_players", 4))
	max_players = int(config.get("max_players", 6))
	default_player_count = int(config.get("default_player_count", 4))
	session_timeout_seconds = int(config.get("session_timeout_seconds", 300))
	auto_pause_on_disconnect = config.get("auto_pause_on_disconnect", true)

	var perf_config: Dictionary = config.get("performance", {})
	target_fps = perf_config.get("target_fps", 60.0)
	fps_variance_threshold = perf_config.get("fps_variance_threshold", 0.1)
	adaptive_quality_enabled = perf_config.get("adaptive_quality_enabled", true)
	quality_adjustment_interval = perf_config.get("quality_adjustment_interval_seconds", 5.0)


## Use default configuration
func _use_default_configuration() -> void:
	config = {
		"min_players": 4,
		"max_players": 6,
		"default_player_count": 4,
		"session_timeout_seconds": 300,
		"auto_pause_on_disconnect": true,
		"performance":
		{
			"target_fps": 60.0,
			"fps_variance_threshold": 0.1,
			"adaptive_quality_enabled": true,
			"quality_adjustment_interval_seconds": 5.0
		}
	}
	_apply_configuration()


## Start a splitscreen session
## Returns true if session started successfully
func start_session(player_count: int) -> bool:
	if session_state == null:
		_emit_error("Splitscreen system not initialized")
		return false

	# Validate player count
	if player_count < min_players:
		_emit_error(
			(
				"Player count %d is below minimum %d. Connect at least %d controllers."
				% [player_count, min_players, min_players]
			)
		)
		return false

	if player_count > max_players:
		_emit_error("Player count %d exceeds maximum %d" % [player_count, max_players])
		return false

	# Transition to initializing state
	if not session_state.transition_to(SessionState.State.INITIALIZING):
		_emit_error("Failed to start session: invalid state transition")
		return false

	# Check for sufficient gamepads
	var connected_devices: Array = gamepad_controller.detect_gamepads()
	if connected_devices.size() < player_count:
		_emit_error(
			(
				(
					"Insufficient controllers connected. Need %d, found %d. "
					+ "Connect at least %d controllers and try again."
				)
				% [player_count, connected_devices.size(), player_count]
			)
		)
		session_state.transition_to(SessionState.State.INACTIVE)
		return false

	# Set expected player count
	gamepad_controller.set_expected_player_count(player_count)

	# Add players to session state
	for i in range(player_count):
		session_state.add_player(i)

	# Transition to assigning devices
	if not session_state.transition_to(SessionState.State.ASSIGNING_DEVICES):
		_emit_error("Failed to transition to device assignment")
		_cleanup_on_error()
		return false

	# Show assignment UI
	gamepad_controller.show_assignment_ui()

	var logger: Node = _get_logger()
	if logger:
		logger.info("Session initialization started for %d players" % player_count, "Splitscreen")

	return true


## Called when all devices are assigned
func _on_assignment_complete() -> void:
	if session_state.current_state != SessionState.State.ASSIGNING_DEVICES:
		return

	# Hide assignment UI
	gamepad_controller.hide_assignment_ui()

	# Create viewports and spawn players
	var player_count: int = session_state.player_count
	for player_id in range(player_count):
		# Create viewport
		var viewport: SubViewport = viewport_manager.create_viewport(player_id, player_scene)
		if viewport == null:
			_emit_error("Failed to create viewport for player %d" % player_id)
			_cleanup_on_error()
			return

		# Update session state with viewport
		session_state.update_player_data(
			player_id, null, viewport, gamepad_controller.get_assigned_device(player_id), true
		)

		# Get player instance and set up input component
		var player_instance: Node = viewport_manager.get_player_instance(player_id)
		if player_instance:
			var input_component: Node = SplitscreenInputComponent.new()
			input_component.set_device(
				gamepad_controller.get_assigned_device(player_id), gamepad_controller, player_id
			)
			player_instance.add_child(input_component)

	# Arrange viewports
	viewport_manager.arrange_viewports(player_count)

	# Synchronize game state
	_synchronize_game_state()

	# Transition to active state
	if not session_state.transition_to(SessionState.State.ACTIVE):
		_emit_error("Failed to transition to active state")
		_cleanup_on_error()
		return

	# Start session timer
	session_state.start_timer()

	# Start performance profiling
	if performance_profiler and performance_profiler.has_method("start_profiling"):
		performance_profiler.start_profiling()

	# Emit signal
	session_started.emit(player_count)

	var logger: Node = _get_logger()
	if logger:
		logger.info("Session started with %d players" % player_count, "Splitscreen")


## Synchronize game state across all players
func _synchronize_game_state() -> void:
	## Sync critical game state across all splitscreen players
	## This ensures all players see the same world state

	if session_state == null or session_state.current_state != SessionState.State.ACTIVE:
		return

	# Get world node
	var world: Node = get_tree().current_scene
	if not world:
		return

	# Sync item pickups - mark as collected for all players
	var pickups: Array[Node] = get_tree().get_nodes_in_group("pickups")
	for pickup in pickups:
		if pickup.has_method("is_collected") and pickup.is_collected():
			# Ensure pickup is hidden/disabled for all viewports
			pickup.visible = false
			if pickup.has_method("set_enabled"):
				pickup.set_enabled(false)

	# Sync enemy states - share health and alive status
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# If enemy is dead for any player, it's dead for all
		if enemy.has_method("is_dead") and enemy.is_dead():
			enemy.visible = false
			if enemy.has_method("set_enabled"):
				enemy.set_enabled(false)

	# Sync interactive objects (doors, switches, etc.)
	var interactables: Array[Node] = get_tree().get_nodes_in_group("interactable")
	for obj in interactables:
		if not is_instance_valid(obj):
			continue

		# Sync door states - just ensure visual consistency
		if obj.has_method("is_open") and obj.has_method("update_visual_state"):
			obj.update_visual_state()

	# Note: Player positions are NOT synced - each player controls their own character
	# This is intentional for local splitscreen gameplay


## End the current session
func end_session() -> void:
	if session_state == null or session_state.current_state == SessionState.State.INACTIVE:
		return

	# Stop performance profiling and get report
	if performance_profiler and performance_profiler.has_method("stop_profiling"):
		var report: Dictionary = performance_profiler.stop_profiling()
		if report.size() > 0:
			var perf_logger: Node = _get_logger()
			if perf_logger:
				perf_logger.info("Performance Report:", "Splitscreen")
				perf_logger.info(
					"  Average FPS: %.1f" % report.get("fps", {}).get("avg", 0.0), "Splitscreen"
				)
				perf_logger.info(
					"  Min FPS: %.1f" % report.get("fps", {}).get("min", 0.0), "Splitscreen"
				)
				perf_logger.info(
					"  Max FPS: %.1f" % report.get("fps", {}).get("max", 0.0), "Splitscreen"
				)
				perf_logger.info(
					"  Peak Memory: %.1f MB" % report.get("memory", {}).get("peak_mb", 0.0),
					"Splitscreen"
				)
				perf_logger.info(
					(
						"  Performance Grade: %s"
						% report.get("analysis", {}).get("performance_grade", "N/A")
					),
					"Splitscreen"
				)

	# Transition to ending state
	session_state.transition_to(SessionState.State.ENDING)

	# Cleanup viewports
	viewport_manager.cleanup_all_viewports()

	# Clear gamepad assignments
	gamepad_controller.clear_assignments()

	# Reset session state
	session_state.reset()

	# Emit signal
	session_ended.emit()

	var logger: Node = _get_logger()
	if logger:
		logger.info("Session ended", "Splitscreen")


## Pause the current session
func pause_session() -> void:
	if session_state == null or session_state.current_state != SessionState.State.ACTIVE:
		return

	session_state.transition_to(SessionState.State.PAUSED)

	# Pause all player instances
	for player_id: int in session_state.active_players:
		var player_data: Variant = session_state.get_player_data(player_id)
		if player_data and player_data.player_instance:
			player_data.player_instance.process_mode = Node.PROCESS_MODE_DISABLED

	var logger: Node = _get_logger()
	if logger:
		logger.info("Session paused", "Splitscreen")


## Resume the current session
func resume_session() -> void:
	if session_state == null or session_state.current_state != SessionState.State.PAUSED:
		return

	session_state.transition_to(SessionState.State.ACTIVE)

	# Resume all player instances
	for player_id: int in session_state.active_players:
		var player_data: Variant = session_state.get_player_data(player_id)
		if player_data and player_data.player_instance:
			player_data.player_instance.process_mode = Node.PROCESS_MODE_INHERIT

	var logger: Node = _get_logger()
	if logger:
		logger.info("Session resumed", "Splitscreen")


## Add a player to an active session
## Returns the player_id if successful, -1 otherwise
func add_player(gamepad_device: int) -> int:
	if session_state == null or session_state.current_state != SessionState.State.ACTIVE:
		return -1

	var player_id: int = session_state.player_count

	# Check max players
	if player_id >= max_players:
		_emit_error("Cannot add player: maximum player count reached")
		return -1

	# Add to session state
	session_state.add_player(player_id)

	# Assign gamepad
	if not gamepad_controller.assign_gamepad(player_id, gamepad_device):
		session_state.remove_player(player_id)
		return -1

	# Create viewport
	var viewport: SubViewport = viewport_manager.create_viewport(player_id, player_scene)
	if viewport == null:
		session_state.remove_player(player_id)
		gamepad_controller.unassign_gamepad(player_id)
		return -1

	# Update session state
	session_state.update_player_data(player_id, null, viewport, gamepad_device, true)

	# Rearrange viewports
	viewport_manager.arrange_viewports(session_state.player_count)

	# Emit signal
	player_joined.emit(player_id, gamepad_device)

	var logger: Node = _get_logger()
	if logger:
		logger.info("Player %d joined" % player_id, "Splitscreen")
	return player_id


## Remove a player from an active session
func remove_player(player_id: int) -> void:
	if session_state == null:
		return

	# Destroy viewport
	viewport_manager.destroy_viewport(player_id)

	# Unassign gamepad
	gamepad_controller.unassign_gamepad(player_id)

	# Remove from session state
	session_state.remove_player(player_id)

	# Check if below minimum players
	if (
		session_state.player_count < min_players
		and session_state.current_state == SessionState.State.ACTIVE
	):
		push_warning(
			(
				"[SplitscreenManager] Player count dropped below minimum. "
				+ "Session will continue but may be unstable."
			)
		)

	# Rearrange viewports
	if session_state.player_count > 0:
		viewport_manager.arrange_viewports(session_state.player_count)

	# Emit signal
	player_left.emit(player_id)

	var logger: Node = _get_logger()
	if logger:
		logger.info("Player %d left" % player_id, "Splitscreen")


## Get the current session state
func get_session_state() -> SessionState:
	return session_state


## Check if a session is currently active
func is_session_active() -> bool:
	return session_state != null and session_state.current_state == SessionState.State.ACTIVE


## Get the current player count
func get_player_count() -> int:
	return session_state.player_count if session_state else 0


## Handle gamepad disconnection
func _on_gamepad_disconnected(device_id: int) -> void:
	var player_id: int = gamepad_controller.get_player_for_device(device_id)
	if player_id == -1:
		return

	var logger: Node = _get_logger()
	if logger:
		logger.info("Gamepad %d disconnected (Player %d)" % [device_id, player_id], "Splitscreen")

	# Update player connection status
	session_state.update_player_data(player_id, null, null, -1, false)

	# Auto-pause if configured
	if auto_pause_on_disconnect and session_state.current_state == SessionState.State.ACTIVE:
		pause_session()
		push_warning("[SplitscreenManager] Session paused due to controller disconnect")


## Handle gamepad reconnection
func _on_gamepad_connected(device_id: int) -> void:
	var logger: Node = _get_logger()
	if logger:
		logger.info("Gamepad %d connected" % device_id, "Splitscreen")

	# Check if this was a previously assigned device
	# GamepadController handles reassignment automatically


## Monitor performance and adjust quality
func _monitor_performance(delta: float) -> void:
	var current_fps: float = Engine.get_frames_per_second()
	_fps_samples.append(current_fps)

	# Keep only recent samples (last 60 frames)
	while _fps_samples.size() > 60:
		_fps_samples.pop_front()

	# Update performance metrics
	var avg_fps: float = _calculate_average_fps()
	var frame_time: float = 1000.0 / current_fps if current_fps > 0 else 0.0
	var memory_usage: int = int(OS.get_static_memory_usage())
	session_state.update_performance_metrics(avg_fps, frame_time, memory_usage)

	# Check if it's time to adjust quality
	_last_quality_adjustment_time += delta
	if _last_quality_adjustment_time >= quality_adjustment_interval:
		_last_quality_adjustment_time = 0.0
		_adjust_quality_if_needed(avg_fps)


## Calculate average FPS from samples
func _calculate_average_fps() -> float:
	if _fps_samples.is_empty():
		return 0.0

	var sum: float = 0.0
	for fps in _fps_samples:
		sum += fps
	return sum / _fps_samples.size()


## Adjust rendering quality based on performance
func _adjust_quality_if_needed(avg_fps: float) -> void:
	var fps_ratio: float = avg_fps / target_fps
	var variance: float = abs(1.0 - fps_ratio)

	# Only adjust if variance exceeds threshold
	if variance <= fps_variance_threshold:
		return

	# Determine new quality level
	var new_quality_level: String = _current_quality_level

	if fps_ratio < 0.9:  # FPS is too low
		match _current_quality_level:
			"high":
				new_quality_level = "medium"
			"medium":
				new_quality_level = "low"
	elif fps_ratio > 1.1:  # FPS is higher than needed
		match _current_quality_level:
			"low":
				new_quality_level = "medium"
			"medium":
				new_quality_level = "high"

	# Apply new quality level
	if new_quality_level != _current_quality_level:
		_apply_quality_level(new_quality_level)
		_current_quality_level = new_quality_level
		var logger: Node = _get_logger()
		if logger:
			logger.info(
				"Adjusted quality to %s (FPS: %.1f)" % [new_quality_level, avg_fps], "Splitscreen"
			)


## Apply a quality level to the viewport manager
func _apply_quality_level(quality_level: String) -> void:
	var quality_map: Dictionary = {"high": 1.0, "medium": 0.7, "low": 0.4}

	var quality_value: float = quality_map.get(quality_level, 0.7)
	viewport_manager.set_rendering_quality(quality_value)


## Emit an error signal
func _emit_error(message: String) -> void:
	push_error("[SplitscreenManager] " + message)
	session_error.emit(message)


## Cleanup resources on error
func _cleanup_on_error() -> void:
	if viewport_manager:
		viewport_manager.cleanup_all_viewports()

	if gamepad_controller:
		gamepad_controller.hide_assignment_ui()
		gamepad_controller.clear_assignments()

	if session_state:
		session_state.reset()

	var logger: Node = _get_logger()
	if logger:
		logger.info("Cleaned up after error", "Splitscreen")


## Set the player scene to use for spawning
func set_player_scene(scene: PackedScene) -> void:
	player_scene = scene


## Handle performance warnings
func _on_performance_warning(message: String) -> void:
	push_warning("[SplitscreenManager] Performance Warning: %s" % message)


## Handle performance critical issues
func _on_performance_critical(message: String) -> void:
	push_error("[SplitscreenManager] Performance Critical: %s" % message)

	# Consider automatic quality reduction
	if adaptive_quality_enabled and _current_quality_level != "low":
		var new_level: String = "medium" if _current_quality_level == "high" else "low"
		_apply_quality_level(new_level)
		_current_quality_level = new_level
		var logger: Node = _get_logger()
		if logger:
			logger.info(
				"Auto-reduced quality to %s due to performance issues" % new_level, "Splitscreen"
			)


## Get performance report
func get_performance_report() -> Dictionary:
	if performance_profiler and performance_profiler.has_method("generate_report"):
		return performance_profiler.generate_report()
	return {}


## Export performance report to file
func export_performance_report(filepath: String) -> bool:
	if performance_profiler and performance_profiler.has_method("export_report_to_file"):
		return performance_profiler.export_report_to_file(filepath)
	return false


## Error recovery: Execute operation with retry logic
func _execute_with_retry(
	operation_name: String, callable: Callable, max_attempts: int = -1
) -> Variant:
	if not _error_recovery_enabled:
		return callable.call()

	# Check circuit breaker
	if _is_circuit_breaker_open(operation_name):
		push_error("[SplitscreenManager] Circuit breaker open for operation: %s" % operation_name)
		return null

	var attempts: int = max_attempts if max_attempts > 0 else _max_retry_attempts

	for attempt in range(attempts):
		var result: Variant = callable.call()

		# Success
		if result != null or not callable.is_valid():
			_record_success(operation_name)
			return result

		# Failure
		_record_failure(operation_name)

		# Wait before retry (except on last attempt)
		if attempt < attempts - 1:
			await get_tree().create_timer(_retry_delay_seconds).timeout

	# All attempts failed
	push_error(
		"[SplitscreenManager] Operation '%s' failed after %d attempts" % [operation_name, attempts]
	)
	return null


## Record operation success
func _record_success(operation_name: String) -> void:
	if _failed_operations.has(operation_name):
		_failed_operations[operation_name] = max(0, _failed_operations[operation_name] - 1)


## Record operation failure
func _record_failure(operation_name: String) -> void:
	if not _failed_operations.has(operation_name):
		_failed_operations[operation_name] = 0

	_failed_operations[operation_name] += 1

	# Check if circuit breaker should open
	if _failed_operations[operation_name] >= _circuit_breaker_threshold:
		_open_circuit_breaker(operation_name)


## Check if circuit breaker is open for an operation
func _is_circuit_breaker_open(operation_name: String) -> bool:
	if not _circuit_breaker_open_time.has(operation_name):
		return false

	var current_time: float = Time.get_ticks_msec() / 1000.0
	var open_time: float = _circuit_breaker_open_time[operation_name]

	# Check if reset time has passed
	if current_time - open_time >= _circuit_breaker_reset_time:
		_close_circuit_breaker(operation_name)
		return false

	return true


## Open circuit breaker for an operation
func _open_circuit_breaker(operation_name: String) -> void:
	_circuit_breaker_open_time[operation_name] = Time.get_ticks_msec() / 1000.0
	push_warning("[SplitscreenManager] Circuit breaker opened for operation: %s" % operation_name)


## Close circuit breaker for an operation
func _close_circuit_breaker(operation_name: String) -> void:
	_circuit_breaker_open_time.erase(operation_name)
	_failed_operations[operation_name] = 0
	var logger: Node = _get_logger()
	if logger:
		logger.info("Circuit breaker closed for operation: %s" % operation_name, "Splitscreen")


## Graceful degradation: Try to recover from error state
func _attempt_graceful_recovery() -> bool:
	push_warning("[SplitscreenManager] Attempting graceful recovery...")

	var logger: Node = _get_logger()

	# Try to save current session state
	var saved_state: Variant = null
	if session_state:
		saved_state = session_state.to_dict()

	# Cleanup current resources
	_cleanup_on_error()

	# Try to restore session if we had one
	if saved_state and saved_state.get("player_count", 0) > 0:
		var player_count: int = saved_state["player_count"]

		# Wait a moment before retry
		await get_tree().create_timer(1.0).timeout

		# Try to restart session
		if start_session(player_count):
			if logger:
				logger.info("Graceful recovery successful", "Splitscreen")
			return true

	if logger:
		logger.info("Graceful recovery failed", "Splitscreen")
	return false


## Enable/disable error recovery
func set_error_recovery_enabled(enabled: bool) -> void:
	_error_recovery_enabled = enabled


## Get error recovery statistics
func get_error_recovery_stats() -> Dictionary:
	return {
		"failed_operations": _failed_operations.duplicate(),
		"open_circuit_breakers": _circuit_breaker_open_time.keys()
	}


## Runtime feature toggle: Enable splitscreen feature
func enable_feature() -> bool:
	if _feature_enabled:
		return true

	var logger: Node = _get_logger()
	if logger:
		logger.info("Enabling splitscreen feature...", "Splitscreen")

	# Reload configuration
	_load_configuration()

	# Check if feature is enabled in config
	if not config.get("enabled", true):
		push_warning("[SplitscreenManager] Feature is disabled in configuration")
		return false

	# Reinitialize components if needed
	if viewport_manager == null or gamepad_controller == null:
		initialize()

	_feature_enabled = true
	if logger:
		logger.info("Splitscreen feature enabled", "Splitscreen")
	return true


## Runtime feature toggle: Disable splitscreen feature
func disable_feature() -> bool:
	if not _feature_enabled:
		return true

	var logger: Node = _get_logger()
	if logger:
		logger.info("Disabling splitscreen feature...", "Splitscreen")

	# End any active session
	if is_session_active():
		end_session()

	# Cleanup components (but don't remove them for hot-reload)
	if _hot_reload_supported:
		# Just mark as disabled, keep components for fast re-enable
		_feature_enabled = false
	else:
		# Full cleanup
		_cleanup_components()
		_feature_enabled = false

	if logger:
		logger.info("Splitscreen feature disabled", "Splitscreen")
	return true


## Cleanup components (for full disable)
func _cleanup_components() -> void:
	# === SIGNAL HYGIENE: Disconnect all signals before freeing components ===

	# Disconnect performance profiler signals
	if performance_profiler:
		if performance_profiler.has_signal("performance_warning"):
			if performance_profiler.performance_warning.is_connected(_on_performance_warning):
				performance_profiler.performance_warning.disconnect(_on_performance_warning)
		if performance_profiler.has_signal("performance_critical"):
			if performance_profiler.performance_critical.is_connected(_on_performance_critical):
				performance_profiler.performance_critical.disconnect(_on_performance_critical)
		performance_profiler.queue_free()
		performance_profiler = null

	# Disconnect gamepad controller signals
	if gamepad_controller:
		if gamepad_controller.gamepad_disconnected.is_connected(_on_gamepad_disconnected):
			gamepad_controller.gamepad_disconnected.disconnect(_on_gamepad_disconnected)
		if gamepad_controller.gamepad_connected.is_connected(_on_gamepad_connected):
			gamepad_controller.gamepad_connected.disconnect(_on_gamepad_connected)
		if gamepad_controller.assignment_complete.is_connected(_on_assignment_complete):
			gamepad_controller.assignment_complete.disconnect(_on_assignment_complete)
		gamepad_controller.queue_free()
		gamepad_controller = null

	# Viewport manager (no signals to disconnect)
	if viewport_manager:
		viewport_manager.queue_free()
		viewport_manager = null

	# Session state (no signals to disconnect)
	if session_state:
		session_state = null

	_initialized = false


## Check if feature is currently enabled
func is_feature_enabled() -> bool:
	return _feature_enabled


## Reload configuration at runtime
func reload_configuration() -> bool:
	var logger: Node = _get_logger()
	if logger:
		logger.info("Reloading configuration...", "Splitscreen")

	var was_active: bool = is_session_active()
	var saved_state: Variant = null

	# Save current session if active
	if was_active and session_state:
		saved_state = session_state.to_dict()
		end_session()

	# Reload config
	_load_configuration()

	# Reapply to components
	if viewport_manager:
		viewport_manager.load_configuration(config)

	if gamepad_controller:
		gamepad_controller.load_configuration(config.get("input", {}))

	# Restore session if it was active
	if was_active and saved_state:
		var player_count: int = saved_state.get("player_count", 0)
		if player_count > 0:
			start_session(player_count)

	if logger:
		logger.info("Configuration reloaded", "Splitscreen")
	return true


## Set hot-reload support
func set_hot_reload_supported(supported: bool) -> void:
	_hot_reload_supported = supported
