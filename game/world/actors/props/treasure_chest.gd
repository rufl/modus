@tool
extends StaticBody3D
class_name TreasureChest

signal chest_opened(position: Vector3)
signal interaction_available(is_available: bool)

@export_group("Chest Settings")
@export var chest_name: String = "Treasure Chest"
@export var loot_table_id: String = "treasure_chest"
@export var requires_interaction: bool = true
@export var interaction_key: String = "interact"
@export var interaction_prompt: String = "Press E to open"
@export_group("Loot Settings")
@export var min_items: int = 2
@export var max_items: int = 5
@export var guaranteed_rare: bool = false  # Always drop at least one rare+
@export_group("Animation Settings")
@export var lid_open_angle: float = -90.0
@export var open_duration: float = 0.8
@export_group("Visual Effects")
@export var glow_color: Color = Color(1.0, 0.9, 0.5)
@export var glow_intensity: float = 1.5
@export var particle_burst_count: int = 60

var is_opened: bool = false
var player_in_range: bool = false
var current_player: Node3D = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var lid_mesh: MeshInstance3D = $LidMesh
@onready var glow_light: OmniLight3D = $GlowLight
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_label: Label3D = $InteractionLabel

var _glow_tween: Tween = null


func _ready() -> void:
	# Setup multiplayer synchronizer
	_setup_multiplayer_sync()

	# Setup glow effect
	_setup_glow_effect()

	# Setup interaction area
	if interaction_area:
		interaction_area.body_entered.connect(_on_interaction_area_entered)
		interaction_area.body_exited.connect(_on_interaction_area_exited)

	# Hide interaction label initially
	if interaction_label:
		interaction_label.visible = false

	# Add to groups
	add_to_group("treasure_chests")
	add_to_group("interactable")
	add_to_group("props")


func _setup_multiplayer_sync() -> void:
	## Add MultiplayerSynchronizer for open state
	if has_node("MultiplayerSynchronizer"):
		return

	var synchronizer: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MultiplayerSynchronizer"
	synchronizer.replication_interval = 0.1

	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(":is_opened")
	synchronizer.replication_config = config

	add_child(synchronizer)


func _setup_glow_effect() -> void:
	## Setup glowing light effect
	if not glow_light:
		glow_light = OmniLight3D.new()
		glow_light.name = "GlowLight"
		add_child(glow_light)

	glow_light.light_color = glow_color
	glow_light.light_energy = glow_intensity
	glow_light.omni_range = 2.5
	glow_light.omni_attenuation = 1.8


func _process(_delta: float) -> void:
	if is_opened:
		return

	# Handle interaction input (only on owning client)
	if player_in_range and requires_interaction:
		if current_player and current_player.is_multiplayer_authority():
			if Input.is_action_just_pressed(interaction_key):
				_request_open()


# =============================================================================
# INTERACTION
# =============================================================================


func _on_interaction_area_entered(body: Node3D) -> void:
	## Handle player entering interaction range
	if not body.is_in_group("player") or is_opened:
		return

	player_in_range = true
	current_player = body

	# Only show prompt for local player
	if body.is_multiplayer_authority():
		# Show interaction prompt
		if interaction_label:
			interaction_label.visible = true
			interaction_label.text = interaction_prompt

		# Brighten glow
		if glow_light:
			_glow_tween = create_tween()
			_glow_tween.tween_property(glow_light, "light_energy", glow_intensity * 1.3, 0.2)

		interaction_available.emit(true)


func _on_interaction_area_exited(body: Node3D) -> void:
	## Handle player leaving interaction range
	if body != current_player:
		return

	player_in_range = false
	current_player = null

	# Hide interaction prompt
	if interaction_label:
		interaction_label.visible = false

	# Dim glow
	if glow_light and not is_opened:
		if _glow_tween:
			_glow_tween.kill()
		_glow_tween = create_tween()
		_glow_tween.tween_property(glow_light, "light_energy", glow_intensity, 0.2)

	interaction_available.emit(false)


# =============================================================================
# OPENING
# =============================================================================


func _request_open() -> void:
	## Request to open chest (client -> server)
	if is_opened:
		return

	if multiplayer.is_server():
		_open_chest()
	else:
		_request_open_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_open_rpc() -> void:
	## Client request to open chest
	if not multiplayer.is_server() or is_opened:
		return

	var peer_id: int = multiplayer.get_remote_sender_id()
	if peer_id <= 0:
		return

	# Validate player is close enough and exists.
	var player: Node3D = _get_player_by_peer(peer_id)
	if not player:
		return
	var distance: float = player.global_position.distance_to(global_position)
	if distance > 3.5:  # Slightly larger than interaction area
		return

	_open_chest()


func _open_chest() -> void:
	## Open the chest (server-side)
	if is_opened:
		return

	is_opened = true

	# Play opening on all clients
	_play_opening.rpc()

	# Drop loot via GameplayService.loot
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.loot and loot_table_id != "":
		# Delay loot spawn until animation is partway through
		await get_tree().create_timer(open_duration * 0.5).timeout
		gs.loot.spawn_loot_from_table(
			global_position + Vector3(0, 0.5, 0), loot_table_id, get_path(), -1  # Anyone can pick up
		)

	# Emit event
	if GameManager:
		GameManager.emit_event(
			"chest_opened", {"chest": self, "position": global_position, "name": chest_name}
		)


@rpc("authority", "call_local", "reliable")
func _play_opening() -> void:
	## Play opening animation and effects (all clients)
	is_opened = true

	# Hide interaction prompt
	if interaction_label:
		interaction_label.visible = false

	# Emit signal
	chest_opened.emit(global_position)

	# Play opening animation
	_play_opening_animation()

	# Play opening effects
	_play_opening_effects()


func _on_opened_changed() -> void:
	## Called when is_opened syncs from server
	if is_opened and interaction_label:
		interaction_label.visible = false


func _play_opening_animation() -> void:
	## Animate the chest lid opening
	if not lid_mesh:
		return

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(lid_mesh, "rotation_degrees:x", lid_open_angle, open_duration)


func _play_opening_effects() -> void:
	## Play visual and audio effects when opening
	# Create burst of particles
	_create_opening_particle_burst()

	# Play opening sound
	_play_opening_sound()

	# Flash glow
	if glow_light:
		var tween: Tween = create_tween()
		tween.tween_property(glow_light, "light_energy", glow_intensity * 2.5, 0.3)
		tween.tween_property(glow_light, "light_energy", glow_intensity * 0.5, 0.5)


func _create_opening_particle_burst() -> void:
	## Create particle burst when opening
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "OpeningBurst"
	particles.global_position = global_position + Vector3(0, 0.5, 0)
	particles.emitting = true
	particles.one_shot = true
	particles.amount = particle_burst_count
	particles.lifetime = 1.2
	particles.explosiveness = 1.0

	# Create process material
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(0.4, 0.2, 0.3)
	material.direction = Vector3(0, 1, 0)
	material.spread = 60.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0, -3.0, 0)
	material.scale_min = 0.08
	material.scale_max = 0.2

	# Color gradient (golden sparkle)
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.0, glow_color)
	gradient.add_point(0.3, glow_color * 1.2)
	gradient.add_point(0.7, glow_color * 0.8)
	gradient.add_point(1.0, Color(glow_color.r, glow_color.g, glow_color.b, 0.0))

	var gradient_texture: GradientTexture1D = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	particles.process_material = material

	# Create draw pass
	var quad_mesh: QuadMesh = QuadMesh.new()
	quad_mesh.size = Vector2(0.15, 0.15)

	var draw_material: StandardMaterial3D = StandardMaterial3D.new()
	draw_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	draw_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw_material.albedo_color = glow_color

	quad_mesh.material = draw_material
	particles.draw_pass_1 = quad_mesh

	# Add to scene
	get_tree().current_scene.add_child(particles)

	# Auto-cleanup
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)


func _play_opening_sound() -> void:
	## Play sound effect when opening
	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.name = "OpeningSound"
	audio.global_position = global_position
	audio.bus = "SFX"
	audio.pitch_scale = randf_range(0.9, 1.1)

	# Try to load chest open sound
	var sound_path: String = "res://game/assets/audio/sfx/chest_open.ogg"
	if ResourceLoader.exists(sound_path):
		audio.stream = load(sound_path)

	get_tree().current_scene.add_child(audio)

	if audio.stream:
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		get_tree().create_timer(0.5).timeout.connect(audio.queue_free)


# =============================================================================
# UTILITY
# =============================================================================


func _get_player_by_peer(peer_id: int) -> Node3D:
	## Get player node by peer ID
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.entity_registry:
		return gs.entity_registry.get_player(peer_id)
	return null


func can_interact() -> bool:
	return not is_opened and player_in_range
