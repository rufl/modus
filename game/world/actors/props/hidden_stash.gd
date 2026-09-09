@tool
extends Area3D
class_name HiddenStash

signal stash_discovered(position: Vector3, discoverer: Node3D)
signal stash_revealed(position: Vector3)

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
@export var interaction_key: String = "interact"
@export_group("Visual")
@export var hidden_alpha: float = 0.25
@export var revealed_alpha: float = 1.0
@export var reveal_duration: float = 0.5

var is_revealed: bool = false:
	set(value):
		var changed := is_revealed != value
		is_revealed = value
		if changed and is_node_ready():
			_animate_reveal()
var is_looted: bool = false
var _damage_accumulated: float = 0.0
var _reveal_timer: Timer

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material:
		material = material.duplicate()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = revealed_alpha if is_revealed else hidden_alpha
		mesh_instance.material_override = material
	var shape := SphereShape3D.new()
	shape.radius = maxf(0.1, proximity_radius)
	collision_shape.shape = shape
	_reveal_timer = Timer.new()
	_reveal_timer.one_shot = true
	add_child(_reveal_timer)
	add_to_group("hidden_stashes")
	add_to_group("secrets")
	add_to_group("interactable")
	add_to_group("damageable")
	add_to_group("props")


func _exit_tree() -> void:
	if is_instance_valid(_reveal_timer):
		_reveal_timer.stop()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or is_revealed:
		return
	for body: Node3D in get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		if reveal_trigger == RevealTrigger.PROXIMITY:
			if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
				if _can_discover(body):
					_reveal_stash(body)
		elif reveal_trigger == RevealTrigger.INTERACT and body.is_multiplayer_authority():
			if Input.is_action_just_pressed(interaction_key):
				interact(body)


func _can_discover(player: Node3D) -> bool:
	if (
		not is_instance_valid(player)
		or not player.is_inside_tree()
		or not player.is_in_group("player")
	):
		return false
	if player.global_position.distance_to(global_position) > proximity_radius + 0.5:
		return false
	if require_line_of_sight:
		var ray := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 0.4, player.global_position + Vector3.UP * 0.4, 1
		)
		if player is CollisionObject3D:
			ray.exclude = [player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			return false
	return true


func take_damage(amount: float, _damage_type: String = "generic", source: Node3D = null) -> void:
	if Engine.is_editor_hint() or reveal_trigger != RevealTrigger.DAMAGE or is_revealed:
		return
	# Damage comes from the authoritative combat simulation, not client reveal requests.
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	_damage_accumulated += maxf(0.0, amount)
	if _damage_accumulated >= reveal_damage_threshold:
		_reveal_stash(source)


func interact(player: Node3D) -> void:
	if Engine.is_editor_hint() or reveal_trigger != RevealTrigger.INTERACT or is_revealed:
		return
	if not _can_discover(player):
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_reveal_stash(player)
	elif player.is_multiplayer_authority():
		_request_reveal.rpc_id(1)


func trigger_reveal(triggerer: Node3D = null) -> void:
	if reveal_trigger == RevealTrigger.CUSTOM:
		_reveal_stash(triggerer)


@rpc("any_peer", "reliable")
func _request_reveal() -> void:
	if not multiplayer.is_server() or reveal_trigger != RevealTrigger.INTERACT:
		return
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var peer_id := multiplayer.get_remote_sender_id()
	var player: Node3D = (
		gs.entity_registry.get_player(peer_id) if gs and gs.entity_registry else null
	)
	if _can_discover(player):
		_reveal_stash(player)


func _reveal_stash(discoverer: Node3D) -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or is_queued_for_deletion() or is_revealed:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	is_revealed = true
	var owner_peer := (
		discoverer.get_multiplayer_authority() if is_instance_valid(discoverer) else -1
	)
	stash_discovered.emit(global_position, discoverer)
	GameManager.emit_event(
		"stash_discovered", {"stash": self, "position": global_position, "discoverer": discoverer}
	)
	if reveal_delay <= 0.0:
		_spawn_loot(owner_peer)
	else:
		_reveal_timer.timeout.connect(_spawn_loot.bind(owner_peer), CONNECT_ONE_SHOT)
		_reveal_timer.start(reveal_delay)


func _spawn_loot(owner_peer: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or is_looted or loot_table_id.is_empty():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var loot := LootSvc.get_instance()
	if not loot:
		return
	is_looted = true
	loot.spawn_loot_from_table(
		global_position + Vector3(0, 0.3, 0), loot_table_id, get_path(), owner_peer
	)


func _animate_reveal() -> void:
	if not is_revealed:
		return
	stash_revealed.emit(global_position)
	var material := mesh_instance.get_active_material(0) as StandardMaterial3D
	if material:
		create_tween().tween_property(material, "albedo_color:a", revealed_alpha, reveal_duration)
