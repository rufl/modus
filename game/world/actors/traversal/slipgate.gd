@tool
extends Area3D
class_name Slipgate

signal entity_entered(entity: Node3D)
signal telefrag_occurred(killer: Node3D, victim: Node3D)

const COOLDOWN_TIME: float = 1.0
const TELEFRAG_RADIUS: float = 1.0  ## Radius to check for victims at destination

@export var destination: NodePath = NodePath()
@export var portal_color: Color = Color(0.4, 0.1, 1.0, 1.0)  ## Purple default
@export var active: bool = true
@export var enable_telefrag: bool = true  ## Kill entities at destination on teleport

@export_category("Visuals")
@export var animate_portal: bool = true
@export var portal_intensity: float = 2.0
@export var portal_size: Vector2 = Vector2(2.0, 3.0)  ## Width, Height
@export var portal_swirl_speed: float = 2.0
@export var portal_pulse_frequency: float = 5.0
@export var portal_edge_smoothness: float = 0.3
@export var portal_emit_direction: Vector3 = Vector3.FORWARD
@export var portal_emit_spread: float = 30.0

@export_category("Effects")
@export var effect_particle_count: int = 80
@export var effect_lifetime: float = 0.5
@export var effect_speed_min: float = 5.0
@export var effect_speed_max: float = 10.0
@export var effect_size_min: float = 0.05
@export var effect_size_max: float = 0.15
@export var effect_damping_min: float = 8.0
@export var effect_damping_max: float = 12.0
@export var effect_emission_radius: float = 1.0
@export var effect_emission_inner_radius: float = 0.5
@export var effect_emission_height: float = 0.1

@export_category("Animations")
@export var animate_teleport: bool = true
@export var teleport_animation_duration: float = 0.1
@export var teleport_animation_type: int = 0  # 0=Instant, 1=FadeOutIn, 2=Scale
@export var animation_fade_duration: float = 0.05
@export var animation_scale_min: float = 0.1
@export var animation_scale_max: float = 2.0

var _destination_node: Node3D = null
var _cooldown_entities: Dictionary = {}
var _portal_mesh: MeshInstance3D = null
var _portal_shader: Shader = null
var _portal_material: ShaderMaterial = null
var _time: float = 0.0


func _exit_tree() -> void:
	# Clean up dynamically created shader resources
	if _portal_material:
		_portal_material = null
	if _portal_shader:
		_portal_shader = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# Resolve destination
	if not destination.is_empty():
		_destination_node = get_node_or_null(destination)

	# Create portal visual
	_create_portal_visual()


func _process(delta: float) -> void:
	if not animate_portal or not _portal_mesh:
		return

	_time += delta

	# Animate portal material
	if _portal_material:
		_portal_material.set_shader_parameter("time", _time)


func _create_portal_visual() -> void:
	# Portal mesh (flat plane)
	_portal_mesh = MeshInstance3D.new()
	_portal_mesh.name = "PortalMesh"

	var plane := PlaneMesh.new()
	plane.size = portal_size  # Use configurable size
	_portal_mesh.mesh = plane
	_portal_mesh.rotation_degrees = Vector3(90, 0, 0)  # Face forward

	# Create portal shader material
	var shader_code: String = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 portal_color : source_color = vec4(0.4, 0.1, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 5.0) = 2.0;
uniform float time = 0.0;
uniform float swirl_speed : hint_range(0.0, 10.0) = 2.0;
uniform float pulse_freq : hint_range(0.0, 20.0) = 5.0;
uniform float edge_smoothness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);

	// Swirling effect
	float angle = atan(uv.y, uv.x);
	float swirl = sin(angle * 3.0 + time * swirl_speed + dist * 10.0);

	// Pulsing rings
	float rings = sin(dist * 20.0 - time * pulse_freq) * 0.5 + 0.5;

	// Edge fade
	float edge = smoothstep(0.5, edge_smoothness, dist);

	// Combine effects
	float glow = (swirl * 0.3 + rings * 0.7) * edge;

	ALBEDO = portal_color.rgb * glow * intensity;
	EMISSION = portal_color.rgb * glow * intensity;
	ALPHA = edge * 0.9;
}
"""
	_portal_shader = Shader.new()
	_portal_shader.code = shader_code

	_portal_material = ShaderMaterial.new()
	_portal_material.shader = _portal_shader
	_portal_material.set_shader_parameter("portal_color", portal_color)
	_portal_material.set_shader_parameter("intensity", portal_intensity)
	_portal_material.set_shader_parameter("swirl_speed", portal_swirl_speed)
	_portal_material.set_shader_parameter("pulse_freq", portal_pulse_frequency)
	_portal_material.set_shader_parameter("edge_smoothness", portal_edge_smoothness)

	_portal_mesh.set_surface_override_material(0, _portal_material)
	add_child(_portal_mesh)


func _on_body_entered(body: Node3D) -> void:
	if not active or not _destination_node:
		return

	if not "global_position" in body:
		return

	# Cooldown check
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if _cooldown_entities.has(body):
		if current_time < _cooldown_entities[body]:
			return

	_cooldown_entities[body] = current_time + COOLDOWN_TIME

	# Teleport
	_teleport_entity(body)


func _teleport_entity(entity: Node3D) -> void:
	if not is_instance_valid(entity) or not is_instance_valid(_destination_node):
		return

	# Apply teleportation animation if enabled
	if animate_teleport:
		await _apply_teleport_animation(entity)

	# Spawn entry effect
	_spawn_slipgate_effect(entity.global_position)

	# === TELEFRAG CHECK ===
	if enable_telefrag:
		_perform_telefrag_check(entity, _destination_node.global_position)

	# Preserve velocity if present
	var velocity: Vector3 = Vector3.ZERO
	if "velocity" in entity:
		velocity = entity.velocity

	# Move entity
	entity.global_position = _destination_node.global_position

	# Restore velocity
	if velocity != Vector3.ZERO and "velocity" in entity:
		entity.velocity = velocity

	# Spawn exit effect
	_spawn_slipgate_effect(_destination_node.global_position)

	entity_entered.emit(entity)
	GameManager.get_core_system("logger").info("[Slipgate] Teleported: %s" % entity.name, "World")


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
		var original_materials: Array = []
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
			func(alpha: float) -> void:
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
			func(alpha: float) -> void:
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

		# Check if entity still exists before final material restore
		if not is_instance_valid(entity):
			return

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
	tween.tween_property(entity, "scale", Vector3.ZERO, animation_fade_duration * 0.5)
	await tween.finished

	# Scale up animation
	tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(entity, "scale", original_scale, animation_fade_duration * 0.5)
	await tween.finished


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
		"[Slipgate] TELEFRAG! %s killed %s" % [killer.name, victim.name], "World"
	)


func _spawn_slipgate_effect(pos: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "SlipgateFlash"
	particles.emitting = true
	particles.one_shot = true
	particles.amount = effect_particle_count
	particles.lifetime = effect_lifetime
	particles.explosiveness = 1.0

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_radius = effect_emission_radius
	material.emission_ring_inner_radius = effect_emission_inner_radius
	material.emission_ring_height = effect_emission_height
	material.emission_ring_axis = portal_emit_direction
	material.direction = portal_emit_direction
	material.spread = portal_emit_spread
	material.initial_velocity_min = effect_speed_min
	material.initial_velocity_max = effect_speed_max
	material.gravity = Vector3.ZERO
	material.damping_min = effect_damping_min
	material.damping_max = effect_damping_max
	material.scale_min = effect_size_min
	material.scale_max = effect_size_max

	# Purple color gradient
	var gradient := Gradient.new()
	gradient.add_point(0.0, portal_color)
	gradient.add_point(0.3, Color(0.8, 0.5, 1.0, 0.8))
	gradient.add_point(1.0, Color(0.4, 0.1, 1.0, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	# Draw pass
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	var mesh_mat := StandardMaterial3D.new()
	mesh_mat.emission_enabled = true
	mesh_mat.emission = portal_color
	mesh_mat.emission_energy_multiplier = 3.0
	mesh_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = mesh_mat
	particles.draw_pass_1 = mesh

	get_tree().current_scene.add_child(particles)
	particles.global_position = pos
	particles.rotation = global_rotation

	get_tree().create_timer(particles.lifetime + 0.3).timeout.connect(particles.queue_free)


## Set portal active state


func set_active(is_active: bool) -> void:
	active = is_active
	if _portal_mesh:
		_portal_mesh.visible = active
