extends Control
class_name Minimap

@export var map_size: float = 150.0  # Size in pixels
@export var zoom_level: float = 1.0  # World units per pixel
@export var min_zoom: float = 0.5
@export var max_zoom: float = 3.0
@export var rotation_smoothing: float = 8.0
@export var show_player_cone: bool = true
@export var map_texture_path: String = ""

var capture_center: Vector3 = Vector3.ZERO
var capture_size: float = 200.0
var tracked_entities: Dictionary = {}
var current_rotation: float = 0.0
var icon_colors: Dictionary = {
	"player": Color.CYAN,
	"enemy": Color.RED,
	"ally": Color.GREEN,
	"item": Color.YELLOW,
}

@onready var map_texture: TextureRect = $CircleMask/MapContainer/MapTexture
@onready var capture_viewport: SubViewport = $CaptureViewport
@onready var capture_camera: Camera3D = $CaptureViewport/CaptureCamera
@onready var map_container: Control = $CircleMask/MapContainer
@onready var icons_container: Control = $CircleMask/MapContainer/Icons
@onready var player_icon: Control = $CircleMask/MapContainer/PlayerIcon
@onready var circle_mask: Control = $CircleMask


func _ready() -> void:
	# Load configuration
	_load_config()
	_update_visibility()

	# Prevent blocking mouse input
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Listen for config changes
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc:
		ui_svc.hud_settings_changed.connect(_on_hud_settings_changed)
		ui_svc.theme_changed.connect(_on_theme_changed)

	# Setup circular border
	_setup_circular_border()

	# Setup circular clip mask
	_setup_circular_clip()

	# Setup player icon
	if player_icon:
		_setup_player_icon()

	# Start tracking
	set_process(true)

	# Listen for enemy death for immediate cleanup
	var entity_service: Node = GameManager.get_core_system("entities")
	if entity_service:
		entity_service.enemy_unregistered.connect(_on_enemy_unregistered)

	# Try to load static texture first, fallback to capture
	if not _try_load_static_map():
		call_deferred("_capture_level_map")


func _setup_circular_border() -> void:
	# Create circular border using StyleBoxFlat
	var border_panel: Panel = get_node_or_null("Border")
	if border_panel:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2, 0.9)

		var ui_svc: Node = GameManager.get_core_system("ui")
		if ui_svc:
			style.border_color = ui_svc.get_theme_color("secondary_color", Color(0.4, 0.5, 0.6))
		else:
			style.border_color = Color(0.4, 0.5, 0.6, 0.8)

		style.set_border_width_all(2)
		# Calculate corner radius based on panel size
		var radius: int = int(min(border_panel.size.x, border_panel.size.y) / 2.0)
		style.set_corner_radius_all(radius)
		border_panel.add_theme_stylebox_override("panel", style)


func _setup_circular_clip() -> void:
	# Apply circular style to mask panel for visual consistency
	if circle_mask:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.12, 0.15, 1.0)
		# Calculate corner radius for circular appearance
		var radius: int = int(min(circle_mask.size.x, circle_mask.size.y) / 2.0)
		style.set_corner_radius_all(radius)
		circle_mask.add_theme_stylebox_override("panel", style)

		# Apply a clip shader for true circular masking
		var shader_code: String = """
shader_type canvas_item;
void fragment() {
	vec2 center = vec2(0.5, 0.5);
	float dist = distance(UV, center);
	float radius = 0.5;
	float edge = 0.01;
	float a = smoothstep(radius, radius - edge, dist);
	COLOR.a *= a;
}
"""
		var shader := Shader.new()
		shader.code = shader_code
		var shader_mat := ShaderMaterial.new()
		shader_mat.shader = shader
		circle_mask.material = shader_mat

		# CRITICAL: Ensure we actually clip the children using the mask
		# CLIP_CHILDREN_ONLY = 1
		circle_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY


func _on_config_reloaded() -> void:
	_load_config()


func _on_config_loaded(_data: Dictionary) -> void:
	_load_config()


func _on_enemy_unregistered(enemy: Node) -> void:
	if enemy is Node3D:
		untrack_entity(enemy)


func _load_config() -> void:
	var ui_svc: Node = GameManager.get_core_system("ui")
	if not ui_svc:
		return

	var config: Dictionary = ui_svc.get_element_config("minimap")

	# Apply scale
	var global_scale: float = ui_svc.get_hud_scale()
	var local_scale: float = config.get("scale", 1.0)
	scale = Vector2.ONE * global_scale * local_scale

	# Apply position offset - use offset properties, not position (preserves anchors)
	var offset: Array = config.get("position_offset", [0, 0])
	if offset.size() >= 2 and (offset[0] != 0 or offset[1] != 0):
		# Adjust the anchor offsets rather than position
		# This preserves the top-right anchor behavior
		offset_left += offset[0]
		offset_right += offset[0]
		offset_top += offset[1]
		offset_bottom += offset[1]

	_update_visibility()


func _on_hud_settings_changed() -> void:
	_load_config()


func _on_theme_changed() -> void:
	# Refresh icon colors
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc:
		var accent: Color = ui_svc.get_theme_color("accent_color", Color.CYAN)
		var danger: Color = ui_svc.get_theme_color("danger_color", Color.RED)
		icon_colors["ally"] = accent
		icon_colors["enemy"] = danger

		# Rebuild icons?
		clear_tracked()


func _update_visibility() -> void:
	var ui_svc: Node = GameManager.get_core_system("ui")
	if ui_svc:
		visible = ui_svc.is_hud_element_visible("minimap")
	else:
		# Default to visible if UI service not available
		visible = true


func _try_load_static_map() -> bool:
	if map_texture_path.is_empty():
		return false

	if not ResourceLoader.exists(map_texture_path):
		push_error("[Minimap] Map texture not found: %s" % map_texture_path)
		return false

	var tex: Texture2D = load(map_texture_path)
	if tex and map_texture:
		map_texture.texture = tex
		# Assume static maps cover the defined capture_size area
		# Users must configure capture_size to match the world width the image represents
		_update_map_texture_transform()
		return true

	return false


func _capture_level_map() -> void:
	# Dynamic capture fallback
	# ... (setup camera) ...
	if capture_camera:
		capture_camera.size = capture_size
		capture_camera.global_position = capture_center + Vector3(0, 100, 0)
		# Top-down (-Z forward for camera looking down at -Y?)
		capture_camera.look_at(capture_center, Vector3.FORWARD)
		# Wait, look_at(center, UP) makes it look at center.
		# If center is (0,0,0) and pos is (0,100,0).
		# We want Top of screen to be North (-Z).
		# Standard look_at(target, UP) usually aligns -Z to target.
		# If we look DOWN (-Y), then UP vector defines rotation.
		# To make Top-screen be -Z (North), we should use Vector3.FORWARD (-Z) as up?
		# Or simplify: Rotate -90 on X.
		capture_camera.rotation_degrees = Vector3(-90, 0, 0)
		capture_camera.projection = Camera3D.PROJECTION_ORTHOGONAL

	# ... (render) ...
	if capture_viewport:
		capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await get_tree().process_frame
		await get_tree().process_frame

		var tex: Texture2D = capture_viewport.get_texture()
		if map_texture:
			map_texture.texture = tex
			_update_map_texture_transform()


func _update_map_texture_transform() -> void:
	if not map_texture:
		return

	# Reset scale first
	map_texture.scale = Vector2.ONE

	# Calculate scale factor
	# Viewport pixels / World Units = Resolution density (pixels/unit)
	var _resolution_density: float = capture_viewport.size.x / capture_size

	# We want displayed size = zoom_level * world_units
	# But we are transforming the texture itself

	# Actually, simpler approach:
	# MapTexture is large. We scale it so that 1 World Unit = 'zoom_level' Pixels
	# Original Width (pixels) = 2048
	# Represented Width (units) = 300
	# Target Width (pixels) = 300 * zoom_level

	var target_pixel_width: float = capture_size * zoom_level
	var scale_factor: float = target_pixel_width / capture_viewport.size.x

	if capture_viewport and capture_viewport.size.x > 0:
		scale_factor = target_pixel_width / capture_viewport.size.x
		map_texture.scale = Vector2(scale_factor, scale_factor)


func _process(delta: float) -> void:
	var player: Node3D = _find_local_player()
	if not player:
		return

	# Smooth rotation
	var target_rot: float = -player.global_rotation.y
	current_rotation = lerp_angle(current_rotation, target_rot, delta * rotation_smoothing)

	# Rotate map container (holds icons and map texture)
	if map_container:
		map_container.rotation = current_rotation

	# Keep player icon upright (counter-rotate)
	if player_icon:
		player_icon.rotation = -current_rotation

	# Update Map Texture Position (Counter-movement)
	if map_texture:
		_update_map_texture_transform()  # Update scale if zoom changed

		# Calculate player offset from capture center
		var offset_from_center: Vector3 = player.global_position - capture_center

		# Convert to map pixels
		# 1 unit = zoom_level pixels
		var pixel_offset: Vector2 = Vector2(offset_from_center.x, offset_from_center.z) * zoom_level

		# Map Texture needs to move OPPOSITE to player to keep player centered
		# Texture is centered at (0,0) of container (via pivot)
		# So if player moves right (+X), texture moves left (-X)
		map_texture.position = (
			(map_container.size / 2.0) - pixel_offset - (map_texture.size * map_texture.scale / 2.0)
		)

		# Counter-rotate the texture ITSELF?
		# No, 'map_container' rotates everything inside it (icons + texture) around the center.
		# This is correct for a "rotating map" style.
		# The player icon stays static in screen center (visually), map rotates around it.

	# Update tracked entities
	_update_entity_icons(player)

	# Auto-track nearby entities
	_auto_track_entities()


func _input(event: InputEvent) -> void:
	# Zoom with mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(zoom_level - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(zoom_level + 0.5)


func _setup_player_icon() -> void:
	# Create player arrow
	var arrow: Polygon2D = Polygon2D.new()
	arrow.polygon = PackedVector2Array(
		[Vector2(0, -8), Vector2(6, 8), Vector2(0, 4), Vector2(-6, 8)]
	)
	arrow.color = icon_colors["player"]
	player_icon.add_child(arrow)

	# Add view cone if enabled
	if show_player_cone:
		var cone: Polygon2D = Polygon2D.new()
		cone.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-15, -30), Vector2(15, -30)])
		cone.color = Color(1, 1, 1, 0.15)
		player_icon.add_child(cone)
		cone.z_index = -1


func track_entity(entity: Node3D, entity_type: String = "enemy") -> void:
	var id: int = entity.get_instance_id()
	if tracked_entities.has(id):
		return

	# Create icon
	var icon: Control = Control.new()
	icon.custom_minimum_size = Vector2(8, 8)

	var dot: Polygon2D = Polygon2D.new()
	dot.polygon = _create_circle_polygon(4, 8)

	var col: Color = icon_colors.get(entity_type, Color.WHITE)
	# Check for theme overrides if needed, but icon_colors should be updated by theme change
	dot.color = col

	icon.add_child(dot)

	if icons_container:
		icons_container.add_child(icon)

	tracked_entities[id] = {"icon": icon, "type": entity_type, "entity": entity}


func untrack_entity(entity: Node3D) -> void:
	var id: int = entity.get_instance_id()
	if tracked_entities.has(id):
		var data: Dictionary = tracked_entities[id]
		if data["icon"]:
			data["icon"].queue_free()
		tracked_entities.erase(id)


func _update_entity_icons(player: Node3D) -> void:
	var player_pos: Vector3 = player.global_position
	var center: Vector2 = map_container.size / 2.0  # Container center

	# Use mask size for clamping, not map size (incase config changed)
	var circle_radius: float = (map_size - 10) / 2.0 - 4
	if circle_mask:
		circle_radius = min(circle_mask.size.x, circle_mask.size.y) / 2.0 - 4

	var ids_to_remove: Array[int] = []
	var track_radius: float = map_size * zoom_level * 1.5  # Slightly larger than visual radius

	for id: int in tracked_entities:
		var data: Dictionary = tracked_entities[id]
		var entity_ref: Variant = data.get("entity")

		# Check validity BEFORE casting to avoid 'freed object' error
		if entity_ref == null or not is_instance_valid(entity_ref):
			ids_to_remove.append(id)
			continue

		var entity: Node3D = entity_ref as Node3D
		if entity == null:
			ids_to_remove.append(id)
			continue

		# Distance check - untrack if too far away
		var relative_world: Vector3 = entity.global_position - player_pos
		if relative_world.length() > track_radius:
			ids_to_remove.append(id)
			continue

		var icon: Control = data["icon"]

		# Convert to map pixels (before rotation)
		var map_offset_unrotated: Vector2 = Vector2(relative_world.x, relative_world.z) * zoom_level
		var icon_pos: Vector2 = center + map_offset_unrotated - Vector2(4, 4)

		# Clamp to circle logic
		var vec_from_center: Vector2 = icon_pos - center + Vector2(4, 4)
		var dist: float = vec_from_center.length()

		if dist > circle_radius:
			var clamped_vec: Vector2 = vec_from_center.normalized() * circle_radius
			icon.position = center + clamped_vec - Vector2(4, 4)
			icon.modulate.a = 0.4
		else:
			icon.position = icon_pos
			icon.modulate.a = 1.0

	# Cleanup untracked
	for id: int in ids_to_remove:
		var data: Dictionary = tracked_entities[id]
		if data["icon"] and is_instance_valid(data["icon"]):
			data["icon"].queue_free()
		tracked_entities.erase(id)


func _auto_track_entities() -> void:
	var player: Node3D = _find_local_player()
	if not player:
		return

	var track_radius: float = map_size * zoom_level

	# Track enemies (use GameManager.get_core_system("entities") for fast lookup)
	for enemy: Node in GameManager.get_core_system("entities").get_all_enemies():
		if enemy is Node3D:
			var dist: float = enemy.global_position.distance_to(player.global_position)
			if dist < track_radius:
				track_entity(enemy, "enemy")

	# Track items
	for item in get_tree().get_nodes_in_group("items"):
		if item is Node3D:
			var dist: float = item.global_position.distance_to(player.global_position)
			if dist < track_radius:
				track_entity(item, "item")

	# Track other players (use GameManager.get_core_system("entities") for fast lookup)
	for other_player: Node in GameManager.get_core_system("entities").get_all_players():
		if other_player != player and other_player is Node3D:
			track_entity(other_player, "ally")


func _create_circle_polygon(radius: float, segments: int = 8) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in segments:
		var angle: float = (float(i) / float(segments)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


func _find_local_player() -> Node3D:
	var local_id: int = multiplayer.get_unique_id()
	# Use GameManager.get_core_system("entities") for fast O(1) lookup
	var entity_svc: Node = GameManager.get_core_system("entities")
	if entity_svc and entity_svc.has_method("get_all_players"):
		for node: Node in entity_svc.get_all_players():
			if node and is_instance_valid(node) and node.get_multiplayer_authority() == local_id:
				return node as Node3D

	# Fallback: Search in players group
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node and is_instance_valid(node) and node.get_multiplayer_authority() == local_id:
			return node as Node3D
	return null


func set_zoom(new_zoom: float) -> void:
	zoom_level = clampf(new_zoom, min_zoom, max_zoom)


func clear_tracked() -> void:
	for id: int in tracked_entities:
		var data: Dictionary = tracked_entities[id]
		if data["icon"]:
			data["icon"].queue_free()
	tracked_entities.clear()
