@tool
class_name LevelPackager
extends RefCounted

const MDSL_EXTENSION := "mdsl"
const MANIFEST_FILE := "manifest.json"
const LEVEL_FILE := "level.tscn"
const ASSETS_DIR := "assets/"
const THUMBNAIL_FILE := "thumbnail.png"
const JSONHelperClass = preload("res://game/core/json_helper.gd")


class LevelManifest:
	var id: String = ""
	var name: String = ""
	var author: String = ""
	var description: String = ""
	var version: String = "1.0.0"
	var created_at: int = 0
	var updated_at: int = 0
	var tags: PackedStringArray = []
	var dependencies: PackedStringArray = []
	var thumbnail: String = THUMBNAIL_FILE
	var level_file: String = LEVEL_FILE
	var asset_count: int = 0
	var workshop_id: String = ""

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"author": author,
			"description": description,
			"version": version,
			"created_at": created_at,
			"updated_at": updated_at,
			"tags": Array(tags),
			"dependencies": Array(dependencies),
			"thumbnail": thumbnail,
			"level_file": level_file,
			"asset_count": asset_count,
			"workshop_id": workshop_id
		}

	static func from_dict(data: Dictionary) -> LevelManifest:
		var manifest := LevelManifest.new()
		manifest.id = data.get("id", "")
		manifest.name = data.get("name", "")
		manifest.author = data.get("author", "")
		manifest.description = data.get("description", "")
		manifest.version = data.get("version", "1.0.0")
		manifest.created_at = data.get("created_at", 0)
		manifest.updated_at = data.get("updated_at", 0)
		manifest.tags = PackedStringArray(data.get("tags", []))
		manifest.dependencies = PackedStringArray(data.get("dependencies", []))
		manifest.thumbnail = data.get("thumbnail", THUMBNAIL_FILE)
		manifest.level_file = data.get("level_file", LEVEL_FILE)
		manifest.asset_count = data.get("asset_count", 0)
		manifest.workshop_id = data.get("workshop_id", "")
		return manifest


## Package result


class PackageResult:
	var success: bool = false
	var error_msg: String = ""
	var output_path: String = ""
	var manifest: LevelManifest = null


## Extract result


class ExtractResult:
	var success: bool = false
	var error_msg: String = ""
	var level_path: String = ""
	var manifest: LevelManifest = null


## Package a level scene into .mdsl format


static func package_level(
	level_root: Node3D, output_dir: String, manifest: LevelManifest, thumbnail: Image = null
) -> PackageResult:
	var result := PackageResult.new()

	if not level_root:
		result.error_msg = "No level root provided"
		return result

	if manifest.name.is_empty():
		manifest.name = level_root.name

	if manifest.id.is_empty():
		manifest.id = _generate_id()

	manifest.created_at = int(Time.get_unix_time_from_system())
	manifest.updated_at = manifest.created_at

	# Create temp directory for packaging
	var temp_dir: String = "user://temp_package/"
	DirAccess.make_dir_recursive_absolute(temp_dir)
	DirAccess.make_dir_recursive_absolute(temp_dir + ASSETS_DIR)

	# Save level scene
	var level_path: String = temp_dir + LEVEL_FILE
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(level_root)
	if pack_err != OK:
		result.error_msg = "Failed to pack level: %s" % error_string(pack_err)
		return result

	var save_err: Error = ResourceSaver.save(packed, level_path)
	if save_err != OK:
		result.error_msg = "Failed to save level: %s" % error_string(save_err)
		return result

	# Collect and copy assets
	var assets: Array[String] = _collect_assets(level_root)
	manifest.asset_count = assets.size()

	for asset_path: String in assets:
		var asset_name: String = asset_path.get_file()
		var dest_path: String = temp_dir + ASSETS_DIR + asset_name
		DirAccess.copy_absolute(asset_path, dest_path)

	# Save thumbnail
	if thumbnail:
		thumbnail.save_png(temp_dir + THUMBNAIL_FILE)
	else:
		# Create placeholder thumbnail
		var placeholder := Image.create(256, 256, false, Image.FORMAT_RGB8)
		placeholder.fill(Color(0.2, 0.3, 0.4))
		placeholder.save_png(temp_dir + THUMBNAIL_FILE)

	# Save manifest
	var manifest_json: String = JSONHelperClass.safe_stringify(manifest.to_dict(), "\t")
	var manifest_file := FileAccess.open(temp_dir + MANIFEST_FILE, FileAccess.WRITE)
	if manifest_file:
		manifest_file.store_string(manifest_json)
		manifest_file.close()

	# Create ZIP archive
	var safe_name: String = manifest.name.to_snake_case().validate_filename()
	var zip_path: String = output_dir.path_join(safe_name + "." + MDSL_EXTENSION)
	DirAccess.make_dir_recursive_absolute(output_dir)

	var zip_err: Error = _create_zip(temp_dir, zip_path)
	if zip_err != OK:
		result.error_msg = "Failed to create ZIP: %s" % error_string(zip_err)
		return result

	# Cleanup temp directory
	_remove_directory(temp_dir)

	result.success = true
	result.output_path = zip_path
	result.manifest = manifest
	return result


## Extract a .mdsl package


static func extract_level(mdsl_path: String, output_dir: String) -> ExtractResult:
	var result := ExtractResult.new()

	if not FileAccess.file_exists(mdsl_path):
		result.error_msg = "Package not found: %s" % mdsl_path
		return result

	# Extract ZIP
	var extract_err: Error = _extract_zip(mdsl_path, output_dir)
	if extract_err != OK:
		result.error_msg = "Failed to extract: %s" % error_string(extract_err)
		return result

	# Load manifest
	var manifest_path: String = output_dir.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(manifest_path):
		result.error_msg = "Manifest not found in package"
		return result

	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if not manifest_file:
		result.error_msg = "Failed to read manifest"
		return result

	var manifest_json: String = manifest_file.get_as_text()
	manifest_file.close()

	var parsed: Variant = JSON.parse_string(manifest_json)
	if not parsed is Dictionary:
		result.error_msg = "Invalid manifest format"
		return result

	result.manifest = LevelManifest.from_dict(parsed)
	result.level_path = output_dir.path_join(result.manifest.level_file)
	result.success = true
	return result


## Read manifest from .mdsl without full extraction


static func read_manifest(mdsl_path: String) -> LevelManifest:
	var reader := ZIPReader.new()
	var err: Error = reader.open(mdsl_path)
	if err != OK:
		reader.close()
		return null

	if not reader.file_exists(MANIFEST_FILE):
		reader.close()
		return null
	var content: PackedByteArray = reader.read_file(MANIFEST_FILE)
	reader.close()

	if content.is_empty():
		return null

	var json_str: String = content.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_str)
	if parsed is Dictionary:
		return LevelManifest.from_dict(parsed)

	return null


## Read thumbnail from .mdsl without full extraction


static func read_thumbnail(mdsl_path: String) -> Image:
	var reader := ZIPReader.new()
	var err: Error = reader.open(mdsl_path)
	if err != OK:
		reader.close()
		return null

	if not reader.file_exists(THUMBNAIL_FILE):
		reader.close()
		return null
	var content: PackedByteArray = reader.read_file(THUMBNAIL_FILE)
	reader.close()

	if content.is_empty():
		return null

	var img := Image.new()
	img.load_png_from_buffer(content)
	return img


## Collect all referenced assets from a level


static func _collect_assets(level_root: Node) -> Array[String]:
	var assets: Array[String] = []
	var visited: Dictionary = {}

	_collect_node_assets(level_root, assets, visited)

	return assets


static func _collect_node_assets(node: Node, assets: Array[String], visited: Dictionary) -> void:
	# Check for materials
	if node is MeshInstance3D:
		for i: int in range(node.get_surface_override_material_count()):
			var mat: Material = node.get_surface_override_material(i)
			if mat and mat.resource_path and not visited.has(mat.resource_path):
				assets.append(mat.resource_path)
				visited[mat.resource_path] = true

	# Check for textures in CSG
	if node is CSGShape3D:
		var mat: Material = node.material
		if mat and mat.resource_path and not visited.has(mat.resource_path):
			assets.append(mat.resource_path)
			visited[mat.resource_path] = true

	# Recurse children
	for child: Node in node.get_children():
		_collect_node_assets(child, assets, visited)


static func _create_zip(source_dir: String, zip_path: String) -> Error:
	var writer := ZIPPacker.new()
	var err: Error = writer.open(zip_path)
	if err != OK:
		return err

	_add_dir_to_zip(writer, source_dir, "")

	writer.close()
	return OK


static func _add_dir_to_zip(writer: ZIPPacker, base_dir: String, relative_path: String) -> void:
	var dir := DirAccess.open(base_dir + relative_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while not file_name.is_empty():
		var full_rel_path: String = relative_path + file_name
		var full_abs_path: String = base_dir + full_rel_path

		if dir.current_is_dir():
			_add_dir_to_zip(writer, base_dir, full_rel_path + "/")
		else:
			var file := FileAccess.open(full_abs_path, FileAccess.READ)
			if file:
				writer.start_file(full_rel_path)
				writer.write_file(file.get_buffer(file.get_length()))
				writer.close_file()
				file.close()

		file_name = dir.get_next()

	dir.list_dir_end()


static func _is_safe_zip_entry(entry_path: String, extraction_root: String) -> bool:
	var normalized_path: String = entry_path.replace("\\", "/")
	if normalized_path.is_empty() or normalized_path.contains("://"):
		return false
	if normalized_path.begins_with("/") or (
		normalized_path.length() >= 2 and normalized_path[1] == ":"
	):
		return false

	for component: String in normalized_path.split("/", true):
		if component == "..":
			return false

	var root_path: String = ProjectSettings.globalize_path(extraction_root).simplify_path()
	var target_path: String = ProjectSettings.globalize_path(
		extraction_root.path_join(normalized_path)
	).simplify_path()
	if not (target_path == root_path or target_path.begins_with(root_path + "/")):
		return false

	var root_parent: DirAccess = DirAccess.open(root_path.get_base_dir())
	if not root_parent or root_parent.is_link(root_path.get_file()):
		return false

	var current_path: String = root_path
	for component: String in normalized_path.split("/", true):
		if component.is_empty() or component == ".":
			continue
		current_path = current_path.path_join(component)
		var parent_dir: DirAccess = DirAccess.open(current_path.get_base_dir())
		if parent_dir and parent_dir.is_link(current_path.get_file()):
			return false
	return true


static func _ensure_zip_directory(path: String) -> Error:
	var absolute_path: String = ProjectSettings.globalize_path(path)
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(absolute_path)
	if dir_err != OK and not DirAccess.dir_exists_absolute(absolute_path):
		return dir_err
	return OK


static func _extract_zip(zip_path: String, output_dir: String) -> Error:
	var reader := ZIPReader.new()
	var err: Error = reader.open(zip_path)
	if err != OK:
		reader.close()
		return err

	var root_err: Error = _ensure_zip_directory(output_dir)
	if root_err != OK:
		reader.close()
		return root_err

	var files: PackedStringArray = reader.get_files()
	for file_path: String in files:
		if not _is_safe_zip_entry(file_path, output_dir):
			reader.close()
			return ERR_INVALID_PARAMETER

		var normalized_path: String = file_path.replace("\\", "/")
		var out_path: String = output_dir.path_join(normalized_path)
		if normalized_path.ends_with("/"):
			var directory_err: Error = _ensure_zip_directory(out_path)
			if directory_err != OK:
				reader.close()
				return directory_err
			continue

		if not reader.file_exists(file_path):
			reader.close()
			return ERR_FILE_CANT_READ
		var content: PackedByteArray = reader.read_file(file_path)

		# Create subdirectories
		var dir_err: Error = _ensure_zip_directory(out_path.get_base_dir())
		if dir_err != OK:
			reader.close()
			return dir_err

		var out_file := FileAccess.open(out_path, FileAccess.WRITE)
		if not out_file:
			reader.close()
			return ERR_FILE_CANT_OPEN
		out_file.store_buffer(content)
		out_file.flush()
		var write_err: Error = out_file.get_error()
		out_file.close()
		if write_err != OK:
			reader.close()
			return write_err

	reader.close()
	return OK


static func _remove_directory(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while not file_name.is_empty():
		var full_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			_remove_directory(full_path)
			DirAccess.remove_absolute(full_path)
		else:
			DirAccess.remove_absolute(full_path)
		file_name = dir.get_next()

	dir.list_dir_end()
	DirAccess.remove_absolute(path)


static func _generate_id() -> String:
	return str(Time.get_unix_time_from_system()).sha256_text().substr(0, 12)
