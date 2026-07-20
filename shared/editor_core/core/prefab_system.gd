@tool
class_name PrefabSystem
extends Node

signal prefab_saved(prefab_path: String)
signal prefab_loaded(instance: Node3D)
signal library_updated

const PREFAB_DIR := "user://prefabs/"
const THUMBNAIL_SIZE := Vector2i(128, 128)
const JSONHelperClass = preload("res://game/core/json_helper.gd")

var library: Dictionary = {}  # id -> PrefabInfo
var selection_manager: Node = null
var editor_camera: Camera3D = null


class PrefabInfo:
	var id: String
	var name: String
	var path: String
	var thumbnail_path: String
	var created_at: float
	var tags: PackedStringArray
	var node_count: int
	var bounds: AABB

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"path": path,
			"thumbnail_path": thumbnail_path,
			"created_at": created_at,
			"tags": Array(tags),
			"node_count": node_count,
			"bounds": {"position": bounds.position, "size": bounds.size}
		}

	static func from_dict(data: Dictionary) -> PrefabInfo:
		var info := PrefabInfo.new()
		info.id = data.get("id", "")
		info.name = data.get("name", "")
		info.path = data.get("path", "")
		info.thumbnail_path = data.get("thumbnail_path", "")
		info.created_at = data.get("created_at", 0.0)
		info.tags = PackedStringArray(data.get("tags", []))
		info.node_count = data.get("node_count", 0)
		var bounds_data: Dictionary = data.get("bounds", {})
		info.bounds = AABB(
			bounds_data.get("position", Vector3.ZERO), bounds_data.get("size", Vector3.ONE)
		)
		return info


## Library of all prefabs
## Selection reference


func _ready() -> void:
	_ensure_prefab_directory()
	_load_library()


func _ensure_prefab_directory() -> void:
	DirAccess.make_dir_recursive_absolute(PREFAB_DIR)
	DirAccess.make_dir_recursive_absolute(PREFAB_DIR + "thumbnails/")


## Setup with references


func setup(selection: Node, camera: Camera3D = null) -> void:
	selection_manager = selection
	editor_camera = camera


## Save selected nodes as prefab


func save_selection_as_prefab(prefab_name: String, tags: PackedStringArray = []) -> String:
	if not selection_manager:
		push_warning("[PrefabSystem] No selection manager")
		return ""

	var selected_nodes: Array = []
	if selection_manager.has_method("get_selected"):
		selected_nodes = selection_manager.get_selected()
	elif selection_manager.has_method("get_selection"):
		selected_nodes = selection_manager.get_selection()

	if selected_nodes.is_empty():
		push_warning("[PrefabSystem] No nodes selected")
		return ""

	return await save_nodes_as_prefab(selected_nodes, prefab_name, tags)


## Save specific nodes as prefab


func save_nodes_as_prefab(
	nodes: Array, prefab_name: String, tags: PackedStringArray = []
) -> String:
	if nodes.is_empty():
		return ""

	# Generate unique ID
	var prefab_id: String = _generate_id()
	var safe_name: String = prefab_name.to_snake_case().validate_filename()
	var prefab_path: String = PREFAB_DIR + safe_name + "_" + prefab_id + ".tscn"

	# Create container node
	var container := Node3D.new()
	container.name = prefab_name

	# Calculate center of selection
	var bounds := _calculate_bounds(nodes)
	var center: Vector3 = bounds.position + bounds.size * 0.5

	# Clone nodes into container (centered)
	for node: Node in nodes:
		if node is Node3D:
			var clone: Node = node.duplicate()
			clone.position -= center
			container.add_child(clone)
			clone.owner = container

	# Pack and save
	var packed := PackedScene.new()
	var err: Error = packed.pack(container)
	if err != OK:
		container.queue_free()
		push_error("[PrefabSystem] Failed to pack prefab: %s" % error_string(err))
		return ""

	err = ResourceSaver.save(packed, prefab_path)
	container.queue_free()

	if err != OK:
		push_error("[PrefabSystem] Failed to save prefab: %s" % error_string(err))
		return ""

	# Create prefab info
	var info := PrefabInfo.new()
	info.id = prefab_id
	info.name = prefab_name
	info.path = prefab_path
	info.created_at = Time.get_unix_time_from_system()
	info.tags = tags
	info.node_count = nodes.size()
	info.bounds = bounds

	# Generate thumbnail
	info.thumbnail_path = await _generate_thumbnail(nodes, prefab_id)

	# Add to library
	library[prefab_id] = info
	_save_library()

	prefab_saved.emit(prefab_path)
	library_updated.emit()

	return prefab_path


## Instantiate a prefab


func instantiate_prefab(
	prefab_id: String, position: Vector3 = Vector3.ZERO, rotation: float = 0.0
) -> Node3D:
	if not library.has(prefab_id):
		push_warning("[PrefabSystem] Prefab not found: %s" % prefab_id)
		return null

	var info: PrefabInfo = library[prefab_id]

	if not ResourceLoader.exists(info.path):
		push_warning("[PrefabSystem] Prefab file not found: %s" % info.path)
		return null

	var scene: PackedScene = load(info.path)
	if not scene:
		push_warning("[PrefabSystem] Failed to load prefab: %s" % info.path)
		return null

	var instance: Node3D = scene.instantiate()
	instance.position = position
	instance.rotation.y = rotation
	instance.set_meta("level_editor_placed", true)
	instance.set_meta("prefab_id", prefab_id)

	prefab_loaded.emit(instance)
	return instance


## Delete a prefab


func delete_prefab(prefab_id: String) -> bool:
	if not library.has(prefab_id):
		return false

	var info: PrefabInfo = library[prefab_id]

	# Delete files
	if FileAccess.file_exists(info.path):
		DirAccess.remove_absolute(info.path)
	if FileAccess.file_exists(info.thumbnail_path):
		DirAccess.remove_absolute(info.thumbnail_path)

	library.erase(prefab_id)
	_save_library()
	library_updated.emit()

	return true


## Get all prefabs


func get_all_prefabs() -> Array[PrefabInfo]:
	var result: Array[PrefabInfo] = []
	for id: String in library:
		result.append(library[id])
	return result


## Get prefabs by tag


func get_prefabs_by_tag(tag: String) -> Array[PrefabInfo]:
	var result: Array[PrefabInfo] = []
	for id: String in library:
		var info: PrefabInfo = library[id]
		if tag in info.tags:
			result.append(info)
	return result


## Search prefabs by name


func search_prefabs(query: String) -> Array[PrefabInfo]:
	var result: Array[PrefabInfo] = []
	query = query.to_lower()
	for id: String in library:
		var info: PrefabInfo = library[id]
		if query in info.name.to_lower() or query in id:
			result.append(info)
	return result


## Calculate AABB of nodes


func _calculate_bounds(nodes: Array) -> AABB:
	var bounds := AABB()
	var first := true

	for node: Node in nodes:
		if node is VisualInstance3D:
			var node_aabb: AABB = node.get_aabb()
			node_aabb.position += node.global_position
			if first:
				bounds = node_aabb
				first = false
			else:
				bounds = bounds.merge(node_aabb)
		elif node is Node3D:
			var pos: Vector3 = node.global_position
			if first:
				bounds = AABB(pos, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(pos)

	return bounds


## Generate thumbnail for prefab


func _generate_thumbnail(nodes: Array, prefab_id: String) -> String:
	var thumbnail_path: String = PREFAB_DIR + "thumbnails/" + prefab_id + ".png"

	# If we have a camera, render thumbnail
	if editor_camera:
		# Calculate camera position to frame the nodes
		var bounds: AABB = _calculate_bounds(nodes)
		var center: Vector3 = bounds.position + bounds.size * 0.5
		var size: float = bounds.size.length()

		# Position camera to see the prefab
		var cam_dist: float = maxf(size * 2.0, 3.0)
		var cam_pos: Vector3 = center + Vector3(1, 1, 1).normalized() * cam_dist

		# Create viewport for thumbnail
		var viewport := SubViewport.new()
		viewport.size = THUMBNAIL_SIZE
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

		var cam := Camera3D.new()
		cam.position = cam_pos
		cam.look_at(center)
		viewport.add_child(cam)

		# Clone nodes into viewport
		for node: Node in nodes:
			if node is Node3D:
				var clone: Node = node.duplicate()
				viewport.add_child(clone)

		add_child(viewport)

		# Wait for render
		await get_tree().process_frame
		await get_tree().process_frame

		# Get image
		var img: Image = viewport.get_texture().get_image()
		img.save_png(thumbnail_path)

		viewport.queue_free()
	else:
		# Create placeholder thumbnail
		var img := Image.create(THUMBNAIL_SIZE.x, THUMBNAIL_SIZE.y, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.3, 0.4, 1.0))
		img.save_png(thumbnail_path)

	return thumbnail_path


func _generate_id() -> String:
	return str(Time.get_unix_time_from_system()).sha256_text().substr(0, 8)


## Save library index


func _save_library() -> void:
	var data: Array[Dictionary] = []
	for id: String in library:
		data.append(library[id].to_dict())

	var json: String = JSONHelperClass.safe_stringify(data, "\t")
	var file := FileAccess.open(PREFAB_DIR + "library.json", FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()


## Load library index


func _load_library() -> void:
	library.clear()

	var path: String = PREFAB_DIR + "library.json"
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	var json_str: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Array:
		for item: Dictionary in parsed:
			var info: PrefabInfo = PrefabInfo.from_dict(item)
			library[info.id] = info
