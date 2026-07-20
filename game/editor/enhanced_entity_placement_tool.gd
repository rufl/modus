@tool
class_name EnhancedEntityPlacementTool
extends Node3D

## Enhanced Entity Placement Tool - Advanced placement with smart snapping, prefabs and layers
## Features: Smart snapping, batch placement, prefab system, layer management

# Signals
signal entity_placed(entity: Node, position: Vector3)
signal entity_removed(entity: Node)
signal batch_operation_started(count: int)
signal batch_operation_completed(success_count: int, total_count: int)
signal prefab_loaded(prefab_name: String)
signal prefab_applied(prefab_name: String, count: int)
signal layer_changed(old_layer: String, new_layer: String)

# Enum definitions
enum SnapMode { NONE = 0, GRID = 1, SURFACE = 2, OBJECT = 3, EDGE = 4, CENTER = 5 }
enum LayerVisibility { VISIBLE = 0, HIDDEN = 1, LOCKED = 2 }


# Prefab class definition
class PrefabData:
	var name: String
	var scene: PackedScene
	var category: String
	var thumbnail: Texture2D
	var tags: Array[String] = []
	var default_position: Vector3 = Vector3.ZERO
	var default_rotation: Vector3 = Vector3.ZERO
	var default_scale: Vector3 = Vector3.ONE


# Layer data class
class EntityLayer:
	var name: String
	var visible: bool = true
	var locked: bool = false
	var entities: Array[Node] = []


# Exported properties
@export_group("Snapping")
@export var snap_mode: SnapMode = SnapMode.GRID
@export var snap_grid_size: float = 1.0
@export var snap_surface_offset: float = 0.1
@export var snap_tolerance: float = 0.1
@export var enable_smart_snapping: bool = true
@export var snap_to_edges: bool = false
@export var snap_to_centers: bool = false

@export_group("Batch Operations")
@export var batch_placement_count: int = 1
@export var batch_spacing: Vector3 = Vector3.ONE
@export var batch_randomize_position: bool = false
@export var batch_randomize_rotation: bool = false
@export var batch_randomize_scale: bool = false
@export var batch_position_variance: Vector3 = Vector3(0.5, 0.5, 0.5)
@export var batch_rotation_variance: Vector3 = Vector3(5, 5, 5)
@export var batch_scale_variance: Vector3 = Vector3(0.1, 0.1, 0.1)

@export_group("Prefab System")
@export var enable_prefab_system: bool = true
@export var prefab_save_path: String = "user://prefabs/"

@export_group("Layer Management")
@export var default_layer: String = "Default"
@export var enable_layer_system: bool = true

# Internal variables
var _active: bool = false
var _current_prefab: PrefabData = null
var _prefabs: Dictionary = {}
var _layers: Dictionary = {}
var _current_layer: String = "Default"
var _placed_entities: Array[Node] = []
var _selection_box: Node3D = null
var _preview_node: Node3D = null
var _object_pool: Dictionary = {}
var _raycast_cache: Dictionary = {}
var _last_placement_time: float = 0.0
var _placement_cooldown: float = 0.1


func _ready() -> void:
	# Initialize layer system
	_initialize_layers()

	# Initialize prefab system
	_load_available_prefabs()

	# Create visual aids
	_create_selection_visuals()
	_create_preview_visuals()


func _process(_delta: float) -> void:
	if _active:
		_update_preview_visuals()


## Initialize layer system with default layers
func _initialize_layers() -> void:
	if enable_layer_system:
		# Create default layers
		var default_layer_data := EntityLayer.new()
		default_layer_data.name = "Default"
		default_layer_data.visible = true
		default_layer_data.locked = false
		_layers["Default"] = default_layer_data

		var environment_layer := EntityLayer.new()
		environment_layer.name = "Environment"
		environment_layer.visible = true
		environment_layer.locked = false
		_layers["Environment"] = environment_layer

		var props_layer := EntityLayer.new()
		props_layer.name = "Props"
		props_layer.visible = true
		props_layer.locked = false
		_layers["Props"] = props_layer

		var enemies_layer := EntityLayer.new()
		enemies_layer.name = "Enemies"
		enemies_layer.visible = true
		enemies_layer.locked = false
		_layers["Enemies"] = enemies_layer

		_current_layer = default_layer


## Create selection and preview visuals
func _create_selection_visuals() -> void:
	# Selection box for multi-select operations
	_selection_box = Node3D.new()
	_selection_box.name = "SelectionBox"
	_selection_box.visible = false
	add_child(_selection_box)


func _create_preview_visuals() -> void:
	# Preview node for showing placement
	_preview_node = Node3D.new()
	_preview_node.name = "PlacementPreview"
	_preview_node.visible = false
	add_child(_preview_node)


## Update preview visuals based on snapping settings
func _update_preview_visuals() -> void:
	if not _current_prefab or not _preview_node:
		return

	# Get mouse position in world space
	var world_pos: Vector3 = _get_world_position_from_mouse()
	if world_pos == Vector3.ZERO:
		return

	# Apply snapping based on mode
	var snapped_pos: Vector3 = _apply_snapping(world_pos)

	# Update preview position
	_preview_node.position = snapped_pos

	# Apply randomization if enabled for batch operations
	if batch_randomize_position:
		var variance: Vector3 = _get_random_vector(batch_position_variance)
		_preview_node.position += variance


## Apply snapping based on current snap mode
func _apply_snapping(position: Vector3) -> Vector3:
	match snap_mode:
		SnapMode.NONE:
			return position
		SnapMode.GRID:
			return _snap_to_grid(position)
		SnapMode.SURFACE:
			return _snap_to_surface(position)
		SnapMode.OBJECT:
			return _snap_to_closest_object(position)
		SnapMode.EDGE:
			return _snap_to_edge(position)
		SnapMode.CENTER:
			return _snap_to_center(position)
		_:
			return position


## Snap to nearest edge of geometry
func _snap_to_edge(position: Vector3) -> Vector3:
	# Simplified: snap to grid if no complex edge detection implementation
	# Real implementation would require analyzing mesh data
	return _snap_to_grid(position)


## Snap to center of nearest object
func _snap_to_center(position: Vector3) -> Vector3:
	var closest_dist: float = INF
	var closest_center: Vector3 = position

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 5.0

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, position)

	var results: Array[Dictionary] = space_state.intersect_shape(params)
	for result in results:
		var collider: Node3D = result.get("collider")
		if collider and collider != _preview_node:
			var center: Vector3 = collider.global_position
			var dist: float = position.distance_to(center)
			if dist < closest_dist:
				closest_dist = dist
				closest_center = center

	return closest_center


## Snap position to grid
func _snap_to_grid(position: Vector3) -> Vector3:
	if snap_grid_size <= 0:
		return position

	return Vector3(
		round(position.x / snap_grid_size) * snap_grid_size,
		round(position.y / snap_grid_size) * snap_grid_size,
		round(position.z / snap_grid_size) * snap_grid_size
	)


## Snap to surface using raycast
func _snap_to_surface(position: Vector3) -> Vector3:
	var camera: Camera3D = _get_current_camera()
	if not camera:
		return position

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 1000.0)
	params.exclude = _get_excluded_bodies()

	var result: Dictionary = space_state.intersect_ray(params)
	if result.size() > 0:
		var hit_pos: Vector3 = result.position
		# Apply surface offset
		return hit_pos + result.normal * snap_surface_offset

	# If no surface found, fall back to grid snap
	return _snap_to_grid(position)


## Get excluded bodies for raycast (to ignore preview objects)
func _get_excluded_bodies() -> Array[RID]:
	var excluded: Array[RID] = []
	# Add preview node bodies to exclude
	if _preview_node:
		_collect_bodies_recursive(_preview_node, excluded)
	return excluded


## Collect all physics bodies from a node recursively
func _collect_bodies_recursive(node: Node, bodies: Array[RID]) -> void:
	if node is PhysicsBody3D:
		bodies.append(node.get_rid())

	for child in node.get_children():
		_collect_bodies_recursive(child, bodies)


## Snap to closest object
func _snap_to_closest_object(position: Vector3) -> Vector3:
	# Find the closest object to snap to
	var closest_dist: float = INF
	var closest_pos: Vector3 = position
	var search_radius: float = 2.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = search_radius

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere_shape
	params.transform = Transform3D(Basis.IDENTITY, position)
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var results: Array[Dictionary] = space_state.intersect_shape(params, 32)

	for result in results:
		var collider: Node3D = result.collider
		if not collider or collider == _preview_node:
			continue

		var dist: float = position.distance_to(collider.global_position)
		if dist < closest_dist and dist > 0.1:  # Avoid snapping to self
			closest_dist = dist
			closest_pos = collider.global_position
			# Snap to specific features based on other settings
			if snap_to_centers:
				# Use the object's center as snap point
				pass
			elif snap_to_edges:
				# Find closest edge point (would require more complex math)
				pass
			else:
				# Default to object position
				closest_pos = collider.global_position

	return closest_pos


## Get world position from mouse cursor
func _get_world_position_from_mouse() -> Vector3:
	var camera: Camera3D = _get_current_camera()
	if not camera:
		return Vector3.ZERO

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse_pos)

	# Simple approach: return position along ray at fixed distance
	return ray_origin + ray_dir * 10.0


## Get current active camera
func _get_current_camera() -> Camera3D:
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		var cameras: Array = current_scene.get_nodes_in_group("editor_camera")
		if cameras.size() > 0:
			return cameras[0] as Camera3D

		var main_camera: Node = current_scene.get_node_or_null("Camera3D")
		if main_camera and main_camera is Camera3D:
			return main_camera as Camera3D

	# Fallback to any camera in scene
	var all_cameras: Array = get_tree().get_nodes_in_group("camera")
	if all_cameras.size() > 0:
		return all_cameras[0] as Camera3D

	return null


## Activate the placement tool
func activate() -> void:
	_active = true
	if _preview_node:
		_preview_node.visible = true


## Deactivate the placement tool
func deactivate() -> void:
	_active = false
	if _preview_node:
		_preview_node.visible = false


## Place a single entity at the current position
func place_entity(
	entity_scene: PackedScene,
	position: Vector3 = Vector3.ZERO,
	rotation: Vector3 = Vector3.ZERO,
	scale: Vector3 = Vector3.ONE
) -> Node:
	if not entity_scene:
		push_error("Cannot place entity: scene is null")
		return null

	# Check placement cooldown
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_placement_time < _placement_cooldown:
		return null  # Too fast

	_last_placement_time = current_time

	# Create instance
	var entity: Node = entity_scene.instantiate()
	if not entity:
		push_error("Failed to instantiate entity scene")
		return null

	# Apply transforms
	if position != Vector3.ZERO:
		entity.global_position = position
	else:
		entity.global_position = _get_world_position_from_mouse()

	entity.rotation = rotation
	entity.scale = scale

	# Apply layer
	if enable_layer_system:
		entity.set_meta("editor_layer", _current_layer)
		var layer_data: EntityLayer = _layers.get(_current_layer)
		if layer_data:
			layer_data.entities.append(entity)

	# Add to scene
	var parent: Node = _get_placement_parent()
	if parent:
		parent.add_child(entity)

	# Track placed entity
	_placed_entities.append(entity)

	# Emit signal
	entity_placed.emit(entity, entity.global_position)

	return entity


## Place entity using current prefab
func place_current_prefab() -> Node:
	if not _current_prefab or not _current_prefab.scene:
		push_warning("No prefab selected for placement")
		return null

	var world_pos: Vector3 = _get_world_position_from_mouse()
	var snapped_pos: Vector3 = _apply_snapping(world_pos)

	return place_entity(
		_current_prefab.scene,
		snapped_pos,
		_current_prefab.default_rotation,
		_current_prefab.default_scale
	)


## Batch place entities with spacing and randomization
func batch_place_entities(
	entity_scene: PackedScene, start_pos: Vector3, count: int, spacing: Vector3 = Vector3.ONE
) -> Array[Node]:
	if count <= 0:
		return []

	batch_operation_started.emit(count)

	var placed_entities: Array[Node] = []
	var current_pos: Vector3 = start_pos

	for i in range(count):
		var pos: Vector3 = current_pos
		var rot: Vector3 = Vector3.ZERO
		var scale: Vector3 = Vector3.ONE

		# Apply randomization if enabled
		if batch_randomize_position:
			pos += _get_random_vector(batch_position_variance)
		if batch_randomize_rotation:
			rot += _get_random_vector(batch_rotation_variance, true)
		if batch_randomize_scale:
			scale += _get_random_vector(batch_scale_variance)

		var entity: Node = place_entity(entity_scene, pos, rot, scale)
		if entity:
			placed_entities.append(entity)

		# Move to next position based on spacing
		current_pos += spacing

	batch_operation_completed.emit(placed_entities.size(), count)
	return placed_entities


## Get random vector with optional degree conversion
func _get_random_vector(variance: Vector3, as_degrees: bool = false) -> Vector3:
	var result: Vector3 = Vector3(
		randf_range(-variance.x, variance.x),
		randf_range(-variance.y, variance.y),
		randf_range(-variance.z, variance.z)
	)

	if as_degrees:
		result = Vector3(deg_to_rad(result.x), deg_to_rad(result.y), deg_to_rad(result.z))

	return result


## Load available prefabs from directory
func _load_available_prefabs() -> void:
	if not enable_prefab_system:
		return

	var dir := DirAccess.open(prefab_save_path)
	if not dir:
		# Create directory if it doesn't exist
		DirAccess.make_dir_recursive_absolute(prefab_save_path)
		dir = DirAccess.open(prefab_save_path)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".tscn") or file_name.ends_with(".scn"):
				var file_path: String = prefab_save_path + file_name
				var scene: PackedScene = load(file_path) as PackedScene

				if scene:
					var prefab_data := PrefabData.new()
					prefab_data.name = file_name.replace(".tscn", "").replace(".scn", "")
					prefab_data.scene = scene
					prefab_data.category = "Custom"

					_prefabs[file_name] = prefab_data
					prefab_loaded.emit(prefab_data.name)

			file_name = dir.get_next()


## Set current prefab by name
func set_current_prefab(prefab_name: String) -> bool:
	if _prefabs.has(prefab_name):
		_current_prefab = _prefabs[prefab_name]
		return true
	if _prefabs.has(prefab_name + ".tscn"):
		_current_prefab = _prefabs[prefab_name + ".tscn"]
		return true

	push_warning("Prefab not found: " + prefab_name)
	return false


## Apply prefab at current position
func apply_prefab(prefab_name: String) -> Array[Node]:
	if not set_current_prefab(prefab_name):
		return []

	if batch_placement_count <= 1:
		var entity: Node = place_current_prefab()
		if entity:
			prefab_applied.emit(prefab_name, 1)
			return [entity]
		return []

	var start_pos: Vector3 = _get_world_position_from_mouse()
	var snapped_pos: Vector3 = _apply_snapping(start_pos)

	var entities: Array[Node] = batch_place_entities(
		_current_prefab.scene, snapped_pos, batch_placement_count, batch_spacing
	)

	prefab_applied.emit(prefab_name, entities.size())
	return entities


## Create new layer
func create_layer(layer_name: String) -> bool:
	if _layers.has(layer_name):
		push_warning("Layer already exists: " + layer_name)
		return false

	var new_layer := EntityLayer.new()
	new_layer.name = layer_name
	new_layer.visible = true
	new_layer.locked = false
	_layers[layer_name] = new_layer

	return true


## Change current active layer
func change_layer(layer_name: String) -> bool:
	if not _layers.has(layer_name):
		push_warning("Layer does not exist: " + layer_name)
		return false

	var old_layer: String = _current_layer
	_current_layer = layer_name
	layer_changed.emit(old_layer, _current_layer)
	return true


## Toggle layer visibility
func toggle_layer_visibility(layer_name: String) -> bool:
	if not _layers.has(layer_name):
		return false

	var layer: EntityLayer = _layers[layer_name]
	layer.visible = not layer.visible

	# Update all entities in the layer
	for entity: Node in layer.entities:
		if entity and is_instance_valid(entity):
			if entity is Node3D:
				entity.visible = layer.visible

	return true


## Toggle layer lock state
func toggle_layer_lock(layer_name: String) -> bool:
	if not _layers.has(layer_name):
		return false

	var layer: EntityLayer = _layers[layer_name]
	layer.locked = not layer.locked
	return true


## Get entities in a specific layer
func get_entities_in_layer(layer_name: String) -> Array[Node]:
	if not _layers.has(layer_name):
		return []

	return _layers[layer_name].entities.duplicate()


## Get all layers
func get_all_layers() -> Dictionary:
	return _layers.duplicate()


## Get current layer name
func get_current_layer() -> String:
	return _current_layer


## Get placement parent node (where entities should be added)
func _get_placement_parent() -> Node:
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		# Look for a specific placement parent or use the current scene
		var placement_parent: Node = current_scene.get_node_or_null("Entities")
		if not placement_parent:
			placement_parent = current_scene
		return placement_parent

	return self


## Remove entity by reference
func remove_entity(entity: Node) -> bool:
	if not entity or not is_instance_valid(entity):
		return false

	# Remove from layer tracking
	var layer_name: String = (
		entity.get_meta("editor_layer", "Default") if entity.has_meta("editor_layer") else "Default"
	)
	if _layers.has(layer_name):
		var layer: EntityLayer = _layers[layer_name]
		layer.entities.erase(entity)

	# Remove from placed entities
	_placed_entities.erase(entity)

	# Queue for removal
	entity.queue_free()

	entity_removed.emit(entity)
	return true


## Remove entities in current layer
func remove_entities_in_current_layer() -> int:
	var count: int = 0
	var entities_to_remove: Array[Node] = get_entities_in_layer(_current_layer)

	for entity: Node in entities_to_remove:
		if remove_entity(entity):
			count += 1

	return count


## Clear all placed entities
func clear_all_entities() -> int:
	var count: int = 0
	var entities_copy: Array[Node] = _placed_entities.duplicate()

	for entity: Node in entities_copy:
		if remove_entity(entity):
			count += 1

	return count


## Save current scene with entity layers
func save_scene_with_layers(_file_path: String) -> Error:
	# This would integrate with the level saving system
	# For now, just return OK as a placeholder
	return OK


## Get statistics about placement
func get_statistics() -> Dictionary:
	return {
		"active": _active,
		"placed_entity_count": _placed_entities.size(),
		"available_prefabs": _prefabs.size(),
		"total_layers": _layers.size(),
		"current_layer": _current_layer,
		"current_prefab": _current_prefab.name if _current_prefab else "None",
		"snap_mode": snap_mode,
		"batch_count": batch_placement_count
	}
