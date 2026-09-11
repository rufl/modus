@tool
extends Area3D
class_name TeleporterPlatform

signal entity_teleported(entity: Node3D)
signal telefrag_occurred(killer: Node3D, victim: Node3D)

const COOLDOWN_TIME: float = 0.5  ## Prevent rapid re-teleports
const TELEFRAG_RADIUS: float = 1.0  ## Radius to check for victims at destination

@export var destination: NodePath = NodePath()
@export var teleport_delay: float = 0.0
@export var play_effect: bool = true
@export var teleport_sound: AudioStream = null
@export var one_way: bool = false  ## If true, destination won't teleport back
@export var enable_telefrag: bool = true  ## Kill entities at destination on teleport

@export_category("Effects")
@export var entry_color: Color = Color(0.0, 1.0, 0.5, 0.8)
@export var particle_count: int = 50
@export var effect_lifetime: float = 0.8
@export var effect_speed_min: float = 3.0
@export var effect_speed_max: float = 6.0
@export var effect_size_min: float = 0.1
@export var effect_size_max: float = 0.3
@export var effect_emit_direction: Vector3 = Vector3.UP
@export var effect_spread: float = 180.0
@export var effect_damping_min: float = 3.0
@export var effect_damping_max: float = 5.0
@export var effect_emission_radius: float = 0.5
@export var effect_emission_shape: int = 0  # 0=Sphere, 1=Box, 2=Ring
@export var effect_emission_height: float = 0.0

@export_category("Animations")
@export var animate_teleport: bool = true
@export var teleport_animation_duration: float = 0.1
@export var teleport_animation_type: int = 0  # 0=Instant, 1=FadeOutIn, 2=Scale
@export var animation_fade_duration: float = 0.05
@export var animation_scale_min: float = 0.1
@export var animation_scale_max: float = 2.0

var _destination_node: Node3D = null
var _cooldown_entities: Dictionary = {}  ## entity -> cooldown_end_time


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Resolve destination
	if not destination.is_empty():
		_destination_node = get_node_or_null(destination)
		if not _destination_node:
			push_warning("[Teleporter] Destination not found: %s" % destination)


func _on_body_entered(body: Node3D) -> void:
	if not _destination_node:
		return

	# Check if entity can be teleported (has global_position)
	if not body.has_method("get") or not "global_position" in body:
		return

	# Ignore if on cooldown
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if _cooldown_entities.has(body):
		if current_time < _cooldown_entities[body]:
			return

	# Apply cooldown
	_cooldown_entities[body] = current_time + COOLDOWN_TIME

	# Teleport with optional delay
	if teleport_delay > 0:
		await get_tree().create_timer(teleport_delay).timeout

	_teleport_entity(body)


func _teleport_entity(entity: Node3D) -> void:
	if not is_instance_valid(entity) or not is_instance_valid(_destination_node):
		return

	# === TELEFRAG CHECK ===
	if enable_telefrag:
		_perform_telefrag_check(entity, _destination_node.global_position)

	# Store velocity if entity has it (for momentum preservation)
	var velocity: Vector3 = Vector3.ZERO
	if "velocity" in entity:
		velocity = entity.velocity

	# Apply teleportation animation if enabled
	if animate_teleport:
		await _apply_teleport_animation(entity)

	# Spawn exit effect at source
	if play_effect:
		_spawn_teleport_effect(entity.global_position, entry_color)

	# Play sound
	if teleport_sound and entity.has_method("play_sound"):
		entity.play_sound(teleport_sound)

	# Move entity
	entity.global_position = _destination_node.global_position

	# Preserve velocity direction relative to destination orientation
	if velocity != Vector3.ZERO and "velocity" in entity:
		entity.velocity = velocity

	# Spawn entry effect at destination
	if play_effect:
		_spawn_teleport_effect(_destination_node.global_position, entry_color)

	entity_teleported.emit(entity)
	GameManager.get_core_system("logger").info("[Teleporter] Teleported: %s" % entity.name, "World")


## Apply teleportation animation based on configuration
func _apply_teleport_animation(entity: Node3D) -> void:
	if not is_instance_valid(entity):
		return

	match teleport_animation_type:
		0:  # Instant - No animation
			return
		1:  # Fade Out/In
			await _animate_fade_teleport(entity)
		2:  # Scale Animation
			await _animate_scale_teleport(entity)
		_:  # Default to instant
			return


## Fade out/in animation for teleportation
func _animate_fade_teleport(entity: Node3D) -> void:
	if not is_instance_valid(entity):
		return

	# Fade out
	if "material" in entity:
		# For MeshInstance3D or similar objects with materials
		var original_materials = []
		if entity is MeshInstance3D:
			for i in range(entity.get_surface_override_material_count()):
				original_materials.append(entity.get_surface_override_material(i))

		# Create temporary fade material
		var fade_material := StandardMaterial3D.new()
		fade_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fade_material.albedo_color = Color.WHITE

		# Apply fade out
		if entity is MeshInstance3D:
			for i in range(entity.get_surface_override_material_count()):
				entity.set_surface_override_material(i, fade_material)

		# Animate alpha
		var tween := get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_method(
			func(alpha):
				if not is_instance_valid(entity) or not is_instance_valid(fade_material):
					return
				fade_material.albedo_color = Color(1, 1, 1, 1 - alpha)
				if entity is MeshInstance3D:
					for i in range(entity.get_surface_override_material_count()):
						var mat: Material = entity.get_surface_override_material(i)
						if is_instance_valid(mat) and mat is StandardMaterial3D:
							(mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, 1 - alpha),
			0.0,
			1.0,
			animation_fade_duration
		)
		await tween.finished

		# Check if entity still exists before restoring materials
		if not is_instance_valid(entity):
			return

		# Restore original materials
		if entity is MeshInstance3D and original_materials.size() > 0:
			for i in range(
				min(original_materials.size(), entity.get_surface_override_material_count())
			):
				entity.set_surface_override_material(i, original_materials[i])

		# Fade in
		if entity is MeshInstance3D:
			for i in range(entity.get_surface_override_material_count()):
				entity.set_surface_override_material(i, fade_material)

		tween = get_tree().create_tween()
		tween.set_parallel(true)
		tween.tween_method(
			func(alpha):
				if not is_instance_valid(entity) or not is_instance_valid(fade_material):
					return
				fade_material.albedo_color = Color(1, 1, 1, alpha)
				if entity is MeshInstance3D:
					for i in range(entity.get_surface_override_material_count()):
						var mat: Material = entity.get_surface_override_material(i)
						if is_instance_valid(mat) and mat is StandardMaterial3D:
							(mat as StandardMaterial3D).albedo_color = Color(1, 1, 1, alpha),
			0.0,
			1.0,
			animation_fade_duration
		)
		await tween.finished

		# Restore original materials again
		if entity is MeshInstance3D and original_materials.size() > 0:
			for i in range(
				min(original_materials.size(), entity.get_surface_override_material_count())
			):
				entity.set_surface_override_material(i, original_materials[i])

	elif entity is Node3D:
		# Alternative approach for entities without materials
		# Use a simple timer for the fade effect
		await get_tree().create_timer(animation_fade_duration).timeout


## Scale animation for teleportation
func _animate_scale_teleport(entity: Node3D) -> void:
	if not is_instance_valid(entity):
		return

	# Get original scale
	var original_scale: Vector3 = entity.scale

	# Scale down animation
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(entity, "scale", Vector3.ZERO, teleport_animation_duration * 0.5)
	await tween.finished

	# Scale up animation
	tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(entity, "scale", original_scale, teleport_animation_duration * 0.5)
	await tween.finished


func _spawn_teleport_effect(pos: Vector3, color: Color) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "TeleportEffect"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = particle_count
	particles.lifetime = effect_lifetime
	particles.explosiveness = 1.0

	var material := ParticleProcessMaterial.new()

	# Apply configurable emission shape
	match effect_emission_shape:
		0:  # Sphere
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			material.emission_sphere_radius = effect_emission_radius
		1:  # Box
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			material.emission_box_extents = Vector3(
				effect_emission_radius, effect_emission_radius, effect_emission_radius
			)
		2:  # Ring
			material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
			material.emission_ring_radius = effect_emission_radius
			material.emission_ring_inner_radius = effect_emission_radius * 0.5
			material.emission_ring_height = (
				effect_emission_height if effect_emission_height > 0 else 0.1
			)

	material.direction = effect_emit_direction
	material.spread = effect_spread
	material.initial_velocity_min = effect_speed_min
	material.initial_velocity_max = effect_speed_max
	material.gravity = Vector3.ZERO
	material.damping_min = effect_damping_min
	material.damping_max = effect_damping_max
	material.scale_min = effect_size_min
	material.scale_max = effect_size_max

	# Color gradient
	var gradient := Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(0.5, Color(color.r, color.g, color.b, 0.5))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	# Simple mesh draw pass
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.emission_enabled = true
	mesh_mat.emission = color
	mesh_mat.emission_energy_multiplier = 2.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = pos

	# Cleanup
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)


## Check for and execute telefrag at destination position


func _perform_telefrag_check(teleporting_entity: Node3D, dest_pos: Vector3) -> void:
	# Find entities at destination using physics query
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var shape := SphereShape3D.new()
	shape.radius = TELEFRAG_RADIUS

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, dest_pos)
	query.collision_mask = 2 | 4  # Players (2) + Enemies (4)
	if teleporting_entity is CollisionObject3D:
		query.exclude = [teleporting_entity.get_rid()]
	else:
		query.exclude = []

	var results: Array[Dictionary] = space_state.intersect_shape(query, 10)

	for result: Dictionary in results:
		var victim: Node3D = result.get("collider")
		if not is_instance_valid(victim):
			continue

		# Don't telefrag yourself
		if victim == teleporting_entity:
			continue

		# Must be a player or enemy
		if not (victim.is_in_group("player") or victim.is_in_group("enemies")):
			continue

		# Execute telefrag
		_execute_telefrag(teleporting_entity, victim)


## Execute telefrag kill on victim


func _execute_telefrag(killer: Node3D, victim: Node3D) -> void:
	var victim_pos: Vector3 = victim.global_position

	# Apply lethal damage via GameplayService.combat. if available
	var combat_service: Node = GameManager.get_core_system("combat") if GameManager else null
	if combat_service:
		combat_service.apply_damage(victim, 10000.0, killer, 0)  # damage_type as int
	elif "health" in victim:
		victim.health = 0.0

	# Spawn gib explosion effect
	var effects_service: Node = GameManager.get_core_system("effects") if GameManager else null
	if effects_service:
		effects_service.spawn_gib_explosion(victim_pos, 8)

	# Emit event for kill feed
	GameManager.emit_event(
		"entity_telefragged", {"killer": killer, "victim": victim, "position": victim_pos}
	)

	telefrag_occurred.emit(killer, victim)
	GameManager.get_core_system("logger").info(
		"[Teleporter] TELEFRAG! %s killed %s" % [killer.name, victim.name], "World"
	)
