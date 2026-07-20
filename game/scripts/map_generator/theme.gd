class_name MapTheme
extends Resource

## MapTheme configuration for visual styling of generated maps
## Defines materials, lighting, and prefab filters for each theme type

@export var theme_type: GenerationConfig.ThemeType = GenerationConfig.ThemeType.TECH
@export var wall_material: Material
@export var floor_material: Material
@export var ceiling_material: Material
@export var ambient_color: Color = Color(0.3, 0.3, 0.3)
@export var ambient_energy: float = 0.5
@export var directional_color: Color = Color(1.0, 1.0, 1.0)
@export var directional_energy: float = 1.0
@export var prefab_filter_tags: Array[String] = []
@export var shape_grammar_rules: Array[String] = []


## Get the theme name as a string
func get_theme_name() -> String:
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


## Create a default theme for the given type
static func create_default_theme(p_theme_type: GenerationConfig.ThemeType) -> MapTheme:
	var theme := MapTheme.new()
	theme.theme_type = p_theme_type

	# Create placeholder materials (will be replaced with actual materials later)
	match p_theme_type:
		GenerationConfig.ThemeType.TECH:
			theme.wall_material = _create_placeholder_material(Color(0.4, 0.5, 0.6))
			theme.floor_material = _create_placeholder_material(Color(0.3, 0.3, 0.35))
			theme.ceiling_material = _create_placeholder_material(Color(0.35, 0.35, 0.4))
			theme.ambient_color = Color(0.4, 0.5, 0.6)
			theme.directional_color = Color(0.9, 0.95, 1.0)

		GenerationConfig.ThemeType.HELL:
			theme.wall_material = _create_placeholder_material(Color(0.5, 0.2, 0.1))
			theme.floor_material = _create_placeholder_material(Color(0.3, 0.1, 0.05))
			theme.ceiling_material = _create_placeholder_material(Color(0.4, 0.15, 0.08))
			theme.ambient_color = Color(0.6, 0.2, 0.1)
			theme.directional_color = Color(1.0, 0.5, 0.3)

		GenerationConfig.ThemeType.URBAN:
			theme.wall_material = _create_placeholder_material(Color(0.6, 0.6, 0.55))
			theme.floor_material = _create_placeholder_material(Color(0.4, 0.4, 0.4))
			theme.ceiling_material = _create_placeholder_material(Color(0.5, 0.5, 0.5))
			theme.ambient_color = Color(0.5, 0.5, 0.5)
			theme.directional_color = Color(1.0, 0.95, 0.9)

		GenerationConfig.ThemeType.CAVE:
			theme.wall_material = _create_placeholder_material(Color(0.3, 0.25, 0.2))
			theme.floor_material = _create_placeholder_material(Color(0.25, 0.2, 0.15))
			theme.ceiling_material = _create_placeholder_material(Color(0.28, 0.23, 0.18))
			theme.ambient_color = Color(0.2, 0.2, 0.25)
			theme.directional_color = Color(0.8, 0.8, 0.9)

		GenerationConfig.ThemeType.JUMBLED:
			# Jumbled uses random mix - start with tech as base
			theme.wall_material = _create_placeholder_material(Color(0.5, 0.5, 0.5))
			theme.floor_material = _create_placeholder_material(Color(0.4, 0.4, 0.4))
			theme.ceiling_material = _create_placeholder_material(Color(0.45, 0.45, 0.45))
			theme.ambient_color = Color(0.4, 0.4, 0.4)
			theme.directional_color = Color(1.0, 1.0, 1.0)

	return theme


## Create a simple placeholder material with the given color
static func _create_placeholder_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.metallic = 0.1
	return material


## Get cave-specific material based on theme
## Used for voxel-based cave terrain
func get_cave_material() -> Material:
	# For cave theme, use wall material
	if theme_type == GenerationConfig.ThemeType.CAVE:
		return (
			wall_material if wall_material else _create_placeholder_material(Color(0.3, 0.25, 0.2))
		)

	# For other themes, create a cave-appropriate material
	var cave_material := StandardMaterial3D.new()

	match theme_type:
		GenerationConfig.ThemeType.TECH:
			# Tech caves: metallic gray/blue
			cave_material.albedo_color = Color(0.35, 0.4, 0.45)
			cave_material.metallic = 0.3
			cave_material.roughness = 0.7

		GenerationConfig.ThemeType.HELL:
			# Hell caves: dark red/brown rock
			cave_material.albedo_color = Color(0.4, 0.15, 0.1)
			cave_material.metallic = 0.0
			cave_material.roughness = 0.95

		GenerationConfig.ThemeType.URBAN:
			# Urban caves: concrete/sewer
			cave_material.albedo_color = Color(0.45, 0.45, 0.4)
			cave_material.metallic = 0.0
			cave_material.roughness = 0.85

		GenerationConfig.ThemeType.JUMBLED:
			# Jumbled: generic brown cave
			cave_material.albedo_color = Color(0.35, 0.3, 0.25)
			cave_material.metallic = 0.1
			cave_material.roughness = 0.8

		_:
			# Default cave material
			cave_material.albedo_color = Color(0.3, 0.25, 0.2)
			cave_material.metallic = 0.0
			cave_material.roughness = 0.9

	return cave_material
