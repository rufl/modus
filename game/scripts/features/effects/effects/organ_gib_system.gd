class_name OrganGibSystem
extends Node

signal organ_spawned(organ_type: String, position: Vector3)

enum OrganType { HEART, LUNG, INTESTINE, BONE_FRAGMENT, FLESH_CHUNK, SKULL_FRAGMENT }

const CONFIG_PATH := "res://game/config/gameplay/blood_effects_config.json"

@export_group("Organ Settings")
@export var enabled: bool = true
@export var organ_spawn_chance: float = 0.7
@export var organ_count_min: int = 1
@export var organ_count_max: int = 3
@export var organ_velocity_base: float = 10.0
@export var organ_lifetime: float = 25.0
@export_group("Physics")
@export var organ_mass: float = 0.5
@export var organ_bounce: float = 0.3
@export var organ_friction: float = 0.8
@export var organ_gravity_scale: float = 1.6
@export_group("Colors")
@export var heart_color: Color = Color(0.5, 0.0, 0.0)
@export var lung_color: Color = Color(0.4, 0.2, 0.2)
@export var intestine_color: Color = Color(0.6, 0.3, 0.2)
@export var bone_color: Color = Color(0.9, 0.9, 0.85)
@export var flesh_color: Color = Color(0.6, 0.1, 0.1)
@export var skull_color: Color = Color(0.95, 0.95, 0.9)

var _organ_definitions: Dictionary = {}

# FIXED C-05: Store timer references for proper cleanup
var _organ_particle_timers: Array[SceneTreeTimer] = []


func _ready() -> void:
	_load_config()
	_setup_organ_definitions()


func spawn_organs(spawn_position: Vector3, velocity: Vector3, damage: int = 10) -> void:
	## Spawn varied organ gibs
	## Args:
	##   spawn_position: Spawn position
	##   velocity: Base velocity
	##   damage: Damage dealt (affects organ count)

	# Check SystemRegistry first
	var gm: Node = get_node_or_null("/root/GameManager")
	var config: Node = gm.get_core_system("config") if gm else null
	if not config or not config.has_method("is_feature_enabled"):
		queue_free()
		return
	if not config.is_feature_enabled("gore"):
		queue_free()
		return

	if not enabled or randf() > organ_spawn_chance:
		return

	# Server broadcasts to all clients
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			_sync_organs.rpc(spawn_position, velocity, damage)
		# Don't execute locally on server - let RPC handle it
		return

	# Singleplayer path
	_do_spawn_organs(spawn_position, velocity, damage)


@rpc("authority", "call_local", "reliable")
func _sync_organs(spawn_position: Vector3, velocity: Vector3, damage: int) -> void:
	## RPC: Sync organ spawning to all clients
	_do_spawn_organs(spawn_position, velocity, damage)


func _do_spawn_organs(spawn_position: Vector3, velocity: Vector3, damage: int) -> void:
	## Internal: Actually spawn organ gibs
	var organ_count := randi_range(organ_count_min, organ_count_max)
	organ_count += int(damage * 0.05)
	organ_count = mini(organ_count, 12)

	for i: int in range(organ_count):
		var organ_type: OrganType = _select_random_organ_type()
		_spawn_organ(organ_type, spawn_position, velocity)


func _select_random_organ_type() -> OrganType:
	## Select random organ type with weighted probabilities
	var roll := randf()

	if roll < 0.05:
		return OrganType.HEART
	if roll < 0.15:
		return OrganType.LUNG
	if roll < 0.30:
		return OrganType.INTESTINE
	if roll < 0.50:
		return OrganType.BONE_FRAGMENT
	if roll < 0.85:
		return OrganType.FLESH_CHUNK
	return OrganType.SKULL_FRAGMENT


func _spawn_organ(organ_type: OrganType, base_position: Vector3, base_velocity: Vector3) -> void:
	## Spawn a single organ gib
	var organ := RigidBody3D.new()
	organ.add_to_group("gibs")
	organ.add_to_group("organs")

	# Set collision layer/mask to WORLD only (passable by players/enemies)
	organ.collision_layer = 0  # No layer
	organ.collision_mask = CollisionLayers.MASK_WORLD_ONLY

	var organ_def: Dictionary = _organ_definitions.get(organ_type, {})

	# Create organ mesh
	var mesh_instance := MeshInstance3D.new()
	var collision := CollisionShape3D.new()

	_create_organ_mesh(organ_type, mesh_instance, collision, organ_def)

	organ.add_child(mesh_instance)
	organ.add_child(collision)

	# Physics properties
	organ.mass = organ_mass * organ_def.get("mass_multiplier", 1.0)
	organ.gravity_scale = organ_gravity_scale
	organ.physics_material_override = PhysicsMaterial.new()
	organ.physics_material_override.bounce = organ_bounce
	organ.physics_material_override.friction = organ_friction
	organ.contact_monitor = true
	organ.max_contacts_reported = 4

	# Position with random offset
	organ.position = (
		base_position
		+ Vector3(randf_range(-0.4, 0.4), randf_range(0.5, 1.2), randf_range(-0.4, 0.4))
	)

	# Add to scene
	get_tree().root.add_child(organ)
	organ.global_position = organ.position

	# Calculate launch velocity
	var angle := randf_range(0, TAU)
	var horizontal_dir := Vector3(cos(angle), 0, sin(angle))
	var velocity_magnitude := organ_velocity_base + randf_range(-3.0, 3.0)

	var launch_vel := base_velocity * 0.5 + horizontal_dir * velocity_magnitude
	launch_vel += Vector3.UP * randf_range(6.0, 10.0)

	organ.linear_velocity = launch_vel

	# Random spin
	organ.angular_velocity = Vector3(
		randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12)
	)

	# Add blood trail for fleshy organs
	var fleshy_types := [
		OrganType.HEART, OrganType.LUNG, OrganType.INTESTINE, OrganType.FLESH_CHUNK
	]
	if organ_type in fleshy_types:
		_add_organ_blood_trail(organ, organ_def.get("color", Color.RED))

	# Setup collision sounds
	organ.body_entered.connect(_on_organ_collision.bind(organ, organ_type))

	# Setup cleanup
	_setup_organ_cleanup(organ)

	organ_spawned.emit(OrganType.keys()[organ_type], base_position)


func _create_organ_mesh(
	organ_type: OrganType,
	mesh_instance: MeshInstance3D,
	collision: CollisionShape3D,
	organ_def: Dictionary
) -> void:
	## Create mesh and collision for specific organ type
	var shape_type: String = organ_def.get("shape", "sphere")
	var organ_size: Vector3 = organ_def.get("size", Vector3(0.1, 0.1, 0.1))
	var color: Color = organ_def.get("color", Color.RED)

	var sphere_mesh := SphereMesh.new()
	var sphere_shape := SphereShape3D.new()
	var box_mesh := BoxMesh.new()
	var box_shape := BoxShape3D.new()
	var capsule_mesh := CapsuleMesh.new()
	var capsule_shape := CapsuleShape3D.new()
	var cylinder_mesh := CylinderMesh.new()
	var cylinder_shape := CylinderShape3D.new()
	var material := StandardMaterial3D.new()

	match shape_type:
		"sphere":
			sphere_mesh.radius = organ_size.x
			mesh_instance.mesh = sphere_mesh

			sphere_shape.radius = organ_size.x
			collision.shape = sphere_shape

		"box":
			box_mesh.size = organ_size
			mesh_instance.mesh = box_mesh

			box_shape.size = organ_size
			collision.shape = box_shape

		"capsule":
			capsule_mesh.radius = organ_size.x
			capsule_mesh.height = organ_size.y
			mesh_instance.mesh = capsule_mesh

			capsule_shape.radius = organ_size.x
			capsule_shape.height = organ_size.y
			collision.shape = capsule_shape

		"cylinder":
			cylinder_mesh.top_radius = organ_size.x
			cylinder_mesh.bottom_radius = organ_size.x
			cylinder_mesh.height = organ_size.y
			mesh_instance.mesh = cylinder_mesh

			cylinder_shape.radius = organ_size.x
			cylinder_shape.height = organ_size.y
			collision.shape = cylinder_shape

	# Apply organ-specific material
	material.albedo_color = color
	material.roughness = organ_def.get("roughness", 0.9)
	material.metallic = 0.0

	# Bones are slightly shiny
	if organ_type in [OrganType.BONE_FRAGMENT, OrganType.SKULL_FRAGMENT]:
		material.roughness = 0.6

	mesh_instance.set_surface_override_material(0, material)


func _add_organ_blood_trail(organ: RigidBody3D, trail_color: Color) -> void:
	## Add blood trail to fleshy organs
	var particles := GPUParticles3D.new()
	organ.add_child(particles)

	particles.emitting = true
	particles.amount = 35
	particles.lifetime = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.4

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.15
	material.direction = Vector3(0, -1, 0)
	material.spread = 25.0
	material.initial_velocity_min = 1.5
	material.initial_velocity_max = 3.5
	material.gravity = Vector3(0, -10, 0)
	material.scale_min = 0.03
	material.scale_max = 0.08
	material.color = trail_color

	particles.process_material = material

	var mesh := SphereMesh.new()
	mesh.radius = 0.03
	mesh.height = 0.06
	particles.draw_pass_1 = mesh

	# FIXED C-05: Store timer reference and use named method
	var timer := get_tree().create_timer(2.5)
	_organ_particle_timers.append(timer)
	timer.timeout.connect(_on_organ_particle_timeout.bind(particles))


func _on_organ_particle_timeout(particles: GPUParticles3D) -> void:
	## Called when organ particle timer completes
	if is_instance_valid(particles):
		particles.emitting = false


func _exit_tree() -> void:
	## FIXED C-05: Cleanup signal connections to prevent memory leaks
	for timer in _organ_particle_timers:
		if timer and timer.timeout.is_connected(_on_organ_particle_timeout):
			timer.timeout.disconnect(_on_organ_particle_timeout)
	_organ_particle_timers.clear()


func _on_organ_collision(_body: Node, organ: RigidBody3D, organ_type: OrganType) -> void:
	## Handle organ collision with surfaces
	## NOTE: body_entered is called from physics thread - must defer scene tree ops
	if not is_instance_valid(organ):
		return

	# Only react to fast impacts
	if organ.linear_velocity.length() < 2.0:
		return

	# Defer to main thread - body_entered is called from physics thread
	call_deferred("_spawn_organ_splatter", organ.global_position, organ_type)


func _spawn_organ_splatter(splatter_position: Vector3, organ_type: OrganType) -> void:
	## Spawn blood splatter when organ hits surface
	var organ_def: Dictionary = _organ_definitions.get(organ_type, {})
	var splatter_color: Color = organ_def.get("color", Color.RED)

	# Don't spawn blood for bones
	if organ_type in [OrganType.BONE_FRAGMENT, OrganType.SKULL_FRAGMENT]:
		return

	var splatter := MeshInstance3D.new()

	var plane_mesh := PlaneMesh.new()
	var splatter_size := randf_range(0.4, 0.8)
	plane_mesh.size = Vector2(splatter_size, splatter_size)
	splatter.mesh = plane_mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = splatter_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.7
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splatter.set_surface_override_material(0, material)

	get_tree().root.add_child(splatter)
	splatter.global_position = splatter_position
	splatter.rotation.x = -PI / 2
	splatter.rotation.y = randf_range(0, TAU)

	# Fade and remove
	var tween := splatter.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 4.0).set_delay(12.0)
	tween.tween_callback(splatter.queue_free)


func _setup_organ_cleanup(organ: RigidBody3D) -> void:
	## Fade out and remove organ after lifetime
	await get_tree().create_timer(organ_lifetime * 0.7).timeout

	if not is_instance_valid(organ):
		return

	var mesh_instance := organ.get_child(0) as MeshInstance3D
	if mesh_instance:
		var mat: StandardMaterial3D = mesh_instance.get_surface_override_material(0)
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var tween := organ.create_tween()
			tween.tween_property(mat, "albedo_color:a", 0.0, organ_lifetime * 0.3)
			tween.tween_callback(organ.queue_free)


func _setup_organ_definitions() -> void:
	## Define properties for each organ type
	_organ_definitions = {
		OrganType.HEART:
		{
			"shape": "sphere",
			"size": Vector3(0.25, 0.25, 0.25),
			"color": heart_color,
			"mass_multiplier": 1.2,
			"roughness": 0.85
		},
		OrganType.LUNG:
		{
			"shape": "box",
			"size": Vector3(0.3, 0.25, 0.2),
			"color": lung_color,
			"mass_multiplier": 0.8,
			"roughness": 0.9
		},
		OrganType.INTESTINE:
		{
			"shape": "capsule",
			"size": Vector3(0.1, 0.6, 0.1),
			"color": intestine_color,
			"mass_multiplier": 0.7,
			"roughness": 0.95
		},
		OrganType.BONE_FRAGMENT:
		{
			"shape": "box",
			"size": Vector3(0.15, 0.4, 0.1),
			"color": bone_color,
			"mass_multiplier": 1.0,
			"roughness": 0.6
		},
		OrganType.FLESH_CHUNK:
		{
			"shape": "box",
			"size": Vector3(0.25, 0.2, 0.2),
			"color": flesh_color,
			"mass_multiplier": 0.9,
			"roughness": 0.9
		},
		OrganType.SKULL_FRAGMENT:
		{
			"shape": "sphere",
			"size": Vector3(0.2, 0.2, 0.2),
			"color": skull_color,
			"mass_multiplier": 1.1,
			"roughness": 0.5
		}
	}


func _load_config() -> void:
	## Load configuration from JSON
	if not FileAccess.file_exists(CONFIG_PATH):
		return

	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()

	if err != OK:
		return

	var config: Dictionary = json.data
	_apply_config(config)


func _apply_config(config: Dictionary) -> void:
	## Apply loaded configuration
	if config.has("advanced_gore"):
		var gore: Dictionary = config["advanced_gore"]
		enabled = gore.get("organ_gibs_enabled", enabled)

	if config.has("organs"):
		var organs: Dictionary = config["organs"]
		organ_spawn_chance = organs.get("spawn_chance", organ_spawn_chance)
		organ_count_min = organs.get("count_min", organ_count_min)
		organ_count_max = organs.get("count_max", organ_count_max)
		organ_velocity_base = organs.get("velocity_base", organ_velocity_base)
		organ_lifetime = organs.get("lifetime", organ_lifetime)
		organ_mass = organs.get("mass", organ_mass)
		organ_bounce = organs.get("bounce", organ_bounce)
		organ_friction = organs.get("friction", organ_friction)
		organ_gravity_scale = organs.get("gravity_scale", organ_gravity_scale)


func set_enabled(value: bool) -> void:
	## Enable or disable organ spawning
	enabled = value
