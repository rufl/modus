class_name MovementPolishSystem
extends Node

signal landing_impact(velocity: float)
signal footstep_played(surface_type: String)
signal jump_grunt_played
signal slide_started
signal slide_stopped
signal speed_boost_started
signal speed_boost_stopped

@export_group("Landing Impact")
@export var landing_velocity_threshold: float = 5.0
@export var landing_sound_volume: float = -10.0
@export var landing_shake_multiplier: float = 0.05
@export_group("Footsteps")
@export var footstep_interval_walk: float = 0.5
@export var footstep_interval_run: float = 0.35
@export var footstep_interval_crouch: float = 0.7
@export var footstep_volume: float = -30.0  # Lowered from -15.0
@export var footstep_pitch_variation: float = 0.1
@export_group("Jump Sounds")
@export var jump_grunt_volume: float = -12.0
@export var jump_grunt_chance: float = 0.7
@export_group("Slide Sounds")
@export var slide_volume: float = -10.0
@export var slide_min_velocity: float = 3.0
@export_group("Speed Effects")
@export var speed_boost_threshold: float = 10.0
@export var fov_boost_amount: float = 5.0
@export var fov_transition_speed: float = 5.0
@export_group("Camera Tilt")
@export var tilt_angle_max: float = 2.0  # Degrees
@export var tilt_speed: float = 5.0

var player: CharacterBody3D
var camera: Camera3D
var screen_shake: ScreenShakeSystem
var was_on_floor: bool = false
var last_velocity_y: float = 0.0
var footstep_timer: float = 0.0
var is_sliding: bool = false
var is_speed_boosted: bool = false
var base_fov: float = 90.0
var target_fov: float = 90.0
var current_surface_type: String = "default"


# Helper function to safely log messages
func _log(message: String, category: String = "Player") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


func _get_audio_service() -> Node:
	return GameManager.get_core_system("audio")


func _ready() -> void:
	# Get references
	player = get_parent() as CharacterBody3D
	if not player:
		push_error("[MovementPolish] Must be child of CharacterBody3D")
		return

	# Find camera
	camera = _find_camera(player)
	if camera:
		base_fov = camera.fov
		target_fov = base_fov

	# Find screen shake system
	screen_shake = player.get_node_or_null("ScreenShakeSystem") as ScreenShakeSystem

	_log("[MovementPolish] Movement polish system initialized", "Player")


func _process(delta: float) -> void:
	if not player or not camera:
		return

	# Only run on local player authority
	# In single player (no peer), always process for local player
	var is_local: bool = (
		not multiplayer.has_multiplayer_peer()
		or (player.has_method("is_multiplayer_authority") and player.is_multiplayer_authority())
	)
	if not is_local:
		return

	# Update footstep timer
	if footstep_timer > 0.0:
		footstep_timer -= delta

	# Check for landing
	_check_landing()

	# Update slide sounds
	_update_slide_sounds()

	# Update speed effects
	_update_speed_effects(delta)

	# Update camera tilt
	_update_camera_tilt(delta)

	# Store state for next frame
	was_on_floor = player.is_on_floor()
	last_velocity_y = player.velocity.y


func _physics_process(delta: float) -> void:
	if not player:
		return

	# Only run on local player authority
	# In single player (no peer), always process for local player
	var is_local: bool = (
		not multiplayer.has_multiplayer_peer()
		or (player.has_method("is_multiplayer_authority") and player.is_multiplayer_authority())
	)
	if not is_local:
		return

	# Update footsteps (requires raycast, must be in physics process)
	_update_footsteps(delta)


func _check_landing() -> void:
	# Check for landing and trigger impact effects
	if not was_on_floor and player.is_on_floor():
		var landing_velocity: float = abs(last_velocity_y)

		if landing_velocity >= landing_velocity_threshold:
			_trigger_landing_impact(landing_velocity)


func _trigger_landing_impact(velocity: float) -> void:
	# Trigger landing impact effects
	landing_impact.emit(velocity)

	# Screen shake
	if screen_shake:
		screen_shake.add_landing_trauma(velocity, 20.0)

	# Landing sound
	_play_landing_sound(velocity)


func _play_landing_sound(velocity: float) -> void:
	# Play landing sound based on velocity
	var sound_name := "landing_light"
	var volume := landing_sound_volume

	# Determine sound intensity
	if velocity > 15.0:
		sound_name = "landing_heavy"
		volume += 3.0
	elif velocity > 10.0:
		sound_name = "landing_medium"
		volume += 1.5

	# Play sound at player position via AudioManager
	var audio := _get_audio_service()
	if audio and audio.has_method("play_footstep"):
		audio.play_footstep(sound_name, player.global_position, volume)


func _update_footsteps(_delta: float) -> void:
	# Update footstep sounds
	if not player.is_on_floor():
		return

	# Check if moving
	var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z)
	if horizontal_velocity.length() < 0.5:
		return

	# Check footstep timer
	if footstep_timer > 0.0:
		return

	# Determine footstep interval based on movement state
	var interval: float = footstep_interval_walk

	if player.is_sprinting:
		interval = footstep_interval_run
	elif player.is_crouching:
		interval = footstep_interval_crouch

	footstep_timer = interval

	# Detect surface type
	_detect_surface_type()

	# Play footstep sound
	_play_footstep_sound()


func _detect_surface_type() -> void:
	# Detect surface type under player
	# Raycast down to detect surface
	var space_state := player.get_world_3d().direct_space_state
	if not space_state:
		current_surface_type = "concrete"
		return

	var query := PhysicsRayQueryParameters3D.create(
		player.global_position,
		player.global_position + Vector3.DOWN * 2.0,
		0xFFFFFFFF,  # Default mask (all layers) since not specified original
		[player.get_rid()]
	)

	var result := space_state.intersect_ray(query)

	if result:
		var collider: Object = result.get("collider")

		# Try to get material from collider metadata or group
		if collider.has_meta("surface_type"):
			current_surface_type = collider.get_meta("surface_type")
		elif collider.is_in_group("wood"):
			current_surface_type = "wood"
		elif collider.is_in_group("metal"):
			current_surface_type = "metal"
		elif collider.is_in_group("dirt"):
			current_surface_type = "dirt"
		elif collider.is_in_group("grass"):
			current_surface_type = "grass"
		elif collider.is_in_group("concrete"):
			current_surface_type = "concrete"
		else:
			current_surface_type = "concrete"  # Default fallback
	else:
		current_surface_type = "concrete"


func _play_footstep_sound() -> void:
	# Play footstep sound for current surface
	footstep_played.emit(current_surface_type)
	var audio := _get_audio_service()
	if audio and audio.has_method("play_footstep"):
		audio.play_footstep(current_surface_type, player.global_position, footstep_volume)


func _update_slide_sounds() -> void:
	# Update slide sound effects
	if not player.is_on_floor():
		if is_sliding:
			_stop_slide_sound()
		return

	# Check if sliding on steep slope
	# We access player's velocity directly
	var floor_angle: float = player.get_floor_angle()
	var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z)
	var is_moving := horizontal_velocity.length() > slide_min_velocity

	# Start sliding if on steep slope and moving
	# 30 degrees is approx 0.52 rad
	if rad_to_deg(floor_angle) > 30.0 and is_moving:
		if not is_sliding:
			_start_slide_sound()
	else:
		if is_sliding:
			_stop_slide_sound()


func _start_slide_sound() -> void:
	# Start slide sound effect
	is_sliding = true
	slide_started.emit()

	# Play slide loop sound if AudioManager supports it
	var audio := _get_audio_service()
	if audio and audio.has_method("play_sound_at"):
		audio.play_sound_at("slide_start", player.global_position, slide_volume)


func _stop_slide_sound() -> void:
	# Stop slide sound effect
	is_sliding = false
	slide_stopped.emit()

	# Play slide stop sound
	var audio := _get_audio_service()
	if audio and audio.has_method("play_sound_at"):
		audio.play_sound_at("slide_stop", player.global_position, slide_volume)


func _update_speed_effects(delta: float) -> void:
	# Update speed-based visual effects
	if not camera:
		return

	# Get current speed
	var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z)
	# Use get_horizontal_speed if available for consistency
	var speed: float = 0.0
	if player.has_method("get_horizontal_speed"):
		speed = player.get_horizontal_speed()
	else:
		speed = horizontal_velocity.length()

	# Check if speed boosted
	if speed >= speed_boost_threshold:
		if not is_speed_boosted:
			is_speed_boosted = true
			speed_boost_started.emit()
		target_fov = base_fov + fov_boost_amount
	else:
		if is_speed_boosted:
			is_speed_boosted = false
			speed_boost_stopped.emit()
		target_fov = base_fov

	# Smoothly transition FOV
	camera.fov = lerp(camera.fov, target_fov, fov_transition_speed * delta)


func _update_camera_tilt(delta: float) -> void:
	if not camera:
		return

	# Calculate target tilt based on input or lateral velocity
	var target_tilt: float = 0.0

	# Use InputComponent if available via player, otherwise fallback or use velocity
	# Ideally we use input for immediate feedback
	var input_x: float = 0.0
	if player.has_node("InputComponent"):
		var input_comp: Node = player.get_node("InputComponent")
		if "move_vector" in input_comp:
			input_x = input_comp.move_vector.x
	else:
		# Fallback to velocity
		var basis_x: Vector3 = player.global_transform.basis.x
		var velocity_x: float = player.velocity.dot(basis_x)
		input_x = clamp(velocity_x / player.move_speed, -1.0, 1.0)

	target_tilt = -input_x * deg_to_rad(tilt_angle_max)

	# Smoothly interpolate rotation.z
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, tilt_speed * delta)


func _find_camera(node: Node) -> Camera3D:
	# Recursively find camera in node tree
	if node is Camera3D:
		return node

	for child in node.get_children():
		var cam := _find_camera(child)
		if cam:
			return cam

	return null


func play_jump_grunt() -> void:
	## Play jump grunt sound with random chance
	## Call this from player when jumping

	# Random chance to play grunt
	if randf() > jump_grunt_chance:
		return

	jump_grunt_played.emit()

	# Play grunt sound via AudioManager
	var audio := _get_audio_service()
	if audio and audio.has_method("play_sound_at"):
		var pitch := 1.0 + randf_range(-0.1, 0.1)  # Slight pitch variation
		audio.play_sound_at("jump_grunt", player.global_position, jump_grunt_volume, pitch)
	elif audio and audio.has_method("play_footstep"):
		# Fallback to footstep method
		audio.play_footstep("jump", player.global_position, jump_grunt_volume)


func set_base_fov(fov: float) -> void:
	## Set base FOV value
	base_fov = fov
	target_fov = fov
	if camera:
		camera.fov = fov


func get_current_surface_type() -> String:
	## Get current surface type
	return current_surface_type
