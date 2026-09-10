class_name WallrunState
extends State

var wall_normal: Vector3 = Vector3.ZERO
var wall_direction: Vector3 = Vector3.ZERO
var wallrun_time_left: float = 0.0
var side: int = 0  # -1 for left, 1 for right
var can_wallrun: bool = true
var last_wall_normal: Vector3 = Vector3.ZERO

# FIXED C-05: Store timer reference for proper cleanup
var _wallrun_cooldown_timer: SceneTreeTimer = null


func enter(_player: CharacterBody3D) -> void:
	## Enter wallrun state
	if not player:
		return

	# Check if wallrunning is enabled
	if not can_wallrun:
		transition_to("inair")
		return

	# Get wallrun configuration
	var wallrun_time: float = 3.5  # Default wallrun time
	var wallrun_speed: float = 18.0  # Default wallrun speed

	# Try to get config from movement component
	var movement_component: Node = player.get_node_or_null("MovementComponent")
	if movement_component:
		wallrun_time = 3.5
		wallrun_speed = 18.0

	wallrun_time_left = wallrun_time

	# Detect wall side and normal
	_detect_wall()

	# Apply wallrun velocity
	var forward_dir: Vector3 = wall_direction.cross(Vector3.UP).normalized()
	if side == -1:  # Left wall
		forward_dir = -forward_dir

	player.velocity = forward_dir * wallrun_speed
	player.velocity.y = 0  # Keep horizontal

	# Notify other clients
	if player.is_multiplayer_authority():
		_sync_wallrun_state.rpc(wall_normal, wall_direction, wallrun_time_left, side)


@rpc("authority", "call_local", "unreliable")
func _sync_wallrun_state(
	w_normal: Vector3, w_direction: Vector3, time_left: float, wall_side: int
) -> void:
	## Sync wallrun state across network
	wall_normal = w_normal
	wall_direction = w_direction
	wallrun_time_left = time_left
	side = wall_side


func _detect_wall() -> void:
	## Detect nearby walls and determine wallrun parameters
	# Check left and right raycasts for walls
	var left_ray: RayCast3D = player.get_node_or_null("LeftWallCheck") as RayCast3D
	var right_ray: RayCast3D = player.get_node_or_null("RightWallCheck") as RayCast3D

	if left_ray and left_ray.is_colliding():
		side = -1
		wall_normal = left_ray.get_collision_normal()
		wall_direction = wall_normal.cross(Vector3.UP).normalized()
	elif right_ray and right_ray.is_colliding():
		side = 1
		wall_normal = right_ray.get_collision_normal()
		wall_direction = wall_normal.cross(Vector3.UP).normalized()
	else:
		# No wall detected, exit wallrun
		transition_to("inair")
		return

	# Check if we can actually wallrun on this wall
	if not _can_wallrun_on_surface(wall_normal):
		transition_to("inair")
		return


func _can_wallrun_on_surface(normal: Vector3) -> bool:
	## Check if the surface is suitable for wallrunning
	# Check slope angle (walls should be mostly vertical)
	var slope_angle: float = normal.angle_to(Vector3.UP)
	var max_wall_angle: float = deg_to_rad(75.0)  # Max 75 degrees from vertical

	return slope_angle >= max_wall_angle


func physics_update(_delta: float) -> void:
	## Handle wallrunning movement and transitions
	if not player:
		return

	# Check if wallrun time is up
	if wallrun_time_left <= 0.0:
		can_wallrun = false
		transition_to("inair")
		return

	# Check if still on wall
	if not _is_still_on_wall():
		transition_to("inair")
		return

	# Check for floor collision (end wallrun)
	var floor_check: RayCast3D = player.get_node_or_null("WallrunFloorCheck") as RayCast3D
	if floor_check and floor_check.is_colliding():
		transition_to("idle")
		return

	# Apply wallrun gravity (reduced)
	var wallrun_gravity: float = -9.8 * 0.006  # Much less gravity while wallrunning
	player.velocity.y += wallrun_gravity

	# Handle input
	var input_component: Node = player.get_node_or_null("InputComponent")
	if input_component:
		# Check for walljump
		if input_component.wish_jump:
			_perform_walljump()
			return

		# Handle movement input during wallrun
		if input_component.move_vector.length() > 0.1:
			_update_wallrun_direction(input_component.move_vector)

	# Decrease wallrun time
	wallrun_time_left -= _delta


func _is_still_on_wall() -> bool:
	## Check if player is still in contact with the wall
	var ray_name: String = "LeftWallCheck" if side == -1 else "RightWallCheck"
	var ray: RayCast3D = player.get_node_or_null(ray_name) as RayCast3D
	if ray:
		return ray.is_colliding()
	return false


func _update_wallrun_direction(move_vector: Vector2) -> void:
	## Update wallrun direction based on input
	var camera: Camera3D = player.get_node_or_null("Camera3D")
	if not camera:
		return

	var camera_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = camera_basis.z.normalized()
	var right: Vector3 = camera_basis.x.normalized()

	var desired_direction: Vector3 = (forward * move_vector.y + right * move_vector.x).normalized()

	# Project onto wall plane
	var wall_plane_normal: Vector3 = wall_normal
	var dot: float = desired_direction.dot(wall_plane_normal)
	var projected_direction: Vector3 = desired_direction - wall_plane_normal * dot
	projected_direction = projected_direction.normalized()

	# Apply to velocity (maintain speed)
	var current_speed: float = player.velocity.length()
	player.velocity = projected_direction * current_speed


func _perform_walljump() -> void:
	## Perform walljump
	var walljump_force: float = 14.0
	var walljump_y_force: float = 8.0

	# Jump away from wall
	var jump_direction: Vector3 = wall_normal + Vector3.UP
	jump_direction = jump_direction.normalized()

	player.velocity = jump_direction * walljump_force
	player.velocity.y = walljump_y_force

	# Disable wallrunning temporarily
	can_wallrun = false

	# Sync walljump
	if player.is_multiplayer_authority():
		_sync_walljump.rpc(wall_normal, walljump_force, walljump_y_force)

	# Transition to in-air
	transition_to("inair")


@rpc("authority", "call_local", "unreliable")
func _sync_walljump(w_normal: Vector3, force: float, y_force: float) -> void:
	## Sync walljump across network
	var jump_direction: Vector3 = w_normal + Vector3.UP
	jump_direction = jump_direction.normalized()

	player.velocity = jump_direction * force
	player.velocity.y = y_force


func exit() -> void:
	## Exit wallrun state
	# Store last wall for cooldown
	last_wall_normal = wall_normal

	# FIXED C-05: Store timer reference and use named method
	if player.is_multiplayer_authority():
		_wallrun_cooldown_timer = player.get_tree().create_timer(0.2)
		_wallrun_cooldown_timer.timeout.connect(_on_wallrun_cooldown_complete)


func _on_wallrun_cooldown_complete() -> void:
	## Called when wallrun cooldown completes
	can_wallrun = true


func _exit_tree() -> void:
	## FIXED C-05: Cleanup signal connections to prevent memory leaks
	if (
		_wallrun_cooldown_timer
		and _wallrun_cooldown_timer.timeout.is_connected(_on_wallrun_cooldown_complete)
	):
		_wallrun_cooldown_timer.timeout.disconnect(_on_wallrun_cooldown_complete)
		_wallrun_cooldown_timer = null


func get_state_name() -> String:
	return "Wallrun"


## Public methods


func enable_wallrun() -> void:
	## Re-enable wallrunning
	can_wallrun = true


func get_wallrun_time_left() -> float:
	## Get remaining wallrun time
	return wallrun_time_left
