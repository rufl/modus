class_name StatusEffectsHUD
extends Control

const ICON_SIZE := Vector2(40, 40)
const EFFECT_SPACING := 8
const EFFECT_ICONS := {
	StatusEffect.EffectType.POISON: "☠",
	StatusEffect.EffectType.BURN: "🔥",
	StatusEffect.EffectType.SLOW: "↓",
	StatusEffect.EffectType.STUN: "⚡",
	StatusEffect.EffectType.FREEZE: "❄",
	StatusEffect.EffectType.BLEED: "💉",
	StatusEffect.EffectType.DROWNING: "💧",
	StatusEffect.EffectType.CUSTOM: "✦",
}
const EFFECT_COLORS := {
	StatusEffect.EffectType.POISON: Color(0.3, 1.0, 0.3),
	StatusEffect.EffectType.BURN: Color(1.0, 0.5, 0.0),
	StatusEffect.EffectType.SLOW: Color(0.5, 0.5, 1.0),
	StatusEffect.EffectType.STUN: Color(1.0, 1.0, 0.0),
	StatusEffect.EffectType.FREEZE: Color(0.5, 0.8, 1.0),
	StatusEffect.EffectType.BLEED: Color(1.0, 0.3, 0.3),
	StatusEffect.EffectType.DROWNING: Color(0.3, 0.5, 1.0),
	StatusEffect.EffectType.CUSTOM: Color(0.8, 0.8, 0.8),
}

@onready var effect_container: HBoxContainer = $EffectContainer

var _effect_displays: Dictionary = {}  # effect_name -> Control node
var _status_manager: StatusEffectManager = null


func _ready() -> void:
	# Create container if not exists
	if not has_node("EffectContainer"):
		effect_container = HBoxContainer.new()
		effect_container.name = "EffectContainer"
		effect_container.add_theme_constant_override("separation", EFFECT_SPACING)
		add_child(effect_container)

	# Defer player connection
	call_deferred("_connect_to_player")


func _connect_to_player() -> void:
	# Try to find local player
	var local_player: Node = null
	for player in get_tree().get_nodes_in_group("player"):
		if player.is_multiplayer_authority():
			local_player = player
			break

	if local_player:
		_status_manager = local_player.get_node_or_null("StatusEffectManager")
		if _status_manager:
			_status_manager.effect_applied.connect(_on_effect_applied)
			_status_manager.effect_removed.connect(_on_effect_removed)
			_status_manager.effect_stacked.connect(_on_effect_stacked)

			# Show any existing effects
			for effect: StatusEffect in _status_manager.active_effects:
				_create_effect_display(effect)
			return

		push_warning("[StatusEffectsHUD] StatusEffectManager missing. Retrying...")

	# Retry after delay if not found
	await get_tree().create_timer(1.0).timeout
	_connect_to_player()


func _on_effect_applied(effect: StatusEffect) -> void:
	_create_effect_display(effect)


func _on_effect_removed(effect_name: String) -> void:
	if _effect_displays.has(effect_name):
		var display: Control = _effect_displays[effect_name]
		display.queue_free()
		_effect_displays.erase(effect_name)


func _on_effect_stacked(effect_name: String, new_stacks: int) -> void:
	if _effect_displays.has(effect_name):
		var display: Control = _effect_displays[effect_name]
		var stack_label: Label = display.get_node_or_null("StackLabel")
		if stack_label:
			stack_label.text = "x%d" % new_stacks
			stack_label.visible = new_stacks > 1


func _create_effect_display(effect: StatusEffect) -> void:
	if _effect_displays.has(effect.effect_name):
		return  # Already displayed

	var display := PanelContainer.new()
	display.name = "Effect_%s" % effect.effect_name
	display.custom_minimum_size = ICON_SIZE

	# Style the panel with effect color
	var style := StyleBoxFlat.new()
	var color: Color = EFFECT_COLORS.get(effect.effect_type, Color.GRAY)
	style.bg_color = Color(color.r, color.g, color.b, 0.3)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	display.add_theme_stylebox_override("panel", style)

	# Main container
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	display.add_child(vbox)

	# Icon
	var icon_label := Label.new()
	icon_label.name = "IconLabel"
	icon_label.text = EFFECT_ICONS.get(effect.effect_type, "✦")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(icon_label)

	# Timer bar
	var timer_bar := ProgressBar.new()
	timer_bar.name = "TimerBar"
	timer_bar.custom_minimum_size = Vector2(ICON_SIZE.x - 8, 4)
	timer_bar.min_value = 0
	timer_bar.max_value = effect.duration
	timer_bar.value = effect.remaining_duration
	timer_bar.show_percentage = false

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	timer_bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	timer_bar.add_theme_stylebox_override("background", bg_style)
	vbox.add_child(timer_bar)

	# Stack label (overlay)
	var stack_label := Label.new()
	stack_label.name = "StackLabel"
	stack_label.text = "x%d" % effect.current_stacks
	stack_label.visible = effect.current_stacks > 1
	stack_label.add_theme_font_size_override("font_size", 10)
	stack_label.add_theme_color_override("font_color", Color.WHITE)
	stack_label.position = Vector2(ICON_SIZE.x - 16, 0)
	display.add_child(stack_label)

	effect_container.add_child(display)
	_effect_displays[effect.effect_name] = display

	# Store effect reference for timer updates
	display.set_meta("effect", effect)


func _process(_delta: float) -> void:
	# Update timer bars
	for effect_name: String in _effect_displays:
		var display: Control = _effect_displays[effect_name]
		if not is_instance_valid(display):
			continue

		var effect: StatusEffect = display.get_meta("effect", null)
		if not effect:
			continue

		var timer_bar: ProgressBar = display.get_node_or_null("VBoxContainer/TimerBar")
		if timer_bar:
			timer_bar.value = effect.remaining_duration
