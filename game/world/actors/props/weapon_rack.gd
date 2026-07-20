@tool
extends StaticBody3D

signal weapon_taken(weapon_type: String, position: Vector3)
signal interaction_available(is_available: bool)

@export_group("Rack Settings")
@export var rack_name: String = "Weapon Rack"
@export var weapon_type: String = "pistol"  # Type to display/give
@export var weapon_scene_path: String = ""  # Optional custom weapon scene
@export var respawn_enabled: bool = false
@export var respawn_time: float = 30.0
@export_group("Interaction")
@export var interaction_key: String = "interact"
@export var interaction_prompt: String = "Press E to take"
@export_group("Visual")
@export var glow_color: Color = Color(0.5, 0.8, 1.0)
@export var glow_intensity: float = 0.8
@export var rotate_display: bool = true
@export var rotation_speed: float = 30.0

var has_weapon: bool = true
var player_in_range: bool = false
var current_player: Node3D = null

@onready var weapon_display: Node3D = $WeaponDisplay
@onready var glow_light: OmniLight3D = $GlowLight
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_label: Label3D = $InteractionLabel

var _respawn_timer: float = 0.0


func _ready() -> void:
	_setup_multiplayer_sync()
	_setup_glow()

	if interaction_area:
		interaction_area.body_entered.connect(_on_area_entered)
		interaction_area.body_exited.connect(_on_area_exited)

	if interaction_label:
		interaction_label.visible = false

	add_to_group("weapon_racks")
	add_to_group("interactable")


func _setup_multiplayer_sync() -> void:
	if has_node("MultiplayerSynchronizer"):
		return

	var synchronizer: MultiplayerSynchronizer = MultiplayerSynchronizer.new()
	synchronizer.name = "MultiplayerSynchronizer"

	var config: SceneReplicationConfig = SceneReplicationConfig.new()
	config.add_property(":has_weapon")
	synchronizer.replication_config = config

	add_child(synchronizer)


func _setup_glow() -> void:
	if not glow_light:
		glow_light = OmniLight3D.new()
		glow_light.name = "GlowLight"
		add_child(glow_light)

	glow_light.light_color = glow_color
	glow_light.light_energy = glow_intensity
	glow_light.omni_range = 1.5


func _process(delta: float) -> void:
	# Rotate display
	if rotate_display and weapon_display and has_weapon:
		weapon_display.rotate_y(deg_to_rad(rotation_speed * delta))

	# Handle respawn timer (server only)
	if multiplayer.is_server() and respawn_enabled and not has_weapon:
		_respawn_timer -= delta
		if _respawn_timer <= 0:
			has_weapon = true

	# Handle interaction
	if player_in_range and has_weapon:
		if current_player and current_player.is_multiplayer_authority():
			if Input.is_action_just_pressed(interaction_key):
				_request_take()


func _on_weapon_state_changed() -> void:
	if weapon_display:
		weapon_display.visible = has_weapon
	if glow_light:
		glow_light.light_energy = glow_intensity if has_weapon else 0.0
	if interaction_label and not has_weapon:
		interaction_label.visible = false


func _on_area_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not has_weapon:
		return

	player_in_range = true
	current_player = body

	if body.is_multiplayer_authority():
		if interaction_label:
			interaction_label.visible = true
			interaction_label.text = "%s\n[%s]" % [weapon_type.capitalize(), interaction_prompt]
		interaction_available.emit(true)


func _on_area_exited(body: Node3D) -> void:
	if body != current_player:
		return

	player_in_range = false
	current_player = null

	if interaction_label:
		interaction_label.visible = false
	interaction_available.emit(false)


func _request_take() -> void:
	if not has_weapon:
		return

	if multiplayer.is_server():
		_take_weapon(multiplayer.get_unique_id())
	else:
		_request_take_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_take_rpc() -> void:
	if not multiplayer.is_server():
		return

	var peer_id: int = multiplayer.get_remote_sender_id()

	if not has_weapon:
		return

	# Validate distance
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var player: Node3D = null
	if gs and gs.entity_registry:
		player = gs.entity_registry.get_player(peer_id)
	if player:
		var dist: float = player.global_position.distance_to(global_position)
		if dist > 3.5:
			return

	_take_weapon(peer_id)


func _take_weapon(peer_id: int) -> void:
	if not has_weapon:
		return

	has_weapon = false

	if respawn_enabled:
		_respawn_timer = respawn_time

	# Give weapon to player
	_give_weapon.rpc_id(peer_id, weapon_type, weapon_scene_path)

	# Play effects on all
	_play_take_effect.rpc()

	weapon_taken.emit(weapon_type, global_position)


@rpc("authority", "call_local", "reliable")
func _give_weapon(w_type: String, _w_scene: String) -> void:
	# Give to local player's inventory
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.inventory and gs.inventory.has_method("add_weapon_by_type"):
		gs.inventory.add_weapon_by_type(w_type)
	else:
		GameManager.get_core_system("logger").info(
			"[WeaponRack] Picked up weapon: %s" % w_type, "World"
		)


@rpc("authority", "call_local", "reliable")
func _play_take_effect() -> void:
	# Play pickup sound
	var audio: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	audio.global_position = global_position
	audio.bus = "SFX"

	var sound_path: String = "res://game/assets/audio/sfx/weapon_pickup.ogg"
	if ResourceLoader.exists(sound_path):
		audio.stream = load(sound_path)

	get_tree().current_scene.add_child(audio)

	if audio.stream:
		audio.play()
		audio.finished.connect(audio.queue_free)
	else:
		get_tree().create_timer(0.3).timeout.connect(audio.queue_free)
