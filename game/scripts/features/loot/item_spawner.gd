extends Node3D
class_name LootItemSpawner

signal item_spawned(item: Node3D)

const CONSUMABLE_SCENE: String = "res://game/scenes/items/pickups/consumable_pickup.tscn"

@export var item_ids: Array[String] = ["health_potion", "shield_booster"]
@export var spawn_radius: float = 0.5
@export var spawn_on_ready: bool = true
@export var respawn_enabled: bool = false
@export var respawn_delay: float = 30.0
@export var random_item: bool = true

var _spawn_points: Array[Vector3] = []
var _spawned_items: Array[Node3D] = []


func _ready() -> void:
	# Collect child Marker3D nodes as spawn points
	for child in get_children():
		if child is Marker3D:
			_spawn_points.append(child.global_position)

	# If no markers, use self position
	if _spawn_points.is_empty():
		_spawn_points.append(global_position)

	if spawn_on_ready:
		spawn_all_items()


## Spawn items at all spawn points


func spawn_all_items() -> void:
	for point in _spawn_points:
		spawn_item_at(point)


## Spawn a single item at position


func spawn_item_at(pos: Vector3, specific_id: String = "") -> Node3D:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return null

	var item_id: String = specific_id
	if item_id.is_empty():
		if random_item:
			item_id = item_ids[randi() % item_ids.size()]
		else:
			item_id = item_ids[0] if not item_ids.is_empty() else "health_potion"

	# Verify item exists in database
	var data_service = GameManager.get_core_system("data")
	var item_data: Dictionary = data_service.get_item_data(item_id) if data_service else {}
	if item_data.is_empty():
		push_warning("[ItemSpawner] Item '%s' not found in database" % item_id)
		return null

	# Load and instantiate scene
	if not ResourceLoader.exists(CONSUMABLE_SCENE):
		push_error("[ItemSpawner] Consumable pickup scene not found: %s" % CONSUMABLE_SCENE)
		return null

	var scene: PackedScene = load(CONSUMABLE_SCENE)
	var instance: Node3D = scene.instantiate()

	# Configure the pickup
	instance.item_id = item_id
	instance.stack_count = 1

	# Add random offset within radius
	# Spawn slightly above ground
	var offset := Vector3(
		randf_range(-spawn_radius, spawn_radius), 0.5, randf_range(-spawn_radius, spawn_radius)
	)

	# Add to scene
	get_tree().current_scene.add_child(instance)
	instance.global_position = pos + offset

	_spawned_items.append(instance)
	item_spawned.emit(instance)

	GameManager.get_core_system("logger").debug(
		"[ItemSpawner] Spawned %s at %s" % [item_id, instance.global_position], "ItemSpawner"
	)

	# Setup respawn if enabled
	if respawn_enabled:
		_setup_respawn(instance, pos, item_id)

	return instance


func _setup_respawn(item: Node3D, spawn_pos: Vector3, item_id: String) -> void:
	# Watch for item deletion
	item.tree_exited.connect(
		func() -> void:
			_spawned_items.erase(item)
			if respawn_enabled:
				get_tree().create_timer(respawn_delay).timeout.connect(
					func() -> void: spawn_item_at(spawn_pos, item_id)
				)
	)


## Clear all spawned items


func clear_items() -> void:
	for item in _spawned_items:
		if is_instance_valid(item):
			item.queue_free()
	_spawned_items.clear()


## Spawn debug items at player position (for console command)


static func spawn_debug_items_for_player(player: Node3D) -> void:
	var items_to_spawn: Array[String] = [
		"health_potion", "large_health_potion", "shield_booster", "speed_stim", "damage_stim"
	]

	var spawn_pos: Vector3 = player.global_position + Vector3(0, 0.5, 2)

	for i in items_to_spawn.size():
		var angle: float = i * TAU / items_to_spawn.size()
		var offset := Vector3(cos(angle) * 2, 0, sin(angle) * 2)
		_spawn_debug_item(items_to_spawn[i], spawn_pos + offset)


static func _spawn_debug_item(item_id: String, pos: Vector3) -> void:
	var scene_path: String = "res://game/scenes/items/pickups/consumable_pickup.tscn"
	if not ResourceLoader.exists(scene_path):
		return

	var scene: PackedScene = load(scene_path)
	var instance: Node3D = scene.instantiate()
	instance.item_id = item_id
	instance.stack_count = 1

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene:
		tree.current_scene.add_child(instance)
		instance.global_position = pos
