extends GameComponent

const DOUBLE_TAP_WINDOW: float = 0.3

@export var move_speed: float = 7.0
@export var max_speed: float = 14.0
@export var jump_velocity: float = 5.5
@export var ground_acceleration: float = 10.0
@export var ground_friction: float = 6.0
@export var air_acceleration: float = 800.0
@export var air_speed_cap: float = 0.7
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.1
@export var sprint_multiplier: float = 1.5
@export var crouch_multiplier: float = 0.5
@export var max_walkable_slope: float = 30.0
@export var slope_friction_factor: float = 0.3
@export var bob_intensity: float = 0.05
@export var bob_speed: float = 12.0
@export_group("Fall Damage")
@export var fall_damage_enabled: bool = true
@export var min_fall_damage_speed: float = 18.0  ## Approx 15m drop
@export var fall_damage_multiplier: float = 2.0  ## Damage per unit of speed over limit

var player: CharacterBody3D
var input_component: Node  # Typed as Node to avoid cyclic dependency with PlayerInputComponent
var rocket_jump_system: Node = null
var advanced_movement: Node = null
var rope_movement: Node = null
var jump_count: int = 0
var has_double_jump: bool = false
var can_fly: bool = false
var noclip: bool = false
var hit_ground: bool = false  # Tracks if we just landed

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _wish_jump: bool = false
var _last_velocity_y: float = 0.0
var _last_jump_press_time: float = -1.0
var _was_jump_pressed: bool = false


func _ready() -> void:
	# Listen for config reloads
	var cfg: Node = GameManager.get_core_system("config")
	if cfg:
		cfg.config_reloaded.connect(_load_config)


func setup(
	p_player: CharacterBody3D,
	p_input: Node,
	p_rocket: Node = null,
	p_adv: Node = null,
	p_rope: Node = null
) -> void:
	player = p_player
	input_component = p_input
	rocket_jump_system = p_rocket
	advanced_movement = p_adv
	rope_movement = p_rope

	_load_config()


func _load_config(_file_path: String = "") -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		return

	# Load balance settings
	move_speed = cfg.get_value("balance.player.base_speed", move_speed)
	jump_velocity = cfg.get_value("balance.player.jump_height", jump_velocity)
	ground_acceleration = cfg.get_value("balance.player.ground_acceleration", 10.0)
	ground_friction = cfg.get_value("balance.player.ground_friction", 6.0)
	air_acceleration = cfg.get_value("balance.player.air_acceleration", 800.0)
	air_speed_cap = cfg.get_value("balance.player.air_speed_cap", 0.7)
	sprint_multiplier = cfg.get_value("balance.player.sprint_multiplier", 1.5)
	crouch_multiplier = cfg.get_value("balance.player.crouch_multiplier", 0.5)

	# Fall damage
	fall_damage_enabled = cfg.get_value("fall_death.show_warning_ui", true)


func process_physics(delta: float) -> void:
	if not player or not input_component:
		return

	# Input State
	var is_crouching: bool = input_component.is_crouching
	var is_sprinting: bool = input_component.is_sprinting and not is_crouching
	var input_dir: Vector2 = input_component.move_vector
	var wish_input_jump: bool = input_component.wish_jump

	# Sync state from player (fix for powerup compatibility)
	if player and "has_double_jump" in player:
		has_double_jump = player.has_double_jump

	# --- Double Tap to Fly ---
	# Detect rising edge (Just Pressed)
	if wish_input_jump and not _was_jump_pressed:
		var current_time: float = Time.get_ticks_msec() / 1000.0
		if _last_jump_press_time > 0 and (current_time - _last_jump_press_time) < DOUBLE_TAP_WINDOW:
			# Double tap detected
			if _try_toggle_fly_mode():
				# Consume input to prevent jump/bunnyhop on toggle
				wish_input_jump = false
				# Reset tap timer to prevent triple-tap behaving weirdly
				_last_jump_press_time = -1.0
			else:
				# Valid double tap but not allowed to fly -> just update time
				_last_jump_press_time = current_time
		else:
			# First tap
			_last_jump_press_time = current_time

	_was_jump_pressed = wish_input_jump

	# Wish Direction
	var wish_dir := (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Speed Modifiers
	var speed_mod: float = 1.0
	if is_crouching:
		speed_mod = crouch_multiplier
	elif is_sprinting:
		speed_mod = sprint_multiplier

	# Ground Status
	var on_floor: bool = player.is_on_floor()
	if on_floor:
		_coyote_timer = coyote_time
		if not hit_ground:
			hit_ground = true
			_handle_fall_damage()
			jump_count = 0
	else:
		_coyote_timer -= delta
		hit_ground = false

	# Jump Buffering
	if wish_input_jump:
		# Simple buffer: reset timer if button is held/pressed
		# Note: "wish_jump" from input is usually polled "is_action_pressed".
		# We might want "just_pressed" tracked in input component for cleaner buffer.
		# For now, we mimic original behavior:
		_jump_buffer_timer = jump_buffer_time
		_wish_jump = true
	else:
		_jump_buffer_timer -= delta
		if _jump_buffer_timer <= 0:
			_wish_jump = false

	# Jump Logic
	var can_jump: bool = (_coyote_timer > 0 or on_floor) and not is_crouching

	if _wish_jump:
		if can_jump:
			_perform_jump()
		elif has_double_jump and jump_count < 2:  # Double jump
			_perform_jump(true)
		elif rope_movement and rope_movement.can_grab:
			rope_movement.attach_to_rope()

	# Gravity
	if not on_floor and not can_fly:  # And not climbing/swimming (handled by player/rope outside)
		player.velocity += player.get_gravity() * delta

	# Slide Logic
	if on_floor and is_crouching and advanced_movement:
		if advanced_movement.has_method("try_start_slide"):
			advanced_movement.try_start_slide(player.velocity, wish_dir)

	# Movement Logic
	if can_fly:
		_fly_move(wish_dir, delta, speed_mod)
	elif on_floor:
		if advanced_movement and "is_sliding" in advanced_movement and advanced_movement.is_sliding:
			player.velocity = advanced_movement.apply_slide_movement(player.velocity, delta)
			player.velocity = advanced_movement.apply_slope_physics(player.velocity, delta)
		else:
			_ground_move(wish_dir, delta, speed_mod)
	elif advanced_movement:
		# If advanced movement module exists, delegate air movement
		player.velocity = advanced_movement.apply_air_movement(
			player.velocity, input_dir, wish_dir, delta
		)
	else:
		_air_move(wish_dir, delta)

	# Note: Slope handling is implicit in move_and_slide via CharacterBody3D settings,
	# but custom slide/friction can be added here if needed.

	# Track velocity for next frame to detect landing impact speed.
	# Godot's move_and_slide updates velocity, so we track Y from the previous frame
	# to know how fast we were falling before hitting the ground.
	# The player.velocity is modified here by air/ground move functions.

	_last_velocity_y = player.velocity.y


func _try_toggle_fly_mode() -> bool:
	# Check for permission (God Mode or already flying to toggle off?)
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var is_god: bool = false
	if gs and gs.match_service and gs.match_service.has_method("is_godmode_active"):
		is_god = gs.match_service.is_godmode_active()

	# Allow toggle if God Mode is on.
	# Allow toggle if God Mode is on.
	# Also allow toggling OFF if we are currently flying
	# (even if godmode oddly turned off, though unlikely)
	if is_god or can_fly:
		can_fly = not can_fly

		# Feedback
		if player.get("is_multiplayer_authority") and player.is_multiplayer_authority():
			var status: String = "Flight ON" if can_fly else "Flight OFF"
			GameManager.get_core_system("logger").info(
				"[Player] %s (Double Tap)" % status, "PlayerMovement"
			)

		# Reset velocity if stopping flight to avoid massive stored momentum issues?
		# Actually, keeping momentum can be fun.
		if can_fly:
			player.velocity.y = 0  # Hover immediately on start

		return true

	return false


# --- Helpers ---


func _perform_jump(is_double: bool = false) -> void:
	if advanced_movement and advanced_movement.has_method("try_bunny_hop"):
		player.velocity = advanced_movement.try_bunny_hop(player.velocity, jump_velocity)
	else:
		player.velocity.y = jump_velocity

	if is_double:
		player.velocity.y = jump_velocity  # Force vertical

	jump_count += 1
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_wish_jump = false


# --- Fall Damage ---


func _handle_fall_damage() -> void:
	if not fall_damage_enabled:
		return

	# _last_velocity_y is negative when falling.
	# We want the speed, so flipped or abs.
	var landing_speed: float = -_last_velocity_y

	if landing_speed < min_fall_damage_speed:
		return

	var excess_speed: float = landing_speed - min_fall_damage_speed
	var damage: float = excess_speed * fall_damage_multiplier

	if damage <= 0:
		return

	# Apply damage
	# We need to construct a DamageInfo.
	# We need to construct a DamageInfo.
	# Note: DamageInfo is a class_name so it is globally available.
	var dmg_info := DamageInfo.new()
	dmg_info.base_amount = damage
	dmg_info.damage_type = DamageInfo.DamageType.FALL
	dmg_info.source_id = -1  # Environment
	dmg_info.weapon_id = "fall"  # For death messages

	if player and player.get("health_component"):
		player.health_component.take_damage(dmg_info)

		# Optional: Screen shake or sound effect for heavy landing
		if damage > 20 and player.get("screen_shake"):
			player.screen_shake.add_landing_trauma(landing_speed)


func _ground_move(wish_dir: Vector3, delta: float, speed_mod: float = 1.0) -> void:
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	var final_speed: float = move_speed * speed_mod

	# Friction
	if speed > 0:
		var drop := speed * ground_friction * delta
		var friction_scale := maxf(speed - drop, 0) / speed
		player.velocity.x *= friction_scale
		player.velocity.z *= friction_scale

	_accelerate(wish_dir, final_speed, ground_acceleration, delta)


func _air_move(wish_dir: Vector3, delta: float) -> void:
	var accel: float = air_acceleration
	if rocket_jump_system and rocket_jump_system.has_method("get_air_control_modifier"):
		accel *= rocket_jump_system.get_air_control_modifier()
	_accelerate(wish_dir, air_speed_cap, accel, delta)


func _fly_move(wish_dir: Vector3, delta: float, speed_mod: float = 1.0) -> void:
	const FLY_SPEED: float = 15.0
	const FLY_ACCEL: float = 8.0
	const FLY_FRICTION: float = 3.0

	var fly_speed: float = FLY_SPEED * speed_mod

	var vertical_dir: float = 0.0
	if input_component.wish_jump:
		vertical_dir = 1.0
	elif input_component.is_crouching or input_component.is_sprinting:
		vertical_dir = -1.0

	var full_wish_dir: Vector3 = wish_dir + Vector3(0, vertical_dir, 0)
	if full_wish_dir.length() > 0.1:
		full_wish_dir = full_wish_dir.normalized()

	if full_wish_dir.length() < 0.1:
		player.velocity = player.velocity.lerp(Vector3.ZERO, FLY_FRICTION * delta)
	else:
		var target_vel: Vector3 = full_wish_dir * fly_speed
		player.velocity = player.velocity.lerp(target_vel, FLY_ACCEL * delta)


func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir.length() < 0.1:
		return
	var current_speed := player.velocity.x * wish_dir.x + player.velocity.z * wish_dir.z
	var add_speed := wish_speed - current_speed
	if add_speed <= 0:
		return
	var accel_speed := accel * delta * wish_speed
	if accel_speed > add_speed:
		accel_speed = add_speed
	player.velocity.x += accel_speed * wish_dir.x
	player.velocity.z += accel_speed * wish_dir.z
