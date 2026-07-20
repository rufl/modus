class_name SlideState
extends State

var slide_time_left: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO


func enter(_player: CharacterBody3D) -> void:
	## Enter slide state and initialize slide parameters
	if not player:
		return

	# Get slide configuration
	var slide_time: float = 1.2  # Default slide time
	var slide_speed: float = 12.0  # Default slide speed

	# Try to get config from movement component
	var movement_component: Node = player.get_node_or_null("MovementComponent")
	if movement_component:
		# Use movement component properties if available
		slide_time = 1.2  # Could be configurable
		slide_speed = 12.0  # Could be configurable

	slide_time_left = slide_time
	slide_direction = player.velocity.normalized()

	# Apply initial slide velocity
	player.velocity = slide_direction * slide_speed

	# Notify other clients of slide state
	if player.is_multiplayer_authority():
		_sync_slide_state.rpc(slide_direction, slide_time_left)


@rpc("any_peer", "call_local", "unreliable")
func _sync_slide_state(direction: Vector3, time_left: float) -> void:
	## Sync slide state across network
	slide_direction = direction
	slide_time_left = time_left


func physics_update(_delta: float) -> void:
	## Handle sliding movement and transitions
	if not player:
		return

	# Get input from input component
	var input_component: Node = player.get_node_or_null("InputComponent")
	if not input_component:
		return

	# Check if slide time is up
	if slide_time_left <= 0.0:
		# Transition back to appropriate state
		if input_component.move_vector.length() > 0.1:
			if input_component.is_sprinting:
				transition_to("run")
			else:
				transition_to("walk")
		else:
			transition_to("idle")
		return

	# Apply sliding deceleration
	var deceleration: float = 4.0  # Amount of velocity lost per second
	var current_speed: float = player.velocity.length()
	var new_speed: float = max(0.0, current_speed - deceleration * _delta)

	if new_speed > 0.0:
		player.velocity = player.velocity.normalized() * new_speed
	else:
		player.velocity = Vector3.ZERO

	# Decrease slide time
	slide_time_left -= _delta

	# Allow early exit with jump
	if input_component.wish_jump:
		transition_to("jump")


func get_state_name() -> String:
	return "Slide"
