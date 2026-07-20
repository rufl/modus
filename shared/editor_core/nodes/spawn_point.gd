@tool
class_name LevelSpawnPoint
extends Node3D

signal spawn_triggered(spawn_type: SpawnType)

enum SpawnType { PLAYER, ENEMY, ITEM }

@export var spawn_type: SpawnType = SpawnType.PLAYER
@export_group("Enemy Settings")
@export var enemy_id: String = ""  # Which enemy type to spawn
@export var patrol_radius: float = 0.0  # Optional patrol area
@export_group("Item Settings")
@export var item_id: String = ""  # Which item to spawn
@export var respawn_time: float = 30.0  # Time to respawn after pickup
@export var model_preview_path: String = ""  # Path to mesh/scene for editor visualization


func _icon_path() -> String:
	match spawn_type:
		SpawnType.PLAYER:
			return "res://shared/editor_core/icons/spawn_point.svg"
		SpawnType.ENEMY:
			return "res://shared/editor_core/icons/enemy_spawn.svg"
		SpawnType.ITEM:
			return "res://shared/editor_core/icons/item_spawn.svg"
	return ""


func _ready() -> void:
	# Hide at runtime, show in editor
	if not Engine.is_editor_hint():
		visible = false
	else:
		_update_visuals()

	# Add to appropriate group
	_update_groups()


func _update_groups() -> void:
	# Clear old groups
	for group: String in ["spawn_player", "spawn_enemy", "spawn_item"]:
		if is_in_group(group):
			remove_from_group(group)

	# Add to new group
	match spawn_type:
		SpawnType.PLAYER:
			add_to_group("spawn_player")
		SpawnType.ENEMY:
			add_to_group("spawn_enemy")
		SpawnType.ITEM:
			add_to_group("spawn_item")


func _update_visuals() -> void:
	if not Engine.is_editor_hint():
		return

	# Update any visual components
	# The gizmo handles most visualization


## Get spawn type as string (for gizmo)


func get_spawn_type() -> String:
	match spawn_type:
		SpawnType.PLAYER:
			return "player"
		SpawnType.ENEMY:
			return "enemy"
		SpawnType.ITEM:
			return "item"
		_:
			return "player"


## Spawn the associated entity (called at runtime)


func spawn() -> Dictionary:
	match spawn_type:
		SpawnType.PLAYER:
			return _get_player_data()
		SpawnType.ENEMY:
			return _get_enemy_data()
		SpawnType.ITEM:
			return _get_item_data()
		_:
			return {}


func _get_player_data() -> Dictionary:
	spawn_triggered.emit(spawn_type)
	return {"type": "player"}


func _get_enemy_data() -> Dictionary:
	if enemy_id.is_empty():
		push_warning("SpawnPoint: No enemy_id configured")
		return {}

	spawn_triggered.emit(spawn_type)

	return {
		"type": "enemy",
		"id": enemy_id,
		"position": global_position,
		"rotation": global_rotation,
		"patrol_radius": patrol_radius
	}


func _get_item_data() -> Dictionary:
	if item_id.is_empty():
		push_warning("SpawnPoint: No item_id configured")
		return {}

	spawn_triggered.emit(spawn_type)

	return {
		"type": "item",
		"id": item_id,
		"position": global_position,
		"rotation": global_rotation,
		"respawn_time": respawn_time
	}


## Get configuration info


func get_info() -> Dictionary:
	return {
		"spawn_type": get_spawn_type(),
		"position": global_position,
		"rotation": global_rotation,
		"enemy_id": enemy_id,
		"item_id": item_id,
		"patrol_radius": patrol_radius,
		"respawn_time": respawn_time
	}
