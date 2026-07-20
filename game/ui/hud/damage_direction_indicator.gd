extends Control
class_name DamageDirectionIndicator

signal indicator_spawned(direction: Vector3)
signal all_indicators_cleared

@export_group("Indicator Settings")
@export var indicator_distance: float = 150.0
@export var indicator_size: Vector2 = Vector2(40, 60)
@export var fade_duration: float = 1.5
@export var max_indicators: int = 8
@export_group("Visual Settings")
@export var default_color: Color = Color(1.0, 0.0, 0.0, 0.8)
@export var critical_color: Color = Color(1.0, 1.0, 0.0, 0.9)
@export var use_gradient: bool = true
@export var pulse_on_critical: bool = true

var active_indicators: Array[Control] = []
var player: Node3D = null
var camera: Camera3D = null

# FIXED C-05: Store tween references for proper cleanup
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	# Find player
	call_deferred("_find_player")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _find_player() -> void:
	## Find player and camera references
	player = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	# Find camera
	camera = player.get_node_or_null("CameraController/Camera3D")
	if not camera:
		camera = player.get_node_or_null("Camera3D")

	# Connect to health component if available
	var health_comp: Node = player.get_node_or_null("HealthComponent")
	if health_comp and health_comp.has_signal("damage_taken"):
		health_comp.damage_taken.connect(_on_player_damaged)


func _on_player_damaged(amount: float, _damage_type: Variant, source: Variant) -> void:
	## Handle player taking damage
	if not source or not player:
		return

	var source_node: Node3D = source as Node3D
	if not source_node:
		return

	# Calculate direction from player to damage source
	var direction: Vector3 = source_node.global_position - player.global_position
	direction = direction.normalized()

	# Check if critical hit (simple check based on damage amount)
	var is_critical: bool = amount > 50.0

	# Show indicator
	show_damage_indicator(direction, is_critical)


func show_damage_indicator(world_direction: Vector3, is_critical: bool = false) -> void:
	## Show damage indicator in direction of damage source
	## Args:
	##   world_direction: Direction to damage source (world space)
	##   is_critical: If true, use critical color and effects

	# Clean up old indicators if at max
	if active_indicators.size() >= max_indicators:
		var oldest: Control = active_indicators.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	# Get player's forward direction (camera facing)
	var camera_forward: Vector3 = Vector3.FORWARD
	if camera:
		camera_forward = -camera.global_transform.basis.z
	elif player:
		camera_forward = -player.global_transform.basis.z

	# Calculate angle from camera forward to damage direction
	var flat_forward: Vector2 = Vector2(camera_forward.x, camera_forward.z).normalized()
	var flat_damage: Vector2 = Vector2(world_direction.x, world_direction.z).normalized()

	var angle: float = flat_forward.angle_to(flat_damage)

	# Create indicator
	var indicator: Control = _create_indicator(angle, is_critical)
	add_child(indicator)
	active_indicators.append(indicator)

	# Animate indicator
	_animate_indicator(indicator, is_critical)

	indicator_spawned.emit(world_direction)


func _create_indicator(angle: float, is_critical: bool) -> Control:
	## Create damage indicator visual
	var indicator: Control = Control.new()
	indicator.name = "DamageIndicator"
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Position indicator around screen center
	var viewport_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = viewport_size / 2.0

	# Calculate position based on angle
	var offset: Vector2 = Vector2(sin(angle), -cos(angle)) * indicator_distance
	indicator.position = center + offset

	if use_gradient:
		# Create gradient arrow
		var texture_rect: TextureRect = TextureRect.new()
		texture_rect.name = "GradientArrow"
		texture_rect.size = indicator_size
		texture_rect.pivot_offset = indicator_size / 2.0
		texture_rect.position = -indicator_size / 2.0
		texture_rect.rotation = angle
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Create gradient texture
		var color: Color = critical_color if is_critical else default_color
		var gradient_texture: GradientTexture2D = GradientTexture2D.new()
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, color)
		gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
		gradient_texture.gradient = gradient
		gradient_texture.fill_from = Vector2(0.5, 0.0)
		gradient_texture.fill_to = Vector2(0.5, 1.0)
		gradient_texture.width = int(indicator_size.x)
		gradient_texture.height = int(indicator_size.y)

		texture_rect.texture = gradient_texture
		indicator.add_child(texture_rect)
	else:
		# Create simple colored arrow
		var arrow: ColorRect = ColorRect.new()
		arrow.name = "Arrow"
		arrow.size = indicator_size
		arrow.pivot_offset = indicator_size / 2.0
		arrow.position = -indicator_size / 2.0
		arrow.color = critical_color if is_critical else default_color
		arrow.rotation = angle

		indicator.add_child(arrow)

	return indicator


func _animate_indicator(indicator: Control, is_critical: bool) -> void:
	## Animate indicator fade out
	var tween: Tween = create_tween()
	tween.set_parallel(true)

	# FIXED C-05: Store tween reference for cleanup
	_active_tweens.append(tween)

	# Fade out
	tween.tween_property(indicator, "modulate:a", 0.0, fade_duration)

	# Pulse effect for critical hits
	if is_critical and pulse_on_critical:
		var scale_up: float = fade_duration * 0.3
		var scale_down: float = fade_duration * 0.7
		tween.tween_property(indicator, "scale", Vector2(1.3, 1.3), scale_up)
		tween.tween_property(indicator, "scale", Vector2(0.8, 0.8), scale_down).set_delay(scale_up)
	else:
		# Slight scale change for normal hits
		tween.tween_property(indicator, "scale", Vector2(0.9, 0.9), fade_duration)

	# FIXED C-05: Use named method instead of lambda
	tween.finished.connect(_on_indicator_tween_finished.bind(indicator))


func _on_indicator_tween_finished(indicator: Control) -> void:
	## Called when indicator fade tween completes
	_cleanup_indicator(indicator)


func _exit_tree() -> void:
	## FIXED C-05: Cleanup tween connections to prevent memory leaks
	for tween in _active_tweens:
		if is_instance_valid(tween) and tween.finished.is_connected(_on_indicator_tween_finished):
			tween.finished.disconnect(_on_indicator_tween_finished)
	_active_tweens.clear()


func _cleanup_indicator(indicator: Control) -> void:
	## Remove and free indicator
	if indicator in active_indicators:
		active_indicators.erase(indicator)

	if is_instance_valid(indicator):
		indicator.queue_free()


func clear_all_indicators() -> void:
	## Clear all active indicators
	for indicator: Control in active_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()

	active_indicators.clear()
	all_indicators_cleared.emit()


func set_enabled(enabled: bool) -> void:
	## Enable or disable damage indicators
	visible = enabled
	if not enabled:
		clear_all_indicators()


func get_active_count() -> int:
	## Get count of active indicators
	return active_indicators.size()


# =============================================================================
# MANUAL TRIGGER API
# =============================================================================


func show_damage_from_position(source_pos: Vector3) -> void:
	## Show damage indicator from a world position
	if not player:
		return

	var direction: Vector3 = (source_pos - player.global_position).normalized()
	show_damage_indicator(direction, false)


func show_critical_damage_from_position(source_pos: Vector3) -> void:
	## Show critical damage indicator from a world position
	if not player:
		return

	var direction: Vector3 = (source_pos - player.global_position).normalized()
	show_damage_indicator(direction, true)


func show_damage_from_angle(screen_angle: float, is_critical: bool = false) -> void:
	## Show damage indicator at a specific screen angle (radians)
	## 0 = top, PI/2 = right, PI = bottom, -PI/2 = left
	var indicator: Control = _create_indicator(screen_angle, is_critical)
	add_child(indicator)
	active_indicators.append(indicator)
	_animate_indicator(indicator, is_critical)
