class_name JumpState
extends State


func enter(_player: CharacterBody3D) -> void:
	## Enter jump state and apply jump impulse
	if not player:
		return

	# Get movement component for jump velocity
	var movement_component: Node = player.get_node_or_null("MovementComponent")
	if movement_component:
		# Apply upward velocity for jump
		player.velocity.y = movement_component.jump_velocity

	# Immediately transition to in-air state
	transition_to("inair")


func get_state_name() -> String:
	return "Jump"
