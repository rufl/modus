class_name LocomotionBlendTree
extends Node

## Advanced locomotion animation system with smooth blending
## Handles walking, running, sprinting, crouching, jumping, and directional movement

signal animation_changed(anim_name: String)

enum LocomotionState {
	IDLE,
	WALK,
	JOG,
	SPRINT,
	CROUCH_IDLE,
	CROUCH_MOVE,
	JUMP,
	FALL,
	LAND,
	CRAWL,
	FLY,  # Flying/swimming state for godmode
}

var anim_tree: AnimationTree
var anim_player: AnimationPlayer
var skeleton: Skeleton3D
var visuals: Node3D  # Reference to SkeletalCharacterVisuals for AnimationTree access

# Blend parameters
var move_speed: float = 0.0
var move_direction: Vector2 = Vector2.ZERO
var is_on_ground: bool = true
var is_crouching: bool = false
var is_sprinting: bool = false
var is_flying: bool = false  # Flying/godmode state
var vertical_velocity: float = 0.0

# Thresholds
var walk_threshold: float = 1.0
var jog_threshold: float = 3.0
var sprint_threshold: float = 6.0

# Smoothing
var speed_smoothing: float = 10.0
var direction_smoothing: float = 15.0

# Internal state
var _current_state: LocomotionState = LocomotionState.IDLE
var _smoothed_speed: float = 0.0
var _smoothed_direction: Vector2 = Vector2.ZERO
var _last_ground_time: float = 0.0


func setup(
	player_anim_player: AnimationPlayer,
	player_skeleton: Skeleton3D = null,
	player_visuals: Node3D = null
) -> void:
	anim_player = player_anim_player
	skeleton = player_skeleton
	visuals = player_visuals

	# Check if visuals has AnimationTree for upper/lower body blending
	if visuals and visuals.has_method("get") and "anim_tree" in visuals:
		anim_tree = visuals.anim_tree
		if anim_tree and anim_tree.active:
			var logger: Node = GameManager.get_core_system("logger")
			if logger and logger.has_method("info"):
				logger.info(
					"[LocomotionBlend] Using AnimationTree for upper/lower body blending", "Game"
				)
		else:
			var logger2: Node = GameManager.get_core_system("logger")
			if logger2 and logger2.has_method("info"):
				logger2.info(
					"[LocomotionBlend] AnimationTree not active, using direct AnimationPlayer",
					"Game"
				)
	else:
		var logger3: Node = GameManager.get_core_system("logger")
		if logger3 and logger3.has_method("info"):
			logger3.info(
				"[LocomotionBlend] No AnimationTree available, using direct AnimationPlayer", "Game"
			)

	if anim_player:
		var logger4: Node = GameManager.get_core_system("logger")
		if logger4 and logger4.has_method("info"):
			logger4.info(
				(
					"[LocomotionBlend] Setup complete with AnimationPlayer: "
					+ str(anim_player.get_path())
				),
				"Game"
			)


func _process(delta: float) -> void:
	if not anim_player:
		return

	# Smooth speed and direction
	_smoothed_speed = lerp(_smoothed_speed, move_speed, speed_smoothing * delta)
	_smoothed_direction = _smoothed_direction.lerp(move_direction, direction_smoothing * delta)

	# Update state machine
	_update_state_machine(delta)

	# Apply animations based on state
	_apply_animations()


func _update_state_machine(_delta: float) -> void:
	var new_state := _current_state

	# Track ground time for landing detection
	if is_on_ground:
		_last_ground_time = Time.get_ticks_msec() / 1000.0

	# Flying state (highest priority - godmode/noclip)
	if is_flying:
		new_state = LocomotionState.FLY
	# Airborne states (highest priority)
	elif not is_on_ground:
		if vertical_velocity > 1.0:
			new_state = LocomotionState.JUMP
		elif vertical_velocity < -1.0:
			new_state = LocomotionState.FALL
	# Landing detection
	elif is_on_ground and _current_state in [LocomotionState.JUMP, LocomotionState.FALL]:
		new_state = LocomotionState.LAND
		# Auto-transition out of land after animation
		get_tree().create_timer(0.3).timeout.connect(_exit_land_state, CONNECT_ONE_SHOT)
	# Crouching states
	elif is_crouching:
		if _smoothed_speed > 0.5:
			new_state = LocomotionState.CROUCH_MOVE
		else:
			new_state = LocomotionState.CROUCH_IDLE
	# Ground locomotion
	elif _smoothed_speed < walk_threshold:
		new_state = LocomotionState.IDLE
	elif _smoothed_speed < jog_threshold:
		new_state = LocomotionState.WALK
	elif _smoothed_speed < sprint_threshold or not is_sprinting:
		new_state = LocomotionState.JOG
	else:
		new_state = LocomotionState.SPRINT

	# State change
	if new_state != _current_state:
		_on_state_changed(_current_state, new_state)
		_current_state = new_state


func _on_state_changed(old_state: LocomotionState, new_state: LocomotionState) -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.debug(
			(
				"State changed: %s -> %s"
				% [LocomotionState.keys()[old_state], LocomotionState.keys()[new_state]]
			),
			"LocomotionBlend"
		)


func _exit_land_state() -> void:
	if _current_state == LocomotionState.LAND:
		# Force re-evaluation
		_current_state = LocomotionState.IDLE


func _apply_animations() -> void:
	if not anim_player:
		return

	var target_anim: String = ""
	var blend_time: float = 0.2

	match _current_state:
		LocomotionState.IDLE:
			target_anim = _get_idle_animation()
			blend_time = 0.3

		LocomotionState.WALK:
			target_anim = _get_walk_animation()
			blend_time = 0.2

		LocomotionState.JOG:
			target_anim = _get_jog_animation()
			blend_time = 0.15

		LocomotionState.SPRINT:
			target_anim = _get_sprint_animation()
			blend_time = 0.1

		LocomotionState.CROUCH_IDLE:
			target_anim = "Crouch_Idle"
			blend_time = 0.3

		LocomotionState.CROUCH_MOVE:
			target_anim = _get_crouch_move_animation()
			blend_time = 0.2

		LocomotionState.JUMP:
			target_anim = "Jump_Start"
			blend_time = 0.05

		LocomotionState.FALL:
			target_anim = "Jump"  # Falling/in-air animation
			blend_time = 0.1

		LocomotionState.LAND:
			target_anim = "Jump_Land"
			blend_time = 0.05

		LocomotionState.FLY:
			target_anim = _get_fly_animation()
			blend_time = 0.2

	# Apply animation based on whether we have AnimationTree or not
	if target_anim != "":
		if anim_tree and anim_tree.active and visuals:
			# Use AnimationTree for upper/lower body blending
			_apply_locomotion_to_tree(target_anim)
		else:
			# Fallback to direct AnimationPlayer (no upper/lower body split)
			_apply_locomotion_to_player(target_anim, blend_time)


func _apply_locomotion_to_tree(anim_name: String) -> void:
	## Apply locomotion animation through AnimationTree (preserves upper body)
	if visuals and visuals.has_method("set_locomotion_animation"):
		visuals.set_locomotion_animation(anim_name)
		animation_changed.emit(anim_name)


func _apply_locomotion_to_player(anim_name: String, blend_time: float) -> void:
	## Apply locomotion animation directly to AnimationPlayer (no upper/lower split)
	if anim_player.current_animation != anim_name:
		if anim_player.has_animation(anim_name):
			anim_player.play(anim_name, blend_time)
			animation_changed.emit(anim_name)
		else:
			# Fallback to Idle if animation doesn't exist
			if anim_player.has_animation("Idle"):
				anim_player.play("Idle", blend_time)


func _get_idle_animation() -> String:
	# Could add variety here (Idle, Idle_LookAround, Idle_Tired, etc.)
	return "Idle"


func _get_walk_animation() -> String:
	# Directional walking based on move_direction
	if _smoothed_direction.length() < 0.1:
		return "Walk"

	# Forward/backward
	if abs(_smoothed_direction.y) > abs(_smoothed_direction.x):
		if _smoothed_direction.y < 0:  # Forward
			return "Walk"
		# Backward
		return "Jog_Bwd"  # No Walk_Bwd, use jog
	# Strafe
	if _smoothed_direction.x < 0:  # Left
		return "Jog_Left"
	# Right
	return "Jog_Right"


func _get_jog_animation() -> String:
	# Directional jogging based on move_direction
	if _smoothed_direction.length() < 0.1:
		return "Jog_Fwd"

	# Determine primary direction
	var abs_x: float = abs(_smoothed_direction.x)
	var abs_y: float = abs(_smoothed_direction.y)

	# Forward/backward dominant
	if abs_y > abs_x * 1.5:
		if _smoothed_direction.y < 0:  # Forward
			# Check for diagonal lean
			if abs_x > 0.3:
				if _smoothed_direction.x < 0:
					return "Jog_Fwd_L"
				return "Jog_Fwd_R"
			return "Jog_Fwd"
		# Backward
		if abs_x > 0.3:
			if _smoothed_direction.x < 0:
				return "Jog_Bwd_L"
			return "Jog_Bwd_R"
		return "Jog_Bwd"

	# Strafe dominant
	if abs_x > abs_y * 1.5:
		if _smoothed_direction.x < 0:
			return "Jog_Left"
		return "Jog_Right"

	# Diagonal movement - use forward with lean
	if _smoothed_direction.y < 0:  # Forward diagonal
		if _smoothed_direction.x < 0:
			return "Jog_Fwd_L"
		return "Jog_Fwd_R"
	# Backward diagonal
	if _smoothed_direction.x < 0:
		return "Jog_Bwd_L"
	return "Jog_Bwd_R"


func _get_sprint_animation() -> String:
	# Sprint is always forward-focused
	if anim_player.has_animation("Sprint"):
		return "Sprint"
	return "Jog_Fwd"  # Fallback


func _get_crouch_move_animation() -> String:
	# Directional crouching based on move_direction
	if _smoothed_direction.length() < 0.1:
		return "Crouch_Fwd"

	var abs_x: float = abs(_smoothed_direction.x)
	var abs_y: float = abs(_smoothed_direction.y)

	# Forward/backward
	if abs_y > abs_x * 1.5:
		if _smoothed_direction.y < 0:
			# Forward crouch with diagonal
			if abs_x > 0.3:
				if _smoothed_direction.x < 0:
					return "Crouch_Fwd_L"
				return "Crouch_Fwd_R"
			return "Crouch_Fwd"
		# Backward crouch with diagonal
		if abs_x > 0.3:
			if _smoothed_direction.x < 0:
				return "Crouch_Bwd_L"
			return "Crouch_Bwd_R"
		return "Crouch_Bwd"

	# Strafe
	if _smoothed_direction.x < 0:
		return "Crouch_Left"
	return "Crouch_Right"


func _get_fly_animation() -> String:
	# Use swimming animations for flying (they look similar)
	if _smoothed_speed > 0.5:
		return "Swim_Fwd"  # Moving while flying
	return "Swim_Idle"  # Hovering/floating


## Update locomotion parameters (call from player/enemy)
func update_locomotion(
	speed: float,
	direction: Vector2,
	on_ground: bool,
	crouching: bool,
	sprinting: bool,
	vert_velocity: float,
	flying: bool = false  # New parameter for flying/godmode
) -> void:
	move_speed = speed
	move_direction = direction
	is_on_ground = on_ground
	is_crouching = crouching
	is_sprinting = sprinting
	is_flying = flying
	vertical_velocity = vert_velocity


## Play a one-shot animation (melee, reload, etc.)
func play_oneshot(anim_name: String, blend_time: float = 0.1) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.play(anim_name, blend_time)
		animation_changed.emit(anim_name)


## Get current state for debugging
func get_current_state_name() -> String:
	return LocomotionState.keys()[_current_state]
