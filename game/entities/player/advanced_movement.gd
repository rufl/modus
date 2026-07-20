class_name AdvancedMovement
extends Node

signal movement_technique_used(technique: String, speed: float)
signal speed_threshold_reached(threshold: String, speed: float)

const CONFIG_PATH := "res://game/config/gameplay/movement.json5"

@export_group("Air Movement")
@export var air_acceleration: float = 800.0
@export var air_strafe_speed: float = 30.0
@export var max_air_speed: float = 12.0
@export var air_control_power: float = 150.0
@export_group("Bunny Hopping")
@export var enable_bunny_hop: bool = true
@export var bhop_speed_cap: float = 15.0
@export var bhop_speed_gain: float = 0.1
@export var bhop_timing_window: float = 0.1
@export_group("Slide Mechanic")
@export var enable_slide: bool = true
@export var slide_speed: float = 10.0
@export var slide_duration: float = 0.8
@export var slide_cooldown: float = 1.5
@export var slide_friction: float = 2.0
@export var slope_slide_threshold: float = 0.5  # Radians, approx 28 degrees
@export var min_slope_slide_speed: float = 15.0

var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_cooldown_timer: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO
var last_jump_time: float = 0.0
var consecutive_jumps: int = 0
var ground_time: float = 0.0
var current_horizontal_speed: float = 0.0
var peak_speed: float = 0.0
var player: CharacterBody3D = null


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("[AdvancedMovement] Must be child of CharacterBody3D")
	_load_config()


func _load_config(_file_path: String = "") -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var cfg: Node = gm.get_core_system("config")
	if not cfg:
		return

	# Load from gameplay.json5 -> balance.player.movement.advanced_movement
	var movement_cfg: Dictionary = cfg.get_value("balance.player.movement", {})
	if movement_cfg.is_empty():
		return

	if movement_cfg.has("advanced_movement"):
		configure(movement_cfg["advanced_movement"])

	# Connection for hot-reloading
	if not cfg.config_reloaded.is_connected(_load_config):
		cfg.config_reloaded.connect(_load_config)


func _exit_tree() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return
	var cfg: Node = gm.get_core_system("config")
	if cfg and cfg.config_reloaded.is_connected(_load_config):
		cfg.config_reloaded.disconnect(_load_config)


## Configure from external source (GameManager.get_core_system("config") injection)


func configure(cfg: Dictionary) -> void:
	# Air movement settings
	if cfg.has("air_movement"):
		var am: Dictionary = cfg["air_movement"]
		air_acceleration = am.get("air_acceleration", air_acceleration)
		air_strafe_speed = am.get("air_strafe_speed", air_strafe_speed)
		max_air_speed = am.get("max_air_speed", max_air_speed)
		air_control_power = am.get("air_control_power", air_control_power)

	# Bunny hop settings
	if cfg.has("bunny_hop"):
		var bh: Dictionary = cfg["bunny_hop"]
		enable_bunny_hop = bh.get("enabled", enable_bunny_hop)
		bhop_speed_cap = bh.get("speed_cap", bhop_speed_cap)
		bhop_speed_gain = bh.get("speed_gain", bhop_speed_gain)
		bhop_timing_window = bh.get("timing_window", bhop_timing_window)

	# Slide settings
	if cfg.has("slide"):
		var s: Dictionary = cfg["slide"]
		enable_slide = s.get("enabled", enable_slide)
		slide_speed = s.get("speed", slide_speed)
		slide_duration = s.get("duration", slide_duration)
		slide_cooldown = s.get("cooldown", slide_cooldown)
		slide_friction = s.get("friction", slide_friction)

	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var logger: Node = gm.get_core_system("logger")
		if logger:
			logger.info(
				"[AdvancedMovement] Configured via GameManager.get_core_system('config')", "Player"
			)


func _process(delta: float) -> void:
	# Only process on authority (client-side for local player)
	# In single player (no peer), always process for local player
	var is_local: bool = (
		player and (not multiplayer.has_multiplayer_peer() or player.is_multiplayer_authority())
	)
	if not is_local:
		return

	# Update timers
	if slide_cooldown_timer > 0.0:
		slide_cooldown_timer -= delta

	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0:
			_end_slide()

	# Track ground time for bhop timing
	if player and player.is_on_floor():
		ground_time += delta
	else:
		ground_time = 0.0

	# Update speed tracking
	_update_speed_tracking()


func apply_air_movement(
	velocity: Vector3, input_dir: Vector2, wish_dir: Vector3, delta: float
) -> Vector3:
	## Apply air strafing and air control
	if not player or player.is_on_floor():
		return velocity

	# Check for rocket jump system to modify air control
	var rocket_jump_system: Node = player.get_node_or_null("RocketJumpSystem")
	var air_control_mod := 1.0
	var speed_cap_mod := 1.0

	if rocket_jump_system and rocket_jump_system.has_method("get_air_control_modifier"):
		air_control_mod = rocket_jump_system.get_air_control_modifier()
		# Allow higher speeds during rocket jumps
		if "is_rocket_jumping" in rocket_jump_system and rocket_jump_system.is_rocket_jumping:
			speed_cap_mod = 2.0

	# Calculate current horizontal speed
	var horizontal_vel := Vector2(velocity.x, velocity.z)
	var current_speed := horizontal_vel.length()

	# Air strafing - gain speed by angling jumps
	if input_dir.length() > 0.1:
		var wish_speed := air_strafe_speed

		# Calculate acceleration direction
		var accel_dir := wish_dir
		accel_dir.y = 0.0
		accel_dir = accel_dir.normalized()

		# Apply air acceleration (enhanced during rocket jump)
		var add_speed := wish_speed - velocity.dot(accel_dir)
		if add_speed > 0.0:
			var accel_speed := minf(air_acceleration * delta * air_control_mod, add_speed)
			velocity += accel_dir * accel_speed

	# Air control - allow direction changes mid-air (enhanced during rocket jump)
	if input_dir.length() > 0.1:
		var control_dir := wish_dir
		control_dir.y = 0.0
		control_dir = control_dir.normalized()

		var control_power := air_control_power * air_control_mod
		velocity.x = move_toward(velocity.x, control_dir.x * current_speed, control_power * delta)
		velocity.z = move_toward(velocity.z, control_dir.z * current_speed, control_power * delta)

	# Cap air speed (higher cap during rocket jumps)
	var effective_max_speed := max_air_speed * speed_cap_mod
	horizontal_vel = Vector2(velocity.x, velocity.z)
	if horizontal_vel.length() > effective_max_speed:
		horizontal_vel = horizontal_vel.normalized() * effective_max_speed
		velocity.x = horizontal_vel.x
		velocity.z = horizontal_vel.y

	return velocity


func _is_player_grounded() -> bool:
	## Centralize the floor query so deterministic movement fixtures and specialized
	## player bodies can supply their own grounded contract without weakening runtime checks.
	return player != null and player.is_on_floor()


func try_bunny_hop(velocity: Vector3, jump_velocity: float) -> Vector3:
	## Attempt bunny hop if timing is correct
	if not enable_bunny_hop:
		return velocity

	if not _is_player_grounded():
		return velocity

	# Check timing window
	var is_good_timing := ground_time <= bhop_timing_window

	if is_good_timing:
		# Calculate horizontal speed
		var horizontal_vel := Vector2(velocity.x, velocity.z)
		var current_speed := horizontal_vel.length()

		# A successful hop always advances the chain. Speed gain is bounded even
		# when the incoming velocity already exceeds the configured cap.
		if current_speed > 0.0:
			var gained_speed := current_speed * (1.0 + bhop_speed_gain)
			var capped_speed := minf(gained_speed, maxf(bhop_speed_cap, 0.0))
			horizontal_vel = horizontal_vel.normalized() * capped_speed
			velocity.x = horizontal_vel.x
			velocity.z = horizontal_vel.y

		consecutive_jumps += 1
		movement_technique_used.emit("bunny_hop", horizontal_vel.length())

		# Check for speed milestones
		if consecutive_jumps == 3:
			speed_threshold_reached.emit("bhop_chain_3", horizontal_vel.length())
		elif consecutive_jumps == 5:
			speed_threshold_reached.emit("bhop_chain_5", horizontal_vel.length())
	else:
		consecutive_jumps = 0

	# Apply jump
	velocity.y = jump_velocity
	last_jump_time = Time.get_ticks_msec() / 1000.0

	return velocity


func try_start_slide(velocity: Vector3, forward_dir: Vector3) -> bool:
	## Attempt to start slide
	if not enable_slide:
		return false

	if is_sliding:
		return false

	if slide_cooldown_timer > 0.0:
		return false

	if not _is_player_grounded():
		return false

	# Require minimum speed to slide
	var horizontal_vel := Vector2(velocity.x, velocity.z)
	if horizontal_vel.length() < 3.0:
		return false

	# Start slide
	is_sliding = true
	slide_timer = slide_duration
	slide_direction = forward_dir
	slide_direction.y = 0.0
	slide_direction = slide_direction.normalized()

	movement_technique_used.emit("slide", horizontal_vel.length())
	return true


func apply_slide_movement(velocity: Vector3, delta: float) -> Vector3:
	## Apply slide movement physics
	if not is_sliding:
		return velocity

	# Maintain slide direction
	var slide_vel := slide_direction * slide_speed

	# Apply friction
	var friction_factor := 1.0 - (slide_friction * delta)
	friction_factor = maxf(friction_factor, 0.0)

	velocity.x = lerp(velocity.x, slide_vel.x, 0.5)
	velocity.z = lerp(velocity.z, slide_vel.z, 0.5)

	# Apply friction over time
	velocity.x *= friction_factor
	velocity.z *= friction_factor

	return velocity


func apply_slope_physics(velocity: Vector3, delta: float) -> Vector3:
	## Apply physics for sliding down steep slopes or gaining speed on ramps
	if not player or not player.is_on_floor():
		return velocity

	var floor_normal: Vector3 = player.get_floor_normal()
	var floor_angle: float = player.get_floor_angle()

	# If on a steep slope (but still considered floor by Godot due to snap), slide down
	# OR if explicitly sliding, gain speed downhill

	var is_steep: bool = floor_angle > slope_slide_threshold

	if is_steep or is_sliding:
		# Calculate slope direction vector (downhill)
		# Project down vector onto plane defined by normal
		var down_dir: Vector3 = Vector3.DOWN - floor_normal * Vector3.DOWN.dot(floor_normal)
		down_dir = down_dir.normalized()

		# Add velocity downhill
		var slope_accel: float = min_slope_slide_speed
		if is_steep:
			slope_accel *= 2.0  # Slide faster on steep slopes

		velocity += down_dir * slope_accel * delta

	return velocity


func end_slide_early() -> void:
	## End slide before timer expires
	if is_sliding:
		_end_slide()


func _end_slide() -> void:
	## End slide and start cooldown
	is_sliding = false
	slide_timer = 0.0
	slide_cooldown_timer = slide_cooldown


func can_slide() -> bool:
	## Check if slide is available
	return enable_slide and not is_sliding and slide_cooldown_timer <= 0.0


func get_slide_cooldown_percent() -> float:
	## Get slide cooldown as percentage (0.0 = ready, 1.0 = just used)
	if slide_cooldown <= 0.0:
		return 0.0
	return slide_cooldown_timer / slide_cooldown


func _update_speed_tracking() -> void:
	## Update speed tracking for UI/feedback
	if not player:
		return

	var horizontal_vel := Vector2(player.velocity.x, player.velocity.z)
	current_horizontal_speed = horizontal_vel.length()

	if current_horizontal_speed > peak_speed:
		peak_speed = current_horizontal_speed


func get_movement_stats() -> Dictionary:
	## Get current movement statistics
	return {
		"horizontal_speed": current_horizontal_speed,
		"peak_speed": peak_speed,
		"is_sliding": is_sliding,
		"slide_cooldown": slide_cooldown_timer,
		"consecutive_bhops": consecutive_jumps,
		"can_slide": can_slide()
	}


func reset_peak_speed() -> void:
	## Reset peak speed tracker
	peak_speed = 0.0
