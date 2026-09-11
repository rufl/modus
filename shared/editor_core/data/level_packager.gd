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
	if not manifest:
		result.error_msg = "No manifest provided"
		return result

	if manifest.name.is_empty():
		manifest.name = level_root.name
	if manifest.id.is_empty():
		manifest.id = _generate_id()
	manifest.created_at = int(Time.get_unix_time_from_system())
	manifest.updated_at = manifest.created_at

	var level_rel_path := manifest.level_file.replace("\\", "/")
	var thumbnail_rel_path := manifest.thumbnail.replace("\\", "/")
	if not _is_valid_package_path(level_rel_path) or not _is_valid_package_path(thumbnail_rel_path):
		result.error_msg = "Manifest paths must be relative package files"
		return result
	manifest.level_file = level_rel_path
	manifest.thumbnail = thumbnail_rel_path
	if level_rel_path == MANIFEST_FILE or thumbnail_rel_path == MANIFEST_FILE:
		result.error_msg = "Manifest paths cannot replace manifest.json"
		return result
	if level_rel_path == thumbnail_rel_path:
		result.error_msg = "Manifest level_file and thumbnail must differ"
		return result

	# Keep each staging directory unique so concurrent exports cannot overwrite one another.
	var temp_dir := "user://temp_package_%s_%s/" % [
		_generate_id(), str(Time.get_ticks_usec())
	]
	var root_err := _ensure_zip_directory(temp_dir)
	if root_err != OK:
		return _package_failure(result, temp_dir, "Failed to create staging directory: %s" % error_string(root_err))

	var assets := _collect_assets(level_root)
	var asset_map := _build_asset_map(assets)
	if asset_map.values().has(level_rel_path) or asset_map.values().has(thumbnail_rel_path):
		return _package_failure(result, temp_dir, "Manifest path conflicts with packaged asset")
	manifest.asset_count = assets.size()

	# Save the packed scene before rewriting its external resource paths.
	var level_path := temp_dir.path_join(level_rel_path)
	var level_parent_err := _ensure_zip_directory(level_path.get_base_dir())
	if level_parent_err != OK:
		return _package_failure(result, temp_dir, "Failed to create level directory: %s" % error_string(level_parent_err))
	var packed := PackedScene.new()
	var pack_err: Error = packed.pack(level_root)
	if pack_err != OK:
		return _package_failure(result, temp_dir, "Failed to pack level: %s" % error_string(pack_err))
	var save_err: Error = ResourceSaver.save(packed, level_path)
	if save_err != OK or not FileAccess.file_exists(level_path):
		if save_err == OK:
			save_err = ERR_FILE_CANT_WRITE
		return _package_failure(result, temp_dir, "Failed to save level: %s" % error_string(save_err))

	for source_path: String in assets:
		var destination_rel: String = asset_map[source_path]
		var destination_path := temp_dir.path_join(destination_rel)
		var destination_dir_err := _ensure_zip_directory(destination_path.get_base_dir())
		if destination_dir_err != OK:
			return _package_failure(result, temp_dir, "Failed to create asset directory: %s" % error_string(destination_dir_err))
		var copy_err: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source_path),
			ProjectSettings.globalize_path(destination_path)
		)
		if copy_err != OK:
			return _package_failure(result, temp_dir, "Failed to copy asset '%s': %s" % [source_path, error_string(copy_err)])
		if not FileAccess.file_exists(destination_path):
			return _package_failure(result, temp_dir, "Copied asset is missing: %s" % destination_rel)

	# Rewrite every text resource independently so references are relative to its package location.
	var rewrite_err := _rewrite_text_resource(
		level_path, level_rel_path, temp_dir, asset_map
	)
	if rewrite_err != OK:
		return _package_failure(result, temp_dir, "Failed to rewrite level resource paths: %s" % error_string(rewrite_err))
	for source_path: String in assets:
		var asset_path := temp_dir.path_join(asset_map[source_path])
		if not _is_text_resource(asset_path):
			var binary_dependencies: PackedStringArray = ResourceLoader.get_dependencies(source_path)
			if not binary_dependencies.is_empty():
				return _package_failure(
					result, temp_dir,
					"Cannot rewrite binary asset dependencies for '%s'" % source_path
				)
		elif _is_text_resource(asset_path):
			rewrite_err = _rewrite_text_resource(
				asset_path, asset_map[source_path], temp_dir, asset_map
			)
			if rewrite_err != OK:
				return _package_failure(result, temp_dir, "Failed to rewrite asset '%s': %s" % [source_path, error_string(rewrite_err)])
			if asset_path.get_extension().to_lower() == "tscn":
				var unresolved_asset := _find_unresolved_scene_paths(asset_path)
				if not unresolved_asset.is_empty():
					return _package_failure(
						result, temp_dir,
						"Packaged scene asset has unresolved references: %s" % ", ".join(unresolved_asset)
					)

	var unresolved := _find_unresolved_scene_paths(level_path)
	if not unresolved.is_empty():
		return _package_failure(
			result, temp_dir,
			"Packaged scene has unresolved resource references: %s" % ", ".join(unresolved)
		)

	# Save thumbnail and check the Image API's returned error.
	var thumbnail_path := temp_dir.path_join(thumbnail_rel_path)
	var thumbnail_parent_err := _ensure_zip_directory(thumbnail_path.get_base_dir())
	if thumbnail_parent_err != OK:
		return _package_failure(result, temp_dir, "Failed to create thumbnail directory: %s" % error_string(thumbnail_parent_err))
	var thumbnail_err: Error
	if thumbnail:
		thumbnail_err = thumbnail.save_png(thumbnail_path)
	else:
		var placeholder := Image.create(256, 256, false, Image.FORMAT_RGB8)
		placeholder.fill(Color(0.2, 0.3, 0.4))
		thumbnail_err = placeholder.save_png(thumbnail_path)
	if thumbnail_err != OK or not FileAccess.file_exists(thumbnail_path):
		if thumbnail_err == OK:
			thumbnail_err = ERR_FILE_CANT_WRITE
		return _package_failure(result, temp_dir, "Failed to save thumbnail: %s" % error_string(thumbnail_err))

	var manifest_json := JSONHelperClass.safe_stringify(manifest.to_dict(), "\t")
	if manifest_json.is_empty():
		return _package_failure(result, temp_dir, "Failed to serialize manifest")
	var manifest_file := FileAccess.open(temp_dir.path_join(MANIFEST_FILE), FileAccess.WRITE)
	if not manifest_file:
		return _package_failure(result, temp_dir, "Failed to open manifest for writing")
	manifest_file.store_string(manifest_json)
	manifest_file.flush()
	var manifest_err := manifest_file.get_error()
	manifest_file.close()
	if manifest_err != OK or not FileAccess.file_exists(temp_dir.path_join(MANIFEST_FILE)):
		if manifest_err == OK:
			manifest_err = ERR_FILE_CANT_WRITE
		return _package_failure(result, temp_dir, "Failed to save manifest: %s" % error_string(manifest_err))

	var safe_name := manifest.name.to_snake_case().validate_filename()
	if safe_name.is_empty():
		safe_name = manifest.id.validate_filename()
	var output_dir_err := _ensure_zip_directory(output_dir)
	if output_dir_err != OK:
		return _package_failure(result, temp_dir, "Failed to create output directory: %s" % error_string(output_dir_err))
	var zip_path := output_dir.path_join(safe_name + "." + MDSL_EXTENSION)
	var zip_err: Error = _create_zip(temp_dir, zip_path)
	if zip_err != OK or not FileAccess.file_exists(zip_path):
		if zip_err == OK:
			zip_err = ERR_FILE_CANT_WRITE
		return _package_failure(result, temp_dir, "Failed to create ZIP: %s" % error_string(zip_err))

	_remove_directory(temp_dir)
	result.success = true
	result.output_path = zip_path
	result.manifest = manifest
	return result


static func _package_failure(result: PackageResult, temp_dir: String, message: String) -> PackageResult:
	_remove_directory(temp_dir)
	result.error_msg = message
	return result


## Extract a .mdsl package
static func extract_level(mdsl_path: String, output_dir: String) -> ExtractResult:
	var result := ExtractResult.new()

	if not FileAccess.file_exists(mdsl_path):
		result.error_msg = "Package not found: %s" % mdsl_path
		return result

	var extract_err: Error = _extract_zip(mdsl_path, output_dir)
	if extract_err != OK:
		result.error_msg = "Failed to extract: %s" % error_string(extract_err)
		return result

	var manifest_path := output_dir.path_join(MANIFEST_FILE)
	if not FileAccess.file_exists(manifest_path):
		result.error_msg = "Manifest not found in package"
		return result
	var manifest_file := FileAccess.open(manifest_path, FileAccess.READ)
	if not manifest_file:
		result.error_msg = "Failed to read manifest"
		return result
	var manifest_json := manifest_file.get_as_text()
	var manifest_read_err := manifest_file.get_error()
	manifest_file.close()
	if manifest_read_err != OK:
		result.error_msg = "Failed to read manifest: %s" % error_string(manifest_read_err)
		return result

	var parsed: Variant = JSON.parse_string(manifest_json)
	if not parsed is Dictionary:
		result.error_msg = "Invalid manifest format"
		return result
	result.manifest = LevelManifest.from_dict(parsed)
	result.manifest.level_file = result.manifest.level_file.replace("\\", "/")
	result.manifest.thumbnail = result.manifest.thumbnail.replace("\\", "/")
	if not _is_safe_zip_entry(result.manifest.level_file, output_dir):
		result.error_msg = "Manifest level_file escapes package: %s" % result.manifest.level_file
		return result
	if not _is_safe_zip_entry(result.manifest.thumbnail, output_dir):
		result.error_msg = "Manifest thumbnail escapes package: %s" % result.manifest.thumbnail
		return result
	result.level_path = output_dir.path_join(result.manifest.level_file)
	var thumbnail_path := output_dir.path_join(result.manifest.thumbnail)
	if not FileAccess.file_exists(result.level_path):
		result.error_msg = "Manifest level_file is missing: %s" % result.manifest.level_file
		return result
	if not FileAccess.file_exists(thumbnail_path):
		result.error_msg = "Manifest thumbnail is missing: %s" % result.manifest.thumbnail
		return result
	result.success = true
	return result


static func _is_valid_package_path(path: String) -> bool:
	var normalized := path.replace("\\", "/")
	if normalized.is_empty() or normalized.contains("://") or normalized.begins_with("/"):
		return false
	if normalized.length() >= 2 and normalized[1] == ":":
		return false
	for component: String in normalized.split("/", true):
		if component == ".." or component.is_empty() or component == ".":
			return false
	return true
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
	if content.is_empty():
		reader.close()
		return null
	var json_str := content.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json_str)
	if not parsed is Dictionary:
		reader.close()
		return null
	var manifest := LevelManifest.from_dict(parsed)
	manifest.level_file = manifest.level_file.replace("\\", "/")
	manifest.thumbnail = manifest.thumbnail.replace("\\", "/")
	if (
		not _is_valid_package_path(manifest.level_file)
		or not _is_valid_package_path(manifest.thumbnail)
		or not reader.file_exists(manifest.level_file)
		or not reader.file_exists(manifest.thumbnail)
	):
		reader.close()
		return null
	reader.close()
	return manifest


## Read thumbnail from .mdsl without full extraction
static func read_thumbnail(mdsl_path: String) -> Image:
	var reader := ZIPReader.new()
	var err: Error = reader.open(mdsl_path)
	if err != OK:
		reader.close()
		return null
	if not reader.file_exists(MANIFEST_FILE):
		reader.close()
		return null
	var manifest_content := reader.read_file(MANIFEST_FILE)
	if manifest_content.is_empty():
		reader.close()
		return null
	var parsed: Variant = JSON.parse_string(manifest_content.get_string_from_utf8())
	if not parsed is Dictionary:
		reader.close()
		return null
	var manifest := LevelManifest.from_dict(parsed)
	manifest.thumbnail = manifest.thumbnail.replace("\\", "/")
	if not _is_valid_package_path(manifest.thumbnail) or not reader.file_exists(manifest.thumbnail):
		reader.close()
		return null
	var content: PackedByteArray = reader.read_file(manifest.thumbnail)
	reader.close()
	if content.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(content) != OK:
		return null
	return img


## Collect all referenced assets, including transitive ResourceLoader dependencies.
static func _collect_assets(level_root: Node) -> Array[String]:
	var assets: Array[String] = []
	var visited: Dictionary = {}
	_collect_node_assets(level_root, assets, visited)
	return assets


static func _collect_node_assets(node: Node, assets: Array[String], visited: Dictionary) -> void:
	if not node:
		return
	var node_key := "node:%s" % str(node.get_instance_id())
	if visited.has(node_key):
		return
	visited[node_key] = true
	for property_info: Dictionary in node.get_property_list():
		var property_name: String = property_info.get("name", "")
		if not property_name.is_empty():
			_collect_variant_assets(node.get(property_name), assets, visited)
	for child: Node in node.get_children():
		_collect_node_assets(child, assets, visited)


static func _collect_variant_assets(value: Variant, assets: Array[String], visited: Dictionary) -> void:
	if value is Resource:
		var resource: Resource = value
		var object_key := "resource:%s" % str(resource.get_instance_id())
		if visited.has(object_key):
			return
		visited[object_key] = true
		if not resource.resource_path.is_empty():
			_collect_file_dependencies(resource.resource_path, assets, visited)
		for property_info: Dictionary in resource.get_property_list():
			var property_name: String = property_info.get("name", "")
			if not property_name.is_empty():
				_collect_variant_assets(resource.get(property_name), assets, visited)
	elif value is Array:
		for item: Variant in value:
			_collect_variant_assets(item, assets, visited)
	elif value is Dictionary:
		for key: Variant in value:
			_collect_variant_assets(key, assets, visited)
			_collect_variant_assets(value[key], assets, visited)


static func _collect_file_dependencies(
	source_path: String, assets: Array[String], visited: Dictionary
) -> void:
	var normalized := source_path.replace("\\", "/").simplify_path()
	if normalized.is_empty() or normalized.begins_with("uid://"):
		return
	var path_key := "path:%s" % normalized
	if visited.has(path_key):
		return
	visited[path_key] = true
	if FileAccess.file_exists(normalized):
		assets.append(normalized)
	else:
		return
	var dependencies: PackedStringArray = ResourceLoader.get_dependencies(normalized)
	for dependency_entry: String in dependencies:
		var dependency := dependency_entry.get_slice("::", 0)
		_collect_file_dependencies(dependency, assets, visited)


static func _build_asset_map(assets: Array[String]) -> Dictionary:
	var asset_map: Dictionary = {}
	var destinations: Dictionary = {}
	for source_path: String in assets:
		var basename := source_path.get_file().validate_filename()
		if basename.is_empty():
			basename = "asset"
		var identity := source_path.replace("\\", "/").sha256_text()
		var destination := ASSETS_DIR + identity + "_" + basename
		var suffix := 1
		while destinations.has(destination) and destinations[destination] != source_path:
			suffix += 1
			destination = ASSETS_DIR + identity + "_%d_%s" % [suffix, basename]
		destinations[destination] = source_path
		asset_map[source_path] = destination
	return asset_map


static func _is_text_resource(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return extension in ["tscn", "tres", "godot", "gd", "gdshader", "shader", "material"]


static func _rewrite_text_resource(
	path: String, package_relative_path: String, _package_root: String, asset_map: Dictionary
) -> Error:
	if not _is_text_resource(path):
		return OK
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ERR_FILE_CANT_OPEN
	var content := file.get_as_text()
	var read_err := file.get_error()
	file.close()
	if read_err != OK:
		return read_err
	var relative_map: Dictionary = {}
	var package_dir := package_relative_path.get_base_dir()
	for source_path: String in asset_map:
		relative_map[source_path] = _relative_package_path(package_dir, asset_map[source_path])
	var sources: Array[String] = []
	for source_path: String in relative_map:
		sources.append(source_path)
	sources.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for source_path: String in sources:
		content = content.replace(source_path, relative_map[source_path])
	var write_file := FileAccess.open(path, FileAccess.WRITE)
	if not write_file:
		return ERR_FILE_CANT_OPEN
	write_file.store_string(content)
	write_file.flush()
	var write_err := write_file.get_error()
	write_file.close()
	return write_err


static func _relative_package_path(from_dir: String, destination: String) -> String:
	var from_parts = [] if from_dir == "." or from_dir.is_empty() else from_dir.split("/", true)
	var destination_parts := destination.split("/", true)
	var common := 0
	while common < from_parts.size() and common < destination_parts.size():
		if from_parts[common] != destination_parts[common]:
			break
		common += 1
	var parts: Array[String] = []
	for _i in range(from_parts.size() - common):
		parts.append("..")
	for i in range(common, destination_parts.size()):
		parts.append(destination_parts[i])
	return "/".join(parts)


static func _find_unresolved_scene_paths(path: String) -> PackedStringArray:
	var unresolved := PackedStringArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		unresolved.append(path)
		return unresolved
	var content := file.get_as_text()
	file.close()
	var regex := RegEx.new()
	if regex.compile("(?:res|user|file|https?)://[^\\\"\\s]+") != OK:
		unresolved.append("invalid resource path scanner")
		return unresolved
	for match: RegExMatch in regex.search_all(content):
		var candidate := match.get_string()
		if not unresolved.has(candidate):
			unresolved.append(candidate)
	return unresolved


static func _create_zip(source_dir: String, zip_path: String) -> Error:
	var writer := ZIPPacker.new()
	var err: Error = writer.open(zip_path)
	if err != OK:
		if FileAccess.file_exists(zip_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
		return err
	var add_err := _add_dir_to_zip(writer, source_dir, "")
	writer.close()
	if add_err != OK:
		if FileAccess.file_exists(zip_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
		return add_err
	return OK


static func _add_dir_to_zip(
	writer: ZIPPacker, base_dir: String, relative_path: String
) -> Error:
	var dir := DirAccess.open(base_dir.path_join(relative_path))
	if not dir:
		return ERR_CANT_OPEN
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		var full_rel_path: String = relative_path + file_name
		var full_abs_path: String = base_dir.path_join(full_rel_path)
		var operation_err: Error = OK
		if dir.current_is_dir():
			operation_err = _add_dir_to_zip(writer, base_dir, full_rel_path + "/")
		else:
			var file := FileAccess.open(full_abs_path, FileAccess.READ)
			if not file:
				operation_err = ERR_FILE_CANT_OPEN
			else:
				var content := file.get_buffer(file.get_length())
				operation_err = file.get_error()
				file.close()
				if operation_err == OK:
					operation_err = writer.start_file(full_rel_path)
				if operation_err == OK:
					operation_err = writer.write_file(content)
				if operation_err == OK:
					operation_err = writer.close_file()
		if operation_err != OK:
			dir.list_dir_end()
			return operation_err
		file_name = dir.get_next()
	dir.list_dir_end()
	return OK

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
