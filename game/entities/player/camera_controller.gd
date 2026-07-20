class_name CameraController
extends Node3D

signal camera_mode_changed(new_mode: CameraMode)

enum CameraMode { FIRST_PERSON, THIRD_PERSON, OVER_SHOULDER }

@export var current_mode: CameraMode = CameraMode.FIRST_PERSON
@export var transition_speed: float = 10.0
@export var min_zoom_distance: float = 1.5
@export var max_zoom_distance: float = 5.0
@export var zoom_step: float = 0.5
@export var pitch_limit_up: float = 80.0
@export var pitch_limit_down: float = 80.0
@export var camera_smoothing: float = 0.1
@export var camera_lag_enabled: bool = true
@export var camera_shake_enabled: bool = true
@export var shake_decay: float = 5.0
@export var camera_bob_enabled: bool = false
@export var bob_frequency: float = 2.0
@export var bob_amplitude: float = 0.05
@export var fps_sensitivity_multiplier: float = 1.0
@export var tps_sensitivity_multiplier: float = 0.8
@export var ots_sensitivity_multiplier: float = 0.9
@export var third_person_player_transparency: float = 0.4  # 0.0 = invisible, 1.0 = opaque

var mode_configs: Dictionary = {}
var current_zoom_offset: float = 0.0
var shake_strength: float = 0.0
var shake_offset: Vector3 = Vector3.ZERO
var bob_time: float = 0.0
var is_moving: bool = false
var camera: Camera3D = null
var spring_arm: SpringArm3D = null
var spring_camera: Camera3D = null
var player_visuals: Node3D = null  # Reference to player visuals for transparency


func _ready() -> void:
	_setup_mode_configurations()
	_setup_camera_nodes()
	_find_player_visuals()
	_apply_camera_mode(current_mode, true)


func _process(delta: float) -> void:
	# Debug: Check if CameraController rotation is being changed
	if abs(rotation.x) > 0.001 or abs(rotation.y) > 0.001 or abs(rotation.z) > 0.001:
		var logger: Node = GameManager.get_core_system("logger")
		if logger:
			logger.info("[CameraController] Rotation: " + " " + str(rotation), "Player")

	# Update camera shake
	if shake_strength > 0.0:
		_update_camera_shake(delta)

	# Update camera bob
	if camera_bob_enabled and current_mode == CameraMode.FIRST_PERSON and is_moving:
		_update_camera_bob(delta)


func _input(event: InputEvent) -> void:
	# Handle zoom with scroll wheel (only in third-person modes)
	if current_mode != CameraMode.FIRST_PERSON:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				adjust_zoom(-zoom_step)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				adjust_zoom(zoom_step)


func _setup_mode_configurations() -> void:
	## Initialize camera mode configurations
	# First-person mode: Camera at eye level (1.55m), FOV 90,
	# slightly forward and down for better body alignment
	mode_configs[CameraMode.FIRST_PERSON] = {
		"distance": 0.0,
		"offset": Vector3(0.0, -0.15, -0.15),  # Lower and slightly forward
		"fov": 90.0,
		"use_spring_arm": false,
		"base_distance": 0.0,
		"crosshair_offset": Vector2.ZERO,
		"sensitivity_multiplier": fps_sensitivity_multiplier,
		"shake_multiplier": 1.0,
		"recoil_multiplier": 1.0
	}

	# Third-person mode: Camera behind player (3m back, 1.5m up), FOV 75
	mode_configs[CameraMode.THIRD_PERSON] = {
		"distance": 3.0,
		"offset": Vector3(0.0, 1.5, 0.0),
		"fov": 75.0,
		"use_spring_arm": true,
		"base_distance": 3.0,
		"crosshair_offset": Vector2.ZERO,
		"sensitivity_multiplier": tps_sensitivity_multiplier,
		"shake_multiplier": 0.7,
		"recoil_multiplier": 0.8
	}

	# Over-shoulder mode: Camera offset right (0.5m right, 1.8m up, 2m back), FOV 80
	mode_configs[CameraMode.OVER_SHOULDER] = {
		"distance": 2.0,
		"offset": Vector3(0.5, 1.8, 0.0),
		"fov": 80.0,
		"use_spring_arm": true,
		"base_distance": 2.0,
		"crosshair_offset": Vector2(50.0, 0.0),  # Offset from center for shoulder view
		"sensitivity_multiplier": ots_sensitivity_multiplier,
		"shake_multiplier": 0.85,
		"recoil_multiplier": 0.9
	}


func _setup_camera_nodes() -> void:
	## Create and configure camera nodes
	# Try to find existing camera
	camera = get_node_or_null("Camera3D") as Camera3D

	# Create first-person camera if it doesn't exist
	if not camera:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
		camera.position = Vector3(0, 1.55, 0)  # Eye level at 1.55m (lowered for better view)

	# Try to find existing spring arm
	spring_arm = get_node_or_null("SpringArm3D") as SpringArm3D

	# Create spring arm for third-person modes if it doesn't exist
	if not spring_arm:
		spring_arm = SpringArm3D.new()
		spring_arm.name = "SpringArm3D"
		add_child(spring_arm)
		spring_arm.position = Vector3(0, 1.6, 0)
		spring_arm.spring_length = 3.0
		spring_arm.collision_mask = 1  # Collide with world geometry

		# Configure spring arm smoothing
		if camera_lag_enabled:
			spring_arm.margin = 0.1

		# Create camera for spring arm
		spring_camera = Camera3D.new()
		spring_camera.name = "Camera3D"
		spring_arm.add_child(spring_camera)
	else:
		spring_camera = spring_arm.get_node_or_null("Camera3D") as Camera3D


func _apply_camera_mode(mode: CameraMode, instant: bool = false) -> void:
	## Apply camera mode configuration
	var config: Dictionary = mode_configs[mode]

	if config["use_spring_arm"]:
		# Use spring arm camera for third-person modes
		if camera:
			camera.current = false
		if spring_camera:
			spring_camera.current = true

		# Configure spring arm
		if spring_arm:
			spring_arm.spring_length = config["distance"]
			spring_arm.position = Vector3(0, 1.6, 0) + config["offset"]

		# Animate FOV
		if spring_camera:
			if instant:
				spring_camera.fov = config["fov"]
			else:
				_animate_fov(spring_camera, config["fov"])
	else:
		# Use direct camera for first-person
		if spring_camera:
			spring_camera.current = false
		if camera:
			camera.current = true

		# Configure camera
		if camera:
			camera.position = Vector3(0, 1.55, 0) + config["offset"]  # Eye level at 1.55m

			# Animate FOV
			if instant:
				camera.fov = config["fov"]
			else:
				_animate_fov(camera, config["fov"])


func _animate_fov(target_camera: Camera3D, target_fov: float) -> void:
	## Smoothly animate camera FOV
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(target_camera, "fov", target_fov, 0.3)


func set_camera_mode(mode: CameraMode) -> void:
	## Change camera mode with smooth transition
	if mode == current_mode:
		return

	current_mode = mode
	_apply_camera_mode(mode, false)
	_update_player_transparency(mode)
	camera_mode_changed.emit(mode)


func cycle_camera_mode() -> void:
	## Cycle through camera modes
	var next_mode: CameraMode
	match current_mode:
		CameraMode.FIRST_PERSON:
			next_mode = CameraMode.THIRD_PERSON
		CameraMode.THIRD_PERSON:
			next_mode = CameraMode.OVER_SHOULDER
		CameraMode.OVER_SHOULDER:
			next_mode = CameraMode.FIRST_PERSON
		_:
			next_mode = CameraMode.FIRST_PERSON

	set_camera_mode(next_mode)


func get_active_camera() -> Camera3D:
	## Get the currently active camera
	if current_mode == CameraMode.FIRST_PERSON:
		return camera
	return spring_camera


func get_camera_mode() -> CameraMode:
	## Get the current camera mode
	return current_mode


func adjust_zoom(delta: float) -> void:
	## Adjust camera zoom distance (for third-person modes)
	if current_mode == CameraMode.FIRST_PERSON:
		return

	var config: Dictionary = mode_configs[current_mode]
	var base_distance: float = config["base_distance"]

	# Calculate new zoom offset
	current_zoom_offset = clamp(
		current_zoom_offset + delta,
		min_zoom_distance - base_distance,
		max_zoom_distance - base_distance
	)

	# Apply new distance
	if spring_arm:
		spring_arm.spring_length = base_distance + current_zoom_offset


func apply_pitch_limits(camera_rotation: Vector3) -> Vector3:
	## Apply pitch limits to prevent gimbal lock
	camera_rotation.x = clamp(camera_rotation.x, -pitch_limit_down, pitch_limit_up)
	return camera_rotation


func set_pitch_limits(up: float, down: float) -> void:
	## Set custom pitch limits
	pitch_limit_up = up
	pitch_limit_down = down


func reset_zoom() -> void:
	## Reset zoom to default for current mode
	current_zoom_offset = 0.0
	if current_mode != CameraMode.FIRST_PERSON and spring_arm:
		var config: Dictionary = mode_configs[current_mode]
		spring_arm.spring_length = config["base_distance"]


func get_crosshair_offset() -> Vector2:
	## Get crosshair offset for current camera mode
	var config: Dictionary = mode_configs[current_mode]
	return config.get("crosshair_offset", Vector2.ZERO)


func get_sensitivity_multiplier() -> float:
	## Get aim sensitivity multiplier for current camera mode
	var config: Dictionary = mode_configs[current_mode]
	return config.get("sensitivity_multiplier", 1.0)


func get_shake_multiplier() -> float:
	## Get camera shake intensity multiplier for current camera mode
	var config: Dictionary = mode_configs[current_mode]
	return config.get("shake_multiplier", 1.0)


func get_recoil_multiplier() -> float:
	## Get weapon recoil visualization multiplier for current camera mode
	var config: Dictionary = mode_configs[current_mode]
	return config.get("recoil_multiplier", 1.0)


func add_camera_shake(strength: float) -> void:
	## Add camera shake effect
	if camera_shake_enabled:
		shake_strength = max(shake_strength, strength * get_shake_multiplier())


func _update_camera_shake(delta: float) -> void:
	## Update camera shake effect
	if shake_strength > 0.0:
		# Generate random shake offset
		shake_offset = (
			Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
			* shake_strength
		)

		# Apply shake to active camera
		var active_camera := get_active_camera()
		if active_camera:
			active_camera.h_offset = shake_offset.x
			active_camera.v_offset = shake_offset.y

		# Decay shake
		shake_strength = max(0.0, shake_strength - shake_decay * delta)
	else:
		# Reset camera offsets
		var active_camera := get_active_camera()
		if active_camera:
			active_camera.h_offset = 0.0
			active_camera.v_offset = 0.0
		shake_offset = Vector3.ZERO


func _update_camera_bob(delta: float) -> void:
	## Update camera bob for first-person walking
	bob_time += delta * bob_frequency

	var bob_offset := Vector3(
		sin(bob_time) * bob_amplitude, abs(cos(bob_time * 2.0)) * bob_amplitude, 0.0
	)

	if camera:
		camera.position = Vector3(0, 1.55, 0) + bob_offset  # Eye level at 1.55m


func set_moving(moving: bool) -> void:
	## Set whether the player is moving (for camera bob)
	is_moving = moving
	if not moving:
		bob_time = 0.0
		if camera:
			camera.position = Vector3(0, 1.55, 0)  # Eye level at 1.55m


func toggle_camera_bob(value: bool) -> void:
	## Toggle camera bob on/off
	camera_bob_enabled = value
	if not value and camera:
		camera.position = Vector3(0, 1.55, 0)  # Eye level at 1.55m


func _find_player_visuals() -> void:
	## Find the player visuals node for transparency control
	var player: Node = get_parent()
	if not player:
		return

	# Try common names for player visuals
	var visual_names := ["PlayerVisuals", "Visuals", "SkeletalCharacterVisuals", "Model"]
	for vis_name: String in visual_names:
		player_visuals = player.get_node_or_null(vis_name)
		if player_visuals:
			var logger: Node = GameManager.get_core_system("logger")
			if logger:
				logger.info("[CameraController] Found player visuals: %s" % vis_name, "Player")
			return

	# If not found by name, search for SkeletalCharacterVisuals type
	for child in player.get_children():
		if child is Node3D and child.get_script():
			var script_path: String = child.get_script().resource_path
			if "skeletal_character_visuals" in script_path.to_lower():
				player_visuals = child
				var logger: Node = GameManager.get_core_system("logger")
				if logger:
					logger.info(
						"[CameraController] Found player visuals by script: %s" % child.name,
						"Player"
					)
				return


func _update_player_transparency(mode: CameraMode) -> void:
	## Update player transparency based on camera mode
	if not player_visuals:
		return

	var target_transparency: float = 1.0  # Default: fully opaque

	# Make player semi-transparent in third-person modes
	if mode == CameraMode.THIRD_PERSON or mode == CameraMode.OVER_SHOULDER:
		target_transparency = third_person_player_transparency

	_set_player_transparency(target_transparency)


func _set_player_transparency(transparency: float) -> void:
	## Set transparency on all player meshes
	if not player_visuals:
		return

	# Clamp transparency between 0.0 and 1.0
	transparency = clamp(transparency, 0.0, 1.0)

	# Find all MeshInstance3D nodes in player visuals
	var meshes := _find_all_mesh_instances(player_visuals)

	for mesh_inst in meshes:
		if not mesh_inst is MeshInstance3D:
			continue

		var mesh_instance: MeshInstance3D = mesh_inst

		# Get or create material override
		var mat: StandardMaterial3D = null

		if (
			mesh_instance.material_override
			and mesh_instance.material_override is StandardMaterial3D
		):
			mat = mesh_instance.material_override
		else:
			# Create new material if none exists
			mat = StandardMaterial3D.new()
			# Copy properties from existing material if available
			if mesh_instance.get_surface_override_material(0):
				var existing: Material = mesh_instance.get_surface_override_material(0)
				if existing is StandardMaterial3D:
					mat.albedo_color = existing.albedo_color
			mesh_instance.material_override = mat

		# Set transparency
		if transparency < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = transparency
		else:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mat.albedo_color.a = 1.0


func _find_all_mesh_instances(node: Node) -> Array[Node]:
	## Recursively find all MeshInstance3D nodes
	var meshes: Array[Node] = []

	if node is MeshInstance3D:
		meshes.append(node)

	for child in node.get_children():
		meshes.append_array(_find_all_mesh_instances(child))

	return meshes


func set_third_person_transparency(value: float) -> void:
	## Set the transparency value for third-person modes (0.0 = invisible, 1.0 = opaque)
	third_person_player_transparency = clamp(value, 0.0, 1.0)

	# Update immediately if in third-person mode
	if current_mode == CameraMode.THIRD_PERSON or current_mode == CameraMode.OVER_SHOULDER:
		_update_player_transparency(current_mode)
