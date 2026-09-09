@tool
extends StaticBody3D

signal weapon_taken(weapon_type: String, position: Vector3)
signal interaction_available(is_available: bool)

@export_group("Rack Settings")
@export var rack_name: String = "Weapon Rack"
@export_enum("pistol", "shotgun", "machinegun", "rocket_launcher") var weapon_type := "pistol"
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

var has_weapon: bool = true:
	set(value):
		has_weapon = value
		if is_node_ready():
			_on_weapon_state_changed()
var current_player: Node3D = null
var _respawn_timer: float = 0.0

@onready var weapon_display: Node3D = $WeaponDisplay
@onready var glow_light: OmniLight3D = $GlowLight
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_label: Label3D = $InteractionLabel


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	glow_light.light_color = glow_color
	# Keep the authored silhouette proportional to the configured weapon family.
	match weapon_type:
		"shotgun":
			weapon_display.scale = Vector3(1.4, 1.0, 1.0)
		"machinegun":
			weapon_display.scale = Vector3(1.2, 1.1, 1.2)
		"rocket_launcher":
			weapon_display.scale = Vector3(1.3, 1.2, 1.2)
			var launcher_tube := CylinderMesh.new()
			launcher_tube.top_radius = 0.14
			launcher_tube.bottom_radius = 0.14
			launcher_tube.height = 0.75
			var receiver := weapon_display.get_node("Receiver") as MeshInstance3D
			receiver.mesh = launcher_tube
			receiver.rotation.z = PI * 0.5
			weapon_display.get_node("Grip").visible = false
	interaction_area.body_entered.connect(_on_area_entered)
	interaction_area.body_exited.connect(_on_area_exited)
	interaction_label.visible = false
	add_to_group("weapon_racks")
	add_to_group("interactable")
	add_to_group("props")
	_on_weapon_state_changed()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if rotate_display and has_weapon:
		weapon_display.rotate_y(deg_to_rad(rotation_speed * delta))
	if (
		(not multiplayer.has_multiplayer_peer() or multiplayer.is_server())
		and respawn_enabled
		and not has_weapon
	):
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			has_weapon = true
	if is_instance_valid(current_player) and current_player.is_multiplayer_authority():
		if Input.is_action_just_pressed(interaction_key):
			interact(current_player)


func _on_weapon_state_changed() -> void:
	weapon_display.visible = has_weapon
	glow_light.light_energy = glow_intensity if has_weapon else 0.0
	interaction_label.visible = has_weapon and is_instance_valid(current_player)
	interaction_available.emit(interaction_label.visible)


func _on_area_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not body.is_multiplayer_authority():
		return
	current_player = body
	interaction_label.text = "%s\n[%s]" % [weapon_type.capitalize(), interaction_prompt]
	_on_weapon_state_changed()


func _on_area_exited(body: Node3D) -> void:
	if body == current_player:
		current_player = null
		_on_weapon_state_changed()


func _can_take(player: Node3D) -> bool:
	return (
		is_instance_valid(player)
		and player.is_inside_tree()
		and player.is_in_group("player")
		and has_weapon
		and player.global_position.distance_to(global_position) <= 3.5
	)


func interact(player: Node3D) -> void:
	if Engine.is_editor_hint() or not _can_take(player):
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_take_weapon(player.get_multiplayer_authority())
	elif player.is_multiplayer_authority():
		_request_take_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_take_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var player: Node3D = (
		gs.entity_registry.get_player(peer_id) if gs and gs.entity_registry else null
	)
	if _can_take(player):
		_take_weapon(peer_id)


func _take_weapon(peer_id: int) -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or is_queued_for_deletion():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not has_weapon:
		return
	var scene_path: String = LootSvc.ITEM_SCENE_MAP.get("weapon_" + weapon_type, "")
	var loot := LootSvc.get_instance()
	if not loot or scene_path.is_empty():
		return
	var item := ItemData.new(
		"weapon_" + weapon_type, weapon_type.capitalize(), ItemData.ItemType.WEAPON
	)
	item.world_scene = load(scene_path)
	# Claim before spawning: pickup readiness may synchronously trigger other interactions.
	has_weapon = false
	var pickup := loot._spawn_pickup(item, global_position + Vector3(0, 1.0, -0.8), peer_id)
	if not pickup:
		has_weapon = true
		return
	_respawn_timer = respawn_time
	weapon_taken.emit(weapon_type, global_position)
