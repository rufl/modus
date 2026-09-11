class_name WalkState
extends State


func enter(_player: CharacterBody3D) -> void:
	## Enter walk state
	# Walk speed is applied by physics_update from the current input.
	pass


func physics_update(_delta: float) -> void:
	## Handle walking movement and state transitions
	if not player:
		return

	# Get input from input component
	var input_component: Node = player.get_node_or_null("InputComponent")
	if not input_component:
		return

	# Check if we should still be walking
	var has_movement_input: bool = input_component.move_vector.length() > 0.1

	if not has_movement_input:
		# No movement input, go back to idle
		transition_to("idle")
		return

	# Check for sprint input (transition to run)
	if input_component.is_sprinting:
		transition_to("run")
		return

	# Check for jump input
	if input_component.wish_jump:
		transition_to("jump")
		return

	# Check for crouch input
	if input_component.is_crouching:
		transition_to("crouch")
		return

	# Check for dash input
	if Input.is_action_just_pressed("dash"):
		transition_to("dash")
		return

	# Check for fly toggle (debug/cheat)
	if Input.is_action_just_pressed("fly"):
		transition_to("fly")
		return

	# Apply walking movement
	_apply_walk_movement(input_component.move_vector)


func _apply_walk_movement(move_vector: Vector2) -> void:
	## Apply walking movement to the player
	# Get movement component for walking speed
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
	desired_velocity *= movement_component.get_effective_move_speed()

	# Apply movement (simplified - actual physics handled by MovementComponent)
	player.velocity.x = desired_velocity.x
	player.velocity.z = desired_velocity.z


func get_state_name() -> String:
	return "Walk"
