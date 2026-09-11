class_name CrouchState
extends State


func enter(_player: CharacterBody3D) -> void:
	## Enter crouch state
	# CameraComponent observes player.is_crouching and owns height interpolation.
	pass


func exit() -> void:
	## Exit crouch state
	# CameraComponent observes player.is_crouching and restores height on transition.
	pass


func physics_update(_delta: float) -> void:
	## Handle crouching movement and state transitions
	if not player:
		return

	# Get input from input component
	var input_component: Node = player.get_node_or_null("InputComponent")
	if not input_component:
		return

	# Check if we should still be crouching
	if not input_component.is_crouching:
		# Stopped crouching, transition based on movement
		if input_component.move_vector.length() > 0.1:
			if input_component.is_sprinting:
				transition_to("run")
			else:
				transition_to("walk")
		else:
			transition_to("idle")
		return

	# Check for jump input
	if input_component.wish_jump:
		transition_to("jump")
		return

	# Apply crouching movement
	if input_component.move_vector.length() > 0.1:
		_apply_crouch_movement(input_component.move_vector)


func _apply_crouch_movement(move_vector: Vector2) -> void:
	## Apply crouching movement to the player
	# Get movement component for crouch speed
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
	desired_velocity *= (
		movement_component.get_effective_move_speed() * movement_component.crouch_multiplier
	)

	# Apply movement (simplified - actual physics handled by MovementComponent)
	player.velocity.x = desired_velocity.x
	player.velocity.z = desired_velocity.z


func get_state_name() -> String:
	return "Crouch"
