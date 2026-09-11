class_name GenerationConfig
extends Resource

## Configuration resource for map generation
## Contains all parameters for controlling generation behavior

enum DifficultyLevel { EASY, NORMAL, HARD, NIGHTMARE }
enum ExportFormat { PACKED_SCENE, GLTF }
enum ThemeType { TECH, HELL, URBAN, CAVE, JUMBLED }

# Layout
@export var map_size: Vector2i = Vector2i(128, 128)  # Grid dimensions
@export var map_seed: String = ""  # Renamed from 'seed' to avoid conflict with built-in function
@export var outdoor_bias: float = 0.3  # 0.0-1.0
@export var cave_bias: float = 0.2  # 0.0-1.0
@export var theme: ThemeType = ThemeType.TECH

# Details
@export var prefab_detail_level: float = 0.7  # 0.0-1.0
@export var prop_density: float = 0.5  # 0.0-1.0
@export var decorative_density: float = 0.6  # 0.0-1.0
@export var enable_lod: bool = true
@export var enable_occlusion_culling: bool = true
@export var use_multimesh: bool = true

# Gameplay
@export var monster_density: float = 0.5  # 0.0-1.0
@export var minimum_monsters: int = 0  # Explicit floor for small maps
@export var difficulty_scaling: DifficultyLevel = DifficultyLevel.NORMAL
@export var item_density: float = 0.5  # 0.0-1.0
@export var enable_key_locks: bool = true
@export var enable_boss_arena: bool = true
@export var enable_secrets: bool = true
@export_range(1, 3) var secret_room_count: int = 1

# Export
@export var export_format: ExportFormat = ExportFormat.PACKED_SCENE
@export var output_directory: String = "res://game/world/maps/generated/"

# Debug
@export var debug_mode: bool = false  # Enable intermediate state saving for debugging


func _init() -> void:
	# Set default values
	pass


## Compatibility helper for callers that also accept dictionary configs.
## Resource properties must be inspected through get_property_list() rather
## than Dictionary.has().
func has(property_name: StringName) -> bool:
	for property: Dictionary in get_property_list():
		if property.get("name", "") == property_name:
			return true
	return false
