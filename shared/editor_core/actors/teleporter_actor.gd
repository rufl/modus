@tool
class_name TeleporterActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum TeleportType { PLATFORM, PORTAL }

@export var teleport_type: TeleportType = TeleportType.PLATFORM
@export var target_teleporter_name: String = ""
@export var teleport_cooldown: float = 2.0
@export var sound_effect: String = "teleport"
@export var particle_effect: bool = true

var teleporter_pad: Node3D = null
var teleport_area: Area3D = null
var particles: GPUParticles3D = null
var teleport_timer: float = 0.0

var _target_teleporter: TeleporterActor = null


func _init() -> void:
	actor_category = "mover"
	actor_name = "Teleporter"
	actor_description = "Teleports entities to target location"


func _on_actor_ready() -> void:
	_create_visual()
	_create_teleport_area()
	_create_particles()

	# Find target teleporter
	if not target_teleporter_name.is_empty():
		call_deferred("_find_target_teleporter")


func _create_visual() -> void:
	if teleport_type == TeleportType.PLATFORM:
		_create_platform_visual()
	else:
		_create_portal_visual()


func _create_platform_visual() -> void:
	# Teleporter pad base
	var base := CSGCylinder3D.new()
	base.name = "TeleporterBase"
	base.radius = 1.0
	base.height = 0.2
	base.position.y = 0.1

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.2, 0.6, 1.0)  # Cyan
	base_mat.emission_enabled = true
	base_mat.emission = Color(0.3, 0.8, 1.0)
	base_mat.emission_energy_multiplier = 2.0
	base.material = base_mat
	add_child(base)

	# Glowing ring
	var ring := CSGTorus3D.new()
	ring.name = "TeleporterRing"
	ring.inner_radius = 0.8
	ring.outer_radius = 1.0
	ring.ring_sides = 16
	ring.sides = 8
	ring.position.y = 0.25

	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.1, 0.4, 0.8)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.4, 0.9, 1.0)
	ring_mat.emission_energy_multiplier = 3.0
	ring.material = ring_mat
	add_child(ring)

	teleporter_pad = base


func _create_portal_visual() -> void:
	# Vertical portal frame
	var frame := CSGBox3D.new()
	frame.name = "PortalFrame"
	frame.size = Vector3(2.0, 3.0, 0.2)
	frame.position.y = 1.5

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.2, 0.2, 0.2)
	frame_mat.metallic = 1.0
	frame.material = frame_mat
	add_child(frame)

	# Portal surface
	var portal := CSGBox3D.new()
	portal.name = "PortalSurface"
	portal.size = Vector3(1.8, 2.8, 0.05)
	portal.position.y = 1.5
	portal.position.z = 0.05

	var portal_mat := StandardMaterial3D.new()
	portal_mat.albedo_color = Color(0.3, 0.1, 0.6, 0.8)  # Purple portal
	portal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_mat.emission_enabled = true
	portal_mat.emission = Color(0.5, 0.2, 1.0)
	portal_mat.emission_energy_multiplier = 4.0
	portal.material = portal_mat
	add_child(portal)

	teleporter_pad = portal


func _create_teleport_area() -> void:
	teleport_area = Area3D.new()
	teleport_area.name = "TeleportArea"
	teleport_area.monitoring = true
	add_child(teleport_area)

	var shape := CollisionShape3D.new()
	if teleport_type == TeleportType.PLATFORM:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 1.0
		cylinder.height = 2.0
		shape.shape = cylinder
		shape.position.y = 1.0
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(1.8, 2.8, 0.2)
		shape.shape = box
		shape.position.y = 1.5

	teleport_area.add_child(shape)
	teleport_area.body_entered.connect(_on_body_entered_teleport)


func _create_particles() -> void:
	if not particle_effect:
		return

	particles = GPUParticles3D.new()
	particles.name = "TeleportParticles"
	particles.amount = 32
	particles.lifetime = 1.0
	particles.emitting = true
	particles.position.y = 1.0 if teleport_type == TeleportType.PLATFORM else 1.5
	add_child(particles)

	# Simple particle material
	var process_mat := ParticleProcessMaterial.new()
	if teleport_type == TeleportType.PLATFORM:
		process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		process_mat.emission_ring_radius = 0.8
		process_mat.emission_ring_inner_radius = 0.6
	else:
		process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process_mat.emission_box_extents = Vector3(0.9, 1.4, 0.1)

	process_mat.direction = Vector3(0, 1, 0)
	process_mat.initial_velocity_min = 1.0
	process_mat.initial_velocity_max = 2.0
	process_mat.gravity = Vector3(0, 0, 0)
	process_mat.color = Color(0.3, 0.8, 1.0, 0.8)
	particles.process_material = process_mat


func _process(delta: float) -> void:
	super._process(delta)

	if teleport_timer > 0:
		teleport_timer -= delta


func _find_target_teleporter() -> void:
	# Search for target in parent tree
	if not is_inside_tree():
		return
	var root: Node = get_tree().root
	_target_teleporter = _find_teleporter_recursive(root, target_teleporter_name)

	if not _target_teleporter:
		push_warning("[TeleporterActor] Target '%s' not found" % target_teleporter_name)


func _find_teleporter_recursive(node: Node, search_name: String) -> TeleporterActor:
	if node is TeleporterActor and node.name == search_name:
		return node

	for child: Node in node.get_children():
		var result: TeleporterActor = _find_teleporter_recursive(child, search_name)
		if result:
			return result

	return null


func _on_body_entered_teleport(body: Node3D) -> void:
	if teleport_timer > 0:
		return

	if not _target_teleporter or not is_instance_valid(_target_teleporter):
		return

	# Only teleport players and enemies
	if not (body.is_in_group("player") or body.is_in_group("enemies")):
		return

	# Spawn feedback at source
	spawn_feedback(body.global_position)

	# Teleport
	body.global_position = _target_teleporter.global_position

	# Spawn feedback at destination
	_target_teleporter.spawn_feedback(body.global_position)

	# Play sound
	var audio_service = GameManager.get_core_system("audio") if GameManager else null
	if audio_service and audio_service.has_method("play_sound_3d"):
		var stream: AudioStream = load("res://game/art/audio/sfx/teleport.wav")
		audio_service.play_sound_3d(stream, body.global_position)

	# Set cooldown
	teleport_timer = teleport_cooldown
	_target_teleporter.teleport_timer = teleport_cooldown


func spawn_feedback(pos: Vector3) -> void:
	# Spawn visual effect
	var gs_node: Node = get_node_or_null("/root/GameplayService")
	if gs_node and gs_node.has_method("get_service"):
		var gs: Node = gs_node.call("get_service")
		if gs and gs.get("effects") and gs.get("effects").has_method("spawn_explosion"):
			# spawn_explosion(position, explosion_type, damage, radius)
			gs.get("effects").spawn_explosion.rpc(pos, 0, 0.0, 0.5)


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "teleport_type",
				"type": TYPE_INT,
				"label": "Teleporter Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Platform,Portal"
			},
			{
				"name": "target_teleporter_name",
				"type": TYPE_STRING,
				"label": "Target Teleporter",
				"description": "Name of the destination teleporter"
			},
			{
				"name": "teleport_cooldown",
				"type": TYPE_FLOAT,
				"label": "Cooldown",
				"description": "Seconds before can teleport again"
			},
			{"name": "particle_effect", "type": TYPE_BOOL, "label": "Particle Effect"}
		]
	)
	return props
