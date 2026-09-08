extends ModusGutTestBase

## Unit tests for MapGenerator export and metadata system
## Tests Requirements 31.1, 31.2, 31.3, 31.4, 31.5, 31.6

const MapGeneratorScript: GDScript = preload("res://game/scripts/map_generator/map_generator.gd")
var map_generator: Node
var temp_export_dir: String = "user://test_exports/"


func before_each() -> void:
	map_generator = MapGeneratorScript.new()
	add_child_autofree(map_generator)

	# Create temporary export directory
	DirAccess.make_dir_recursive_absolute(temp_export_dir)


func after_each() -> void:
	# Clean up test exports
	_cleanup_test_exports()

	if map_generator:
		map_generator = null


## Clean up test export files
func _cleanup_test_exports() -> void:
	var dir := DirAccess.open(temp_export_dir)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()


## Test that export_map saves PackedScene to .tscn file
func test_export_packed_scene_creates_file() -> void:
	var map_scene := _create_test_map_scene()
	var output_path := temp_export_dir + "test_map.tscn"

	var success: bool = map_generator.export_map(
		map_scene, output_path, GenerationConfig.ExportFormat.PACKED_SCENE
	)

	assert_true(success, "Export should succeed")
	assert_true(FileAccess.file_exists(output_path), "Exported .tscn file should exist")


## Test that export_map saves metadata JSON with same base name
func test_export_creates_metadata_json() -> void:
	var map_scene := _create_test_map_scene()
	var output_path := temp_export_dir + "test_map.tscn"
	var metadata_path := temp_export_dir + "test_map.json"

	var success: bool = map_generator.export_map(
		map_scene, output_path, GenerationConfig.ExportFormat.PACKED_SCENE
	)

	assert_true(success, "Export should succeed")
	assert_true(FileAccess.file_exists(metadata_path), "Metadata JSON file should exist")


## Test that metadata includes required fields
func test_metadata_includes_required_fields() -> void:
	# Set up generation context with test data
	_setup_test_generation_context()

	var map_scene := _create_test_map_scene()
	var output_path := temp_export_dir + "test_map.tscn"
	var metadata_path := temp_export_dir + "test_map.json"

	var success: bool = map_generator.export_map(
		map_scene, output_path, GenerationConfig.ExportFormat.PACKED_SCENE
	)

	assert_true(success, "Export should succeed")

	# Load and parse metadata JSON
	var file := FileAccess.open(metadata_path, FileAccess.READ)
	assert_not_null(file, "Should be able to open metadata file")

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	assert_eq(parse_result, OK, "Metadata JSON should be valid")

	var metadata: Dictionary = json.data

	# Check required fields
	assert_has(metadata, "seed", "Metadata should include seed")
	assert_has(metadata, "generation_time", "Metadata should include generation_time")
	assert_has(metadata, "map_size", "Metadata should include map_size")
	assert_has(metadata, "theme", "Metadata should include theme")
	assert_has(metadata, "config", "Metadata should include config")
	assert_has(metadata, "statistics", "Metadata should include statistics")
	assert_has(metadata, "rule_modules_used", "Metadata should include rule_modules_used")
	assert_has(metadata, "phase_times", "Metadata should include phase_times")


## Test that metadata statistics include all required counts
func test_metadata_statistics_complete() -> void:
	_setup_test_generation_context()

	var map_scene := _create_test_map_scene()
	var output_path := temp_export_dir + "test_map.tscn"
	var metadata_path := temp_export_dir + "test_map.json"

	map_generator.export_map(map_scene, output_path, GenerationConfig.ExportFormat.PACKED_SCENE)

	var metadata := _load_metadata_json(metadata_path)
	var stats: Dictionary = metadata["statistics"]

	assert_has(stats, "room_count", "Statistics should include room_count")
	assert_has(stats, "hallway_count", "Statistics should include hallway_count")
	assert_has(stats, "secret_count", "Statistics should include secret_count")
	assert_has(stats, "monster_spawn_count", "Statistics should include monster_spawn_count")
	assert_has(stats, "item_spawn_count", "Statistics should include item_spawn_count")


## Test that exported PackedScene is loadable
func test_exported_scene_is_loadable() -> void:
	var map_scene := _create_test_map_scene()
	var output_path := temp_export_dir + "test_map.tscn"

	var success: bool = map_generator.export_map(
		map_scene, output_path, GenerationConfig.ExportFormat.PACKED_SCENE
	)

	assert_true(success, "Export should succeed")

	# Try to load the exported scene
	var loaded_scene := ResourceLoader.load(output_path, "PackedScene")
	assert_not_null(loaded_scene, "Exported scene should be loadable")

	# Try to instantiate the loaded scene
	var instance: Node = loaded_scene.instantiate()
	assert_not_null(instance, "Loaded scene should be instantiable")

	instance.free()


## Test that export fails gracefully with null scene
func test_export_fails_with_null_scene() -> void:
	var output_path := temp_export_dir + "null_test.tscn"

	var success: bool = map_generator.export_map(
		null, output_path, GenerationConfig.ExportFormat.PACKED_SCENE
	)

	assert_false(success, "Export should fail with null scene")


## Test that export creates output directory if it doesn't exist
func test_export_creates_output_directory() -> void:
	var new_dir := temp_export_dir + "new_subdir/"
	var output_path := new_dir + "test_map.tscn"

	# Ensure directory doesn't exist
	if DirAccess.dir_exists_absolute(new_dir):
		DirAccess.remove_absolute(new_dir)

	var map_scene := _create_test_map_scene()
	var success: bool = map_generator.export_map(
		map_scene, output_path, GenerationConfig.ExportFormat.PACKED_SCENE
	)

	assert_true(success, "Export should succeed")
	assert_true(DirAccess.dir_exists_absolute(new_dir), "Output directory should be created")
	assert_true(FileAccess.file_exists(output_path), "Exported file should exist in new directory")


## Test GLTF export format (optional)
func test_export_gltf_format() -> void:
	var map_scene := _create_test_map_scene()
	var output_path := temp_export_dir + "test_map.gltf"

	var success: bool = map_generator.export_map(
		map_scene, output_path, GenerationConfig.ExportFormat.GLTF
	)

	assert_true(success, "GLTF export should succeed")
	assert_true(FileAccess.file_exists(output_path), "Exported .gltf file should exist")


## Test that GLTF export is loadable
func test_gltf_export_is_loadable() -> void:
	var map_scene := _create_test_map_scene()
	var output_path := temp_export_dir + "test_map.gltf"

	var success: bool = map_generator.export_map(
		map_scene, output_path, GenerationConfig.ExportFormat.GLTF
	)

	assert_true(success, "GLTF export should succeed")

	# Try to load the GLTF
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	var err := gltf_document.append_from_file(output_path, gltf_state)
	assert_eq(err, OK, "GLTF file should be loadable")

	var scene := gltf_document.generate_scene(gltf_state)
	assert_not_null(scene, "GLTF should generate a scene")

	scene.free()


## Test that phase times are converted to seconds in metadata
func test_phase_times_in_seconds() -> void:
	_setup_test_generation_context()

	# Add some test phase times (in milliseconds)
	map_generator.generation_context.phase_times["test_phase"] = 1500  # 1.5 seconds

	var map_scene := _create_test_map_scene()
	var output_path := temp_export_dir + "test_map.tscn"
	var metadata_path := temp_export_dir + "test_map.json"

	map_generator.export_map(map_scene, output_path, GenerationConfig.ExportFormat.PACKED_SCENE)

	var metadata := _load_metadata_json(metadata_path)
	var phase_times: Dictionary = metadata["phase_times"]

	assert_has(phase_times, "test_phase", "Phase times should include test_phase")
	assert_almost_eq(
		phase_times["test_phase"], 1.5, 0.01, "Phase time should be converted to seconds"
	)


## Helper: Create a simple test map scene
func _create_test_map_scene() -> PackedScene:
	var scene := PackedScene.new()
	var root := Node3D.new()
	root.name = "TestMap"

	# Add a simple child node
	var child := MeshInstance3D.new()
	child.name = "TestMesh"
	child.mesh = BoxMesh.new()
	root.add_child(child)
	child.owner = root

	scene.pack(root)
	root.free()
	return scene


## Helper: Set up test generation context
func _setup_test_generation_context() -> void:
	var config := GenerationConfig.new()
	config.map_seed = "test_seed"
	config.map_size = Vector2i(128, 128)
	config.theme = GenerationConfig.ThemeType.TECH

	map_generator.config = config
	map_generator.generation_context = GenerationContext.new()
	map_generator.generation_context.config = config
	map_generator.generation_context.seed_hash = map_generator.hash_seed("test_seed")
	map_generator.generation_context.generation_start_time = Time.get_ticks_msec()

	# Add some test data
	var room := Room.new()
	room.id = 0
	room.center = Vector2i(64, 64)
	room.type = Room.RoomType.MEDIUM
	map_generator.generation_context.rooms.append(room)

	var hallway := Hallway.new()
	hallway.start_room_id = 0
	hallway.end_room_id = 1
	map_generator.generation_context.hallways.append(hallway)


## Helper: Load and parse metadata JSON
func _load_metadata_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		return {}

	return json.data
