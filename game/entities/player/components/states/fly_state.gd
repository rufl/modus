class_name FlyState
extends State

var fly_speed: float = 20.0
var boost_multiplier: float = 3.0
var boosting: bool = false


func enter(_player: CharacterBody3D) -> void:
	## Enter fly state
	if not player:
		return

	# Set fly speed
	fly_speed = 20.0
	boost_multiplier = 3.0

	# Enable noclip (disable gravity and collisions)
	player.set_collision_layer_value(1, false)  # Disable player layer
	player.set_collision_mask_value(1, false)  # Don't collide with world

	# Reset velocity
	player.velocity = Vector3.ZERO

	# Notify other clients
	if player.is_multiplayer_authority():
		_sync_fly_state.rpc(true)


@rpc("any_peer", "call_local", "reliable")
func _sync_fly_state(flying: bool) -> void:
	## Sync fly state across network
	if flying:
		player.set_collision_layer_value(1, false)
		player.set_collision_mask_value(1, false)
		player.velocity = Vector3.ZERO
	else:
		player.set_collision_layer_value(1, true)
		player.set_collision_mask_value(1, true)


func physics_update(_delta: float) -> void:
	## Handle flying movement
	if not player:
		return

	var input_component: InputComponent = player.get_node_or_null("InputComponent")
	if not input_component:
		return

	# Check for exit flight (jump to exit)
	if input_component.wish_jump:
		exit_flight()
		return

	# Handle movement input
	if input_component.move_vector.length() > 0.1:
		_apply_fly_movement(input_component.move_vector)

	# Handle boost input (sprint key)
	boosting = input_component.is_sprinting
	if boosting:
		fly_speed = 20.0 * boost_multiplier
	else:
		fly_speed = 20.0


func _apply_fly_movement(move_vector: Vector2) -> void:
	## Apply flying movement
	var camera: Camera3D = player.get_node_or_null("Camera3D")
	if not camera:
		return

	var camera_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = camera_basis.z.normalized()
	var right: Vector3 = camera_basis.x.normalized()
	var up: Vector3 = camera_basis.y.normalized()

	# Calculate movement direction
	var move_direction: Vector3 = Vector3.ZERO
	move_direction += forward * move_vector.y  # Forward/backward
	move_direction += right * move_vector.x  # Left/right

	# Handle vertical movement with separate inputs
	var vertical_input: float = 0.0
	if Input.is_action_pressed("jump"):
		vertical_input = 1.0
	if Input.is_action_pressed("crouch"):
		vertical_input = -1.0

	move_direction += up * vertical_input

	# Normalize and apply speed
	if move_direction.length() > 0.0:
		move_direction = move_direction.normalized()
		player.velocity = move_direction * fly_speed
	else:
		player.velocity = Vector3.ZERO


func exit_flight() -> void:
	## Exit flight mode
	# Re-enable collisions
	player.set_collision_layer_value(1, true)
	player.set_collision_mask_value(1, true)

	# Reset velocity
	player.velocity = Vector3.ZERO

	# Notify other clients
	if player.is_multiplayer_authority():
		_sync_fly_state.rpc(false)

	# Transition to appropriate state
	transition_to("idle")


func exit() -> void:
	## Exit fly state
	# Ensure collisions are re-enabled
	player.set_collision_layer_value(1, true)
	player.set_collision_mask_value(1, true)


func get_state_name() -> String:
	return "Fly"


## Public methods


func set_fly_speed(speed: float) -> void:
	## Set flight speed
	fly_speed = speed


func get_fly_speed() -> float:
	## Get current flight speed
	return fly_speed


func is_boosting() -> bool:
	## Check if currently boosting
	return boosting
