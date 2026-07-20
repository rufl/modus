class_name DashState
extends State

var dash_time_left: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO
var dash_count: int = 3  # Available dashes
var is_dashing: bool = false


func enter(_player: CharacterBody3D) -> void:
	## Enter dash state and perform dash
	if not player:
		return

	# Check if we have dashes available
	if dash_count <= 0:
		# No dashes available, transition back
		transition_to("idle")
		return

	# Get dash configuration
	var dash_time: float = 0.11  # Default dash time
	var dash_speed: float = 120.0  # Default dash speed

	# Try to get config from movement component
	var movement_component: Node = player.get_node_or_null("MovementComponent")
	if movement_component:
		# Use movement component properties if available
		dash_time = 0.11
		dash_speed = 120.0

	dash_time_left = dash_time
	is_dashing = true

	# Determine dash direction
	var input_component: Node = player.get_node_or_null("InputComponent")
	if input_component and input_component.move_vector.length() > 0.1:
		# Dash in input direction
		var player_basis: Basis = player.global_transform.basis
		var forward: Vector3 = -player_basis.z.normalized()
		var right: Vector3 = player_basis.x.normalized()
		var input_vec: Vector2 = input_component.move_vector
		dash_direction = (forward * input_vec.y + right * input_vec.x).normalized()
	else:
		# Dash forward
		var camera: Camera3D = player.get_node_or_null("Camera3D")
		if camera:
			dash_direction = -camera.global_transform.basis.z.normalized()

	# Apply dash velocity
	player.velocity = dash_direction * dash_speed

	# Consume a dash
	dash_count -= 1

	# Notify other clients of dash
	if player.is_multiplayer_authority():
		_sync_dash_state.rpc(dash_direction, dash_time_left, dash_count)


@rpc("any_peer", "call_local", "unreliable")
func _sync_dash_state(direction: Vector3, time_left: float, count: int) -> void:
	## Sync dash state across network
	dash_direction = direction
	dash_time_left = time_left
	dash_count = count
	is_dashing = true

	# Apply dash velocity on remote clients
	if not player.is_multiplayer_authority():
		player.velocity = direction * 120.0  # Use same speed


func physics_update(_delta: float) -> void:
	## Handle dash timing and completion
	if not player:
		return

	# Decrease dash time
	dash_time_left -= _delta

	# Check if dash is complete
	if dash_time_left <= 0.0:
		is_dashing = false

		# Transition based on current input
		var input_component: Node = player.get_node_or_null("InputComponent")
		if input_component:
			if input_component.move_vector.length() > 0.1:
				if input_component.is_sprinting:
					transition_to("run")
				else:
					transition_to("walk")
			else:
				transition_to("idle")
		else:
			transition_to("idle")


func exit() -> void:
	## Exit dash state
	is_dashing = false


func get_state_name() -> String:
	return "Dash"


## Public methods for dash management


func can_dash() -> bool:
	## Check if dash is available
	return dash_count > 0


func refill_dash() -> void:
	## Refill dash count (called periodically)
	dash_count = min(dash_count + 1, 3)  # Max 3 dashes


func get_dash_count() -> int:
	## Get current dash count
	return dash_count
