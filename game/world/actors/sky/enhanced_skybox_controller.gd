@tool
class_name EnhancedSkyboxController
extends Node3D

# Enhanced Skybox Controller with dynamic clouds, time-based changes,
# weather integration and performance optimization
# Features: Dynamic time-of-day, weather-based sky changes,
# configurable cloud systems, performance optimization

@export_category("Time Settings")
@export var enable_time_cycle: bool = true
@export var time_speed_multiplier: float = 1.0
@export var start_time: float = 12.0  # Start at noon (0-24 hours)

@export_category("Weather Integration")
@export var enable_weather_integration: bool = true
@export var weather_influence_strength: float = 1.0

@export_category("Cloud Settings")
@export var enable_clouds: bool = true
@export var cloud_layer_count: int = 2
@export var cloud_speed: float = 0.5
@export var cloud_coverage: float = 0.6
@export var cloud_thickness: float = 0.8
@export var cloud_altitude: float = 2000.0

@export_category("Performance")
@export var lod_distance: float = 100.0
@export var enable_culling: bool = true

var current_time: float = 12.0  # Hours (0-24)
var current_weather: int = 0  # 0=Clear, 1=Rain, 2=Snow, 3=Storm, 4=Windy

var _sky_material: ProceduralSkyMaterial = null
var _cloud_instances: Array[Node3D] = []
var _time_accumulator: float = 0.0
var _weather_service: Node = null

signal time_changed(hours: float)
signal weather_changed(weather_type: int)


func _ready() -> void:
	# Load the enhanced sky shader
	_setup_sky_material()

	# Create cloud layers if enabled
	if enable_clouds:
		_create_cloud_layers()

	# Initialize time
	current_time = start_time

	# Connect to weather service if available
	if enable_weather_integration:
		_weather_service = _find_weather_service()
		if _weather_service:
			# Assuming weather service has a signal for weather changes
			if _weather_service.has_signal("weather_changed"):
				_weather_service.weather_changed.connect(_on_weather_changed)


func _process(delta: float) -> void:
	# Update time if enabled
	if enable_time_cycle:
		_time_accumulator += delta * time_speed_multiplier
		# Update time every few seconds to reduce computation
		if _time_accumulator >= 1.0:  # Update once per second
			current_time += _time_accumulator / 3600.0  # Convert to hours
			if current_time >= 24.0:
				current_time -= 24.0
			_time_accumulator = 0.0

			# Update sky material with new time
			_update_sky_material()

			time_changed.emit(current_time)

	# Update cloud positions
	if enable_clouds:
		_update_clouds(delta)


func _setup_sky_material() -> void:
	# Create or find the WorldEnvironment node
	var world_env: WorldEnvironment = _find_world_environment()
	if not world_env:
		push_error("[EnhancedSkyboxController] No WorldEnvironment found!")
		return

	# Use ProceduralSkyMaterial (GLES3 compatible)
	# Sky shaders are not supported in gl_compatibility renderer
	_sky_material = ProceduralSkyMaterial.new()

	# Set initial sky colors based on time of day
	_update_sky_colors_for_time(_sky_material)

	# Cloud settings
	_sky_material.sky_cover_modulate = Color(1.0, 1.0, 1.0, cloud_coverage)

	# Apply to WorldEnvironment
	if world_env.environment:
		var sky := Sky.new()
		sky.sky_material = _sky_material
		world_env.environment.sky = sky
		world_env.environment.background_mode = Environment.BG_SKY


func _find_world_environment() -> WorldEnvironment:
	# Try to find WorldEnvironment in scene
	var world_envs = get_tree().get_nodes_in_group("world_environment")
	if world_envs.size() > 0:
		return world_envs[0] as WorldEnvironment

	# Try to find by name in current scene
	var root = get_tree().current_scene
	if root:
		var node = root.get_node_or_null("WorldEnvironment")
		if node:
			return node as WorldEnvironment

	# Try to find as direct child of root
	if root and root.has_node("WorldEnvironment"):
		return root.get_node("WorldEnvironment") as WorldEnvironment

	return null


func _create_cloud_layers() -> void:
	# Create multiple cloud layers at different altitudes and speeds
	for i in range(cloud_layer_count):
		var cloud_layer = _create_cloud_plane(i)
		if cloud_layer:
			_cloud_instances.append(cloud_layer)
			add_child(cloud_layer)


func _create_cloud_plane(layer_index: int) -> Node3D:
	# Create a large plane for cloud layer
	var cloud_plane = MeshInstance3D.new()
	cloud_plane.name = "CloudLayer" + str(layer_index)

	# Create a large plane mesh
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(10000, 10000)  # Very large plane
	plane_mesh.subdivide_width = 50
	plane_mesh.subdivide_depth = 50
	cloud_plane.mesh = plane_mesh

	# Create cloud material
	var cloud_material = StandardMaterial3D.new()
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	cloud_material.albedo_color = Color.WHITE
	var texture_path: String = "res://textures/clouds/cloud_layer_%d.png" % (layer_index % 3)
	cloud_material.albedo_texture = load(texture_path) as Texture2D
	cloud_plane.material_override = cloud_material

	# Position at altitude
	cloud_plane.position = Vector3(0, cloud_altitude + (layer_index * 200), 0)

	return cloud_plane


func _update_clouds(delta: float) -> void:
	# Update cloud positions based on time and weather
	for i in range(_cloud_instances.size()):
		var cloud_layer = _cloud_instances[i]
		if cloud_layer:
			# Apply base movement (different speeds for each layer)
			var base_speed = cloud_speed * (0.5 + i * 0.2)
			# Weather affects speed
			cloud_layer.position.x -= base_speed * delta * (1.0 + current_weather * 0.2)


func _update_sky_material() -> void:
	if _sky_material:
		# Update time-based sky colors
		_update_sky_colors_for_time(_sky_material)

		# Update cloud coverage based on weather
		var weather_cloud_multiplier = 1.0
		match current_weather:
			1:
				weather_cloud_multiplier = 1.5  # Rain
			2:
				weather_cloud_multiplier = 1.3  # Snow
			3:
				weather_cloud_multiplier = 2.0  # Storm
			4:
				weather_cloud_multiplier = 1.2  # Windy

		_sky_material.sky_cover_modulate = Color(
			1.0, 1.0, 1.0, clamp(cloud_coverage * weather_cloud_multiplier, 0.0, 1.0)
		)


func _on_weather_changed(weather_type: int) -> void:
	current_weather = weather_type
	# Update sky material with new weather
	_update_sky_material()
	weather_changed.emit(weather_type)


func _update_sky_colors_for_time(sky_mat: ProceduralSkyMaterial) -> void:
	# Define colors for different times of day
	var dawn_top = Color(0.4, 0.5, 0.7)
	var dawn_horizon = Color(0.9, 0.6, 0.4)

	var day_top = Color(0.385, 0.454, 0.55)
	var day_horizon = Color(0.646, 0.656, 0.67)

	var dusk_top = Color(0.3, 0.4, 0.6)
	var dusk_horizon = Color(0.9, 0.5, 0.3)

	var night_top = Color(0.05, 0.05, 0.15)
	var night_horizon = Color(0.1, 0.1, 0.2)

	# Interpolate colors based on time
	var top_color: Color
	var horizon_color: Color

	if current_time < 6.0:  # Night (0-6)
		var t = current_time / 6.0
		top_color = night_top.lerp(dawn_top, t)
		horizon_color = night_horizon.lerp(dawn_horizon, t)
	elif current_time < 8.0:  # Dawn (6-8)
		var t = (current_time - 6.0) / 2.0
		top_color = dawn_top.lerp(day_top, t)
		horizon_color = dawn_horizon.lerp(day_horizon, t)
	elif current_time < 18.0:  # Day (8-18)
		top_color = day_top
		horizon_color = day_horizon
	elif current_time < 20.0:  # Dusk (18-20)
		var t = (current_time - 18.0) / 2.0
		top_color = day_top.lerp(dusk_top, t)
		horizon_color = day_horizon.lerp(dusk_horizon, t)
	else:  # Night (20-24)
		var t = (current_time - 20.0) / 4.0
		top_color = dusk_top.lerp(night_top, t)
		horizon_color = dusk_horizon.lerp(night_horizon, t)

	# Apply weather influence
	if current_weather > 0:
		var darken = 0.3 * weather_influence_strength
		top_color = top_color.darkened(darken)
		horizon_color = horizon_color.darkened(darken)

	# Set sky material properties
	sky_mat.sky_top_color = top_color
	sky_mat.sky_horizon_color = horizon_color
	sky_mat.ground_bottom_color = horizon_color.darkened(0.3)
	sky_mat.ground_horizon_color = horizon_color.darkened(0.1)


func _find_weather_service() -> Node:
	# Try to get weather service from GameCore
	var gs = GameManager.get_core_system("weather") if GameManager else null
	if gs:
		return gs

	# Try to find in scene tree
	var nodes = get_tree().get_nodes_in_group("weather_service")
	if nodes.size() > 0:
		return nodes[0]

	return null


## Set current time of day (0-24 hours)
func set_time_of_day(hours: float) -> void:
	current_time = fmod(hours, 24.0)
	_update_sky_material()
	time_changed.emit(current_time)


## Get current time of day (0-24 hours)
func get_time_of_day() -> float:
	return current_time


## Set current weather type
func set_weather_type(weather_type: int) -> void:
	current_weather = weather_type
	_on_weather_changed(weather_type)


## Get current weather type
func get_weather_type() -> int:
	return current_weather


## Pause or resume time cycling
func set_time_cycling(enabled: bool) -> void:
	enable_time_cycle = enabled


## Pause or resume weather integration
func set_weather_integration(enabled: bool) -> void:
	enable_weather_integration = enabled
