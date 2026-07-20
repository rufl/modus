extends Marker3D
class_name LootSpawner

@export var item_scene: PackedScene
@export var respawn_time: float = 15.0
@export var initial_delay: float = 1.0

var _current_item: Node3D = null
var _respawn_timer: Timer = null


func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		set_process(false)
		return

	_respawn_timer = Timer.new()
	_respawn_timer.one_shot = true
	_respawn_timer.timeout.connect(_spawn_item)
	add_child(_respawn_timer)

	# Initial spawn
	get_tree().create_timer(initial_delay).timeout.connect(_spawn_item)


func _spawn_item() -> void:
	if not item_scene:
		return

	if is_instance_valid(_current_item):
		return  # Already has item

	var item: Node3D = item_scene.instantiate()
	# Add to scene root so it replicates properly via MP Spawner (if set up)
	# OR simpler: add as child of this spawner?
	# networked objects usually need to be under a MultiplayerSpawner.
	# World.tscn has a MultiplayerSpawner spanning ".." (World).
	# So any child of World (or deep child) is covered IF layout matches.
	# BUT dynamically spawned nodes must be added to a node listed in 'spawn_path'.
	# World's spawner has `spawn_path = NodePath("..")` which is World.
	# So we should parent the item to World, not this marker.

	var world: Node = find_parent("World")
	if not world:
		# Fallback to current scene
		world = get_tree().current_scene

	world.add_child(item)
	item.global_position = global_position
	item.global_rotation = global_rotation

	_current_item = item

	# Watch for deletion (tree_exited) to trigger respawn
	item.tree_exited.connect(_on_item_taken)


func _on_item_taken() -> void:
	# Item was removed (picked up)
	if _respawn_timer:
		_respawn_timer.start(respawn_time)
