@tool
class_name HazardVolumeActor
extends "res://shared/editor_core/actors/actor_base.gd"

enum HazardType { LAVA, ACID, ELECTRIC, POISON }

@export var hazard_type: HazardType = HazardType.LAVA
@export var damage_per_second: float = 20.0
@export var damage_interval: float = 0.5
@export var volume_size: Vector3 = Vector3(2.0, 1.0, 2.0)

var hazard_mesh: Node3D = null
var damage_area: Area3D = null
var particles: GPUParticles3D = null

var _damage_timer: float = 0.0
var _entities_in_zone: Array[Node] = []


func _init() -> void:
	actor_category = "hazard"
	actor_name = "Hazard Volume"
	actor_description = "Damage zone (lava, acid, etc.)"


func _on_actor_ready() -> void:
	_create_visual()
	_create_damage_area()
	_create_particles()


func _create_visual() -> void:
	# Hazard volume mesh
	hazard_mesh = CSGBox3D.new()
	hazard_mesh.name = "HazardMesh"
	hazard_mesh.size = volume_size
	hazard_mesh.position.y = volume_size.y * 0.5

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = _get_hazard_color()
	mat.emission_enabled = true
	mat.emission = _get_hazard_emission()
	mat.emission_energy_multiplier = 2.0
	hazard_mesh.material = mat
	add_child(hazard_mesh)


func _get_hazard_color() -> Color:
	match hazard_type:
		HazardType.LAVA:
			return Color(1.0, 0.3, 0.1, 0.6)  # Red-orange
		HazardType.ACID:
			return Color(0.3, 1.0, 0.2, 0.6)  # Green
		HazardType.ELECTRIC:
			return Color(0.3, 0.5, 1.0, 0.6)  # Blue
		HazardType.POISON:
			return Color(0.5, 0.2, 0.8, 0.6)  # Purple
		_:
			return Color(1.0, 0.0, 0.0, 0.6)


func _get_hazard_emission() -> Color:
	match hazard_type:
		HazardType.LAVA:
			return Color(1.0, 0.5, 0.2)
		HazardType.ACID:
			return Color(0.5, 1.0, 0.3)
		HazardType.ELECTRIC:
			return Color(0.5, 0.7, 1.0)
		HazardType.POISON:
			return Color(0.7, 0.4, 1.0)
		_:
			return Color(1.0, 0.0, 0.0)


func _create_damage_area() -> void:
	damage_area = Area3D.new()
	damage_area.name = "DamageArea"
	damage_area.monitoring = true
	add_child(damage_area)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = volume_size
	shape.shape = box
	shape.position.y = volume_size.y * 0.5
	damage_area.add_child(shape)

	damage_area.body_entered.connect(_on_body_entered_hazard)
	damage_area.body_exited.connect(_on_body_exited_hazard)


func _create_particles() -> void:
	particles = GPUParticles3D.new()
	particles.name = "HazardParticles"
	particles.amount = 64
	particles.lifetime = 2.0
	particles.emitting = true
	particles.position.y = volume_size.y * 0.5
	add_child(particles)

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = volume_size * 0.5
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.initial_velocity_min = 0.5
	process_mat.initial_velocity_max = 1.5
	process_mat.gravity = Vector3(0, -2.0, 0)
	process_mat.color = _get_hazard_color()
	particles.process_material = process_mat


func _process(delta: float) -> void:
	super._process(delta)

	# Apply damage to entities in zone
	_damage_timer -= delta
	if _damage_timer <= 0:
		_deal_damage()
		_damage_timer = damage_interval


func _on_body_entered_hazard(body: Node3D) -> void:
	if body.is_in_group("player") or body.is_in_group("enemies"):
		_entities_in_zone.append(body)

		# Play sound on entry
		var audio_service = GameManager.get_core_system("audio") if GameManager else null
		if audio_service and audio_service.has_method("play_sound_3d"):
			var lava_sound: String = "res://game/art/audio/sfx/burn.wav"
			var damage_sound: String = "res://game/art/audio/sfx/damage.wav"
			var sound_path: String = lava_sound if hazard_type == HazardType.LAVA else damage_sound
			audio_service.play_sound_3d(load(sound_path), body.global_position)


func _on_body_exited_hazard(body: Node3D) -> void:
	_entities_in_zone.erase(body)


func _deal_damage() -> void:
	for entity: Node in _entities_in_zone:
		if is_instance_valid(entity):
			# Use CombatService if available via GameplayService
			var gs_node: Node = get_node_or_null("/root/GameplayService")
			if gs_node and gs_node.has_method("get_service"):
				var gs: Node = gs_node.call("get_service")
				if gs and gs.get("combat") and gs.get("combat").has_method("apply_damage"):
					var damage_type: int = 4  # ENVIRONMENT (Assuming 4 based on typical enums)
					gs.get("combat").apply_damage(
						entity, damage_per_second * damage_interval, self, damage_type
					)
			elif entity.has_method("take_damage"):
				entity.take_damage(damage_per_second * damage_interval, self)


func get_inspector_properties() -> Array[Dictionary]:
	var props: Array[Dictionary] = super.get_inspector_properties()
	props.append_array(
		[
			{
				"name": "hazard_type",
				"type": TYPE_INT,
				"label": "Hazard Type",
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Lava,Acid,Electric,Poison"
			},
			{"name": "damage_per_second", "type": TYPE_FLOAT, "label": "Damage/Second"},
			{"name": "volume_size", "type": TYPE_VECTOR3, "label": "Volume Size"}
		]
	)
	return props
