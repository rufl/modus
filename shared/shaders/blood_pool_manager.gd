extends Node3D
class_name BloodPoolManager

## Manages multiple blood pool surfaces in a scene
## Automatically routes blood spawns to the nearest pool

@export var blood_pools: Array[BloodPool] = []
@export var max_spawn_distance: float = 50.0  ## Max distance to spawn blood from impact
@export var auto_discover_pools: bool = true


func _ready() -> void:
	if auto_discover_pools:
		_discover_blood_pools()


func _discover_blood_pools() -> void:
	blood_pools.clear()
	var pools: Array[Node] = get_tree().get_nodes_in_group("blood_pool")
	for pool: Node in pools:
		if pool is BloodPool:
			blood_pools.append(pool)


## Spawn blood at a world position, automatically finding the nearest pool
func spawn_blood_at_world_position(world_pos: Vector3) -> bool:
	var nearest_pool: BloodPool = _find_nearest_pool(world_pos)
	if not nearest_pool:
		return false

	var distance: float = world_pos.distance_to(nearest_pool.global_position)
	if distance > max_spawn_distance:
		return false

	var uv_pos: Vector2 = _world_to_uv(world_pos, nearest_pool)
	nearest_pool.drop_at(uv_pos)
	return true


## Spawn blood trail between two positions
func spawn_blood_trail(start_pos: Vector3, end_pos: Vector3, drops: int = 5) -> void:
	for i in range(drops):
		var t: float = float(i) / float(drops - 1) if drops > 1 else 0.0
		var pos: Vector3 = start_pos.lerp(end_pos, t)
		spawn_blood_at_world_position(pos)


## Spawn blood splatter (multiple drops in a radius)
func spawn_blood_splatter(center: Vector3, radius: float = 0.5, drop_count: int = 8) -> void:
	for i in range(drop_count):
		var angle: float = (TAU / drop_count) * i
		var offset: Vector3 = Vector3(cos(angle), 0, sin(angle)) * radius * randf_range(0.3, 1.0)
		spawn_blood_at_world_position(center + offset)


func _find_nearest_pool(world_pos: Vector3) -> BloodPool:
	if blood_pools.is_empty():
		return null

	var nearest: BloodPool = null
	var min_distance := INF

	for pool: BloodPool in blood_pools:
		if not is_instance_valid(pool):
			continue
		var distance: float = world_pos.distance_to(pool.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = pool

	return nearest


func _world_to_uv(world_pos: Vector3, pool: BloodPool) -> Vector2:
	# Convert world position to local space of the pool
	var local_pos: Vector3 = pool.to_local(world_pos)

	# Get mesh size from the pool's mesh
	var mesh_size := Vector2(10, 10)  # Default
	if pool.mesh is PlaneMesh:
		var plane_mesh: PlaneMesh = pool.mesh
		mesh_size = plane_mesh.size

	# Convert to UV coordinates (0.0 to 1.0)
	var uv_x: float = (local_pos.x / mesh_size.x) + 0.5
	var uv_z: float = (local_pos.z / mesh_size.y) + 0.5

	return Vector2(uv_x, uv_z)


## Add a blood pool to be managed
func register_pool(pool: BloodPool) -> void:
	if pool and not blood_pools.has(pool):
		blood_pools.append(pool)


## Remove a blood pool from management
func unregister_pool(pool: BloodPool) -> void:
	blood_pools.erase(pool)
