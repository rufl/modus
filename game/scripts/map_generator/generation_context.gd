class_name GenerationContext
extends RefCounted

## Container for all generation state and data
## Passed between generation phases and rule modules

# Grid state
var grid: Array[Array]  # 2D array of Cell
var grid_size: Vector2i
var rooms: Array[Room] = []
var hallways: Array[Hallway] = []
var outdoor_areas: Array = []  # Array of Rect2i regions
var cave_areas: Array = []  # Array of Rect2i regions

# Generation parameters
var seed_hash: int
var rng: RandomNumberGenerator
var config: GenerationConfig
var theme: MapTheme

# Placement tracking
var monster_spawns: Array = []  # Array of spawn point dictionaries
var item_spawns: Array = []  # Array of spawn point dictionaries
var key_placements: Array = []  # Array of key placement dictionaries
var secret_rooms: Array = []  # Array of secret room dictionaries
var skipped_prefabs: Array = []  # Invalid prefab diagnostics
var metadata: Dictionary = {}  # Optional phase and feature metadata
var player_start_position: Vector2i = Vector2i(-1, -1)

# Geometry
var csg_root: CSGCombiner3D
var prefab_instances: Array[Node3D] = []
var navigation_region: NavigationRegion3D

# Metadata
var generation_start_time: int
var phase_times: Dictionary = {}  # phase_name -> time_ms
var rule_modules_used: Array[String] = []


func _init() -> void:
	generation_start_time = Time.get_ticks_msec()
	rng = RandomNumberGenerator.new()


## Compatibility helper for callers that also accept dictionary contexts.
## RefCounted properties must be inspected through get_property_list() rather
## than Dictionary.has().
func has(property_name: StringName) -> bool:
	for property: Dictionary in get_property_list():
		if property.get("name", "") == property_name:
			return true
	return false
