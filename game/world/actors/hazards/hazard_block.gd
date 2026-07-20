extends Area3D
class_name HazardBlock

signal entity_damaged(entity: Node3D, damage: float)
signal entity_killed(entity: Node3D)

enum HazardType { GENERIC, LAVA, ACID, ELECTRICITY, CRUSHING, SPIKES }

@export var hazard_type: HazardType = HazardType.GENERIC
@export var damage_per_tick: float = 10.0
@export var damage_interval: float = 0.5
@export var instant_kill: bool = false
@export_category("Effects")
@export var spawn_particles: bool = true
@export var hazard_color: Color = Color(1.0, 0.3, 0.0, 1.0)

var _entities_inside: Dictionary = {}  # entity -> last_damage_time
var _timer: Timer = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Create damage timer
	_timer = Timer.new()
	_timer.wait_time = damage_interval
	_timer.timeout.connect(_apply_damage_tick)
	add_child(_timer)
	_timer.start()

	# Set hazard color based on type
	_configure_hazard_type()


func _configure_hazard_type() -> void:
	match hazard_type:
		HazardType.LAVA:
			hazard_color = Color(1.0, 0.3, 0.0, 1.0)  # Orange-red
		HazardType.ACID:
			hazard_color = Color(0.2, 1.0, 0.1, 1.0)  # Green
		HazardType.ELECTRICITY:
			hazard_color = Color(0.3, 0.5, 1.0, 1.0)  # Blue
		HazardType.CRUSHING:
			hazard_color = Color(0.5, 0.5, 0.5, 1.0)  # Gray
		HazardType.SPIKES:
			hazard_color = Color(0.8, 0.2, 0.2, 1.0)  # Dark red


func _apply_damage_tick() -> void:
	var _current_time: float = Time.get_ticks_msec() / 1000.0

	for entity: Node3D in _entities_inside.keys():
		if not is_instance_valid(entity):
			_entities_inside.erase(entity)
			continue

		_damage_entity(entity)


func _damage_entity(entity: Node3D) -> void:
	# Get health component
	var health: Node = null
	if entity.has_node("HealthComponent"):
		health = entity.get_node("HealthComponent")
	elif entity.has_method("get") and "health_component" in entity:
		health = entity.health_component

	if not health:
		return

	if instant_kill:
		# Instakill
		if health.has_method("set_health"):
			health.set_health(0)
		entity_killed.emit(entity)
	else:
		# Apply damage
		if health.has_method("take_damage"):
			var damage_info := DamageInfo.new()
			damage_info.base_amount = damage_per_tick
			damage_info.source = self
			damage_info.damage_type = _get_damage_type() as DamageInfo.DamageType
			health.take_damage(damage_info)

		entity_damaged.emit(entity, damage_per_tick)

	# Spawn effect
	if spawn_particles:
		_spawn_damage_effect(entity.global_position)


func _get_damage_type() -> int:
	# Map HazardType to DamageInfo type if applicable
	match hazard_type:
		HazardType.LAVA:
			return 2  # Fire
		HazardType.ACID:
			return 4  # Poison/Acid
		HazardType.ELECTRICITY:
			return 3  # Electric
		_:
			return 0  # Generic


func _spawn_damage_effect(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "HazardDamage"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 15
	particles.lifetime = 0.4
	particles.explosiveness = 0.9

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.2
	material.direction = Vector3.UP
	material.spread = 60.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, -5, 0)
	material.scale_min = 0.1
	material.scale_max = 0.2

	var gradient := Gradient.new()
	gradient.add_point(0.0, hazard_color)
	gradient.add_point(1.0, Color(hazard_color.r, hazard_color.g, hazard_color.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.emission_enabled = true
	mesh_mat.emission = hazard_color
	mesh_mat.emission_energy_multiplier = 1.5
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = pos

	get_tree().create_timer(particles.lifetime + 0.2).timeout.connect(particles.queue_free)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemies"):
		_entities_inside[body] = Time.get_ticks_msec() / 1000.0
		# Immediate first damage
		_damage_entity(body)


func _on_body_exited(body: Node3D) -> void:
	_entities_inside.erase(body)
