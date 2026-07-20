class_name RunState
extends State


func enter(_player: CharacterBody3D) -> void:
	## Enter run state
	pass


func physics_update(_delta: float) -> void:
	## Handle running movement and state transitions
	if not player:
		return

	# Get input from input component
	var input_component: Node = player.get_node_or_null("InputComponent")
	if not input_component:
		return

	# Check if we should still be running
	var has_movement_input: bool = input_component.move_vector.length() > 0.1

	if not has_movement_input or not input_component.is_sprinting:
		# Lost movement input or stopped sprinting, go back to walk/idle
		if has_movement_input:
			transition_to("walk")
		else:
			transition_to("idle")
		return

	# Check for jump input
	if input_component.wish_jump:
		transition_to("jump")
		return

	# Check for crouch input (transition to slide)
	if input_component.is_crouching:
		transition_to("slide")
		return

	# Check for dash input (space bar or special key)
	if Input.is_action_just_pressed("dash"):  # Assuming "dash" input action exists
		transition_to("dash")
		return

	# Apply running movement
	_apply_run_movement(input_component.move_vector)


func _apply_run_movement(move_vector: Vector2) -> void:
	## Apply running movement to the player
	# Get movement component for running speed
	var movement_component: Node = player.get_node_or_null("MovementComponent")
	if not movement_component:
		return

	# Calculate movement direction relative to camera
	var camera: Camera3D = player.get_node_or_null("Camera3D")
	if not camera:
		return

	var camera_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = camera_basis.z.normalized()
	var right: Vector3 = camera_basis.x.normalized()

	# Calculate desired velocity
	var desired_velocity: Vector3 = (forward * move_vector.y + right * move_vector.x).normalized()
	desired_velocity *= movement_component.move_speed * movement_component.sprint_multiplier

	# Apply movement (simplified - actual physics handled by MovementComponent)
	player.velocity.x = desired_velocity.x
	player.velocity.z = desired_velocity.z


func get_state_name() -> String:
	return "Run"
