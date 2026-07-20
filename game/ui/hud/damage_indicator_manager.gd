extends Control

const CONFIG_PATH := "res://game/config/gameplay/ui.json5"

var fade_time: float = 3.0
var indicator_radius: float = 0.42  # Percentage of screen half-size
var indicator_color: Color = Color(0.9, 0.15, 0.1, 0.7)
var indicator_size: float = 48.0
var pulse_on_hit: bool = true

@onready var player: Node = _find_player()

var _current_attacker: Node = null
var _attacker_id: int = -1
var _last_damage_time: float = 0.0
var _indicator_alpha: float = 0.0
var _arrow_polygon: Polygon2D
var _glow_polygon: Polygon2D


func _find_player() -> Node:
	var p: Node = get_parent()
	if p and p.name == "HUDLayer":
		return p.get_parent()
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_config()
	_create_indicator()

	if not player:
		return

	if player.has_node("HealthComponent"):
		var health_comp: Node = player.get_node("HealthComponent")
		if health_comp.has_signal("damage_received"):
			health_comp.damage_received.connect(_on_damage_taken)


func _load_config() -> void:
	var config_system: Node = GameManager.get_core_system("config")
	if not config_system or not config_system.has_method("get_value"):
		return

	var config_var: Variant = config_system.get_value("visuals.hud.damage_indicator", {})
	if not config_var is Dictionary:
		return

	var config: Dictionary = config_var
	if config.is_empty():
		return

	fade_time = config.get("fade_time", fade_time)
	indicator_radius = config.get("radius", indicator_radius)
	indicator_size = config.get("size", indicator_size)
	pulse_on_hit = config.get("pulse_on_hit", pulse_on_hit)

	var c: Dictionary = config.get("color", {})
	if c.has("r") and c.has("g") and c.has("b"):
		indicator_color = Color(c.r, c.g, c.b, c.get("a", 0.7))


func _create_indicator() -> void:
	# Glow/shadow layer (slightly larger, darker)
	_glow_polygon = Polygon2D.new()
	_glow_polygon.color = Color(0.0, 0.0, 0.0, 0.3)
	_glow_polygon.polygon = _create_curved_arrow_shape(indicator_size * 1.15)
	_glow_polygon.visible = false
	_glow_polygon.z_index = 24
	add_child(_glow_polygon)

	# Main arrow
	_arrow_polygon = Polygon2D.new()
	_arrow_polygon.color = indicator_color
	_arrow_polygon.polygon = _create_curved_arrow_shape(indicator_size)
	_arrow_polygon.visible = false
	_arrow_polygon.z_index = 25
	add_child(_arrow_polygon)


func _create_curved_arrow_shape(arrow_size: float) -> PackedVector2Array:
	# Curved chevron/arrow shape pointing outward (like Doom Eternal)
	# Arrow points "up" by default, rotated to face attacker direction
	var points: PackedVector2Array = PackedVector2Array()
	var w: float = arrow_size * 0.5  # Half width
	var h: float = arrow_size * 0.8  # Height
	var curve: float = arrow_size * 0.12  # Curve amount

	# Outer edge (curved chevron shape)
	# Left arm
	points.append(Vector2(-w, h * 0.3))  # Left bottom
	points.append(Vector2(-w + curve, 0))  # Left curve point
	points.append(Vector2(-w * 0.3, -h * 0.4))  # Left top inner

	# Tip
	points.append(Vector2(0, -h * 0.5))  # Top point

	# Right arm
	points.append(Vector2(w * 0.3, -h * 0.4))  # Right top inner
	points.append(Vector2(w - curve, 0))  # Right curve point
	points.append(Vector2(w, h * 0.3))  # Right bottom

	# Inner cutout (makes it a chevron, not solid triangle)
	points.append(Vector2(w * 0.5, h * 0.15))
	points.append(Vector2(0, -h * 0.15))  # Inner tip
	points.append(Vector2(-w * 0.5, h * 0.15))

	return points


func _process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	# Check if attacker is still valid
	if _current_attacker and not is_instance_valid(_current_attacker):
		_current_attacker = null
		_attacker_id = -1

	# Check if attacker is dead
	if _current_attacker:
		if _current_attacker.has_method("is_dead") and _current_attacker.is_dead():
			_current_attacker = null
			_attacker_id = -1
		elif _current_attacker.has_node("HealthComponent"):
			var hc: Node = _current_attacker.get_node("HealthComponent")
			if "current_health" in hc and hc.current_health <= 0:
				_current_attacker = null
				_attacker_id = -1

	# Fade out over time
	var time_since_hit: float = Time.get_ticks_msec() / 1000.0 - _last_damage_time
	if time_since_hit < fade_time and _current_attacker:
		var fade_start: float = fade_time * 0.5
		if time_since_hit > fade_start:
			var fade_progress: float = (time_since_hit - fade_start) / (fade_time - fade_start)
			_indicator_alpha = lerpf(indicator_color.a, 0.0, fade_progress)
		else:
			_indicator_alpha = indicator_color.a
	else:
		_indicator_alpha = maxf(0.0, _indicator_alpha - delta * 2.0)

	# Update visibility
	var should_show: bool = _indicator_alpha > 0.01 and _current_attacker != null
	_arrow_polygon.visible = should_show
	_glow_polygon.visible = should_show

	if not should_show:
		return

	# Calculate direction to attacker
	var attacker_pos: Vector3 = _current_attacker.global_position
	var player_pos: Vector3 = player.global_position
	var dir_to_attacker: Vector3 = (attacker_pos - player_pos).normalized()

	# Get camera forward (horizontal only)
	var cam: Camera3D = player.get_node_or_null("Camera3D")
	if not cam:
		return

	var cam_forward: Vector3 = -cam.global_transform.basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()

	var cam_right: Vector3 = cam.global_transform.basis.x
	cam_right.y = 0
	cam_right = cam_right.normalized()

	# Calculate angle (0 = forward, positive = right)
	var dir_flat: Vector3 = dir_to_attacker
	dir_flat.y = 0
	dir_flat = dir_flat.normalized()

	var forward_dot: float = cam_forward.dot(dir_flat)
	var right_dot: float = cam_right.dot(dir_flat)
	var angle: float = atan2(right_dot, forward_dot)

	# Position indicator at screen edge
	var screen_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = screen_size / 2.0
	var radius: float = minf(screen_size.x, screen_size.y) * indicator_radius

	var indicator_pos: Vector2 = center + Vector2(sin(angle), -cos(angle)) * radius

	# Update arrow position and rotation
	_arrow_polygon.position = indicator_pos
	_arrow_polygon.rotation = angle  # Point toward attacker

	_glow_polygon.position = indicator_pos + Vector2(2, 2)  # Slight offset for shadow
	_glow_polygon.rotation = angle

	# Update alpha
	var final_color: Color = indicator_color
	final_color.a = _indicator_alpha
	_arrow_polygon.color = final_color

	var glow_color: Color = Color(0.0, 0.0, 0.0, _indicator_alpha * 0.4)
	_glow_polygon.color = glow_color


func _on_damage_taken(amount: float, source_id: int, _type: int) -> void:
	var config_system: Node = GameManager.get_core_system("config")
	if not config_system or not config_system.has_method("is_feature_enabled"):
		return
	if not config_system.is_feature_enabled("damage_indicator"):
		return
	if amount <= 0:
		return

	_attacker_id = source_id
	_last_damage_time = Time.get_ticks_msec() / 1000.0

	# Find attacker node
	_current_attacker = _find_node_by_id(source_id)

	# Pulse effect on hit
	if pulse_on_hit and _arrow_polygon:
		_do_pulse()


func _find_node_by_id(node_id: int) -> Node:
	if node_id <= 0:
		return null

	var tree := get_tree()
	if not tree:
		return null

	# Check enemies group first
	for enemy in tree.get_nodes_in_group("enemies"):
		if enemy.name.to_int() == node_id or str(enemy.get_instance_id()) == str(node_id):
			return enemy

	# Check players group
	for p in tree.get_nodes_in_group("players"):
		if p.name.to_int() == node_id:
			return p

	return null


func _do_pulse() -> void:
	if not _arrow_polygon:
		return

	# Quick scale pulse
	var tween: Tween = create_tween()
	tween.tween_property(_arrow_polygon, "scale", Vector2(1.3, 1.3), 0.08)
	tween.tween_property(_arrow_polygon, "scale", Vector2(1.0, 1.0), 0.15)

	if _glow_polygon:
		var glow_tween: Tween = create_tween()
		glow_tween.tween_property(_glow_polygon, "scale", Vector2(1.3, 1.3), 0.08)
		glow_tween.tween_property(_glow_polygon, "scale", Vector2(1.0, 1.0), 0.15)


# Legacy API compatibility


func show_damage_from(source_pos: Vector3, _player_pos: Vector3, _player_rot_y: float) -> void:
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	# Try to find attacker near source_pos
	if not _current_attacker:
		_current_attacker = _find_nearest_enemy(source_pos)
	if pulse_on_hit:
		_do_pulse()


func show_indicator(_world_dir: Vector3) -> void:
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	if pulse_on_hit:
		_do_pulse()


func _find_nearest_enemy(pos: Vector3) -> Node:
	var tree := get_tree()
	if not tree:
		return null

	var closest: Node = null
	var closest_dist: float = 100.0

	for enemy in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		var dist: float = enemy.global_position.distance_to(pos)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy

	return closest
