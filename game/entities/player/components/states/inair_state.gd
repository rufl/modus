class_name InAirState
extends State


func enter(_player: CharacterBody3D) -> void:
	## Enter in-air state
	pass


func physics_update(_delta: float) -> void:
	## Handle airborne movement and landing detection
	if not player:
		return

	var input_component: Node = player.get_node_or_null("InputComponent")

	# Check if we've landed
	if player.is_on_floor():
		# Landed - transition based on input
		if input_component:
			if input_component.move_vector.length() > 0.1:
				if input_component.is_sprinting:
					transition_to("run")
				else:
					transition_to("walk")
			else:
				transition_to("idle")
		return

	# Check for wallrun opportunity
	if _can_wallrun():
		transition_to("wallrun")
		return

	# Still airborne - apply air control
	if input_component and input_component.move_vector.length() > 0.1:
		_apply_air_control(input_component.move_vector)

	# Check for fly toggle (debug/cheat)
	if Input.is_action_just_pressed("fly"):  # Assuming "fly" input action exists
		transition_to("fly")


func _apply_air_control(move_vector: Vector2) -> void:
	## Apply air control movement
	# Get movement component for air acceleration
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

	# Apply air acceleration (simplified)
	var air_accel: float = movement_component.air_acceleration
	player.velocity.x = move_toward(player.velocity.x, desired_velocity.x, air_accel)
	player.velocity.z = move_toward(player.velocity.z, desired_velocity.z, air_accel)


func _can_wallrun() -> bool:
	## Check if wallrunning is possible from current position
	# Check left and right raycasts for walls
	var left_ray: RayCast3D = player.get_node_or_null("LeftWallCheck") as RayCast3D
	var right_ray: RayCast3D = player.get_node_or_null("RightWallCheck") as RayCast3D

	# If either ray detects a wall, wallrunning is possible
	return (left_ray and left_ray.is_colliding()) or (right_ray and right_ray.is_colliding())


func get_state_name() -> String:
	return "InAir"
