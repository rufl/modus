class_name PrefabMetadata
extends Resource

## Metadata for prefab placement in generated maps
## Defines dimensions, anchor points, theme requirements, and placement rules

@export var dimensions: Vector3 = Vector3.ZERO  # Bounding box size
@export var anchor_points: Array[Vector3] = []  # Snap points for placement
@export var required_theme: GenerationConfig.ThemeType = GenerationConfig.ThemeType.TECH
@export var density_weight: float = 1.0  # Multiplier for density calculations
@export var tags: Array[String] = []  # Categories: "prop", "furniture", "cover", etc.
@export var collision_radius: float = 0.5  # For spatial constraint checking
@export var placement_rules: Dictionary = {}  # Custom placement constraints


## Validate that the metadata has all required fields
func is_valid() -> bool:
	return dimensions.length() > 0.0


## Parse JSON metadata from a dictionary
## Returns a PrefabMetadata object or null if parsing fails
static func from_dict(data: Dictionary) -> PrefabMetadata:
	var metadata := PrefabMetadata.new()

	# Parse dimensions (required)
	if not data.has("dimensions"):
		push_error("PrefabMetadata: Missing required field 'dimensions'")
		return null

	var dims: Variant = data["dimensions"]
	if dims is Array and dims.size() == 3:
		metadata.dimensions = Vector3(dims[0], dims[1], dims[2])
	else:
		push_error("PrefabMetadata: Invalid 'dimensions' format, expected array of 3 numbers")
		return null

	# Parse anchor_points (required)
	if not data.has("anchor_points"):
		push_error("PrefabMetadata: Missing required field 'anchor_points'")
		return null

	var anchors: Variant = data["anchor_points"]
	if anchors is Array:
		for anchor: Variant in anchors:
			if anchor is Array and anchor.size() == 3:
				metadata.anchor_points.append(Vector3(anchor[0], anchor[1], anchor[2]))
			else:
				push_error(
					"PrefabMetadata: Invalid anchor point format, " + "expected array of 3 numbers"
				)
				return null
	else:
		push_error("PrefabMetadata: Invalid 'anchor_points' format, expected array")
		return null

	# Parse required_theme (required)
	if not data.has("required_theme"):
		push_error("PrefabMetadata: Missing required field 'required_theme'")
		return null

	var theme_str: String = data["required_theme"]
	match theme_str.to_lower():
		"tech":
			metadata.required_theme = GenerationConfig.ThemeType.TECH
		"hell":
			metadata.required_theme = GenerationConfig.ThemeType.HELL
		"urban":
			metadata.required_theme = GenerationConfig.ThemeType.URBAN
		"cave":
			metadata.required_theme = GenerationConfig.ThemeType.CAVE
		"jumbled", "shared":
			metadata.required_theme = GenerationConfig.ThemeType.JUMBLED
		_:
			push_error(
				(
					"PrefabMetadata: Invalid theme '%s', "
					+ "expected tech/hell/urban/cave/jumbled" % theme_str
				)
			)
			return null

	# Parse optional fields with defaults
	metadata.density_weight = data.get("density_weight", 1.0)

	# Parse tags (optional, default to empty array)
	if data.has("tags"):
		var tags_data: Variant = data["tags"]
		if tags_data is Array:
			for tag: Variant in tags_data:
				if tag is String:
					metadata.tags.append(tag)
		else:
			push_warning("PrefabMetadata: Invalid 'tags' format, expected array of strings")

	# Parse collision_radius (optional, default to 0.5)
	metadata.collision_radius = data.get("collision_radius", 0.5)

	# Parse placement_rules (optional, default to empty dictionary)
	if data.has("placement_rules"):
		var rules: Variant = data["placement_rules"]
		if rules is Dictionary:
			metadata.placement_rules = rules
		else:
			push_warning(
				"PrefabMetadata: Invalid 'placement_rules' format, " + "expected dictionary"
			)

	return metadata


## Parse JSON metadata from a file path
## Returns a PrefabMetadata object or null if parsing fails
static func from_file(file_path: String) -> PrefabMetadata:
	if not FileAccess.file_exists(file_path):
		push_error("PrefabMetadata: File not found: %s" % file_path)
		return null

	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error(
			(
				"PrefabMetadata: Failed to open file: %s (Error: %d)"
				% [file_path, FileAccess.get_open_error()]
			)
		)
		return null

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_text)

	if parse_result != OK:
		push_error(
			(
				"PrefabMetadata: JSON parse error in %s at line %d: %s"
				% [file_path, json.get_error_line(), json.get_error_message()]
			)
		)
		return null

	var data: Variant = json.data
	if not data is Dictionary:
		push_error("PrefabMetadata: Expected JSON object in %s" % file_path)
		return null

	return from_dict(data)


## Convert metadata to a dictionary for JSON export
func to_dict() -> Dictionary:
	var data := {}

	# Export dimensions
	data["dimensions"] = [dimensions.x, dimensions.y, dimensions.z]

	# Export anchor_points
	var anchors := []
	for anchor in anchor_points:
		anchors.append([anchor.x, anchor.y, anchor.z])
	data["anchor_points"] = anchors

	# Export required_theme
	match required_theme:
		GenerationConfig.ThemeType.TECH:
			data["required_theme"] = "tech"
		GenerationConfig.ThemeType.HELL:
			data["required_theme"] = "hell"
		GenerationConfig.ThemeType.URBAN:
			data["required_theme"] = "urban"
		GenerationConfig.ThemeType.CAVE:
			data["required_theme"] = "cave"
		GenerationConfig.ThemeType.JUMBLED:
			data["required_theme"] = "jumbled"

	# Export optional fields
	data["density_weight"] = density_weight
	data["tags"] = tags.duplicate()
	data["collision_radius"] = collision_radius
	data["placement_rules"] = placement_rules.duplicate()

	return data


## Pretty print metadata to JSON string
func to_json_string(indent: String = "\t") -> String:
	return JSON.stringify(to_dict(), indent)


## Save metadata to a file
func save_to_file(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error(
			(
				"PrefabMetadata: Failed to open file for writing: %s (Error: %d)"
				% [file_path, FileAccess.get_open_error()]
			)
		)
		return false

	file.store_string(to_json_string())
	file.close()
	return true
