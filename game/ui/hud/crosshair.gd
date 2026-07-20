extends Control
class_name DynamicCrosshair

@export var default_color := Color.WHITE
@export var target_color := Color.RED
@export var line_length := 8.0
@export var line_thickness := 2.0
@export var gap := 4.0
@export var dot_size := 2.0
@export var show_dot := true
@export var expansion_per_shot := 15.0
@export var recovery_speed := 4.0

var current_spread: float = 0.0
var target_acquired: bool = false


func _ready() -> void:
	# Center in viewport
	set_anchors_preset(PRESET_CENTER)
	mouse_filter = MOUSE_FILTER_IGNORE

	# Listen to events (with null checks)
	var events: Node = GameManager.get_core_system("events")
	if events and events.has_method("subscribe"):
		events.subscribe("weapon_fired", _on_fire)

	if GameManager.has_method("subscribe"):
		GameManager.subscribe("crosshair_target_changed", _on_target_event)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE ===
	var events: Node = GameManager.get_core_system("events")
	if events and events.has_method("unsubscribe"):
		events.unsubscribe("weapon_fired", _on_fire)

	if GameManager.has_method("unsubscribe"):
		GameManager.unsubscribe("crosshair_target_changed", _on_target_event)


func _on_target_event(data: Dictionary) -> void:
	_on_target_changed(data.get("active", false), data.get("is_enemy", false))


func _process(delta: float) -> void:
	# Recover spread
	current_spread = lerp(current_spread, 0.0, recovery_speed * delta)

	# Add movement spread if player's moving (walk up hierarchy to find player)
	var player: Node = _find_player()
	if player and "velocity" in player:
		var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		if speed > 1.0:
			current_spread = max(current_spread, speed * 1.5)

	queue_redraw()


func _draw() -> void:
	var center := size / 2
	var color := target_color if target_acquired else default_color
	var spread := gap + current_spread

	# Center dot
	if show_dot:
		draw_circle(center, dot_size, color)

	# Top line
	draw_line(
		center + Vector2(0, -spread),
		center + Vector2(0, -spread - line_length),
		color,
		line_thickness,
		true
	)

	# Bottom line
	draw_line(
		center + Vector2(0, spread),
		center + Vector2(0, spread + line_length),
		color,
		line_thickness,
		true
	)

	# Left line
	draw_line(
		center + Vector2(-spread, 0),
		center + Vector2(-spread - line_length, 0),
		color,
		line_thickness,
		true
	)

	# Right line
	draw_line(
		center + Vector2(spread, 0),
		center + Vector2(spread + line_length, 0),
		color,
		line_thickness,
		true
	)


func _on_fire(_data: Dictionary) -> void:
	current_spread += expansion_per_shot
	current_spread = min(current_spread, 50.0)


func _on_target_changed(has_target: bool, is_enemy: bool) -> void:
	target_acquired = has_target and is_enemy


func _find_player() -> Node:
	var node: Node = get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
