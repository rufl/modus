@tool
extends Area3D
class_name EnvironmentVolume

enum WeatherType { NONE = -1, CLEAR = 0, RAIN = 1, SNOW = 2, STORM = 3, WINDY = 4 }  # No override

@export_group("Overrides")
@export var weather_override: WeatherType = WeatherType.NONE
@export var gravity_multiplier: float = 1.0:
	set = _set_gravity_multiplier
@export var fog_density_override: float = -1.0  # -1 to use global

@export_group("Wind Effects")
@export var enable_wind_zone: bool = false
@export var wind_force: Vector3 = Vector3.ZERO
@export var wind_turbulence: float = 0.0
@export var wind_radius: float = 10.0
@export var wind_attenuation: float = 1.0

@export_group("Atmospheric Effects")
@export var enable_atmospheric_zone: bool = false
@export var atmospheric_density: float = 1.0
@export var atmospheric_color: Color = Color.WHITE
@export var light_absorption: float = 0.0
@export var light_scattering: float = 0.0

@export_group("Audio Effects")
@export var ambient_sound: AudioStream = null
@export var ambient_volume_db: float = 0.0
@export var ambient_pitch_scale: float = 1.0

@export_group("Visual Effects")
@export var sky_override_enabled: bool = false
@export var sky_override_sky: Sky = null
@export var sky_override_bg_color: Color = Color.BLACK
@export var fog_enabled: bool = false
@export var fog_color: Color = Color.GRAY
@export var fog_sun_color: Color = Color.YELLOW
@export var fog_sun_direction: Vector3 = Vector3(-1, -1, -1)

@export_group("Physics Effects")
@export var air_resistance: float = 0.0
@export var friction_multiplier: float = 1.0
@export var bounce_multiplier: float = 1.0

@export_group("Editor Visuals")
@export var debug_color: Color = Color(0, 0.5, 1.0, 0.1)

var _weather_controller: WeatherController
var _affected_bodies: Array[Node3D] = []


func _ready() -> void:
	# Setup editor visual
	if Engine.is_editor_hint():
		if not has_node("DebugBox"):
			_create_debug_box()
		return

	# Runtime
	monitorable = false
	monitoring = true

	# Find Weather Controller (Global)
	_weather_controller = _find_weather_controller()

	add_to_group("environment_zone")

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not enable_wind_zone or _affected_bodies.is_empty():
		return

	for body in _affected_bodies:
		if not is_instance_valid(body):
			continue

		var force: Vector3 = wind_force
		if wind_turbulence > 0.0:
			var noise := (
				Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
				* wind_turbulence
			)
			force += noise

		if body is RigidBody3D:
			body.apply_central_force(force)
		elif body is CharacterBody3D:
			# For CharacterBody3D, we apply as acceleration
			body.velocity += force * delta


func _find_weather_controller() -> WeatherController:
	# Try group first
	var nodes: Array[Node] = get_tree().get_nodes_in_group("weather_controller")
	if nodes.size() > 0:
		return nodes[0] as WeatherController

	# Search up keys
	var root: Node = get_tree().current_scene
	if root:
		var node: Node = root.get_node_or_null("WeatherController")
		if node:
			return node as WeatherController

	return null


## Apply environmental effects to entities entering the volume
func _apply_environment(active: bool) -> void:
	if not _weather_controller:
		_weather_controller = _find_weather_controller()

	if _weather_controller:
		if active:
			_weather_controller.set_weather_override(int(weather_override))
		else:
			# Revert
			# If volumes overlap, this is buggy. For MVP/Sector system, assume disjoint
			# or simple nesting.
			_weather_controller.set_weather_override(-1)

	# Apply other environmental effects
	if active:
		_apply_wind_effects()
		_apply_atmospheric_effects()
		_apply_physics_effects()
		_apply_audio_effects()
		_apply_visual_effects()
	else:
		_remove_wind_effects()
		_remove_atmospheric_effects()
		_remove_physics_effects()
		_remove_audio_effects()
		_remove_visual_effects()


## Apply wind effects to the area
func _apply_wind_effects() -> void:
	if not enable_wind_zone:
		return

	# Set up Area3D wind properties
	# Additional wind effects can be applied through physics callbacks


## Remove wind effects
func _remove_wind_effects() -> void:
	if not enable_wind_zone:
		return


## Apply atmospheric effects
func _apply_atmospheric_effects() -> void:
	if not enable_atmospheric_zone:
		return

	# Apply fog and atmospheric effects to the environment
	var world_env: WorldEnvironment = _find_world_environment()
	if world_env and world_env.environment:
		var env: Environment = world_env.environment

		# Store original values to restore later
		if not has_meta("original_fog_color"):
			set_meta("original_fog_color", env.fog_color)
		if not has_meta("original_fog_enabled"):
			set_meta("original_fog_enabled", env.fog_enabled)
		if not has_meta("original_fog_density"):
			set_meta("original_fog_density", env.fog_density)

		# Apply overrides
		env.fog_enabled = true
		env.fog_color = fog_color
		env.fog_density = atmospheric_density


## Remove atmospheric effects
func _remove_atmospheric_effects() -> void:
	if not enable_atmospheric_zone:
		return

	# Reset to default atmospheric values
	var world_env: WorldEnvironment = _find_world_environment()
	if world_env and world_env.environment:
		var env: Environment = world_env.environment

		# Restore original values if they were stored
		if has_meta("original_fog_color"):
			env.fog_color = get_meta("original_fog_color")
		if has_meta("original_fog_enabled"):
			env.fog_enabled = get_meta("original_fog_enabled")
		if has_meta("original_fog_density"):
			env.fog_density = get_meta("original_fog_density")


## Find the WorldEnvironment in the scene
func _find_world_environment() -> WorldEnvironment:
	# Try to find WorldEnvironment in the current scene
	var world_envs: Array[Node] = get_tree().get_nodes_in_group("world_environment")
	if world_envs.size() > 0:
		return world_envs[0] as WorldEnvironment

	# Look for WorldEnvironment in the root
	var root: Node = get_tree().current_scene
	if root:
		var node: Node = root.get_node_or_null("WorldEnvironment")
		if node:
			return node as WorldEnvironment

	return null


## Apply physics effects to entities
func _apply_physics_effects() -> void:
	# These effects would typically be applied to entities in the area
	# through collision/physics callbacks
	pass


## Remove physics effects
func _remove_physics_effects() -> void:
	# Reset physics effects to default
	pass


## Apply audio effects
func _apply_audio_effects() -> void:
	if ambient_sound:
		# Play ambient sound if available
		# This would typically be done through an audio system
		pass


## Remove audio effects
func _remove_audio_effects() -> void:
	if ambient_sound:
		# Stop playing ambient sound
		pass


## Apply visual effects
func _apply_visual_effects() -> void:
	# Apply sky overrides and visual effects
	if sky_override_enabled:
		# This would typically interact with the WorldEnvironment
		# or rendering system
		pass


## Remove visual effects
func _remove_visual_effects() -> void:
	if sky_override_enabled:
		# Reset to default sky
		pass


func _on_weather_changed(_type: int) -> void:
	pass  # Placeholder for future implementation


func _on_body_entered(body: Node3D) -> void:
	# Track physical bodies for wind/physics effects
	if body is RigidBody3D or body is CharacterBody3D:
		if body not in _affected_bodies:
			_affected_bodies.append(body)

	# Only affect local player's camera perspective for visual/weather overrides
	if body.is_in_group("player"):
		if body.is_multiplayer_authority():  # Local player
			_apply_environment(true)


func _on_body_exited(body: Node3D) -> void:
	# Remove from tracked bodies
	_affected_bodies.erase(body)

	if body.is_in_group("player"):
		if body.is_multiplayer_authority():
			_apply_environment(false)


func _create_debug_box() -> void:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = "DebugBox"
	var box: BoxMesh = BoxMesh.new()
	# Default size 1, can be scaled by node scale
	mesh_inst.mesh = box

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = debug_color
	mesh_inst.material_override = mat

	add_child(mesh_inst)


func _process(_delta: float) -> void:
	# Editor Update
	if Engine.is_editor_hint():
		# Sync Area3D gravity properties with export
		gravity_space_override = Area3D.SPACE_OVERRIDE_COMBINE
		gravity_point_unit_distance = gravity_multiplier
		# Wait, Area3D gravity is simple:
		gravity = 9.8 * gravity_multiplier
		# So we should set that if we use native physics

		# Update debug color
		var mesh_inst: MeshInstance3D = get_node_or_null("DebugBox")
		if mesh_inst and mesh_inst.material_override:
			mesh_inst.material_override.albedo_color = debug_color


# Override setters to update editor instantly


func _set_gravity_multiplier(val: float) -> void:
	gravity_multiplier = val
	gravity = 9.8 * gravity_multiplier
	gravity_space_override = SPACE_OVERRIDE_REPLACE
