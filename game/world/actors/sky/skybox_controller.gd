@tool
extends Node3D
class_name SkyboxController

signal time_of_day_changed(hour: float)

enum SkyStyle { GRADIENT, PROCEDURAL, CUBEMAP }

const CloudsShader = preload("res://game/world/actors/sky/clouds.gdshader")

@export var sky_style: SkyStyle = SkyStyle.GRADIENT
@export_category("Gradient Sky")
@export var sky_top_color: Color = Color(0.2, 0.4, 0.8)
@export var sky_horizon_color: Color = Color(0.6, 0.7, 0.9)
@export var sky_bottom_color: Color = Color(0.3, 0.35, 0.4)
@export_category("Sun Settings")
@export var sun_enabled: bool = true
@export var sun_color: Color = Color(1.0, 0.95, 0.85)
@export var sun_energy: float = 1.0
@export var sun_angle_degrees: float = 45.0
@export var sun_rotation_degrees: float = 0.0
@export_category("Time of Day")
@export var enable_day_cycle: bool = false
@export var day_cycle_speed: float = 1.0  ## 1.0 = 1 game hour per real minute
@export_range(0.0, 24.0) var current_hour: float = 12.0
@export_category("Clouds")
@export var clouds_enabled: bool = true
@export var cloud_coverage: float = 0.5
@export var cloud_speed: float = 0.1
@export var cloud_color: Color = Color.WHITE
@export_category("Stars (Night)")
@export var stars_enabled: bool = true
@export var star_brightness: float = 1.0

var _sky: Sky = null
var _sky_material: ProceduralSkyMaterial = null
var _environment: Environment = null
var _world_environment: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _clouds_mesh: MeshInstance3D = null
var _clouds_material: ShaderMaterial = null


func _exit_tree() -> void:
	# Clean up shader material
	if _clouds_material:
		_clouds_material = null


func _ready() -> void:
	_setup_environment()
	_setup_sun()
	_setup_clouds()
	_apply_sky_settings()

	if Engine.is_editor_hint():
		return


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if enable_day_cycle:
		_update_day_cycle(delta)


func _setup_environment() -> void:
	# Check if WorldEnvironment exists
	_world_environment = get_node_or_null("WorldEnvironment") as WorldEnvironment
	if not _world_environment:
		_world_environment = WorldEnvironment.new()
		_world_environment.name = "WorldEnvironment"
		add_child(_world_environment)

	_environment = _world_environment.environment
	if not _environment:
		_environment = Environment.new()
		_world_environment.environment = _environment

	# Setup sky
	_sky_material = ProceduralSkyMaterial.new()
	_sky = Sky.new()
	_sky.sky_material = _sky_material
	_environment.sky = _sky
	_environment.background_mode = Environment.BG_SKY


func _setup_sun() -> void:
	if not sun_enabled:
		return

	_sun = get_node_or_null("Sun") as DirectionalLight3D
	if not _sun:
		_sun = DirectionalLight3D.new()
		_sun.name = "Sun"
		add_child(_sun)

	_sun.light_color = sun_color
	_sun.light_energy = sun_energy
	_sun.shadow_enabled = true
	_update_sun_position()


func _setup_clouds() -> void:
	if not clouds_enabled:
		return

	_clouds_mesh = MeshInstance3D.new()
	_clouds_mesh.name = "Clouds"
	add_child(_clouds_mesh)

	# Create a large plane for clouds
	var plane := PlaneMesh.new()
	plane.size = Vector2(1000, 1000)
	plane.subdivide_width = 10
	plane.subdivide_depth = 10
	_clouds_mesh.mesh = plane

	# Apply shader material
	_clouds_material = ShaderMaterial.new()
	_clouds_material.shader = CloudsShader
	_clouds_mesh.material_override = _clouds_material

	# Position high up
	_clouds_mesh.position.y = 100.0

	_update_clouds()


func _apply_sky_settings() -> void:
	if not _sky_material:
		return

	_sky_material.sky_top_color = sky_top_color
	_sky_material.sky_horizon_color = sky_horizon_color
	_sky_material.ground_bottom_color = sky_bottom_color
	_sky_material.ground_horizon_color = sky_horizon_color

	# Sun settings in sky material
	# Sun settings in sky material
	_sky_material.sun_angle_max = sun_angle_degrees
	_sky_material.sun_curve = 0.15

	_update_clouds()


func _update_clouds() -> void:
	if not _clouds_mesh:
		return

	if not clouds_enabled:
		_clouds_mesh.visible = false
		return

	_clouds_mesh.visible = true
	if _clouds_material:
		_clouds_material.set_shader_parameter("density", cloud_coverage)
		_clouds_material.set_shader_parameter("speed", cloud_speed)
		_clouds_material.set_shader_parameter("cloud_color", cloud_color)


func _update_day_cycle(delta: float) -> void:
	# Advance time
	current_hour += (delta / 60.0) * day_cycle_speed
	if current_hour >= 24.0:
		current_hour -= 24.0

	time_of_day_changed.emit(current_hour)

	# Update sky colors based on time
	_update_colors_for_time()
	_update_sun_position()


func _update_colors_for_time() -> void:
	var day_factor: float = _get_day_factor()

	# Dawn/dusk colors
	var sunrise_color := Color(1.0, 0.6, 0.4)
	var sunset_color := Color(0.9, 0.4, 0.3)
	var night_sky := Color(0.02, 0.02, 0.08)
	var night_horizon := Color(0.05, 0.05, 0.15)

	if day_factor > 0.5:
		# Full day
		_sky_material.sky_top_color = sky_top_color
		_sky_material.sky_horizon_color = sky_horizon_color
	elif day_factor > 0.0:
		# Sunrise/sunset blend
		var t: float = day_factor * 2.0
		var transition_color: Color = sunrise_color if current_hour < 12.0 else sunset_color
		_sky_material.sky_top_color = sky_top_color.lerp(transition_color, 1.0 - t)
		_sky_material.sky_horizon_color = sky_horizon_color.lerp(transition_color, 1.0 - t)
	else:
		# Night
		_sky_material.sky_top_color = night_sky
		_sky_material.sky_horizon_color = night_horizon

	# Adjust sun energy
	if _sun:
		_sun.light_energy = sun_energy * clampf(day_factor, 0.1, 1.0)

	# Adjust clouds visibility at night?
	if _clouds_material:
		var night_cloud := cloud_color.lerp(Color(0.1, 0.1, 0.2), 1.0 - day_factor)
		_clouds_material.set_shader_parameter("cloud_color", night_cloud)


func _get_day_factor() -> float:
	# 0 = midnight, 1 = noon, back to 0 at midnight
	# Sunrise around 6, sunset around 18
	if current_hour < 6.0:
		return 0.0
	if current_hour < 8.0:
		return (current_hour - 6.0) / 2.0 * 0.5  # Rise to 0.5
	if current_hour < 16.0:
		return 0.5 + (1.0 - abs(current_hour - 12.0) / 4.0) * 0.5  # Peak at noon
	if current_hour < 18.0:
		return (18.0 - current_hour) / 2.0 * 0.5  # Set to 0.5
	if current_hour < 20.0:
		return (20.0 - current_hour) / 2.0 * 0.5  # Fade to night
	return 0.0


func _update_sun_position() -> void:
	if not _sun:
		return

	# Calculate sun position based on time
	var sun_progress: float = (current_hour - 6.0) / 12.0  # 0 at 6AM, 1 at 6PM
	sun_progress = clampf(sun_progress, 0.0, 1.0)

	# Arc from east to west
	var altitude: float = sin(sun_progress * PI) * sun_angle_degrees
	var azimuth: float = lerp(-90.0, 90.0, sun_progress) + sun_rotation_degrees

	_sun.rotation_degrees = Vector3(-altitude, azimuth, 0)


## Set time of day directly


func set_time(hour: float) -> void:
	current_hour = fmod(hour, 24.0)
	_update_colors_for_time()
	_update_sun_position()


## Set cloud coverage (0-1)


func set_cloud_coverage(coverage: float) -> void:
	cloud_coverage = clampf(coverage, 0.0, 1.0)
	_update_clouds()


## Editor property updates


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_apply_sky_settings()
