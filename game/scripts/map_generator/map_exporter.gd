extends RefCounted
class_name MapExporter

## MapExporter - Handles exporting generated maps to various formats
## Implements Requirements 31.1-31.6

const GenConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const GenContext = preload("res://game/scripts/map_generator/generation_context.gd")


## Export map as PackedScene (.tscn)
func export_packed_scene(map_scene: PackedScene, output_path: String, metadata: Dictionary) -> bool:
	# Ensure output directory exists
	var dir_path := output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Save PackedScene
	var save_result := ResourceSaver.save(map_scene, output_path)
	if save_result != OK:
		push_error(
			"MapExporter: Failed to save PackedScene to %s (error %d)" % [output_path, save_result]
		)
		return false

	# Save metadata JSON
	var metadata_path := output_path.get_basename() + ".json"
	if not _save_metadata_json(metadata, metadata_path):
		push_warning("MapExporter: Failed to save metadata to %s" % metadata_path)
		# Don't fail export if metadata save fails

	return true


## Export map as GLTF (optional)
func export_gltf(map_scene: PackedScene, output_path: String, metadata: Dictionary) -> bool:
	# Instantiate scene to export
	var scene_root := map_scene.instantiate()
	if not scene_root:
		push_error("MapExporter: Failed to instantiate scene for GLTF export")
		return false

	# Create GLTF document
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	# Append scene to GLTF state
	var append_result := gltf_document.append_from_scene(scene_root, gltf_state)
	if append_result != OK:
		push_error("MapExporter: Failed to append scene to GLTF (error %d)" % append_result)
		scene_root.free()
		return false

	# Embed metadata in GLTF extras
	gltf_state.json["extras"] = metadata

	# Ensure output directory exists
	var dir_path := output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Write GLTF file
	var write_result := gltf_document.write_to_filesystem(gltf_state, output_path)
	scene_root.free()

	if write_result != OK:
		push_error(
			"MapExporter: Failed to write GLTF to %s (error %d)" % [output_path, write_result]
		)
		return false

	return true


## Validate exported file can be loaded
func validate_export(output_path: String) -> bool:
	# Check file exists
	if not FileAccess.file_exists(output_path):
		push_error("MapExporter: Exported file does not exist: %s" % output_path)
		return false

	# Try to load the resource
	var loaded_resource: Resource = ResourceLoader.load(output_path)
	if not loaded_resource:
		push_error("MapExporter: Failed to load exported file: %s" % output_path)
		return false

	# Verify it's a PackedScene or GLTFDocument
	if not (loaded_resource is PackedScene or loaded_resource is GLTFDocument):
		push_error("MapExporter: Exported file is not a valid scene: %s" % output_path)
		return false

	# If PackedScene, try to instantiate it
	if loaded_resource is PackedScene:
		var instance: Node = loaded_resource.instantiate()
		if not instance:
			push_error("MapExporter: Failed to instantiate exported scene: %s" % output_path)
			return false
		instance.free()

	return true


## Build comprehensive metadata dictionary
func build_metadata(
	context: GenContext, config: GenConfig, total_time_ms: int, seed_str: String
) -> Dictionary:
	var metadata := {
		"version": "1.0",
		"generator": "MODUS Obsidian-Style Map Generator",
		"export_timestamp": Time.get_datetime_string_from_system(),
		"seed": seed_str,
		"seed_hash": context.seed_hash if context else 0,
		"generation_time_ms": total_time_ms,
		"map_size": [config.map_size.x, config.map_size.y] if config else [0, 0],
		"theme": _theme_to_string(config.theme) if config else "unknown",
		"config": _build_config_metadata(config),
		"statistics": _build_statistics(context),
		"phase_times": context.phase_times if context else {},
		"rule_modules_used": context.rule_modules_used if context else []
	}

	return metadata


## Save metadata to JSON file
func _save_metadata_json(metadata: Dictionary, output_path: String) -> bool:
	var json_string := JSON.stringify(metadata, "\t")

	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		push_error("MapExporter: Failed to open metadata file for writing: %s" % output_path)
		return false

	file.store_string(json_string)
	file.close()

	return true


## Build configuration metadata
func _build_config_metadata(config: GenConfig) -> Dictionary:
	if not config:
		return {}

	return {
		"outdoor_bias": config.outdoor_bias,
		"cave_bias": config.cave_bias,
		"prefab_detail_level": config.prefab_detail_level,
		"prop_density": config.prop_density,
		"decorative_density": config.decorative_density,
		"monster_density": config.monster_density,
		"difficulty_scaling": _difficulty_to_string(config.difficulty_scaling),
		"item_density": config.item_density,
		"secret_room_count": config.secret_room_count,
		"enable_key_locks": config.enable_key_locks,
		"enable_boss_arena": config.enable_boss_arena,
		"enable_secrets": config.enable_secrets,
		"enable_lod": config.enable_lod,
		"enable_occlusion_culling": config.enable_occlusion_culling,
		"use_multimesh": config.use_multimesh
	}


## Build statistics metadata
func _build_statistics(context: GenContext) -> Dictionary:
	if not context:
		return {}

	return {
		"room_count": context.rooms.size(),
		"hallway_count": context.hallways.size(),
		"outdoor_area_count": context.outdoor_areas.size(),
		"cave_area_count": context.cave_areas.size(),
		"secret_count": _count_secret_rooms(context),
		"monster_spawn_count": context.monster_spawns.size(),
		"item_spawn_count": context.item_spawns.size(),
		"key_placement_count": context.key_placements.size(),
		"prefab_instance_count": context.prefab_instances.size()
	}


## Count secret rooms
func _count_secret_rooms(context: GenContext) -> int:
	var count := 0
	for room: Room in context.rooms:
		if room.metadata.get("is_secret", false):
			count += 1
	return count


## Convert theme enum to string
func _theme_to_string(theme: GenConfig.ThemeType) -> String:
	match theme:
		GenConfig.ThemeType.TECH:
			return "tech"
		GenConfig.ThemeType.HELL:
			return "hell"
		GenConfig.ThemeType.URBAN:
			return "urban"
		GenConfig.ThemeType.CAVE:
			return "cave"
		GenConfig.ThemeType.JUMBLED:
			return "jumbled"
		_:
			return "unknown"


## Convert difficulty enum to string
func _difficulty_to_string(difficulty: GenConfig.DifficultyLevel) -> String:
	match difficulty:
		GenConfig.DifficultyLevel.EASY:
			return "easy"
		GenConfig.DifficultyLevel.NORMAL:
			return "normal"
		GenConfig.DifficultyLevel.HARD:
			return "hard"
		GenConfig.DifficultyLevel.NIGHTMARE:
			return "nightmare"
		_:
			return "normal"
