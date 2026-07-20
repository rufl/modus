class_name Gibfest
extends RefCounted

const GIB_SCENE_PATH = "res://game/entities/effects/gib.tscn"
const GIB_COUNT_MIN = 3
const GIB_COUNT_MAX = 6

static var _recent_spawn_count: int = 0
static var _spawn_decay_timer: float = 0.0


static func spawn_gibs(
	context: Node,
	global_pos: Vector3,
	dir: Vector3 = Vector3.ZERO,
	power: float = 1.0,
	count_override: int = -1
) -> void:
	if not context or not context.is_inside_tree():
		return

	# Try to find or create GibPool
	var gib_pool: Node = _get_or_create_pool(context)
	if not gib_pool:
		push_warning("[Gibfest] Could not access GibPool, using fallback")
		_spawn_gibs_fallback(context, global_pos, dir, power, count_override)
		return

	# Calculate gib count with spawn limiting
	var base_count: int = (
		count_override if count_override > 0 else randi_range(GIB_COUNT_MIN, GIB_COUNT_MAX)
	)
	var count: int = base_count

	# Reduce count based on recent spawn load
	if _recent_spawn_count > 60:
		count = mini(count, 4)  # Drastically reduced
	elif _recent_spawn_count > 30:
		count = mini(count, 8)  # Moderately reduced

	_recent_spawn_count += count

	# Spawn gibs from pool
	for i in range(count):
		if gib_pool.has_method("spawn_gib"):
			var owner_node: Node = context.get_parent() if context.get_parent() is Node3D else null
			gib_pool.spawn_gib(global_pos, dir, power, owner_node)


static func decay_spawn_counter(delta: float) -> void:
	## Call this from a persistent node's _process to decay spawn counter
	_spawn_decay_timer += delta
	if _spawn_decay_timer >= 0.5:
		_recent_spawn_count = maxi(0, _recent_spawn_count - 5)
		_spawn_decay_timer = 0.0


static func _get_or_create_pool(context: Node) -> Node:
	## Find existing GibPool or create one
	var tree: SceneTree = context.get_tree()
	if not tree:
		return null

	# Check if pool already exists
	var existing_pool: Node = tree.root.get_node_or_null("GibPool")
	if existing_pool:
		return existing_pool

	# Create new pool
	var GibPoolScript: GDScript = load("res://game/scripts/features/effects/effects/gib_pool.gd")
	if not GibPoolScript:
		return null

	var pool: Node = Node.new()
	pool.set_script(GibPoolScript)
	pool.name = "GibPool"
	tree.root.add_child(pool)
	return pool


static func _spawn_gibs_fallback(
	context: Node, global_pos: Vector3, dir: Vector3, power: float, count_override: int
) -> void:
	## Fallback if pool unavailable (original method)
	var gib_scene: PackedScene = load(GIB_SCENE_PATH)
	if not gib_scene:
		return

	var count: int = (
		count_override if count_override > 0 else randi_range(GIB_COUNT_MIN, GIB_COUNT_MAX)
	)
	var parent: Node = context.get_tree().current_scene
	if not parent:
		return

	for i in range(count):
		var gib: RigidBody3D = gib_scene.instantiate()
		parent.add_child(gib)
		if gib.has_method("launch"):
			var owner_node: Node = context.get_parent() if context.get_parent() is Node3D else null
			gib.launch(global_pos, dir, power, owner_node)
