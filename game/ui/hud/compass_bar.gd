extends Control
class_name CompassBar

enum MarkerType { QUEST, ENEMY, ALLY, ITEM, LOCATION }

const CONFIG_PATH := "res://game/config/gameplay/ui.json5"

@export var compass_width: float = 400.0
@export var marker_spacing: float = 100.0  # Pixels per 90 degrees
@export var smooth_speed: float = 10.0
@export var max_enemy_markers: int = 5  # Limit number of enemies shown

var cardinal_labels: Dictionary = {}  # "N", "E", "S", "W" -> Label
var objective_markers: Dictionary = {}  # marker_id -> {node, position}
var current_rotation: float = 0.0
var target_rotation: float = 0.0
var marker_colors: Dictionary = {
	MarkerType.QUEST: Color.YELLOW,
	MarkerType.ENEMY: Color.RED,
	MarkerType.ALLY: Color.GREEN,
	MarkerType.ITEM: Color.CYAN,
	MarkerType.LOCATION: Color.WHITE,
}

@onready var compass_strip: Control = $CompassStrip
@onready var markers_container: Control = $CompassStrip/Markers
@onready var center_indicator: Control = $CenterIndicator


func _ready() -> void:
	# Load configuration from JSON
	_load_config()
	add_to_group("compass_bar")

	# Prevent blocking mouse input
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Check if compass is enabled via GameManager.get_core_system("config")
	var config: Node = GameManager.get_core_system("config")
	if config and config.has_method("is_feature_enabled"):
		if not config.is_feature_enabled("u_hud_compass"):
			hide()
			set_process(false)
			return

	# Create cardinal direction labels
	_create_cardinal_markers()

	# Connect to GameManager.get_core_system("entities") for enemy tracking
	var entities: Node = GameManager.get_core_system("entities")
	if entities and entities.has_signal("enemy_registered"):
		entities.enemy_registered.connect(_on_enemy_registered)
		entities.enemy_unregistered.connect(_on_enemy_unregistered)

	# Initial update
	await get_tree().process_frame
	_update_compass(0.0, null)


func _on_enemy_registered(enemy: Node) -> void:
	# Add marker for new enemy
	var id: String = "enemy_" + str(enemy.get_instance_id())
	add_marker(
		id,
		enemy.global_position if "global_position" in enemy else Vector3.ZERO,
		MarkerType.ENEMY,
		null,
		{"enemy_ref": enemy}
	)


func _on_enemy_unregistered(enemy: Node) -> void:
	# Remove marker when enemy dies/is freed
	var id: String = "enemy_" + str(enemy.get_instance_id())
	remove_marker(id)


func _load_config() -> void:
	var config_system: Node = GameManager.get_core_system("config")
	if not config_system or not config_system.has_method("get_value"):
		return

	var config_var: Variant = config_system.get_value("visuals.hud.compass", {})
	if not config_var is Dictionary:
		return
	var config: Dictionary = config_var

	if config.is_empty():
		return

	# Load values with fallbacks
	compass_width = config.get("width", compass_width)
	marker_spacing = config.get("marker_spacing", marker_spacing)
	smooth_speed = config.get("smooth_speed", smooth_speed)

	# Load marker colors
	var colors: Dictionary = config.get("marker_colors", {})
	var type_map: Dictionary = {
		"quest": MarkerType.QUEST,
		"enemy": MarkerType.ENEMY,
		"ally": MarkerType.ALLY,
		"item": MarkerType.ITEM,
		"location": MarkerType.LOCATION
	}
	for color_name: String in colors:
		if type_map.has(color_name):
			var c: Dictionary = colors[color_name]
			if c.has("r") and c.has("g") and c.has("b"):
				marker_colors[type_map[color_name]] = Color(c.r, c.g, c.b, c.get("a", 1.0))


func _process(delta: float) -> void:
	# Get player rotation
	var player: Node3D = _find_local_player()
	if player:
		# Get Y rotation in degrees (0 = North)
		target_rotation = rad_to_deg(player.global_rotation.y)
		# Normalize to 0-360
		target_rotation = fmod(target_rotation + 360.0, 360.0)

	# Smooth interpolation
	current_rotation = lerp_angle(
		deg_to_rad(current_rotation), deg_to_rad(target_rotation), delta * smooth_speed
	)
	_update_compass(current_rotation, player)
	# Debug print (remove after fixing)
	# print("Compass: Player found? ", player != null, " Rotation: ", current_rotation)


func _create_cardinal_markers() -> void:
	var directions: Dictionary = {
		"N": 0.0,
		"NE": 45.0,
		"E": 90.0,
		"SE": 135.0,
		"S": 180.0,
		"SW": 225.0,
		"W": 270.0,
		"NW": 315.0
	}

	for dir_name: String in directions:
		var label: Label = Label.new()
		label.text = dir_name
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		# Style main cardinals differently
		if dir_name.length() == 1:
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

		if markers_container:
			markers_container.add_child(label)
			cardinal_labels[dir_name] = {"node": label, "angle": directions[dir_name]}
		else:
			label.free()  # Clean up if no container


func _update_compass(player_rotation: float, player: Node3D) -> void:
	var center_x: float = compass_width / 2.0

	# Update cardinal markers
	for dir_name: String in cardinal_labels:
		var data: Dictionary = cardinal_labels[dir_name]
		var label: Label = data["node"]
		var angle: float = data["angle"]

		# Calculate relative angle
		var relative_angle: float = _normalize_angle(angle - player_rotation)

		# Convert to screen position
		var x_offset: float = relative_angle * (marker_spacing / 90.0)
		var x_pos: float = center_x + x_offset

		# Position label
		label.position.x = x_pos - label.size.x / 2.0

		# Hide if outside compass bounds
		if abs(x_offset) > compass_width / 2.0:
			label.hide()
		else:
			label.show()
			# Fade at edges
			var fade: float = 1.0 - (abs(x_offset) / (compass_width / 2.0))
			label.modulate.a = fade

	# Optimize: Pre-calculate nearest enemies if player exists
	var allowed_enemies: Dictionary = {}
	if player:
		var enemies: Array = []
		for id: String in objective_markers:
			var m: Dictionary = objective_markers[id]
			if m.type == MarkerType.ENEMY:
				# Update position from enemy reference if available
				if m.has("enemy_ref") and is_instance_valid(m["enemy_ref"]):
					var enemy: Node = m["enemy_ref"]
					if "global_position" in enemy:
						m["position"] = enemy.global_position

				var dist_sq: float = player.global_position.distance_squared_to(m.position)
				enemies.append({"id": id, "dist": dist_sq})

		# Sort by distance
		if enemies.size() > max_enemy_markers:
			enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.dist < b.dist)
			# Keep only closest
			for i in range(max_enemy_markers):
				allowed_enemies[enemies[i].id] = true
		else:
			# All allowed
			for e: Dictionary in enemies:
				allowed_enemies[e.id] = true

	# Track markers that need removal (cannot remove during iteration)
	var markers_to_remove: Array[String] = []

	# Update objective markers
	for marker_id: String in objective_markers:
		var m_data: Dictionary = objective_markers[marker_id]

		# Filter enemies (and remove dead ones)
		if m_data.type == MarkerType.ENEMY:
			# Check if we should clean up invalid markers
			if not is_instance_valid(m_data.get("node")):
				markers_to_remove.append(marker_id)
				continue

			# Check if enemy reference is invalid (freed)
			if m_data.has("enemy_ref") and not is_instance_valid(m_data["enemy_ref"]):
				markers_to_remove.append(marker_id)
				continue

			if m_data.has("enemy_ref"):
				var enemy: Node = m_data["enemy_ref"]
				# Check if enemy is dead - schedule for removal, not just hide
				if enemy.has_method("is_dead_check") and enemy.is_dead_check():
					markers_to_remove.append(marker_id)
					continue
				if "is_dead" in enemy and enemy.is_dead:
					markers_to_remove.append(marker_id)
					continue
				if "health" in enemy and enemy.health <= 0:
					markers_to_remove.append(marker_id)
					continue

			if not player or not allowed_enemies.has(marker_id):
				m_data.node.hide()
				continue

		_update_marker_position(marker_id, player_rotation, player)

	# Deferred cleanup: Remove stale markers after iteration
	for marker_id: String in markers_to_remove:
		remove_marker(marker_id)


func _normalize_angle(angle: float) -> float:
	# Normalize to -180 to 180
	while angle > 180.0:
		angle -= 360.0
	while angle < -180.0:
		angle += 360.0
	return angle


func add_marker(
	marker_id: String,
	world_position: Vector3,
	marker_type: MarkerType = MarkerType.QUEST,
	icon: Texture2D = null,
	extra_data: Dictionary = {}
) -> void:
	# Prevent duplicates/orphaned nodes (Fixes trails if registered multiple times)
	if objective_markers.has(marker_id):
		remove_marker(marker_id)

	# Create marker visual
	var marker: Control
	if icon:
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.texture = icon
		tex_rect.custom_minimum_size = Vector2(16, 16)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		marker = tex_rect
	else:
		# Default triangle marker
		var polygon: Polygon2D = Polygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(0, 0), Vector2(8, 16), Vector2(-8, 16)])
		polygon.color = marker_colors.get(marker_type, Color.WHITE)
		marker = Control.new()
		marker.add_child(polygon)

	if markers_container:
		markers_container.add_child(marker)
		marker.position = Vector2(0, 0)  # Initialize position

	var data: Dictionary = {"node": marker, "position": world_position, "type": marker_type}

	# Merge extra data (like enemy_ref)
	data.merge(extra_data)

	objective_markers[marker_id] = data


func remove_marker(marker_id: String) -> void:
	if objective_markers.has(marker_id):
		var data: Dictionary = objective_markers[marker_id]
		if data["node"]:
			data["node"].queue_free()
		objective_markers.erase(marker_id)


func update_marker_position(marker_id: String, new_position: Vector3) -> void:
	if objective_markers.has(marker_id):
		objective_markers[marker_id]["position"] = new_position


func _update_marker_position(marker_id: String, player_rotation: float, player: Node3D) -> void:
	if not objective_markers.has(marker_id):
		return

	var data: Dictionary = objective_markers[marker_id]
	var marker: Control = data["node"]
	var target_pos: Vector3 = data["position"]

	if not player:
		marker.hide()
		return

	# Calculate angle from player to marker
	var to_target: Vector3 = target_pos - player.global_position
	var angle_to_target: float = rad_to_deg(atan2(to_target.x, to_target.z))

	# Relative to player facing
	var relative_angle: float = _normalize_angle(angle_to_target - player_rotation)

	# Position on compass
	var center_x: float = compass_width / 2.0
	var x_offset: float = relative_angle * (marker_spacing / 90.0)
	var x_pos: float = center_x + x_offset

	# Set BOTH x and y position (y at 0 for consistent bar placement)
	marker.position = Vector2(x_pos - 8, 0)  # Center marker at y=0

	if abs(x_offset) > compass_width / 2.0:
		marker.hide()
	else:
		marker.show()
		var fade: float = 1.0 - (abs(x_offset) / (compass_width / 2.0))
		marker.modulate.a = fade


func _find_local_player() -> Node3D:
	var local_id: int = multiplayer.get_unique_id()
	for node in get_tree().get_nodes_in_group("player"):
		if node.get_multiplayer_authority() == local_id:
			return node as Node3D
	return null
