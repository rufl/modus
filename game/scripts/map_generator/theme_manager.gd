class_name ThemeManager
extends RefCounted

## ThemeManager handles theme configuration, prefab filtering, and lighting setup
## Manages visual styling for generated maps based on selected theme

var _themes: Dictionary = {}  # ThemeType -> MapTheme
var _current_theme: MapTheme = null
var _rng: RandomNumberGenerator = null


## Initialize the theme manager with all available themes
func _init() -> void:
	_load_default_themes()


## Load default theme configurations for all theme types
func _load_default_themes() -> void:
	_themes[GenerationConfig.ThemeType.TECH] = MapTheme.create_default_theme(
		GenerationConfig.ThemeType.TECH
	)
	_themes[GenerationConfig.ThemeType.HELL] = MapTheme.create_default_theme(
		GenerationConfig.ThemeType.HELL
	)
	_themes[GenerationConfig.ThemeType.URBAN] = MapTheme.create_default_theme(
		GenerationConfig.ThemeType.URBAN
	)
	_themes[GenerationConfig.ThemeType.CAVE] = MapTheme.create_default_theme(
		GenerationConfig.ThemeType.CAVE
	)
	_themes[GenerationConfig.ThemeType.JUMBLED] = MapTheme.create_default_theme(
		GenerationConfig.ThemeType.JUMBLED
	)


## Set the active theme for generation
func set_theme(theme_type: GenerationConfig.ThemeType, rng: RandomNumberGenerator = null) -> void:
	if not _themes.has(theme_type):
		push_error("ThemeManager: Unknown theme type: %d" % theme_type)
		return

	var theme: MapTheme = _themes[theme_type]
	theme.ensure_materials()
	_current_theme = theme
	_rng = rng


## Get the current active theme
func get_current_theme() -> MapTheme:
	return _current_theme


## Get a specific theme by type
func get_theme(theme_type: GenerationConfig.ThemeType) -> MapTheme:
	return _themes.get(theme_type, null)


## Get wall material for the current theme
func get_wall_material() -> Material:
	if _current_theme:
		return _current_theme.wall_material
	return null


## Get floor material for the current theme
func get_floor_material() -> Material:
	if _current_theme:
		return _current_theme.floor_material
	return null


## Get ceiling material for the current theme
func get_ceiling_material() -> Material:
	if _current_theme:
		return _current_theme.ceiling_material
	return null


## Get cave material for the current theme
func get_cave_material() -> Material:
	if _current_theme:
		return _current_theme.get_cave_material()
	return null


## Get ambient light color for the current theme
func get_ambient_color() -> Color:
	if _current_theme:
		return _current_theme.ambient_color
	return Color(0.3, 0.3, 0.3)


## Get ambient light energy for the current theme
func get_ambient_energy() -> float:
	if _current_theme:
		return _current_theme.ambient_energy
	return 0.5


## Get directional light color for the current theme
func get_directional_color() -> Color:
	if _current_theme:
		return _current_theme.directional_color
	return Color(1.0, 1.0, 1.0)


## Get directional light energy for the current theme
func get_directional_energy() -> float:
	if _current_theme:
		return _current_theme.directional_energy
	return 1.0


## Filter prefabs by theme compatibility
## Returns true if the prefab is compatible with the current theme
func is_prefab_compatible(prefab_metadata: PrefabMetadata) -> bool:
	if not _current_theme:
		return false

	# Jumbled theme accepts all prefabs
	if _current_theme.theme_type == GenerationConfig.ThemeType.JUMBLED:
		return true

	# Check if prefab's required theme matches current theme
	var prefab_theme_type := prefab_metadata.required_theme
	var current_theme_type := _current_theme.theme_type

	# Jumbled/shared prefabs work with all themes
	if prefab_theme_type == GenerationConfig.ThemeType.JUMBLED:
		return true

	return prefab_theme_type == current_theme_type


## Get theme name from prefab metadata
func _get_theme_name_from_metadata(prefab_metadata: PrefabMetadata) -> String:
	match prefab_metadata.required_theme:
		GenerationConfig.ThemeType.TECH:
			return "tech"
		GenerationConfig.ThemeType.HELL:
			return "hell"
		GenerationConfig.ThemeType.URBAN:
			return "urban"
		GenerationConfig.ThemeType.CAVE:
			return "cave"
		GenerationConfig.ThemeType.JUMBLED:
			return "shared"
		_:
			return "unknown"


## Get a random theme for Jumbled mode
## Used when placing individual prefabs in Jumbled theme
func get_random_theme_for_jumbled() -> MapTheme:
	if not _rng:
		push_warning("ThemeManager: RNG not set, using default theme")
		return _current_theme

	var theme_types := [
		GenerationConfig.ThemeType.TECH,
		GenerationConfig.ThemeType.HELL,
		GenerationConfig.ThemeType.URBAN,
		GenerationConfig.ThemeType.CAVE
	]

	var random_type: GenerationConfig.ThemeType = theme_types[_rng.randi() % theme_types.size()]
	return _themes[random_type]


## Apply lighting configuration to a scene
## Creates or updates WorldEnvironment and DirectionalLight3D nodes
func apply_lighting_to_scene(root_node: Node3D) -> void:
	if not _current_theme:
		push_warning("ThemeManager: No theme set, skipping lighting setup")
		return

	# Create or update WorldEnvironment
	var world_env := _find_or_create_world_environment(root_node)
	_configure_world_environment(world_env)

	# Create or update DirectionalLight3D
	var directional_light := _find_or_create_directional_light(root_node)
	_configure_directional_light(directional_light)


## Find existing WorldEnvironment or create a new one
func _find_or_create_world_environment(root_node: Node3D) -> WorldEnvironment:
	for child in root_node.get_children():
		if child is WorldEnvironment:
			return child

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	root_node.add_child(world_env)
	world_env.owner = root_node
	return world_env


## Configure WorldEnvironment with theme-specific ambient lighting
func _configure_world_environment(world_env: WorldEnvironment) -> void:
	if not world_env.environment:
		world_env.environment = Environment.new()

	var env := world_env.environment

	# Set ambient light
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _current_theme.ambient_color
	env.ambient_light_energy = _current_theme.ambient_energy

	# Basic environment settings
	env.background_mode = Environment.BG_COLOR
	env.background_color = _current_theme.ambient_color.darkened(0.3)

	# Enable basic fog for atmosphere
	env.fog_enabled = true
	env.fog_light_color = _current_theme.ambient_color
	env.fog_density = 0.01


## Find existing DirectionalLight3D or create a new one
func _find_or_create_directional_light(root_node: Node3D) -> DirectionalLight3D:
	for child in root_node.get_children():
		if child is DirectionalLight3D:
			return child

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	root_node.add_child(light)
	light.owner = root_node
	return light


## Configure DirectionalLight3D with theme-specific settings
func _configure_directional_light(light: DirectionalLight3D) -> void:
	light.light_color = _current_theme.directional_color
	light.light_energy = _current_theme.directional_energy

	# Set light direction (45-degree angle from above)
	light.rotation_degrees = Vector3(-45, 45, 0)

	# Enable shadows
	light.shadow_enabled = true
	light.shadow_bias = 0.1


## Get material for a specific surface type
## surface_type: "wall", "floor", "ceiling", "cave"
func get_material_for_surface(surface_type: String) -> Material:
	match surface_type.to_lower():
		"wall":
			return get_wall_material()
		"floor":
			return get_floor_material()
		"ceiling":
			return get_ceiling_material()
		"cave":
			return get_cave_material()
		_:
			push_warning("ThemeManager: Unknown surface type '%s'" % surface_type)
			return get_wall_material()


## Load custom theme from resource file
## Returns true if successful
func load_custom_theme(theme_path: String, theme_type: GenerationConfig.ThemeType) -> bool:
	if not ResourceLoader.exists(theme_path):
		push_error("ThemeManager: Theme resource not found: %s" % theme_path)
		return false

	var theme := ResourceLoader.load(theme_path) as MapTheme
	if not theme:
		push_error("ThemeManager: Failed to load theme from: %s" % theme_path)
		return false

	theme.theme_type = theme_type
	_themes[theme_type] = theme
	return true


## Get all available theme types
func get_available_themes() -> Array:
	var types := []
	for theme_type in _themes.keys():
		types.append(theme_type)
	return types


## Check if a theme type is available
func has_theme(theme_type: GenerationConfig.ThemeType) -> bool:
	return _themes.has(theme_type)
