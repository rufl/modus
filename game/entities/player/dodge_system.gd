class_name DodgeSystem
extends Node

signal dodge_performed(direction: Vector3, speed: float)
signal dodge_ready

# Double-tap direction keys, press dodge action key, or either method works
enum InputMode { DOUBLE_TAP, DEDICATED_KEY, BOTH }

@export_group("Input Mode")
@export var input_mode: InputMode = InputMode.DOUBLE_TAP
@export var dodge_action: String = "dodge"  ## Input action for dedicated key mode
@export_group("Dodge Mechanics")
@export var enable_dodge: bool = true
@export var dodge_speed: float = 15.0
@export var dodge_duration: float = 0.2
@export var dodge_cooldown: float = 1.0
@export var air_dodge_speed_multiplier: float = 0.7
@export var air_dodge_enabled: bool = true
@export_group("Double-Tap Detection")
@export var double_tap_window: float = 0.25
@export var require_release: bool = true

var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown_timer: float = 0.0
var dodge_direction: Vector3 = Vector3.ZERO
var player: CharacterBody3D = null

var _last_tap_direction: String = ""
var _last_tap_time: float = 0.0
var _direction_released: bool = true
var _forward: Vector3 = Vector3.FORWARD
var _right: Vector3 = Vector3.RIGHT


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("[DodgeSystem] Must be child of CharacterBody3D")
	_load_config()


func _load_config() -> void:
	## Try GameManager.get_core_system("config") first, fall back to direct JSON loading
	## This gives buyers flexibility to use either approach

	# Option 1: GameManager.get_core_system("config") (recommended for hot-reload support)
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var cfg: Node = gm.get_core_system("config")
		var config_result: Variant = cfg.get_value("movement") if cfg else null
		if config_result != null and config_result is Dictionary:
			var cm_data: Dictionary = config_result
			if cm_data.has("dodge"):
				_apply_dodge_config(cm_data["dodge"])
				return

	# Option 2: Direct JSON file loading (fallback)
	const CONFIG_PATH := "res://game/config/gameplay/movement.json5"
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("[DodgeSystem] Failed to parse config: %s" % CONFIG_PATH)
		return

	var data: Dictionary = json.data
	if not data.has("dodge"):
		return
	_apply_dodge_config(data["dodge"])


func _apply_dodge_config(cfg: Dictionary) -> void:
	# Apply dodge settings
	enable_dodge = cfg.get("enabled", enable_dodge)
	dodge_speed = cfg.get("speed", dodge_speed)
	dodge_duration = cfg.get("duration", dodge_duration)
	dodge_cooldown = cfg.get("cooldown", dodge_cooldown)
	air_dodge_enabled = cfg.get("air_dodge_enabled", air_dodge_enabled)
	air_dodge_speed_multiplier = cfg.get("air_dodge_speed_multiplier", air_dodge_speed_multiplier)
	double_tap_window = cfg.get("double_tap_window", double_tap_window)
	require_release = cfg.get("require_release", require_release)

	# Parse input mode
	var mode_str: String = cfg.get("input_mode", "")
	match mode_str.to_upper():
		"DOUBLE_TAP":
			input_mode = InputMode.DOUBLE_TAP
		"DEDICATED_KEY":
			input_mode = InputMode.DEDICATED_KEY
		"BOTH":
			input_mode = InputMode.BOTH


## Configure from external source (GameManager.get_core_system("config") injection)


func configure(cfg: Dictionary) -> void:
	enable_dodge = cfg.get("enabled", enable_dodge)
	dodge_speed = cfg.get("speed", dodge_speed)
	dodge_duration = cfg.get("duration", dodge_duration)
	dodge_cooldown = cfg.get("cooldown", dodge_cooldown)
	air_dodge_enabled = cfg.get("air_dodge_enabled", air_dodge_enabled)
	air_dodge_speed_multiplier = cfg.get("air_dodge_speed_multiplier", air_dodge_speed_multiplier)
	double_tap_window = cfg.get("double_tap_window", double_tap_window)
	require_release = cfg.get("require_release", require_release)

	# Parse input mode
	var mode_str: String = cfg.get("input_mode", "")
	match mode_str.to_upper():
		"DOUBLE_TAP":
			input_mode = InputMode.DOUBLE_TAP
		"DEDICATED_KEY":
			input_mode = InputMode.DEDICATED_KEY
		"BOTH":
			input_mode = InputMode.BOTH

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info(
				"[DodgeSystem] Configured via GameManager.get_core_system('config')", "Player"
			)


func _process(delta: float) -> void:
	# Only process for multiplayer authority
	# In single player (no peer), always process for local player
	var is_local: bool = (
		player
		and (
			not multiplayer.has_multiplayer_peer()
			or (player.has_method("is_multiplayer_authority") and player.is_multiplayer_authority())
		)
	)
	if not is_local:
		return

	# Update cooldown timer
	if dodge_cooldown_timer > 0.0:
		dodge_cooldown_timer -= delta
		if dodge_cooldown_timer <= 0.0:
			dodge_ready.emit()

	# Update dodge timer
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0.0:
			_end_dodge()


func update_directions(forward: Vector3, right: Vector3) -> void:
	## Update cached direction vectors (call from player each frame)
	_forward = forward
	_right = right


func check_input() -> void:
	## Check for dodge input based on current mode
	if not enable_dodge or is_dodging or dodge_cooldown_timer > 0.0:
		return

	if not air_dodge_enabled and player and not player.is_on_floor():
		return

	# Check based on input mode
	match input_mode:
		InputMode.DOUBLE_TAP:
			_check_double_tap()
		InputMode.DEDICATED_KEY:
			_check_dedicated_key()
		InputMode.BOTH:
			_check_dedicated_key()
			if not is_dodging:
				_check_double_tap()


func _check_dedicated_key() -> void:
	## Check for dedicated key press
	if not InputMap.has_action(dodge_action):
		return

	if Input.is_action_just_pressed(dodge_action):
		var input_dir := Input.get_vector("left", "right", "up", "down")
		_execute_dodge_from_input(input_dir)


func _check_double_tap() -> void:
	## Check for double-tap input
	var current_time := Time.get_ticks_msec() / 1000.0

	# Check each direction
	var directions := {
		"up": Input.is_action_just_pressed("up"),
		"down": Input.is_action_just_pressed("down"),
		"left": Input.is_action_just_pressed("left"),
		"right": Input.is_action_just_pressed("right")
	}

	for dir_name: String in directions.keys():
		if directions[dir_name]:
			# Key just pressed
			var valid_double_tap := _last_tap_direction == dir_name
			if require_release:
				valid_double_tap = valid_double_tap and _direction_released

			if valid_double_tap:
				# Same direction pressed again - check timing
				if current_time - _last_tap_time <= double_tap_window:
					# Double-tap detected!
					_execute_dodge_direction(dir_name)
					_last_tap_direction = ""
					_last_tap_time = 0.0
					return

			# Record this tap
			_last_tap_direction = dir_name
			_last_tap_time = current_time
			_direction_released = false

	# Check if the last tapped direction was released
	if _last_tap_direction != "" and require_release:
		var release_check := {
			"up": not Input.is_action_pressed("up"),
			"down": not Input.is_action_pressed("down"),
			"left": not Input.is_action_pressed("left"),
			"right": not Input.is_action_pressed("right")
		}
		if release_check.get(_last_tap_direction, false):
			_direction_released = true

	# Clear old taps
	if current_time - _last_tap_time > double_tap_window * 1.5:
		_last_tap_direction = ""


func _execute_dodge_from_input(input_dir: Vector2) -> void:
	## Execute dodge based on input vector
	var dodge_dir := Vector3.ZERO

	if input_dir.length() > 0.1:
		dodge_dir = (_forward * -input_dir.y + _right * input_dir.x).normalized()
	else:
		dodge_dir = _forward

	dodge_dir.y = 0.0
	dodge_dir = dodge_dir.normalized() if dodge_dir.length() > 0.1 else _forward

	_start_dodge(dodge_dir)


func _execute_dodge_direction(dir_name: String) -> void:
	## Execute dodge in the specified named direction
	var dodge_dir := Vector3.ZERO

	match dir_name:
		"up":
			dodge_dir = _forward
		"down":
			dodge_dir = -_forward
		"left":
			dodge_dir = -_right
		"right":
			dodge_dir = _right

	dodge_dir.y = 0.0
	dodge_dir = dodge_dir.normalized()

	_start_dodge(dodge_dir)


func _start_dodge(direction: Vector3) -> void:
	## Start dodge in specified direction
	is_dodging = true
	dodge_timer = dodge_duration
	dodge_direction = direction

	# Calculate dodge speed (reduced in air)
	var effective_speed := dodge_speed
	if player and not player.is_on_floor():
		effective_speed *= air_dodge_speed_multiplier

	dodge_performed.emit(direction, effective_speed)

	# Sync to other players
	if player and player.has_method("is_multiplayer_authority"):
		if player.multiplayer.has_multiplayer_peer() and player.is_multiplayer_authority():
			_sync_dodge_state.rpc(true, direction)


func apply_dodge_movement(velocity: Vector3) -> Vector3:
	## Apply dodge movement to velocity - call in _physics_process
	if not is_dodging:
		return velocity

	var effective_speed := dodge_speed
	if player and not player.is_on_floor():
		effective_speed *= air_dodge_speed_multiplier

	velocity.x = dodge_direction.x * effective_speed
	velocity.z = dodge_direction.z * effective_speed

	return velocity


func _end_dodge() -> void:
	## End dodge and start cooldown
	is_dodging = false
	dodge_timer = 0.0
	dodge_cooldown_timer = dodge_cooldown

	# Sync to other players
	if player and player.has_method("is_multiplayer_authority"):
		if player.multiplayer.has_multiplayer_peer() and player.is_multiplayer_authority():
			_sync_dodge_state.rpc(false, Vector3.ZERO)


## Sync dodge state to other players for visual feedback

@rpc("authority", "call_remote", "unreliable")
func _sync_dodge_state(dodging: bool, direction: Vector3) -> void:
	## Receive dodge state from authority player
	# Only apply if we're not the authority (remote player visualization)
	if player and player.has_method("is_multiplayer_authority"):
		if player.is_multiplayer_authority():
			return  # Don't override local state

	is_dodging = dodging
	dodge_direction = direction


func can_dodge() -> bool:
	## Check if dodge is available
	if not enable_dodge or is_dodging or dodge_cooldown_timer > 0.0:
		return false

	# Check Player Capability
	if player and "has_dodge" in player and not player.has_dodge:
		# If feature is enabled but player lacks powerup, deny
		return false

	if not air_dodge_enabled and player and not player.is_on_floor():
		return false
	return true


func get_dodge_cooldown_percent() -> float:
	## Get dodge cooldown as percentage (0.0 = ready, 1.0 = just used)
	if dodge_cooldown <= 0.0:
		return 0.0
	return dodge_cooldown_timer / dodge_cooldown


func get_stats() -> Dictionary:
	## Get current dodge statistics for HUD/debug
	return {
		"is_dodging": is_dodging,
		"can_dodge": can_dodge(),
		"cooldown_remaining": dodge_cooldown_timer,
		"cooldown_percent": get_dodge_cooldown_percent(),
		"input_mode": InputMode.keys()[input_mode]
	}
