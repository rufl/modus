class_name IdleState
extends State


func enter(_player: CharacterBody3D) -> void:
	## Enter idle state
	# Idle has no entry side effects; its physics callback handles transitions.
	pass


func physics_update(_delta: float) -> void:
	## Check for state transitions
	if not player:
		return

	# Get input from input component
	var input_component: Node = player.get_node_or_null("InputComponent")
	if not input_component:
		return

	# Check for movement input
	if input_component.move_vector.length() > 0.1:
		# Check if sprinting
		if input_component.is_sprinting:
			transition_to("run")
		else:
			transition_to("walk")

	# Check for jump input
	if input_component.wish_jump:
		transition_to("jump")

	# Check for crouch input
	if input_component.is_crouching:
		transition_to("crouch")

	# Check for dash input
	if Input.is_action_just_pressed("dash"):
		transition_to("dash")

	# Check for fly toggle (debug/cheat)
	if Input.is_action_just_pressed("fly"):
		transition_to("fly")


func get_state_name() -> String:
	return "Idle"
