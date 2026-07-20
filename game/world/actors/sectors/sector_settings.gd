@tool
extends Area3D
class_name SectorSettings

signal player_entered_sector(player: Node3D)
signal player_exited_sector(player: Node3D)

enum WeatherType { NONE, RAIN, SNOW, FOG, SANDSTORM }

@export_category("Physics")
@export var wind_direction: Vector3 = Vector3.ZERO
@export var wind_strength: float = 0.0
@export var gravity_multiplier: float = 1.0
@export var friction_multiplier: float = 1.0
@export_category("Weather")
@export var weather_type: WeatherType = WeatherType.NONE
@export var weather_intensity: float = 1.0
@export_category("Atmosphere")
@export var fog_enabled: bool = false
@export var fog_density: float = 0.05
@export var fog_color: Color = Color(0.7, 0.7, 0.8, 1.0)
@export var ambient_light_color: Color = Color.WHITE
@export var ambient_light_energy: float = 1.0
@export_category("Hazards")
@export var is_underwater: bool = false
@export var is_toxic: bool = false
@export var toxic_damage_per_second: float = 5.0
@export_category("Audio")
@export var ambient_sound: AudioStream = null
@export var ambient_volume_db: float = -10.0

var _entities_inside: Array[Node3D] = []
var _weather_particles: GPUParticles3D = null
var _audio_player: AudioStreamPlayer3D = null
var _original_gravity: float = -1.0
var _damage_timer: Timer = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if Engine.is_editor_hint():
		return

	# Cache original gravity
	_original_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

	# Setup weather particles
	if weather_type != WeatherType.NONE:
		_setup_weather_particles()

	# Setup ambient audio
	if ambient_sound:
		_setup_ambient_audio()

	# Setup toxic damage timer
	if is_toxic:
		_damage_timer = Timer.new()
		_damage_timer.wait_time = 1.0
		_damage_timer.timeout.connect(_apply_toxic_damage)
		add_child(_damage_timer)
		_damage_timer.start()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Apply wind force to entities
	if wind_strength > 0 and wind_direction != Vector3.ZERO:
		for entity: Node3D in _entities_inside:
			if is_instance_valid(entity) and "velocity" in entity:
				var wind_force: Vector3 = wind_direction.normalized() * wind_strength * delta
				entity.velocity += wind_force


func _setup_weather_particles() -> void:
	_weather_particles = GPUParticles3D.new()
	_weather_particles.name = "WeatherParticles"
	_weather_particles.emitting = true
	_weather_particles.amount = int(500 * weather_intensity)
	_weather_particles.lifetime = 3.0
	_weather_particles.visibility_aabb = AABB(Vector3(-50, -20, -50), Vector3(100, 40, 100))

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(25, 0.5, 25)

	match weather_type:
		WeatherType.RAIN:
			_configure_rain_particles(material)
		WeatherType.SNOW:
			_configure_snow_particles(material)
		WeatherType.FOG:
			# Fog uses environment settings, not particles primarily
			_weather_particles.queue_free()
			_weather_particles = null
			return
		WeatherType.SANDSTORM:
			_configure_sandstorm_particles(material)

	_weather_particles.process_material = material
	add_child(_weather_particles)


func _configure_rain_particles(material: ParticleProcessMaterial) -> void:
	material.direction = Vector3(0, -1, 0)
	material.spread = 5.0
	material.initial_velocity_min = 15.0
	material.initial_velocity_max = 20.0
	material.gravity = Vector3(0, -30, 0)
	material.scale_min = 0.02
	material.scale_max = 0.05

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.6, 0.7, 0.9, 0.8))
	gradient.add_point(1.0, Color(0.6, 0.7, 0.9, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	# Elongated raindrop mesh
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.01
	mesh.bottom_radius = 0.01
	mesh.height = 0.5
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.6, 0.7, 0.9, 0.6)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mesh_mat
	_weather_particles.draw_pass_1 = mesh


func _configure_snow_particles(material: ParticleProcessMaterial) -> void:
	material.direction = Vector3(0, -1, 0)
	material.spread = 45.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, -2, 0)
	material.scale_min = 0.03
	material.scale_max = 0.08
	material.damping_min = 1.0
	material.damping_max = 2.0

	# Sway effect
	material.attractor_interaction_enabled = true

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color.WHITE)
	gradient.add_point(0.8, Color(1.0, 1.0, 1.0, 0.8))
	gradient.add_point(1.0, Color(1.0, 1.0, 1.0, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color.WHITE
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mesh_mat
	_weather_particles.draw_pass_1 = mesh


func _configure_sandstorm_particles(material: ParticleProcessMaterial) -> void:
	material.direction = Vector3(1, -0.2, 0)  # Horizontal with slight drop
	material.spread = 30.0
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 15.0
	material.gravity = Vector3(0, -1, 0)
	material.scale_min = 0.05
	material.scale_max = 0.15

	var gradient := Gradient.new()
	gradient.add_point(0.0, Color(0.7, 0.5, 0.3, 0.6))
	gradient.add_point(0.5, Color(0.6, 0.4, 0.2, 0.4))
	gradient.add_point(1.0, Color(0.6, 0.4, 0.2, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.albedo_color = Color(0.7, 0.5, 0.3, 0.5)
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_mat
	_weather_particles.draw_pass_1 = mesh


func _setup_ambient_audio() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "SectorAmbient"
	_audio_player.stream = ambient_sound
	_audio_player.volume_db = ambient_volume_db
	_audio_player.autoplay = true
	_audio_player.max_distance = 50.0
	add_child(_audio_player)


func _apply_toxic_damage() -> void:
	for entity: Node3D in _entities_inside:
		if not is_instance_valid(entity):
			continue

		var health: Node = null
		if entity.has_node("HealthComponent"):
			health = entity.get_node("HealthComponent")

		if health and health.has_method("take_damage"):
			var damage_info := DamageInfo.new()
			damage_info.base_amount = toxic_damage_per_second
			damage_info.source = self
			damage_info.damage_type = 4 as DamageInfo.DamageType  # Poison/Toxic
			health.take_damage(damage_info)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player") and not body.is_in_group("enemies"):
		return

	_entities_inside.append(body)

	if body.is_in_group("player"):
		player_entered_sector.emit(body)
		_apply_sector_effects_to_player(body)


func _on_body_exited(body: Node3D) -> void:
	_entities_inside.erase(body)

	if body.is_in_group("player"):
		player_exited_sector.emit(body)
		_remove_sector_effects_from_player(body)


func _apply_sector_effects_to_player(player: Node3D) -> void:
	# Modify player gravity if applicable
	if gravity_multiplier != 1.0 and "gravity_multiplier" in player:
		player.gravity_multiplier = gravity_multiplier

	# Apply underwater effects
	if is_underwater and player.has_method("set_underwater"):
		player.set_underwater(true)


func _remove_sector_effects_from_player(player: Node3D) -> void:
	# Reset gravity
	if gravity_multiplier != 1.0 and "gravity_multiplier" in player:
		player.gravity_multiplier = 1.0

	# Remove underwater
	if is_underwater and player.has_method("set_underwater"):
		player.set_underwater(false)


## Editor visualization


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if is_toxic and toxic_damage_per_second <= 0:
		warnings.append("Toxic sector has 0 damage per second")
	return warnings
