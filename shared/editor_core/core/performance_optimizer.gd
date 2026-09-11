@tool
class_name PerformanceOptimizer
extends RefCounted

var _asset_thumbnail_cache: Dictionary = {}
var _node_bounds_cache: Dictionary = {}
var _material_cache: Dictionary = {}
var _pending_grid_updates: Array[Vector3i] = []
var _pending_gizmo_updates: Array[Node3D] = []
var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _operation_times: Dictionary = {}


func clear_caches() -> void:
	_asset_thumbnail_cache.clear()
	_node_bounds_cache.clear()
	_material_cache.clear()


## Get cached thumbnail or create and cache it


func get_cached_thumbnail(asset_path: String, size: Vector2i) -> Texture2D:
	var cache_key := "%s_%dx%d" % [asset_path, size.x, size.y]

	if _asset_thumbnail_cache.has(cache_key):
		return _asset_thumbnail_cache[cache_key]

	var thumb := _load_thumbnail_texture(asset_path, size)
	_asset_thumbnail_cache[cache_key] = thumb

	# Limit cache size
	if _asset_thumbnail_cache.size() > 100:
		_evict_oldest_cache_entries(_asset_thumbnail_cache, 50)

	return thumb


func _load_thumbnail_texture(asset_path: String, size: Vector2i) -> Texture2D:
	var resource := ResourceLoader.load(asset_path)
	if resource is Texture2D:
		return resource
	return _generate_placeholder_thumbnail(asset_path, size)

	# Limit cache size
	if _asset_thumbnail_cache.size() > 100:
		_evict_oldest_cache_entries(_asset_thumbnail_cache, 50)

	return thumb


func _generate_placeholder_thumbnail(asset_path: String, size: Vector2i) -> Texture2D:
	# Create a colored placeholder based on asset type
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)

	var color := Color(0.3, 0.3, 0.3)
	if asset_path.contains("block"):
		color = Color(0.4, 0.3, 0.2)
	elif asset_path.contains("prop"):
		color = Color(0.2, 0.4, 0.3)
	elif asset_path.contains("enemy"):
		color = Color(0.4, 0.2, 0.2)

	img.fill(color)
	return ImageTexture.create_from_image(img)


## Get cached node bounds


func get_node_bounds(node: Node3D) -> AABB:
	var node_id := node.get_instance_id()

	if _node_bounds_cache.has(node_id):
		return _node_bounds_cache[node_id]

	var bounds := _calculate_node_bounds(node)
	_node_bounds_cache[node_id] = bounds

	return bounds


func _calculate_node_bounds(node: Node3D) -> AABB:
	var bounds := AABB(node.global_position, Vector3.ZERO)

	# CSG shapes
	if node is CSGShape3D:
		if node is CSGBox3D:
			var half_size: Vector3 = node.size / 2.0
			bounds = AABB(node.global_position - half_size, node.size)
		elif node is CSGCylinder3D:
			var r: float = node.radius
			var h: float = node.height / 2.0
			bounds = AABB(
				node.global_position - Vector3(r, h, r), Vector3(r * 2, node.height, r * 2)
			)

	# Mesh instances
	elif node is MeshInstance3D and node.mesh:
		bounds = node.mesh.get_aabb()
		bounds.position += node.global_position

	# Expand for children
	for child in node.get_children():
		if child is Node3D:
			var child_bounds := get_node_bounds(child)
			bounds = bounds.merge(child_bounds)

	return bounds


## Invalidate bounds cache for a node
func invalidate_bounds(_node: Node3D) -> void:
	# Parent bounds include descendants, so invalidating one node must invalidate
	# every cached aggregate to avoid stale culling after transforms/child edits.
	_node_bounds_cache.clear()


## Get cached material


func get_material(path: String) -> Material:
	if _material_cache.has(path):
		return _material_cache[path]

	if ResourceLoader.exists(path):
		var mat := load(path) as Material
		if mat:
			_material_cache[path] = mat
			return mat

	return null


## Batch grid updates for efficiency


func schedule_grid_update(cell: Vector3i) -> void:
	if cell not in _pending_grid_updates:
		_pending_grid_updates.append(cell)


## Process pending grid updates


func flush_grid_updates(grid_system: Node) -> int:
	if _pending_grid_updates.is_empty():
		return 0

	var count := _pending_grid_updates.size()

	for cell in _pending_grid_updates:
		if grid_system.has_method("update_cell"):
			grid_system.update_cell(cell)

	_pending_grid_updates.clear()
	return count


## Schedule gizmo update for a node


func schedule_gizmo_update(node: Node3D) -> void:
	if node not in _pending_gizmo_updates:
		_pending_gizmo_updates.append(node)


## Process pending gizmo updates


func flush_gizmo_updates() -> int:
	if _pending_gizmo_updates.is_empty():
		return 0

	var count := _pending_gizmo_updates.size()

	for node in _pending_gizmo_updates:
		if is_instance_valid(node):
			node.update_gizmos()

	_pending_gizmo_updates.clear()
	return count


## Record frame time for performance monitoring


func record_frame_time(delta: float) -> void:
	_frame_times.append(delta)

	# Keep last 60 frames
	if _frame_times.size() > 60:
		_frame_times.remove_at(0)


## Get average FPS over recorded frames


func get_average_fps() -> float:
	if _frame_times.is_empty():
		return 0.0

	var total := 0.0
	for t in _frame_times:
		total += t

	var avg_delta: float = total / _frame_times.size()
	return 1.0 / avg_delta if avg_delta > 0 else 0.0


## Start timing an operation


func start_operation(op_name: String) -> void:
	_operation_times[op_name] = Time.get_ticks_usec()


## End timing and get duration in milliseconds


func end_operation(op_name: String) -> float:
	if not _operation_times.has(op_name):
		return 0.0

	var start: int = _operation_times[op_name]
	var end := Time.get_ticks_usec()
	_operation_times.erase(op_name)

	return (end - start) / 1000.0


## Evict oldest entries from a cache


func _evict_oldest_cache_entries(cache: Dictionary, keep_count: int) -> void:
	var keys := cache.keys()
	var to_remove := keys.size() - keep_count

	for i in range(to_remove):
		cache.erase(keys[i])


## Optimize physics queries by using area checks


func get_nodes_in_area(center: Vector3, radius: float, level_root: Node3D) -> Array[Node3D]:
	var results: Array[Node3D] = []
	var radius_sq := radius * radius

	for child in level_root.get_children():
		if child is Node3D:
			var dist_sq: float = child.global_position.distance_squared_to(center)
			if dist_sq <= radius_sq:
				results.append(child)

	return results


## Check if node is visible in camera frustum


func is_visible_in_camera(node: Node3D, camera: Camera3D) -> bool:
	if not camera:
		return true

	var bounds := get_node_bounds(node)
	if bounds.size == Vector3.ZERO:
		return camera.is_position_in_frustum(bounds.position)
	var max_corner := bounds.position + bounds.size
	for corner: Vector3 in [
		bounds.position,
		Vector3(max_corner.x, bounds.position.y, bounds.position.z),
		Vector3(bounds.position.x, max_corner.y, bounds.position.z),
		Vector3(bounds.position.x, bounds.position.y, max_corner.z),
		Vector3(max_corner.x, max_corner.y, bounds.position.z),
		Vector3(max_corner.x, bounds.position.y, max_corner.z),
		Vector3(bounds.position.x, max_corner.y, max_corner.z),
		max_corner,
	]:
		if camera.is_position_in_frustum(corner):
			return true
	return false


## Filter nodes by visibility for culling


func get_visible_nodes(nodes: Array[Node3D], camera: Camera3D) -> Array[Node3D]:
	var visible: Array[Node3D] = []

	for node in nodes:
		if is_visible_in_camera(node, camera):
			visible.append(node)

	return visible
