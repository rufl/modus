class_name MovementHUD
extends Control

@export var show_speed: bool = true
@export var show_movement_state: bool = true
@export var show_ability_cooldowns: bool = true
@export var speed_units: String = "u/s"

var _player: CharacterBody3D = null
var _speed_label: Label = null
var _state_label: Label = null
var _cooldown_container: HBoxContainer = null
var _cooldown_bars: Dictionary = {}


func _ready() -> void:
	_create_ui()
	call_deferred("_find_player")


## Create the movement HUD UI elements


func _create_ui() -> void:
	# Main container
	var vbox := VBoxContainer.new()
	vbox.name = "MovementContainer"
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Position bottom-left
	anchor_left = 0.0
	anchor_right = 0.2
	anchor_top = 0.7
	anchor_bottom = 0.95
	offset_left = 20
	offset_right = 0
	offset_top = 0
	offset_bottom = -20

	# Speed display
	if show_speed:
		var speed_container := HBoxContainer.new()
		speed_container.add_theme_constant_override("separation", 8)
		vbox.add_child(speed_container)

		var speed_icon := Label.new()
		speed_icon.text = "⚡"
		speed_icon.add_theme_font_size_override("font_size", 20)
		speed_container.add_child(speed_icon)

		_speed_label = Label.new()
		_speed_label.text = "0 " + speed_units
		_speed_label.add_theme_font_size_override("font_size", 18)
		_speed_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		speed_container.add_child(_speed_label)

	# Movement state
	if show_movement_state:
		_state_label = Label.new()
		_state_label.text = "WALKING"
		_state_label.add_theme_font_size_override("font_size", 14)
		_state_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(_state_label)

	# Ability cooldowns
	if show_ability_cooldowns:
		_cooldown_container = HBoxContainer.new()
		_cooldown_container.add_theme_constant_override("separation", 10)
		vbox.add_child(_cooldown_container)


## Find the local player


func _find_player() -> void:
	for node: Node in get_tree().get_nodes_in_group("player"):
		if node is CharacterBody3D and node.is_multiplayer_authority():
			_player = node
			return


func _process(_delta: float) -> void:
	if not _player or not is_instance_valid(_player):
		_find_player()
		return

	_update_speed_display()
	_update_state_display()
	_update_cooldowns()


## Update speed readout


func _update_speed_display() -> void:
	if not _speed_label or not show_speed:
		return

	var horizontal_vel := Vector3(_player.velocity.x, 0, _player.velocity.z)
	var speed := horizontal_vel.length()

	_speed_label.text = "%d %s" % [int(speed), speed_units]

	# Color based on speed thresholds
	if speed > 15.0:
		_speed_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))  # Fast = gold
	elif speed > 8.0:
		_speed_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))  # Medium = green
	else:
		_speed_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))  # Normal = white


## Update movement state label


func _update_state_display() -> void:
	if not _state_label or not show_movement_state:
		return

	var state := "IDLE"
	var color := Color(0.7, 0.7, 0.7)

	# Check various movement states
	if not _player.is_on_floor():
		if _player.velocity.y > 0:
			state = "JUMPING"
			color = Color(0.4, 0.8, 1.0)
		else:
			state = "FALLING"
			color = Color(1.0, 0.6, 0.2)
	elif _player.velocity.length() < 0.5:
		state = "IDLE"
		color = Color(0.5, 0.5, 0.5)
	else:
		# Check for special movement states
		if "is_sliding" in _player and _player.is_sliding:
			state = "SLIDING"
			color = Color(0.2, 0.8, 1.0)
		elif "is_sprinting" in _player and _player.is_sprinting:
			state = "SPRINTING"
			color = Color(1.0, 0.9, 0.2)
		elif "is_crouching" in _player and _player.is_crouching:
			state = "CROUCHING"
			color = Color(0.6, 0.6, 0.8)
		else:
			state = "WALKING"
			color = Color(0.7, 0.7, 0.7)

	_state_label.text = state
	_state_label.add_theme_color_override("font_color", color)


## Update ability cooldown displays


func _update_cooldowns() -> void:
	if not _cooldown_container or not show_ability_cooldowns:
		return

	# Check for dodge system
	var dodge_system: Node = _player.get_node_or_null("DodgeSystem")
	if dodge_system and "dodge_cooldown" in dodge_system:
		var current: float = dodge_system.get("cooldown_timer") or 0.0
		_update_cooldown_bar("Dodge", dodge_system.dodge_cooldown, current)


func _update_cooldown_bar(
	ability_name: String, max_cooldown: float, current_cooldown: float
) -> void:
	## Update or create a cooldown bar
	if ability_name not in _cooldown_bars:
		_create_cooldown_bar(ability_name, max_cooldown)

	var bar: ProgressBar = _cooldown_bars[ability_name]
	if max_cooldown > 0:
		var progress := (max_cooldown - current_cooldown) / max_cooldown * 100.0
		bar.value = progress

		# Change color based on availability
		if current_cooldown <= 0:
			bar.modulate = Color(0.4, 1.0, 0.4)  # Ready = green
		else:
			bar.modulate = Color(0.8, 0.8, 0.8)  # Cooling down = gray


## Create a cooldown bar for an ability


func _create_cooldown_bar(ability_name: String, _max_cooldown: float) -> void:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	_cooldown_container.add_child(container)

	var label := Label.new()
	label.text = ability_name
	label.add_theme_font_size_override("font_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(60, 8)
	bar.max_value = 100
	bar.value = 100
	bar.show_percentage = false
	container.add_child(bar)

	# Style the bar
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.7, 1.0)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.15, 0.15, 0.15)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_left = 2
	bg_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", bg_style)

	_cooldown_bars[ability_name] = bar


## Set player reference manually


func set_player(player: CharacterBody3D) -> void:
	_player = player
