class_name MapPrefabSystem
extends RefCounted

## System for loading, managing, and placing prefab assets in generated maps
## Supports theme-based organization, JSON metadata parsing, and spatial constraint validation


## Prefab entry containing the scene and metadata
class PrefabEntry:
	var scene: PackedScene
	var metadata: PrefabMetadata
	var file_path: String

	func _init(p_scene: PackedScene, p_metadata: PrefabMetadata, p_file_path: String) -> void:
		scene = p_scene
		metadata = p_metadata
		file_path = p_file_path


# Prefab cache: theme -> category -> Array[PrefabEntry]
var _prefab_cache: Dictionary = {}

# Reference to ThemeManager for filtering
var _theme_manager: ThemeManager = null

# Base directory for prefabs
const PREFAB_BASE_DIR := "res://game/data/map_generator/prefabs/"

# MapTheme directory names
const THEME_DIRS := {
	GenerationConfig.ThemeType.TECH: "tech",
	GenerationConfig.ThemeType.HELL: "hell",
	GenerationConfig.ThemeType.URBAN: "urban",
	GenerationConfig.ThemeType.CAVE: "cave",
	GenerationConfig.ThemeType.JUMBLED: "shared"
}


## Initialize the prefab system
func _init() -> void:
	_initialize_cache()


## Initialize the prefab cache structure
func _initialize_cache() -> void:
	for theme: int in GenerationConfig.ThemeType.values():
		_prefab_cache[theme] = {}


## Load all prefabs for a specific theme
## Returns the number of prefabs loaded
func load_prefabs_for_theme(theme: GenerationConfig.ThemeType) -> int:
	var theme_dir: String = THEME_DIRS.get(theme, "")
	if theme_dir.is_empty():
		push_warning("PrefabSystem: Unknown theme type: %d" % theme)
		return 0

	var full_path: String = PREFAB_BASE_DIR + theme_dir

	if not DirAccess.dir_exists_absolute(full_path):
		push_warning("PrefabSystem: MapTheme directory does not exist: %s" % full_path)
		return 0

	return _load_prefabs_from_directory(full_path, theme)


## Load all prefabs from all themes
## Returns the total number of prefabs loaded
func load_all_prefabs() -> int:
	var total_loaded := 0

	for theme: GenerationConfig.ThemeType in GenerationConfig.ThemeType.values():
		total_loaded += load_prefabs_for_theme(theme)

	return total_loaded


## Load prefabs from a specific directory
func _load_prefabs_from_directory(dir_path: String, theme: GenerationConfig.ThemeType) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error(
			(
				"PrefabSystem: Failed to open directory: %s (Error: %d)"
				% [dir_path, DirAccess.get_open_error()]
			)
		)
		return 0

	var loaded_count := 0
	var files := dir.get_files()

	# Find all .tscn files
	for file_name in files:
		if not file_name.ends_with(".tscn"):
			continue

		var scene_path := dir_path + "/" + file_name
		var metadata_path := scene_path.replace(".tscn", ".json")

		# Check if metadata file exists
		if not FileAccess.file_exists(metadata_path):
			push_warning("PrefabSystem: No metadata file found for prefab: %s" % scene_path)
			continue

		# Load the scene
		var scene := load(scene_path) as PackedScene
		if scene == null:
			push_error("PrefabSystem: Failed to load prefab scene: %s" % scene_path)
			continue

		# Load the metadata
		var metadata: PrefabMetadata = PrefabMetadata.from_file(metadata_path)
		if metadata == null:
			push_error("PrefabSystem: Failed to load metadata for prefab: %s" % scene_path)
			continue

		# Validate metadata
		if not metadata.is_valid():
			push_error("PrefabSystem: Invalid metadata for prefab: %s" % scene_path)
			continue

		# Create prefab entry
		var entry := PrefabEntry.new(scene, metadata, scene_path)

		# Cache by tags (categories)
		if metadata.tags.is_empty():
			# No tags, add to "uncategorized"
			_add_to_cache(theme, "uncategorized", entry)
		else:
			# Add to each tag category
			for tag: String in metadata.tags:
				_add_to_cache(theme, tag, entry)

		loaded_count += 1

	return loaded_count


## Add a prefab entry to the cache
func _add_to_cache(theme: GenerationConfig.ThemeType, category: String, entry: PrefabEntry) -> void:
	if not _prefab_cache[theme].has(category):
		_prefab_cache[theme][category] = []

	_prefab_cache[theme][category].append(entry)


## Get all prefabs for a theme and category
func get_prefabs(theme: GenerationConfig.ThemeType, category: String = "") -> Array[PrefabEntry]:
	var result: Array[PrefabEntry] = []

	if not _prefab_cache.has(theme):
		return result

	var theme_cache: Dictionary = _prefab_cache[theme]

	# If no category specified, return all prefabs for this theme
	if category.is_empty():
		for cat: String in theme_cache.keys():
			result.append_array(theme_cache[cat])
		return result

	# Return prefabs for specific category
	if theme_cache.has(category):
		result.append_array(theme_cache[category])

	return result


## Get prefabs for Jumbled theme (mix from all themes)
func get_jumbled_prefabs(category: String = "") -> Array[PrefabEntry]:
	var result: Array[PrefabEntry] = []

	# Collect from all themes except Jumbled itself
	for theme: GenerationConfig.ThemeType in [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.URBAN,
		GenerationConfig.ThemeType.CAVE
	]:
		result.append_array(get_prefabs(theme, category))

	# Also include shared prefabs
	result.append_array(get_prefabs(GenerationConfig.ThemeType.JUMBLED, category))

	return result


## Get a random prefab from a theme and category
func get_random_prefab(
	theme: GenerationConfig.ThemeType, category: String, rng: RandomNumberGenerator
) -> PrefabEntry:
	var prefabs: Array[PrefabEntry]

	if theme == GenerationConfig.ThemeType.JUMBLED:
		prefabs = get_jumbled_prefabs(category)
	else:
		prefabs = get_prefabs(theme, category)

	if prefabs.is_empty():
		return null

	return prefabs[rng.randi_range(0, prefabs.size() - 1)]


## Get prefab count for a theme
func get_prefab_count(theme: GenerationConfig.ThemeType, category: String = "") -> int:
	return get_prefabs(theme, category).size()


## Get all categories for a theme
func get_categories(theme: GenerationConfig.ThemeType) -> Array[String]:
	var categories: Array[String] = []

	if _prefab_cache.has(theme):
		categories.assign(_prefab_cache[theme].keys())

	return categories


## Clear the prefab cache
func clear_cache() -> void:
	_prefab_cache.clear()
	_initialize_cache()


## Check if prefabs are loaded for a theme
func has_prefabs_for_theme(theme: GenerationConfig.ThemeType) -> bool:
	return get_prefab_count(theme) > 0


## Set the theme manager for prefab filtering
func set_theme_manager(theme_manager: ThemeManager) -> void:
	_theme_manager = theme_manager


## Get filtered prefabs based on current theme compatibility
## Only returns prefabs that are compatible with the current theme
func get_filtered_prefabs(
	theme: GenerationConfig.ThemeType, category: String = ""
) -> Array[PrefabEntry]:
	var all_prefabs := get_prefabs(theme, category)

	# If no theme manager, return all prefabs
	if not _theme_manager:
		return all_prefabs

	# Filter by theme compatibility
	var filtered: Array[PrefabEntry] = []
	for entry: PrefabEntry in all_prefabs:
		if _theme_manager.is_prefab_compatible(entry.metadata):
			filtered.append(entry)

	return filtered


## Get filtered prefabs for Jumbled theme
func get_filtered_jumbled_prefabs(category: String = "") -> Array[PrefabEntry]:
	var all_prefabs := get_jumbled_prefabs(category)

	# Jumbled theme accepts all prefabs, so no filtering needed
	return all_prefabs


## Get a random filtered prefab from a theme and category
func get_random_filtered_prefab(
	theme: GenerationConfig.ThemeType, category: String, rng: RandomNumberGenerator
) -> PrefabEntry:
	var prefabs: Array[PrefabEntry]

	if theme == GenerationConfig.ThemeType.JUMBLED:
		prefabs = get_filtered_jumbled_prefabs(category)
	else:
		prefabs = get_filtered_prefabs(theme, category)

	if prefabs.is_empty():
		return null

	return prefabs[rng.randi_range(0, prefabs.size() - 1)]


## Placement result containing the instantiated node and metadata
class PlacementResult:
	var node: Node3D
	var entry: PrefabEntry
	var position: Vector3
	var rotation: float

	func _init(
		p_node: Node3D, p_entry: PrefabEntry, p_position: Vector3, p_rotation: float
	) -> void:
		node = p_node
		entry = p_entry
		position = p_position
		rotation = p_rotation


## Place prefabs in a room based on density control
## Returns an array of PlacementResult objects
func place_prefabs_in_room(
	room: Room,
	context: GenerationContext,
	parent_node: Node3D,
	category: String = "",
	density_override: float = -1.0
) -> Array[PlacementResult]:
	var results: Array[PlacementResult] = []

	# Get density from config or use override
	var density: float = (
		density_override if density_override >= 0.0 else context.config.prop_density
	)

	# Get theme
	var theme := context.config.theme

	# Get available prefabs (filtered by theme compatibility)
	var available_prefabs: Array[PrefabEntry]
	if theme == GenerationConfig.ThemeType.JUMBLED:
		available_prefabs = get_filtered_jumbled_prefabs(category)
	else:
		available_prefabs = get_filtered_prefabs(theme, category)

	if available_prefabs.is_empty():
		return results

	# Calculate number of prefabs to place based on room size and density
	var room_area := room.cells.size()
	var base_count := int(room_area * density * 0.5)  # 0.5 prefabs per cell at max density

	# Adjust by density weights
	var weighted_count := 0.0
	for entry: PrefabEntry in available_prefabs:
		weighted_count += entry.metadata.density_weight

	var avg_weight: float = (
		weighted_count / available_prefabs.size() if available_prefabs.size() > 0 else 1.0
	)
	var target_count: int = max(1, int(base_count * avg_weight))

	# Track placed positions for collision avoidance
	var placed_positions: Array[Vector3] = []

	# Attempt to place prefabs
	var attempts := 0
	var max_attempts: int = target_count * 10  # Allow multiple attempts per prefab

	while results.size() < target_count and attempts < max_attempts:
		attempts += 1

		# Pick a random prefab
		var entry := available_prefabs[context.rng.randi_range(0, available_prefabs.size() - 1)]

		# Pick a random cell in the room
		var cell_pos := room.cells[context.rng.randi_range(0, room.cells.size() - 1)]

		# Convert to world position (2 meters per cell)
		var world_pos := Vector3(cell_pos.x * 2.0, 0.0, cell_pos.y * 2.0)

		# Add random offset within cell
		world_pos.x += context.rng.randf_range(-0.8, 0.8)
		world_pos.z += context.rng.randf_range(-0.8, 0.8)

		# Check spatial constraints
		if not _check_spatial_constraints(world_pos, entry.metadata, placed_positions, context):
			continue

		# Check placement rules
		if not _check_placement_rules(world_pos, cell_pos, entry.metadata, room, context):
			continue

		# Instantiate the prefab
		var instance := entry.scene.instantiate() as Node3D
		if instance == null:
			push_warning("PrefabSystem: Failed to instantiate prefab: %s" % entry.file_path)
			continue

		# Set position and random rotation
		instance.position = world_pos
		var rotation := context.rng.randf_range(0.0, TAU)
		instance.rotation.y = rotation

		# Add to parent
		parent_node.add_child(instance)

		# Track placement
		placed_positions.append(world_pos)
		results.append(PlacementResult.new(instance, entry, world_pos, rotation))

	return results


## Check spatial constraints for prefab placement
func _check_spatial_constraints(
	position: Vector3,
	metadata: PrefabMetadata,
	placed_positions: Array[Vector3],
	_context: GenerationContext
) -> bool:
	# Check collision with already placed prefabs
	for placed_pos in placed_positions:
		var distance := position.distance_to(placed_pos)
		if distance < metadata.collision_radius * 2.0:
			return false

	return true


## Check placement rules for prefab placement
func _check_placement_rules(
	_world_pos: Vector3,
	cell_pos: Vector2i,
	metadata: PrefabMetadata,
	room: Room,
	context: GenerationContext
) -> bool:
	var rules: Dictionary = metadata.placement_rules

	# Check min_distance_from_walls
	if rules.has("min_distance_from_walls"):
		var min_dist: float = rules["min_distance_from_walls"]
		if not _check_wall_distance(cell_pos, min_dist, room, context):
			return false

	# Check requires_floor
	if rules.has("requires_floor"):
		var requires_floor: bool = rules["requires_floor"]
		if requires_floor:
			# For now, assume all positions have floor
			# This can be enhanced with actual floor detection
			pass

	# Check max_per_room
	if rules.has("max_per_room"):
		# This would need to be tracked per room
		# For now, we'll skip this check as it requires additional state tracking
		pass

	return true


## Check if position is far enough from walls
func _check_wall_distance(
	cell_pos: Vector2i, min_distance: float, room: Room, _context: GenerationContext
) -> bool:
	# Check if cell is on room boundary
	var is_boundary := false

	# Check 4-directional neighbors
	var neighbors := [
		Vector2i(cell_pos.x + 1, cell_pos.y),
		Vector2i(cell_pos.x - 1, cell_pos.y),
		Vector2i(cell_pos.x, cell_pos.y + 1),
		Vector2i(cell_pos.x, cell_pos.y - 1)
	]

	for neighbor: Vector2i in neighbors:
		if not room.cells.has(neighbor):
			is_boundary = true
			break

	# If on boundary and min_distance > 0, reject
	if is_boundary and min_distance > 0.0:
		return false

	return true


## Place prefabs in multiple rooms based on density control
func place_prefabs_in_rooms(
	rooms: Array[Room],
	context: GenerationContext,
	parent_node: Node3D,
	category: String = "",
	density_override: float = -1.0
) -> Array[PlacementResult]:
	var all_results: Array[PlacementResult] = []

	for room in rooms:
		var results := place_prefabs_in_room(room, context, parent_node, category, density_override)
		all_results.append_array(results)

	return all_results


## Place a specific prefab at a specific position
func place_prefab_at_position(
	entry: PrefabEntry, position: Vector3, rotation: float, parent_node: Node3D
) -> PlacementResult:
	var instance := entry.scene.instantiate() as Node3D
	if instance == null:
		push_error("PrefabSystem: Failed to instantiate prefab: %s" % entry.file_path)
		return null

	instance.position = position
	instance.rotation.y = rotation
	parent_node.add_child(instance)

	return PlacementResult.new(instance, entry, position, rotation)


## Get prefabs by category across all themes (for statistics)
func get_all_prefabs_by_category(category: String) -> Array[PrefabEntry]:
	var result: Array[PrefabEntry] = []

	for theme: GenerationConfig.ThemeType in GenerationConfig.ThemeType.values():
		result.append_array(get_prefabs(theme, category))

	return result


## Get statistics about loaded prefabs
func get_statistics() -> Dictionary:
	var stats := {"total_prefabs": 0, "by_theme": {}, "by_category": {}}

	for theme: GenerationConfig.ThemeType in GenerationConfig.ThemeType.values():
		var theme_name: String = THEME_DIRS.get(theme, "unknown")
		var count := get_prefab_count(theme)
		stats["by_theme"][theme_name] = count
		stats["total_prefabs"] += count

		# Count by category
		var categories := get_categories(theme)
		for category: String in categories:
			if not stats["by_category"].has(category):
				stats["by_category"][category] = 0
			stats["by_category"][category] += get_prefab_count(theme, category)

	return stats


## Apply MultiMesh batching to placement results
## This should be called after all prefabs have been placed
## Returns statistics about the batching operation
func apply_multimesh_batching(
	placement_results: Array[PlacementResult], parent_node: Node3D, context: GenerationContext
) -> Dictionary:
	# Load MultiMeshManager
	var MultiMeshManager := preload("res://game/scripts/map_generator/multimesh_manager.gd")
	var multimesh_manager := MultiMeshManager.new()

	# Apply batching
	return multimesh_manager.apply_multimesh_batching(placement_results, parent_node, context)
