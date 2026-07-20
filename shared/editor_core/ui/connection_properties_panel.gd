@tool
extends Control

signal connection_updated(channel_name: String)
signal connection_deleted(channel_name: String)

var channel_system: Node = null
var current_channel: String = ""

@onready var channel_label: Label
@onready var delay_spin: SpinBox
@onready var invert_check: CheckBox
@onready var color_picker: ColorPickerButton
@onready var enabled_check: CheckBox
@onready var delete_btn: Button


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	custom_minimum_size = Vector2(200, 180)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "🔗 Connection Properties"
	title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(title)

	# Channel name
	channel_label = Label.new()
	channel_label.text = "Channel: (none)"
	channel_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(channel_label)

	# Enabled
	enabled_check = CheckBox.new()
	enabled_check.text = "Enabled"
	enabled_check.button_pressed = true
	enabled_check.toggled.connect(_on_enabled_changed)
	vbox.add_child(enabled_check)

	# Delay
	var delay_hbox := HBoxContainer.new()
	vbox.add_child(delay_hbox)

	var delay_label := Label.new()
	delay_label.text = "Delay (sec)"
	delay_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delay_hbox.add_child(delay_label)

	delay_spin = SpinBox.new()
	delay_spin.min_value = 0.0
	delay_spin.max_value = 30.0
	delay_spin.step = 0.1
	delay_spin.value = 0.0
	delay_spin.value_changed.connect(_on_delay_changed)
	delay_hbox.add_child(delay_spin)

	# Invert
	invert_check = CheckBox.new()
	invert_check.text = "Invert Output"
	invert_check.toggled.connect(_on_invert_changed)
	vbox.add_child(invert_check)

	# Color
	var color_hbox := HBoxContainer.new()
	vbox.add_child(color_hbox)

	var color_label := Label.new()
	color_label.text = "Wire Color"
	color_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_hbox.add_child(color_label)

	color_picker = ColorPickerButton.new()
	color_picker.custom_minimum_size = Vector2(60, 24)
	color_picker.color = Color.WHITE
	color_picker.color_changed.connect(_on_color_changed)
	color_hbox.add_child(color_picker)

	# Separator
	vbox.add_child(HSeparator.new())

	# Delete button
	delete_btn = Button.new()
	delete_btn.text = "🗑️ Delete Channel"
	delete_btn.pressed.connect(_on_delete_pressed)
	vbox.add_child(delete_btn)


## Setup with channel system reference


func setup(system: Node) -> void:
	channel_system = system


## Edit a specific channel


func edit_channel(channel_name: String) -> void:
	current_channel = channel_name
	_load_channel_properties()


func _load_channel_properties() -> void:
	if not channel_system or current_channel.is_empty():
		_clear_ui()
		return

	if not "channels" in channel_system:
		_clear_ui()
		return

	var channels: Dictionary = channel_system.channels
	if not channels.has(current_channel):
		_clear_ui()
		return

	var channel: Dictionary = channels[current_channel]

	if channel_label:
		channel_label.text = "Channel: %s" % current_channel
	if enabled_check:
		enabled_check.button_pressed = channel.get("enabled", true)
	if delay_spin:
		delay_spin.value = channel.get("delay", 0.0)
	if invert_check:
		invert_check.button_pressed = channel.get("inverted", false)
	if color_picker:
		color_picker.color = channel.get("color", Color.WHITE)


func _clear_ui() -> void:
	current_channel = ""
	if channel_label:
		channel_label.text = "Channel: (none)"
	if enabled_check:
		enabled_check.button_pressed = true
	if delay_spin:
		delay_spin.value = 0.0
	if invert_check:
		invert_check.button_pressed = false
	if color_picker:
		color_picker.color = Color.WHITE


func _on_enabled_changed(pressed: bool) -> void:
	if channel_system and not current_channel.is_empty():
		if channel_system.has_method("set_channel_enabled"):
			channel_system.set_channel_enabled(current_channel, pressed)
			connection_updated.emit(current_channel)


func _on_delay_changed(value: float) -> void:
	if channel_system and not current_channel.is_empty():
		if channel_system.has_method("set_channel_delay"):
			channel_system.set_channel_delay(current_channel, value)
			connection_updated.emit(current_channel)


func _on_invert_changed(pressed: bool) -> void:
	if channel_system and not current_channel.is_empty():
		if channel_system.has_method("set_channel_inverted"):
			channel_system.set_channel_inverted(current_channel, pressed)
			connection_updated.emit(current_channel)


func _on_color_changed(color: Color) -> void:
	if channel_system and not current_channel.is_empty():
		if channel_system.has_method("set_channel_color"):
			channel_system.set_channel_color(current_channel, color)
			connection_updated.emit(current_channel)


func _on_delete_pressed() -> void:
	if channel_system and not current_channel.is_empty():
		if channel_system.has_method("delete_channel"):
			var deleted := current_channel
			channel_system.delete_channel(current_channel)
			_clear_ui()
			connection_deleted.emit(deleted)
