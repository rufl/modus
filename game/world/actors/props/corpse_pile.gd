@tool
extends StaticBody3D
class_name CorpsePile

signal pile_looted(position: Vector3)
signal interaction_available(is_available: bool)

@export_group("Pile Settings")
@export var pile_name: String = "Corpse Pile"
@export var loot_table_id: String = "corpse_pile"
@export var can_loot_multiple: bool = false
@export var max_loots: int = 1
@export_group("Interaction")
@export var interaction_key: String = "interact"
@export var interaction_prompt: String = "Search corpses"
@export_group("Visual")
@export var highlight_on_hover: bool = true
@export var searched_tint: Color = Color(0.5, 0.5, 0.5)

var loot_count: int = 0
var player_in_range: bool = false
var current_player: Node3D = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_label: Label3D = $InteractionLabel


func _ready() -> void:
	_setup_multiplayer_sync()

	if interaction_area:
		interaction_area.body_entered.connect(_on_area_entered)
		interaction_area.body_exited.connect(_on_area_exited)

	if interaction_label:
		interaction_label.visible = false

	add_to_group("corpse_piles")
	add_to_group("lootable")
	add_to_group("interactable")


func _setup_multiplayer_sync() -> void:
	if has_node("MultiplayerSynchronizer"):
		return

	var synchronizer: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MultiplayerSynchronizer"

	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(":loot_count")
	synchronizer.replication_config = config

	add_child(synchronizer)


func _process(_delta: float) -> void:
	if not player_in_range or not can_be_looted():
		return

	if current_player and current_player.is_multiplayer_authority():
		if Input.is_action_just_pressed(interaction_key):
			_request_loot()


func can_be_looted() -> bool:
	if can_loot_multiple:
		return loot_count < max_loots
	return loot_count == 0


func _on_loot_count_changed() -> void:
	if not can_be_looted():
		# Apply searched visual
		if mesh_instance:
			var material: Material = mesh_instance.get_active_material(0)
			if material is StandardMaterial3D:
				material.albedo_color = searched_tint

		if interaction_label:
			interaction_label.visible = false


func _on_area_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not can_be_looted():
		return

	player_in_range = true
	current_player = body

	if body.is_multiplayer_authority():
		if interaction_label:
			interaction_label.visible = true
			interaction_label.text = interaction_prompt
		interaction_available.emit(true)


func _on_area_exited(body: Node3D) -> void:
	if body != current_player:
		return

	player_in_range = false
	current_player = null

	if interaction_label:
		interaction_label.visible = false
	interaction_available.emit(false)


func _request_loot() -> void:
	if not can_be_looted():
		return

	if multiplayer.is_server():
		_loot_pile(multiplayer.get_unique_id())
	else:
		_request_loot_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_loot_rpc() -> void:
	if not multiplayer.is_server():
		return

	if not can_be_looted():
		return

	var peer_id: int = multiplayer.get_remote_sender_id()

	# Validate distance
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var registry: Node = gs.entity_registry if gs else null
	var player: Node3D = registry.get_player(peer_id) if registry else null
	if player:
		var dist: float = player.global_position.distance_to(global_position)
		if dist > 3.5:
			return

	_loot_pile(peer_id)


func _loot_pile(peer_id: int) -> void:
	if not can_be_looted():
		return

	loot_count += 1

	# Play loot effects on all
	_play_loot_effect.rpc()

	# Spawn loot for this player
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.loot and loot_table_id != "":
		gs.loot.spawn_loot_from_table(
			global_position + Vector3(0, 0.5, 0), loot_table_id, get_path(), peer_id  # Owner-specific loot
		)

	pile_looted.emit(global_position)

	# Emit event
	if GameManager:
		GameManager.emit_event(
			"corpse_looted", {"pile": self, "position": global_position, "peer_id": peer_id}
		)


@rpc("authority", "call_local", "reliable")
func _play_loot_effect() -> void:
	# Play search sound
	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.global_position = global_position
	audio.bus = "SFX"

	var sound_path: String = "res://game/assets/audio/sfx/corpse_search.ogg"
	if ResourceLoader.exists(sound_path):
		audio.stream = load(sound_path)

	get_tree().current_scene.add_child(audio)

	if audio.stream:
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)

	# Small particle effect
	_spawn_search_particles()


func _spawn_search_particles() -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.global_position = global_position + Vector3(0, 0.3, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 10
	particles.lifetime = 0.5
	particles.explosiveness = 1.0

	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.3
	material.direction = Vector3(0, 1, 0)
	material.spread = 90.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	material.gravity = Vector3.ZERO

	particles.process_material = material

	get_tree().current_scene.add_child(particles)
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
