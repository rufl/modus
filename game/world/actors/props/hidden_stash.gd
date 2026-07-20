@tool
extends Area3D
class_name HiddenStash

signal stash_discovered(position: Vector3, discoverer: Node3D)
signal stash_revealed(position: Vector3)

# Player walks near, shoots it, presses interact, or external trigger
enum RevealTrigger { PROXIMITY, DAMAGE, INTERACT, CUSTOM }

@export_group("Stash Settings")
@export var stash_name: String = "Hidden Stash"
@export var loot_table_id: String = "hidden_stash"
@export var reveal_trigger: RevealTrigger = RevealTrigger.PROXIMITY
@export_group("Reveal Settings")
@export var proximity_radius: float = 1.5
@export var require_line_of_sight: bool = true
@export var reveal_damage_threshold: float = 10.0
@export var reveal_delay: float = 0.5
@export_group("Visual")
@export var hidden_alpha: float = 0.0
@export var revealed_alpha: float = 1.0
@export var reveal_duration: float = 0.5
@export var reveal_particle_color: Color = Color(1.0, 0.8, 0.3)

var is_revealed: bool = false
var is_looted: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _damage_accumulated: float = 0.0


func _ready() -> void:
	_setup_multiplayer_sync()

	# Start hidden
	if mesh_instance:
		var material: Material = mesh_instance.get_active_material(0)
		if material is StandardMaterial3D:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color.a = hidden_alpha

	# Connect signals based on trigger type
	if reveal_trigger == RevealTrigger.PROXIMITY:
		body_entered.connect(_on_body_entered)

	add_to_group("hidden_stashes")
	add_to_group("secrets")


func _setup_multiplayer_sync() -> void:
	if has_node("MultiplayerSynchronizer"):
		return

	var synchronizer: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MultiplayerSynchronizer"

	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(":is_revealed")
	config.add_property(":is_looted")
	synchronizer.replication_config = config

	add_child(synchronizer)


func _on_revealed_changed() -> void:
	if is_revealed:
		_animate_reveal()


func _on_body_entered(body: Node3D) -> void:
	if reveal_trigger != RevealTrigger.PROXIMITY:
		return
	if not body.is_in_group("player"):
		return
	if is_revealed:
		return

	# Request reveal from server
	if multiplayer.is_server():
		_reveal_stash(body)
	else:
		_request_reveal.rpc_id(1)


func take_damage(amount: float, _damage_type: String = "generic", source: Node3D = null) -> void:
	if reveal_trigger != RevealTrigger.DAMAGE or is_revealed:
		return

	_damage_accumulated += amount

	if _damage_accumulated >= reveal_damage_threshold:
		if multiplayer.is_server():
			_reveal_stash(source)
		else:
			_request_reveal.rpc_id(1)


func interact(player: Node3D) -> void:
	if reveal_trigger != RevealTrigger.INTERACT or is_revealed:
		return

	if multiplayer.is_server():
		_reveal_stash(player)
	else:
		_request_reveal.rpc_id(1)


func trigger_reveal(triggerer: Node3D = null) -> void:
	## External trigger for CUSTOM reveal type
	if is_revealed:
		return

	if multiplayer.is_server():
		_reveal_stash(triggerer)
	else:
		_request_reveal.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_reveal() -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = multiplayer.get_remote_sender_id()
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var player: Node3D = null
	if gs and gs.entity_registry:
		player = gs.entity_registry.get_player(peer_id)

	_reveal_stash(player)


func _reveal_stash(discoverer: Node3D) -> void:
	if is_revealed:
		return

	is_revealed = true

	# Play reveal on all clients
	_play_reveal.rpc()

	# Emit discovery event
	if GameManager:
		GameManager.emit_event(
			"stash_discovered",
			{"stash": self, "position": global_position, "discoverer": discoverer}
		)

	stash_discovered.emit(global_position, discoverer)

	# Spawn loot after reveal delay
	await get_tree().create_timer(reveal_delay).timeout
	_spawn_loot(discoverer)


func _spawn_loot(discoverer: Node3D) -> void:
	if is_looted or loot_table_id == "":
		return

	is_looted = true

	var owner_peer: int = -1
	if discoverer and "get_multiplayer_authority" in discoverer:
		owner_peer = discoverer.get_multiplayer_authority()

	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.loot:
		gs.loot.spawn_loot_from_table(
			global_position + Vector3(0, 0.3, 0), loot_table_id, get_path(), owner_peer
		)


@rpc("authority", "call_local", "reliable")
func _play_reveal() -> void:
	is_revealed = true
	stash_revealed.emit(global_position)
	_animate_reveal()
	_spawn_reveal_particles()


func _animate_reveal() -> void:
	if not mesh_instance:
		return

	var material: Material = mesh_instance.get_active_material(0)
	if material is StandardMaterial3D:
		var tween: Tween = create_tween()
		tween.tween_property(material, "albedo_color:a", revealed_alpha, reveal_duration)


func _spawn_reveal_particles() -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.global_position = global_position
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 1.0
	particles.explosiveness = 1.0

	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.3
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 3.0
	material.gravity = Vector3(0, -2.0, 0)

	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, reveal_particle_color)
	gradient.add_point(
		1.0, Color(reveal_particle_color.r, reveal_particle_color.g, reveal_particle_color.b, 0.0)
	)

	var gradient_tex: GradientTexture1D = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	material.color_ramp = gradient_tex

	particles.process_material = material

	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(2.0).timeout.connect(particles.queue_free)
