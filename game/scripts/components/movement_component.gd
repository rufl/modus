class_name MovementComponent
extends Node3D

signal destination_reached
signal movement_stuck

@export var speed: float = 4.0
@export var acceleration: float = 10.0
@export var rotation_speed: float = 10.0
@export var can_jump: bool = false
@export var jump_height: float = 2.0
@export var gravity: float = 20.0
@export var can_dash: bool = false
@export var dash_speed: float = 15.0
@export var dash_cooldown: float = 3.0

var nav_agent: NavigationAgent3D
var blocked_timer: float = 0.0

var _dash_timer: float = 0.0
var _is_dashing: bool = false
var _dash_duration: float = 0.2
var _dash_time_left: float = 0.0
var _dash_velocity: Vector3 = Vector3.ZERO
var _parent_body: CharacterBody3D
var _target_pos: Vector3 = Vector3.ZERO
var _is_moving: bool = false


func _ready() -> void:
	_parent_body = get_parent()
	if not _parent_body:
		push_warning("MovementComponent needs a CharacterBody3D parent")
		set_physics_process(false)
		return

	nav_agent = NavigationAgent3D.new()
	add_child(nav_agent)
	nav_agent.path_desired_distance = 1.0
	nav_agent.target_desired_distance = 1.0
	nav_agent.avoidance_enabled = true

	# Listen to navigation signals
	# SIGNAL HYGIENE: Use named method instead of lambda
	nav_agent.target_reached.connect(_on_target_reached)
	nav_agent.link_reached.connect(_on_link_reached)

	# Setup navigation after NavigationServer is ready
	call_deferred("_setup_navigation")


func _on_target_reached() -> void:
	## Called when navigation target is reached
	destination_reached.emit()


func _on_link_reached(details: Dictionary) -> void:
	## Called when navigation link is reached (e.g., jump points)
	if not can_jump:
		return

	# Check if link requires jumping (e.g., vertical difference)
	var link_exit: Vector3 = details.position_out
	var link_enter: Vector3 = details.position_in

	# If target is higher, jump
	if link_exit.y > link_enter.y + 0.5:
		jump(jump_height)


func _exit_tree() -> void:
	## SIGNAL HYGIENE: Cleanup signal connections to prevent memory leaks
	if nav_agent:
		if nav_agent.target_reached.is_connected(_on_target_reached):
			nav_agent.target_reached.disconnect(_on_target_reached)
		if nav_agent.link_reached.is_connected(_on_link_reached):
			nav_agent.link_reached.disconnect(_on_link_reached)


func _setup_navigation() -> void:
	## Validate NavigationServer is ready before using navigation
	## This prevents crashes from using navigation before server sync

	# Wait for physics frames to ensure NavigationServer is synced
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Validate NavigationServer has maps
	if NavigationServer3D.get_maps().size() == 0:
		var parent_name: String = "unknown"
		if _parent_body:
			parent_name = _parent_body.name
		push_warning(
			(
				"[MovementComponent] NavigationServer has no maps - navigation disabled for %s"
				% parent_name
			)
		)
		return

	# Validate nav_agent is properly configured
	if not nav_agent or not nav_agent.is_inside_tree():
		var parent_name: String = "unknown"
		if _parent_body:
			parent_name = _parent_body.name
		push_error("[MovementComponent] NavigationAgent3D not ready for %s" % parent_name)
		return

	# Navigation is now ready to use
	# Debug logging removed - navigation setup is silent unless errors occur


## Configures the component from a dictionary of movement parameters.


func configure(config: Dictionary) -> void:
	if "move_speed" in config:
		speed = config.move_speed
	# if "acceleration" in config: acceleration = config.acceleration


## Configures the component with a single speed value.
## [param move_speed]: The movement speed in units per second.


func configure_from_data(move_speed: float) -> void:
	speed = move_speed


## Configures advanced movement capabilities (jump, dash) from a dictionary.


func configure_advanced(data: Dictionary) -> void:
	if "can_jump" in data:
		can_jump = data.can_jump
	if "jump_height" in data:
		jump_height = data.jump_height
	if "can_dash" in data:
		can_dash = data.can_dash
	if "dash_speed" in data:
		dash_speed = data.dash_speed
	if "dash_cooldown" in data:
		dash_cooldown = data.dash_cooldown


## Initiates a jump if the parent body is on the floor.
## [param height]: The desired jump height in units.


func jump(height: float) -> void:
	if _parent_body and _parent_body.is_on_floor():
		# v = sqrt(2 * g * h)
		var jump_vel: float = sqrt(2.0 * gravity * height)
		_parent_body.velocity.y = jump_vel


## Initiates a horizontal dash in the given direction.
## [param direction]: The direction vector for the dash.


func dash(direction: Vector3) -> void:
	if not can_dash or _dash_timer > 0.0:
		return

	_is_dashing = true
	_dash_time_left = _dash_duration
	_dash_timer = dash_cooldown
	_dash_velocity = direction.normalized() * dash_speed
	_dash_velocity.y = 0  # Keep dash horizontal primarily

	# EventBus for dash effect?


func set_target_position(pos: Vector3) -> void:
	_target_pos = pos
	if _parent_body and _parent_body.global_position.distance_squared_to(pos) <= 0.01:
		stop()
		destination_reached.emit()
		return

	_is_moving = true
	nav_agent.target_position = pos


func stop() -> void:
	_is_moving = false
	_is_dashing = false
	_dash_time_left = 0.0
	_dash_velocity = Vector3.ZERO
	if _parent_body:
		_parent_body.velocity.x = 0.0
		_parent_body.velocity.z = 0.0
		if nav_agent:
			nav_agent.target_position = _parent_body.global_position


func _physics_process(delta: float) -> void:
	# Don't process if navigation isn't ready yet
	if not nav_agent or not is_instance_valid(nav_agent):
		return

	if not _is_moving:
		return

	# Dash Cooldown
	if _dash_timer > 0.0:
		_dash_timer -= delta

	# Dash Execution
	if _is_dashing:
		_dash_time_left -= delta
		if _dash_time_left <= 0.0:
			_is_dashing = false
			_parent_body.velocity = Vector3.ZERO  # Stop dash momentum? Or decay?
		else:
			_parent_body.velocity = _dash_velocity
			move_and_slide_proxy()
			return

	# If we are close enough or navigation finished
	if nav_agent.is_navigation_finished():
		stop()
		destination_reached.emit()
		return

	var next_path_pos: Vector3 = nav_agent.get_next_path_position()
	var current_pos: Vector3 = _parent_body.global_position

	# Stuck detection
	if _parent_body.velocity.length_squared() < 0.1:
		blocked_timer += delta
		if blocked_timer > 1.0:
			blocked_timer = 0.0
			movement_stuck.emit()
			var gm: Node = get_node_or_null("/root/GameManager")
			if gm:
				gm.emit_event("ai_movement_stuck", {"unit": _parent_body})
			# Optional: Automatic repath or stop?
	else:
		blocked_timer = 0.0

	var dir: Vector3 = (next_path_pos - current_pos).normalized()
	dir.y = 0  # Keep movement horizontal for now (extend for flying later)

	# Velocity update
	var target_vel: Vector3 = dir * speed
	var current_vel: Vector3 = _parent_body.velocity
	current_vel.y = 0  # Ignore gravity for horiz smoothing

	var new_vel: Vector3 = current_vel.move_toward(target_vel, acceleration * delta)

	# Apply gravity manually here or let parent handle it?
	# Usually better to let component calculate DESIRED velocity and parent apply
	# it with gravity. But for encapsulation, let's write to a public variable
	# the parent can use, or apply directly x/z

	_parent_body.velocity.x = new_vel.x
	_parent_body.velocity.z = new_vel.z

	# NOTE: Gravity is handled by the parent CharacterBody3D in _physics_process
	# Do NOT apply gravity here to avoid double-application which causes flying enemies

	# Direct rotation
	if dir.length_squared() > 0.01:
		var target_rot: float = atan2(dir.x, dir.z)
		var current_rot: float = _parent_body.rotation.y
		_parent_body.rotation.y = lerp_angle(current_rot, target_rot, rotation_speed * delta)

	# Avoidance
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(_parent_body.velocity)


# Call this from parent _physics_process if using avoidance


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if _is_dashing:
		return  # Ignore avoidance during dash
	_parent_body.velocity.x = safe_velocity.x
	_parent_body.velocity.z = safe_velocity.z


func move_and_slide_proxy() -> void:
	# Wrapper to call move_and_slide on parent if needed,
	# but usually parent calls it in their physics process.
	# Here we just set velocity.
	pass
