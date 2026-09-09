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
@export var searched_tint: Color = Color(0.5, 0.5, 0.5)

var loot_count: int = 0:
	set(value):
		loot_count = value
		if is_node_ready():
			_on_loot_count_changed()
var current_player: Node3D = null

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var interaction_area: Area3D = $InteractionArea
@onready var interaction_label: Label3D = $InteractionLabel


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var material := mesh_instance.get_active_material(0)
	if material:
		mesh_instance.material_override = material.duplicate()
	interaction_area.body_entered.connect(_on_area_entered)
	interaction_area.body_exited.connect(_on_area_exited)
	interaction_label.visible = false
	add_to_group("corpse_piles")
	add_to_group("lootable")
	add_to_group("interactable")
	add_to_group("props")
	_on_loot_count_changed()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_instance_valid(current_player) and current_player.is_multiplayer_authority():
		if Input.is_action_just_pressed(interaction_key):
			interact(current_player)


func can_be_looted() -> bool:
	return loot_count < max_loots if can_loot_multiple else loot_count == 0


func _on_loot_count_changed() -> void:
	if not can_be_looted():
		var material := mesh_instance.get_active_material(0) as StandardMaterial3D
		if material:
			material.albedo_color = searched_tint
		interaction_label.visible = false
		interaction_available.emit(false)


func _on_area_entered(body: Node3D) -> void:
	if not body.is_in_group("player") or not body.is_multiplayer_authority():
		return
	current_player = body
	interaction_label.text = interaction_prompt
	interaction_label.visible = can_be_looted()
	interaction_available.emit(can_be_looted())


func _on_area_exited(body: Node3D) -> void:
	if body == current_player:
		current_player = null
		interaction_label.visible = false
		interaction_available.emit(false)


func _can_loot(player: Node3D) -> bool:
	return (
		is_instance_valid(player)
		and player.is_inside_tree()
		and player.is_in_group("player")
		and can_be_looted()
		and player.global_position.distance_to(global_position) <= 3.5
	)


func interact(player: Node3D) -> void:
	if Engine.is_editor_hint() or not _can_loot(player):
		return
	if not multiplayer.has_multiplayer_peer() or multiplayer.is_server():
		_loot_pile(player.get_multiplayer_authority())
	elif player.is_multiplayer_authority():
		_request_loot_rpc.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_loot_rpc() -> void:
	if not multiplayer.is_server():
		return
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	var peer_id := multiplayer.get_remote_sender_id()
	var player: Node3D = (
		gs.entity_registry.get_player(peer_id) if gs and gs.entity_registry else null
	)
	if _can_loot(player):
		_loot_pile(peer_id)


func _loot_pile(peer_id: int) -> void:
	if Engine.is_editor_hint() or not is_inside_tree() or is_queued_for_deletion():
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not can_be_looted() or loot_table_id.is_empty():
		return
	var loot := LootSvc.get_instance()
	if not loot:
		return
	loot_count += 1
	loot.spawn_loot_from_table(
		global_position + Vector3(0, 0.5, 0), loot_table_id, get_path(), peer_id
	)
	pile_looted.emit(global_position)
	GameManager.emit_event(
		"corpse_looted", {"pile": self, "position": global_position, "peer_id": peer_id}
	)
