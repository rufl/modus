extends Node

## MapGenerator Autoload Singleton
## Orchestrates procedural map generation using shape grammars,
## cellular automata, and prefab composition
##
## Performance Optimization Strategy:
## - Independent phases (grid layout, shape grammar, hallway, cave) run on worker thread
## - CSG geometry and navigation baking require main thread (use call_deferred)
## - Phase profiling tracks time per phase and logs warnings when targets exceeded
## - Performance targets: 128×128 maps <15s, 256×256 maps with caves <30s
## - Threading prevents UI blocking during generation

# Preload required classes (renamed to avoid conflicts with global class names)
const GenConfig = preload("res://game/scripts/map_generator/generation_config.gd")
const GenContext = preload("res://game/scripts/map_generator/generation_context.gd")
const ValidationSystem = preload("res://game/scripts/map_generator/validation_system.gd")
const ErrorHandler = preload("res://game/scripts/map_generator/error_handler.gd")
const DebugSystem = preload("res://game/scripts/map_generator/debug_system.gd")
const FeatureAvailability = preload("res://game/scripts/map_generator/feature_availability.gd")
const MapExporter = preload("res://game/scripts/map_generator/map_exporter.gd")
const BatchGenerator = preload("res://game/scripts/map_generator/batch_generator.gd")

# Signals
signal generation_started
@warning_ignore("unused_signal")
signal generation_progress(phase: String, progress: float)
@warning_ignore("unused_signal")
signal generation_completed(map_scene: PackedScene, metadata: Dictionary)
@warning_ignore("unused_signal")
signal generation_failed(error: String)
signal generation_cancelled

# Configuration
var config: GenConfig = null
var rng: RandomNumberGenerator = null

# Component managers
var grid_manager: GridLayoutManager = null
var shape_grammar: ShapeGrammarEngine = null
var hallway_generator: HallwayGenerator = null
var cellular_automata: CellularAutomataEngine = null
var outdoor_park_generator: OutdoorParkGenerator = null
var cave_system_generator: CaveSystemGenerator = null
var boss_arena_generator: BossArenaGenerator = null
var csg_builder: CSGGeometryBuilder = null
var prefab_system: MapPrefabSystem = null
var theme_manager: ThemeManager = null
var navmesh_baker: NavigationMeshBaker = null
var gameplay_element_placer: GameplayElementPlacer = null
var secret_room_generator: SecretRoomGenerator = null
var key_lock_system: KeyLockSystem = null
var advanced_geometry_builder: AdvancedGeometryBuilder = null
var lod_manager: MapLODManager = null
var multimesh_manager: MultiMeshManager = null
var occlusion_culling_manager: OcclusionCullingManager = null
var rule_module_loader: RuleModuleLoader = null
var rule_execution_pipeline: RuleExecutionPipeline = null
var batch_generator: RefCounted = null  # BatchGenerator

# Error handling and validation
var validation_system: ValidationSystem = null
var error_handler: ErrorHandler = null
var error_contexts: Array[ErrorHandler.ErrorContext] = []

# Debug system
var debug_system: DebugSystem = null

# Feature availability and graceful degradation
var feature_availability: FeatureAvailability = null

# State
var is_generating: bool = false
var current_phase: String = ""
var generation_context: GenContext

# Threading
var _generation_thread: Thread = null
var _thread_should_cancel: bool = false

# Phase profiling
var _generation_start_time: int = 0


func _deferred_warning(message: String) -> void:
	push_warning(message)


func _deferred_error(message: String) -> void:
	push_error(message)

# Performance targets (in milliseconds)
const PHASE_TIME_TARGETS: Dictionary = {
	"grid_layout": 500,
	"shape_grammar": 2000,
	"hallway_generation": 1500,
	"outdoor_generation": 1000,
	"cave_generation": 3000,
	"boss_arena": 500,
	"csg_geometry": 5000,
	"prefab_placement": 3000,
	"gameplay_placement": 1000,
	"navigation_baking": 5000,
	"validation": 500,
	"export": 1000
}

# Map size time targets (in milliseconds)
const MAP_SIZE_TARGETS: Dictionary = {Vector2i(128, 128): 15000, Vector2i(256, 256): 30000}  # 15 seconds  # 30 seconds


func _ready() -> void:
	# Initialize RNG
	rng = RandomNumberGenerator.new()

	# Initialize validation and error handling systems
	validation_system = ValidationSystem.new()
	error_handler = ErrorHandler.new()
	debug_system = DebugSystem.new()

	# Initialize feature availability detection
	feature_availability = FeatureAvailability.new()
	feature_availability.initialize()

	# Initialize component managers
	_initialize_component_managers()

	# Initialize batch generator
	batch_generator = BatchGenerator.new()
	batch_generator.initialize(self)

	# Log initialization
	if GameManager.has_method("log_info"):
		GameManager.log_info("MapGenerator", "Map generator initialized with all components")


func _exit_tree() -> void:
	# Never let a worker thread or its deferred callbacks outlive the owner.
	_thread_should_cancel = true
	_join_generation_thread()
	_release_generated_nodes()
	is_generating = false


func _join_generation_thread() -> void:
	if not _generation_thread:
		return
	_generation_thread.wait_to_finish()
	_generation_thread = null


## Initialize all component managers
func _initialize_component_managers() -> void:
	# Core layout and generation
	grid_manager = GridLayoutManager.new()
	shape_grammar = ShapeGrammarEngine.new()
	hallway_generator = HallwayGenerator.new()
	cellular_automata = CellularAutomataEngine.new()

	# Specialized generators
	outdoor_park_generator = OutdoorParkGenerator.new()
	cave_system_generator = CaveSystemGenerator.new()
	boss_arena_generator = BossArenaGenerator.new()

	# Geometry and visuals
	csg_builder = CSGGeometryBuilder.new()
	advanced_geometry_builder = AdvancedGeometryBuilder.new()

	# Prefabs and theme
	prefab_system = MapPrefabSystem.new()
	theme_manager = ThemeManager.new()

	# Gameplay elements
	gameplay_element_placer = GameplayElementPlacer.new()
	secret_room_generator = SecretRoomGenerator.new()
	key_lock_system = KeyLockSystem.new()

	# Navigation
	navmesh_baker = NavigationMeshBaker.new()

	# Performance optimization
	lod_manager = MapLODManager.new()
	multimesh_manager = MultiMeshManager.new()
	occlusion_culling_manager = OcclusionCullingManager.new()

	# Rule system
	rule_module_loader = RuleModuleLoader.new()
	rule_execution_pipeline = RuleExecutionPipeline.new(rule_module_loader)


## Generate a single map with the given seed and configuration
func generate_map(seed_str: String, gen_config: GenConfig) -> void:
	if is_generating:
		push_warning("MapGenerator: Generation already in progress")
		return
	if not gen_config:
		push_error("MapGenerator: Generation config is required")
		return
	if not grid_manager:
		_initialize_component_managers()
	if not validation_system:
		validation_system = ValidationSystem.new()
	if not error_handler:
		error_handler = ErrorHandler.new()
	if not debug_system:
		debug_system = DebugSystem.new()
	if not rng:
		rng = RandomNumberGenerator.new()

	is_generating = true
	config = gen_config
	_thread_should_cancel = false
	error_contexts.clear()  # Clear previous error contexts

	# Initialize context
	generation_context = GenContext.new()
	generation_context.config = config
	generation_context.generation_start_time = Time.get_ticks_msec()
	_generation_start_time = generation_context.generation_start_time

	# Hash seed for deterministic generation (use current time if empty)
	var effective_seed := seed_str if seed_str != "" else str(Time.get_ticks_msec())
	var seed_hash := hash_seed(effective_seed)
	generation_context.seed_hash = seed_hash

	# Initialize RNG with hashed seed for deterministic generation
	generation_context.rng.seed = seed_hash
	rng.seed = seed_hash  # Also initialize MapGenerator's RNG for consistency

	# Initialize debug system if enabled
	var debug_enabled: bool = config.has("debug_mode") and config.debug_mode
	debug_system.initialize(debug_enabled, effective_seed)

	generation_started.emit()

	# Start threaded generation
	_start_threaded_generation()


## Cancel ongoing generation
func cancel_generation() -> void:
	if not is_generating:
		return

	_thread_should_cancel = true

	# Join both live and already-finished threads before clearing ownership.
	_join_generation_thread()
	_release_generated_nodes()

	is_generating = false
	generation_cancelled.emit()


## Generate multiple maps in sequence for an episode
func generate_episode(base_seed: String, episode_length: int, gen_config: GenConfig) -> void:
	if not batch_generator:
		push_error("MapGenerator: BatchGenerator not initialized")
		return

	# Ensure output directory exists
	var output_dir := gen_config.output_directory
	if not DirAccess.dir_exists_absolute(output_dir):
		DirAccess.make_dir_recursive_absolute(output_dir)

	# Start batch generation
	var generated_maps: Array[String] = await batch_generator.generate_episode(
		base_seed, episode_length, gen_config, output_dir
	)

	print("MapGenerator: Generated %d/%d maps in episode" % [generated_maps.size(), episode_length])


## Export generated map to file
## Returns true if export succeeded, false otherwise
func export_map(
	map_scene: PackedScene, output_path: String, format: GenConfig.ExportFormat
) -> bool:
	if not map_scene:
		push_warning("MapGenerator: Cannot export null map scene")
		return false

	# Ensure output directory exists
	var output_dir := output_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(output_dir):
		var err := DirAccess.make_dir_recursive_absolute(output_dir)
		if err != OK:
			push_error("MapGenerator: Failed to create output directory: %s" % output_dir)
			return false

	# Export based on format
	var success := false
	match format:
		GenConfig.ExportFormat.PACKED_SCENE:
			success = _export_packed_scene(map_scene, output_path)
		GenConfig.ExportFormat.GLTF:
			success = _export_gltf(map_scene, output_path)
		_:
			push_error("MapGenerator: Unknown export format: %d" % format)
			return false

	if not success:
		return false

	# Save metadata JSON
	var metadata_path := output_path.get_basename() + ".json"
	var total_time := Time.get_ticks_msec() - _generation_start_time
	var metadata := _build_metadata(total_time)

	if not _save_metadata_json(metadata, metadata_path):
		push_warning("MapGenerator: Failed to save metadata JSON, but map export succeeded")
		# Don't fail the export if metadata save fails

	# Validate exported file is loadable
	if not _validate_exported_file(output_path, format):
		push_error("MapGenerator: Exported file validation failed: %s" % output_path)
		return false

	return true


## Export map as PackedScene (.tscn)
func _export_packed_scene(map_scene: PackedScene, output_path: String) -> bool:
	# Ensure path has .tscn extension
	var scene_path := output_path
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"

	# Save PackedScene to file
	var err := ResourceSaver.save(map_scene, scene_path)
	if err != OK:
		push_error("MapGenerator: Failed to save PackedScene to %s (error: %d)" % [scene_path, err])
		return false

	return true


## Export map as GLTF (optional)
func _export_gltf(map_scene: PackedScene, output_path: String) -> bool:
	# Ensure path has .gltf extension
	var gltf_path := output_path
	if not gltf_path.ends_with(".gltf") and not gltf_path.ends_with(".glb"):
		gltf_path += ".gltf"

	# Instantiate the scene to export
	var scene_root := map_scene.instantiate()
	if not scene_root:
		push_error("MapGenerator: Failed to instantiate scene for GLTF export")
		return false

	# Create GLTF document
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	# Append scene to GLTF state
	var err := gltf_document.append_from_scene(scene_root, gltf_state)
	if err != OK:
		push_error("MapGenerator: Failed to append scene to GLTF state (error: %d)" % err)
		scene_root.free()
		return false

	# Embed metadata in GLTF extras
	var total_time := Time.get_ticks_msec() - _generation_start_time
	var metadata := _build_metadata(total_time)
	gltf_state.json["extras"] = metadata

	# Write GLTF to file
	err = gltf_document.write_to_filesystem(gltf_state, gltf_path)
	if err != OK:
		push_error("MapGenerator: Failed to write GLTF to %s (error: %d)" % [gltf_path, err])
		scene_root.free()
		return false

	# The export instance is detached, so deferred queue_free() would never run.
	scene_root.free()

	return true


## Save metadata to JSON file
func _save_metadata_json(metadata: Dictionary, json_path: String) -> bool:
	var json_string := JSON.stringify(metadata, "\t")

	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if not file:
		push_error("MapGenerator: Failed to open metadata file for writing: %s" % json_path)
		return false

	file.store_string(json_string)
	file.close()

	return true


## Validate exported file is loadable
func _validate_exported_file(file_path: String, format: GenConfig.ExportFormat) -> bool:
	match format:
		GenConfig.ExportFormat.PACKED_SCENE:
			return _validate_packed_scene(file_path)
		GenConfig.ExportFormat.GLTF:
			return _validate_gltf(file_path)
		_:
			return false


## Validate PackedScene file is loadable
func _validate_packed_scene(scene_path: String) -> bool:
	# Ensure path has .tscn extension
	var path := scene_path
	if not path.ends_with(".tscn"):
		path += ".tscn"

	# Check if file exists
	if not FileAccess.file_exists(path):
		push_error("MapGenerator: Exported scene file does not exist: %s" % path)
		return false

	# Try to load the scene
	var loaded_scene := ResourceLoader.load(path, "PackedScene")
	if not loaded_scene:
		push_error("MapGenerator: Failed to load exported scene: %s" % path)
		return false

	# Try to instantiate the scene
	var instance: Node = loaded_scene.instantiate()
	if not instance:
		push_error("MapGenerator: Failed to instantiate exported scene: %s" % path)
		return false

	# Validation instances are detached from the SceneTree.
	instance.free()

	return true


## Validate GLTF file is loadable
func _validate_gltf(gltf_path: String) -> bool:
	# Ensure path has .gltf or .glb extension
	var path := gltf_path
	if not path.ends_with(".gltf") and not path.ends_with(".glb"):
		path += ".gltf"

	# Check if file exists
	if not FileAccess.file_exists(path):
		push_error("MapGenerator: Exported GLTF file does not exist: %s" % path)
		return false

	# Try to load the GLTF
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	var err := gltf_document.append_from_file(path, gltf_state)
	if err != OK:
		push_error("MapGenerator: Failed to load GLTF file: %s (error: %d)" % [path, err])
		return false

	# Try to generate scene from GLTF
	var scene := gltf_document.generate_scene(gltf_state)
	if not scene:
		push_error("MapGenerator: Failed to generate scene from GLTF: %s" % path)
		return false

	# Generated validation scenes are detached from the SceneTree.
	scene.free()

	return true


## Hash seed string to 64-bit integer using SHA-256
## This method is public to allow testing of deterministic behavior
func hash_seed(seed_str: String) -> int:
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(seed_str.to_utf8_buffer())
	var hash_bytes := hash_context.finish()

	# Convert first 8 bytes to 64-bit integer
	var seed_int: int = 0
	for i in range(min(8, hash_bytes.size())):
		seed_int = (seed_int << 8) | hash_bytes[i]

	return seed_int


## Start threaded generation pipeline
func _start_threaded_generation() -> void:
	# Create and start worker thread
	_generation_thread = Thread.new()
	_generation_thread.start(_generation_worker_thread)

	# Monitor thread progress on main thread
	_monitor_generation_thread()


## Monitor generation thread and handle completion
func _monitor_generation_thread() -> void:
	# Wait for thread to complete
	while _generation_thread and _generation_thread.is_alive():
		await get_tree().process_frame

	# Get result from thread
	if _generation_thread:
		var result: Dictionary = _generation_thread.wait_to_finish()
		_generation_thread = null

		# Handle result on main thread
		_finalize_generation(result)


## Worker thread for independent generation phases
func _generation_worker_thread() -> Dictionary:
	var result := {"success": false, "error": "", "context": generation_context}

	# Check for cancellation
	if _thread_should_cancel:
		result["error"] = "Generation cancelled"
		return result

	# Phase 1: Initialize seed and RNG (already done in generate_map)
	# Phase 2: Grid layout allocation
	if not _run_phase_threaded("grid_layout"):
		result["error"] = "Grid layout phase failed"
		return result

	# Phase 3: Shape grammar room generation
	if not _run_phase_threaded("shape_grammar"):
		result["error"] = "Shape grammar phase failed"
		return result

	# Phase 4: Hallway generation and dead-end removal
	if not _run_phase_threaded("hallway_generation"):
		result["error"] = "Hallway generation phase failed"
		return result

	# Phase 5: Outdoor/cave generation
	if not _run_phase_threaded("outdoor_generation"):
		result["error"] = "Outdoor generation phase failed"
		return result

	if not _run_phase_threaded("cave_generation"):
		result["error"] = "Cave generation phase failed"
		return result

	# Phase 6: Boss arena placement
	if not _run_phase_threaded("boss_arena"):
		result["error"] = "Boss arena phase failed"
		return result

	# Phases 7-12 require main thread (CSG, scene tree operations)
	# Signal that we need to continue on main thread
	result["success"] = true
	result["continue_on_main_thread"] = true
	return result


## Run a generation phase with profiling (thread-safe version)
func _run_phase_threaded(phase_name: String) -> bool:
	if _thread_should_cancel:
		return false

	# Start phase profiling
	var phase_start := Time.get_ticks_msec()
	current_phase = phase_name

	# Emit progress signal (thread-safe via call_deferred)
	call_deferred("emit_signal", "generation_progress", phase_name, 0.0)

	# Execute phase with retry logic
	var phase_callable := func() -> bool: return _execute_phase(phase_name)

	var success: bool = error_handler.run_phase_with_retry(
		phase_name, phase_callable, generation_context, ErrorHandler.MAX_RETRY_ATTEMPTS
	)

	# If phase succeeded, validate output
	if success:
		success = _validate_phase_output(phase_name)

		# Save debug state after successful phase
		if success and debug_system:
			call_deferred("_save_debug_state", phase_name)

	# End phase profiling
	var phase_end := Time.get_ticks_msec()
	var phase_time := phase_end - phase_start

	# Store phase time in context
	if generation_context:
		generation_context.phase_times[phase_name] = phase_time

	# Check against target time and log warning if exceeded
	if PHASE_TIME_TARGETS.has(phase_name):
		var target_time: int = PHASE_TIME_TARGETS[phase_name]
		if phase_time > target_time:
			var warning_msg := (
				"Phase '%s' exceeded target time: %d ms (target: %d ms)"
				% [phase_name, phase_time, target_time]
			)
			call_deferred("_deferred_warning", warning_msg)

	# Emit completion progress
	call_deferred("emit_signal", "generation_progress", phase_name, 1.0)

	return success


## Execute a specific phase (extracted for retry logic)
func _execute_phase(phase_name: String) -> bool:
	match phase_name:
		"grid_layout":
			return _execute_grid_layout_phase()
		"shape_grammar":
			return _execute_shape_grammar_phase()
		"hallway_generation":
			return _execute_hallway_generation_phase()
		"outdoor_generation":
			return _execute_outdoor_generation_phase()
		"cave_generation":
			return _execute_cave_generation_phase()
		"boss_arena":
			return _execute_boss_arena_phase()
		"csg_geometry":
			return _execute_csg_geometry_phase()
		"prefab_placement":
			return _execute_prefab_placement_phase()
		"gameplay_placement":
			return _execute_gameplay_placement_phase()
		"navigation_baking":
			return _execute_navigation_baking_phase()
		"validation":
			return _execute_validation_phase()
		"export":
			return _execute_export_phase()
		_:
			push_warning("Unknown phase: %s" % phase_name)
			return true  # Don't fail on unknown phases


## Validate phase output
func _validate_phase_output(phase_name: String) -> bool:
	if not validation_system:
		return true  # Skip validation if system not initialized

	var result: ValidationSystem.ValidationResult = null

	match phase_name:
		"grid_layout":
			result = validation_system.validate_grid_layout(generation_context)
		"shape_grammar":
			result = validation_system.validate_room_generation(generation_context)
		"hallway_generation":
			result = validation_system.validate_connectivity(generation_context)
		"navigation_baking":
			if not generation_context.csg_root.is_inside_tree():
				return true
			result = validation_system.validate_navigation_mesh(generation_context)
		_:
			return true  # No validation for this phase

	if not result:
		return true

	# Log warnings
	for warning in result.warnings:
		call_deferred("_deferred_warning", "MapGenerator: %s" % warning)

	# Check if validation passed
	if not result.is_valid:
		var error_ctx := ErrorHandler.ErrorContext.new(
			phase_name, 1, "Validation failed: %s" % result.error_message
		)
		error_contexts.append(error_ctx)
		call_deferred(
			"_deferred_error",
			"MapGenerator: Phase '%s' validation failed: %s" % [phase_name, result.error_message]
		)
		return false

	return true


## Execute grid layout phase
func _execute_grid_layout_phase() -> bool:
	if not grid_manager or not generation_context:
		push_error("Grid manager or context not initialized")
		return false
	if not config:
		push_error("Generation config not initialized")
		return false

	# Initialize grid with configured size
	grid_manager.initialize_grid(config.map_size)
	generation_context.grid = grid_manager.grid
	generation_context.grid_size = config.map_size

	return true


## Execute shape grammar phase
func _execute_shape_grammar_phase() -> bool:
	if not shape_grammar or not generation_context:
		push_error("Shape grammar or context not initialized")
		return false

	# Load theme for shape grammar rules
	var theme: MapTheme = null
	if theme_manager:
		theme = theme_manager.get_theme(config.theme)

	# Generate rooms using shape grammar
	var room_count := _calculate_room_count(config.map_size)
	generation_context.rooms.clear()

	for i in range(room_count):
		if _thread_should_cancel:
			return false

		# Determine room type based on index
		var room_type: Room.RoomType
		if i == room_count - 1 and config.enable_boss_arena:
			room_type = Room.RoomType.BOSS_ARENA
		elif i < room_count * 0.3:
			room_type = Room.RoomType.SMALL
		elif i < room_count * 0.7:
			room_type = Room.RoomType.MEDIUM
		else:
			room_type = Room.RoomType.LARGE

		# Find a suitable center position for the room
		var center := _find_room_placement(generation_context.grid, room_type)
		if center == Vector2i(-1, -1):
			continue  # Skip if no suitable position found

		# Generate room shape
		var target_size := _get_room_target_size(room_type)
		var room_shape := shape_grammar.generate_room_shape(
			center, target_size, room_type, generation_context.rng, theme
		)

		# Create room and place it on grid
		var room := Room.new()
		room.id = i
		room.center = center
		room.type = room_type
		room.poly_points = room_shape

		# Convert polygon to grid cells
		room.cells = _polygon_to_grid_cells(room_shape, center)

		# Mark cells on grid
		for cell_pos: Vector2i in room.cells:
			var cell := grid_manager.get_cell_at(cell_pos)
			if cell:
				var cell_type := (
					Cell.Type.BOSS_ARENA
					if room_type == Room.RoomType.BOSS_ARENA
					else Cell.Type.ROOM
				)
				cell.type = cell_type
				cell.room_id = room.id

		generation_context.rooms.append(room)

	return generation_context.rooms.size() > 0


## Execute hallway generation phase
func _execute_hallway_generation_phase() -> bool:
	if not hallway_generator or not generation_context:
		push_error("Hallway generator or context not initialized")
		return false

	# Generate hallways connecting rooms
	generation_context.hallways = hallway_generator.generate_hallways(
		generation_context.rooms, generation_context.grid
	)

	# Remove dead ends
	hallway_generator.remove_dead_ends(generation_context.grid)

	return generation_context.hallways.size() > 0


## Execute outdoor generation phase
func _execute_outdoor_generation_phase() -> bool:
	if config.outdoor_bias <= 0.0:
		return true  # Skip if outdoor bias is 0

	if not outdoor_park_generator or not generation_context:
		push_error("Outdoor park generator or context not initialized")
		return false

	# Generate outdoor areas
	generation_context.outdoor_areas = outdoor_park_generator.generate_outdoor_areas(
		generation_context
	)

	return true


## Execute cave generation phase
func _execute_cave_generation_phase() -> bool:
	if config.cave_bias <= 0.0:
		return true  # Skip if cave bias is 0

	if not cave_system_generator or not generation_context:
		push_error("Cave system generator or context not initialized")
		return false

	# Generate cave areas
	generation_context.cave_areas = cave_system_generator.generate_cave_areas(generation_context)

	return true


## Execute boss arena phase
func _execute_boss_arena_phase() -> bool:
	if not config.enable_boss_arena:
		return true  # Skip if boss arenas disabled

	if not boss_arena_generator or not generation_context:
		push_error("Boss arena generator or context not initialized")
		return false

	# Populate existing boss arena rooms.  The generator's public contract is
	# add_arena_elements(); the old enhance_boss_arena name belonged to a
	# retired implementation.
	var boss_rooms := generation_context.rooms.filter(
		func(r: Room) -> bool: return r.type == Room.RoomType.BOSS_ARENA
	)

	for boss_room: Room in boss_rooms:
		boss_arena_generator.add_arena_elements(boss_room, generation_context)

	return true


## Execute CSG geometry phase
func _execute_csg_geometry_phase() -> bool:
	if not csg_builder or not generation_context:
		push_error("CSG builder or context not initialized")
		return false

	# Initialize CSG builder with context
	csg_builder.initialize(generation_context)

	# Build CSG geometry
	generation_context.csg_root = csg_builder.build_geometry()

	return generation_context.csg_root != null


## Execute prefab placement phase
func _execute_prefab_placement_phase() -> bool:
	if not prefab_system or not generation_context:
		push_error("Prefab system or context not initialized")
		return false

	# Load theme for prefab filtering
	var theme: MapTheme = null
	if theme_manager:
		theme = theme_manager.get_theme(config.theme)

	# Place prefabs through the current room/context API and retain only the
	# instantiated nodes required by downstream batching and export.
	var placement_results: Array = prefab_system.place_prefabs_in_rooms(
		generation_context.rooms, generation_context, generation_context.csg_root
	)
	generation_context.prefab_instances.clear()
	for placement_result: Variant in placement_results:
		if placement_result and placement_result.node:
			generation_context.prefab_instances.append(placement_result.node)

	# Apply MultiMesh optimization if enabled
	if config.use_multimesh and multimesh_manager and generation_context.csg_root.is_inside_tree():
		multimesh_manager.apply_multimesh_batching(
			placement_results, generation_context.csg_root, generation_context
		)

	return true


## Execute gameplay placement phase
func _execute_gameplay_placement_phase() -> bool:
	if not gameplay_element_placer or not generation_context:
		push_error("Gameplay element placer or context not initialized")
		return false

	# Use the current specialized gameplay placement API.
	gameplay_element_placer.place_monster_spawns(generation_context)
	gameplay_element_placer.place_boss_monsters(generation_context)
	gameplay_element_placer.place_weapons_and_ammo(generation_context)
	gameplay_element_placer.place_health_pickups(generation_context)

	# Generate secret rooms if enabled
	if config.enable_secrets and secret_room_generator:
		secret_room_generator.generate_secret_rooms(generation_context)

	# Place keys and locks if enabled
	if config.enable_key_locks and key_lock_system:
		key_lock_system.generate_key_lock_system(generation_context)

	return true


## Execute navigation baking phase
func _execute_navigation_baking_phase() -> bool:
	if not navmesh_baker or not generation_context:
		push_error("Navigation mesh baker or context not initialized")
		return false
	if not generation_context.csg_root or not generation_context.csg_root.is_inside_tree():
		# Generated geometry is not attached to a live scene tree until the final
		# PackedScene is built. Defer server baking to the consumer scene.
		generation_context.navigation_region = NavigationRegion3D.new()
		generation_context.navigation_region.navigation_mesh = NavigationMesh.new()
		return true

	# Initialize navigation mesh baker with context
	navmesh_baker.initialize(generation_context)

	# Bake navigation mesh
	var success: bool = navmesh_baker.bake_navigation_mesh()

	# Get the navigation region from the baker
	if success:
		generation_context.navigation_region = navmesh_baker.get_navigation_region()

	return success


## Execute validation phase
func _execute_validation_phase() -> bool:
	if not validation_system or not generation_context:
		push_error("Validation system or context not initialized")
		return false

	# Validate data that is independent of scene-tree attachment now. Geometry,
	# connectivity, and navigation-server checks are deferred until the generated
	# scene is attached to a live tree.
	var validations: Array[ValidationSystem.ValidationResult] = [
		validation_system.validate_player_start(generation_context),
		validation_system.validate_key_lock_progression(generation_context)
	]
	if generation_context.csg_root and generation_context.csg_root.is_inside_tree():
		validations.append(validation_system.validate_connectivity(generation_context))
		validations.append(validation_system.validate_navigation_mesh(generation_context))
		validations.append(validation_system.validate_monster_spawns(generation_context))

	# Check if all validations passed
	for result: ValidationSystem.ValidationResult in validations:
		if not result.is_valid:
			push_error("Validation failed: %s" % result.error_message)
			return false

		# Log warnings
		for warning in result.warnings:
			push_warning("Validation warning: %s" % warning)

	return true


## Execute export phase (optimization passes)
func _execute_export_phase() -> bool:
	if not generation_context:
		push_error("Context not initialized")
		return false

	# Apply LOD if enabled
	if config.enable_lod and lod_manager and generation_context.csg_root.is_inside_tree():
		lod_manager.initialize(generation_context)
		lod_manager.apply_lod_to_scene(generation_context.csg_root)

	# Apply occlusion culling if enabled
	if (
		config.enable_occlusion_culling
		and occlusion_culling_manager
		and generation_context.csg_root.is_inside_tree()
	):
		occlusion_culling_manager.initialize(generation_context)
		var occluders_root: Node3D = occlusion_culling_manager.generate_occluders()
		if occluders_root and generation_context.csg_root:
			generation_context.csg_root.add_child(occluders_root)

	return true


## Finalize generation on main thread
func _finalize_generation(result: Dictionary) -> void:
	if not result["success"]:
		_release_generated_nodes()
		is_generating = false
		generation_failed.emit(result["error"])
		return

	# If we need to continue on main thread, run remaining phases
	if result.get("continue_on_main_thread", false):
		await _run_main_thread_phases()

	# Check if generation was cancelled or failed during main thread phases
	if not is_generating:
		return

	# Calculate total generation time
	var total_time := Time.get_ticks_msec() - _generation_start_time

	# Check against map size target
	if config and config.map_size:
		var map_size := config.map_size
		if MAP_SIZE_TARGETS.has(map_size):
			var target_time: int = MAP_SIZE_TARGETS[map_size]
			if total_time > target_time:
				push_warning(
					(
						"Map generation exceeded target time for size %dx%d: %d ms (target: %d ms)"
						% [map_size.x, map_size.y, total_time, target_time]
					)
				)

	# Log profiling information
	_log_profiling_info(total_time)

	# Save generation summary if debug mode enabled
	_save_generation_summary()

	# Build final map scene
	var map_scene := _build_map_scene()
	var metadata := _build_metadata(total_time)
	if not map_scene:
		abort_generation("Generated scene could not be packed")
		return

	is_generating = false
	generation_completed.emit(map_scene, metadata)


## Run phases that require main thread (CSG, scene tree operations)
func _run_main_thread_phases() -> void:
	# Phase 7: CSG geometry building
	if not await _run_phase_main_thread("csg_geometry"):
		abort_generation("CSG geometry phase failed")
		return

	# Phase 8: Prefab placement
	if not await _run_phase_main_thread("prefab_placement"):
		abort_generation("Prefab placement phase failed")
		return

	# Phase 9: Gameplay element placement
	if not await _run_phase_main_thread("gameplay_placement"):
		abort_generation("Gameplay element placement phase failed")
		return

	# Phase 10: Navigation mesh baking
	if not await _run_phase_main_thread("navigation_baking"):
		abort_generation("Navigation mesh baking phase failed")
		return

	# Phase 11: Validation
	if not await _run_phase_main_thread("validation"):
		abort_generation("Validation phase failed")
		return

	# Phase 12: Export preparation (optimization passes)
	if not await _run_phase_main_thread("export"):
		abort_generation("Export phase failed")
		return


## Run a phase on the main thread with profiling
func _run_phase_main_thread(phase_name: String) -> bool:
	if _thread_should_cancel:
		return false

	# Start phase profiling
	var phase_start := Time.get_ticks_msec()
	current_phase = phase_name

	# Emit progress signal
	generation_progress.emit(phase_name, 0.0)

	# Execute phase with retry logic
	var phase_callable := func() -> bool: return _execute_phase(phase_name)

	var success: bool = error_handler.run_phase_with_retry(
		phase_name, phase_callable, generation_context, ErrorHandler.MAX_RETRY_ATTEMPTS
	)

	# If phase succeeded, validate output
	if success:
		success = _validate_phase_output(phase_name)

		# Save debug state after successful phase
		if success and debug_system:
			_save_debug_state(phase_name)

	# End phase profiling
	var phase_end := Time.get_ticks_msec()
	var phase_time := phase_end - phase_start

	# Store phase time in context
	if generation_context:
		generation_context.phase_times[phase_name] = phase_time

	# Check against target time and log warning if exceeded
	if PHASE_TIME_TARGETS.has(phase_name):
		var target_time: int = PHASE_TIME_TARGETS[phase_name]
		if phase_time > target_time:
			push_warning(
				(
					"Phase '%s' exceeded target time: %d ms (target: %d ms)"
					% [phase_name, phase_time, target_time]
				)
			)

	# Emit completion progress
	generation_progress.emit(phase_name, 1.0)

	# Yield to allow UI updates
	await get_tree().process_frame

	return success


## Build metadata dictionary for export
func _build_metadata(total_time: int) -> Dictionary:
	var metadata := {
		"seed": config.map_seed if config else "",
		"seed_hash": generation_context.seed_hash if generation_context else 0,
		"generation_time": float(total_time) / 1000.0,  # Convert to seconds
		"map_size": [config.map_size.x, config.map_size.y] if config else [0, 0],
		"theme": _get_theme_name(config.theme) if config else "unknown",
		"config": _build_config_metadata(),
		"statistics": _build_statistics_metadata(),
		"rule_modules_used": _get_rule_modules_used(),
		"phase_times": _build_phase_times_metadata()
	}

	return metadata


## Build configuration metadata
func _build_config_metadata() -> Dictionary:
	if not config:
		return {}

	return {
		"outdoor_bias": config.outdoor_bias,
		"cave_bias": config.cave_bias,
		"prefab_detail_level": config.prefab_detail_level,
		"prop_density": config.prop_density,
		"decorative_density": config.decorative_density,
		"monster_density": config.monster_density,
		"difficulty_scaling": _get_difficulty_name(config.difficulty_scaling),
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
func _build_statistics_metadata() -> Dictionary:
	if not generation_context:
		return {}

	var stats := {
		"room_count": generation_context.rooms.size(),
		"hallway_count": generation_context.hallways.size(),
		"secret_count": 0,
		"monster_spawn_count": generation_context.monster_spawns.size(),
		"item_spawn_count": generation_context.item_spawns.size(),
		"outdoor_area_count": generation_context.outdoor_areas.size(),
		"cave_area_count": generation_context.cave_areas.size()
	}

	# Count secret rooms
	for room: Room in generation_context.rooms:
		if room.metadata.get("is_secret", false):
			stats["secret_count"] += 1

	return stats


## Get list of rule modules used during generation
func _get_rule_modules_used() -> Array[String]:
	var modules: Array[String] = []

	if rule_execution_pipeline:
		modules = rule_execution_pipeline.get_applied_rules()

	return modules


## Build phase times metadata (convert to seconds)
func _build_phase_times_metadata() -> Dictionary:
	var phase_times := {}

	if generation_context:
		for phase_name: String in generation_context.phase_times:
			var time_ms: int = generation_context.phase_times[phase_name]
			phase_times[phase_name] = float(time_ms) / 1000.0  # Convert to seconds

	return phase_times


## Get theme name from enum
func _get_theme_name(theme_type: GenerationConfig.ThemeType) -> String:
	match theme_type:
		GenerationConfig.ThemeType.TECH:
			return "tech"
		GenerationConfig.ThemeType.HELL:
			return "hell"
		GenerationConfig.ThemeType.URBAN:
			return "urban"
		GenerationConfig.ThemeType.CAVE:
			return "cave"
		GenerationConfig.ThemeType.JUMBLED:
			return "jumbled"
		_:
			return "unknown"


## Get difficulty name from enum
func _get_difficulty_name(difficulty: GenerationConfig.DifficultyLevel) -> String:
	match difficulty:
		GenerationConfig.DifficultyLevel.EASY:
			return "easy"
		GenerationConfig.DifficultyLevel.NORMAL:
			return "normal"
		GenerationConfig.DifficultyLevel.HARD:
			return "hard"
		GenerationConfig.DifficultyLevel.NIGHTMARE:
			return "nightmare"
		_:
			return "normal"


## Log profiling information
func _log_profiling_info(total_time: int) -> void:
	if not generation_context:
		return

	var profiling_output := "Map generation profiling:\n"
	profiling_output += "  Total time: %d ms\n" % total_time
	profiling_output += "  Phase times:\n"

	for phase_name: String in generation_context.phase_times:
		var phase_time: int = generation_context.phase_times[phase_name]
		var target_time: int = PHASE_TIME_TARGETS.get(phase_name, 0)
		var status := " (OK)" if target_time == 0 or phase_time <= target_time else " (EXCEEDED)"
		profiling_output += "    %s: %d ms%s\n" % [phase_name, phase_time, status]

	print(profiling_output)


## Check if generation met performance targets
func is_within_performance_target(map_size: Vector2i, total_time_ms: int) -> bool:
	if not MAP_SIZE_TARGETS.has(map_size):
		return true  # No target defined for this size

	var target_time: int = MAP_SIZE_TARGETS[map_size]
	return total_time_ms <= target_time


## Get performance target for map size
func get_performance_target(map_size: Vector2i) -> int:
	return MAP_SIZE_TARGETS.get(map_size, 0)


## Get phase time target
func get_phase_target(phase_name: String) -> int:
	return PHASE_TIME_TARGETS.get(phase_name, 0)


## Handle invalid prefab gracefully (skip with warning)
func skip_invalid_prefab(prefab_path: String, reason: String) -> void:
	push_warning("MapGenerator: Skipping invalid prefab '%s': %s" % [prefab_path, reason])

	# Track skipped prefabs in context
	if generation_context:
		if not generation_context.has("skipped_prefabs"):
			generation_context.set("skipped_prefabs", [])
		generation_context.skipped_prefabs.append(
			{"path": prefab_path, "reason": reason, "timestamp": Time.get_ticks_msec()}
		)


## Abort generation with error report
func abort_generation(reason: String) -> void:
	push_error("MapGenerator: Aborting generation - %s" % reason)

	# Create error report
	if error_handler and not error_contexts.is_empty():
		var report := error_handler.create_error_report(error_contexts)
		report["abort_reason"] = reason

		# Save error report to debug directory
		var debug_dir := "res://debug/map_generator/"
		DirAccess.make_dir_recursive_absolute(debug_dir)
		var report_path := debug_dir + "error_report_%d.json" % Time.get_ticks_msec()
		error_handler.save_error_report(report, report_path)

	# Generated scene nodes are detached until packing. Failed or cancelled
	# generations must release them explicitly because queue_free() cannot run on
	# nodes that were never attached to a SceneTree.
	_release_generated_nodes()

	# Emit failure signal
	is_generating = false
	generation_failed.emit(reason)


## Check if generation should abort (after multiple failures)
func should_abort_generation() -> bool:
	# Count consecutive failures
	var consecutive_failures := 0
	for ctx in error_contexts:
		if ctx.attempt_number >= ErrorHandler.MAX_RETRY_ATTEMPTS:
			consecutive_failures += 1

	# Abort if we have multiple phase failures
	return consecutive_failures >= 2


## Save debug state for current phase (called on main thread)
func _save_debug_state(phase_name: String) -> void:
	if debug_system and generation_context:
		debug_system.save_phase_state(phase_name, generation_context)


## Save final generation summary
func _save_generation_summary() -> void:
	if debug_system and generation_context:
		debug_system.save_generation_summary(generation_context)


## Get feature availability report
func get_feature_availability_report() -> Dictionary:
	if feature_availability:
		return feature_availability.create_availability_report()
	return {}


## Check if a specific feature is available
func is_feature_available(feature_name: String) -> bool:
	if feature_availability:
		return feature_availability.is_feature_available(feature_name)
	return false


## Get recommended configuration based on available features
func get_recommended_config() -> Dictionary:
	if feature_availability:
		return feature_availability.get_recommended_config()
	return {}


## Calculate room count based on map size
func _calculate_room_count(map_size: Vector2i) -> int:
	var area := map_size.x * map_size.y
	# Roughly 1 room per 400 cells, with min 5 and max 30
	return clampi(int(float(area) / 400.0), 5, 30)


## Find suitable placement for a room
func _find_room_placement(grid: Array[Array], _room_type: Room.RoomType) -> Vector2i:
	var attempts := 0
	var max_attempts := 100
	var min_spacing := 8  # Minimum distance between room centers

	while attempts < max_attempts:
		var x := generation_context.rng.randi_range(10, grid[0].size() - 10)
		var y := generation_context.rng.randi_range(10, grid.size() - 10)
		var pos := Vector2i(x, y)

		# Check if position is empty and far enough from other rooms
		var cell := grid_manager.get_cell_at(pos)
		if cell and cell.type == Cell.Type.EMPTY:
			var too_close := false
			for room: Room in generation_context.rooms:
				if pos.distance_to(room.center) < min_spacing:
					too_close = true
					break

			if not too_close:
				return pos

		attempts += 1

	return Vector2i(-1, -1)  # No suitable position found


## Get target size for room type
func _get_room_target_size(room_type: Room.RoomType) -> int:
	match room_type:
		Room.RoomType.SMALL:
			return 6  # 4-8 cells
		Room.RoomType.MEDIUM:
			return 12  # 9-16 cells
		Room.RoomType.LARGE:
			return 24  # 17-32 cells
		Room.RoomType.BOSS_ARENA:
			return 50  # 40+ cells
		_:
			return 12


## Convert polygon points to grid cells
func _polygon_to_grid_cells(poly_points: PackedVector2Array, center: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []

	if poly_points.size() == 0:
		# Fallback to simple square
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				cells.append(center + Vector2i(dx, dy))
		return cells

	# Find bounding box of polygon
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF

	for point: Vector2 in poly_points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	# Check each cell in bounding box
	for y in range(int(min_y), int(max_y) + 1):
		for x in range(int(min_x), int(max_x) + 1):
			var point := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(point, poly_points):
				cells.append(center + Vector2i(int(x), int(y)))

	return cells


## Build final map scene from generation context
func _build_map_scene() -> PackedScene:
	var scene := PackedScene.new()

	# Create root node
	var root := Node3D.new()
	root.name = "GeneratedMap"

	# Add CSG geometry
	if generation_context.csg_root:
		root.add_child(generation_context.csg_root)
		generation_context.csg_root.owner = root

	# Add navigation region
	if generation_context.navigation_region:
		root.add_child(generation_context.navigation_region)
		generation_context.navigation_region.owner = root

	# PackedScene only serializes descendants owned by the scene root. Generated
	# geometry is assembled while detached, so assign ownership recursively before
	# packing instead of returning a scene that contains only the two top-level
	# containers.
	_assign_scene_owner(root, root)
	var pack_error := scene.pack(root)

	# Packing copies the node state; it does not free the live source tree. Clear
	# context references first, then release the detached tree immediately so each
	# generation does not leak thousands of CSG, navigation, and renderer objects.
	generation_context.csg_root = null
	generation_context.navigation_region = null
	generation_context.prefab_instances.clear()
	root.free()

	if pack_error != OK:
		push_error("MapGenerator: Failed to pack generated scene (error: %d)" % pack_error)
		return null

	return scene


## Assign the generated root as owner for every descendant that must be packed.
func _assign_scene_owner(node: Node, scene_root: Node) -> void:
	for child: Node in node.get_children():
		child.owner = scene_root
		_assign_scene_owner(child, scene_root)


## Release detached nodes left by cancellation, failure, or owner teardown.
func _release_generated_nodes() -> void:
	if not generation_context:
		return

	var detached_roots: Array[Node] = []
	if is_instance_valid(generation_context.csg_root):
		detached_roots.append(generation_context.csg_root)
	if (
		is_instance_valid(generation_context.navigation_region)
		and generation_context.navigation_region.get_parent() == null
	):
		detached_roots.append(generation_context.navigation_region)

	generation_context.csg_root = null
	generation_context.navigation_region = null
	generation_context.prefab_instances.clear()

	for detached_root: Node in detached_roots:
		if is_instance_valid(detached_root) and detached_root.get_parent() == null:
			detached_root.free()
