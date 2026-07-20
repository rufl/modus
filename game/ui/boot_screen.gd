class_name BootScreen
extends Control

@export var next_scene_path: String = "res://game/ui/menus/main_menu.tscn"

var _boot_sequence: BootSequence
var _log_label: RichTextLabel
var _progress_bar: ProgressBar
var _lines: Array[String] = []


func _ready() -> void:
	# Build UI
	_setup_ui()

	# Start Boot Sequence
	_boot_sequence = BootSequence.new()
	add_child(_boot_sequence)

	_boot_sequence.log_message.connect(_on_log_message)
	_boot_sequence.progress_updated.connect(_on_progress_updated)
	_boot_sequence.boot_complete.connect(_on_boot_complete)

	# Small delay before starting
	await get_tree().create_timer(1.0).timeout
	_boot_sequence.start_sequence()


func _setup_ui() -> void:
	# Full screen black background
	var bg: ColorRect = ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# VBox for layout
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(800, 600)
	# Center it
	vbox.position = (get_viewport_rect().size - vbox.custom_minimum_size) / 2
	add_child(vbox)

	# Header
	var header: Label = Label.new()
	header.text = "MODUS 0.9.5-beta / Godot 4.7"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_theme_font_size_override("font_size", 32)
	header.modulate = Color(0.2, 0.8, 0.2)  # Retro green
	vbox.add_child(header)

	# Separator
	vbox.add_child(HSeparator.new())

	# Log Area (Console style)
	_log_label = RichTextLabel.new()
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.scroll_following = true
	_log_label.bbcode_enabled = true
	_log_label.add_theme_color_override("default_color", Color(0.2, 0.8, 0.2))  # Retro green
	_log_label.add_theme_font_size_override("normal_font_size", 20)
	vbox.add_child(_log_label)

	# Progress Bar
	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 30)
	_progress_bar.show_percentage = false
	# Style it a bit if possible, but default is fine for now
	vbox.add_child(_progress_bar)


func _on_log_message(text: String) -> void:
	_lines.append(text)
	# Keep log buffer reasonable (optional)
	if _lines.size() > 50:
		_lines.pop_front()

	# Typewriter effect or just append?
	# Just append for speed/readability for now
	_log_label.append_text(text + "\n")


func _on_progress_updated(percent: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_progress_bar, "value", percent * 100, 0.5)


func _on_boot_complete() -> void:
	# Flash "OK" or similar?
	_log_label.append_text("[b][color=white]INIT COMPLETE.[/color][/b]\n")
	await get_tree().create_timer(1.0).timeout

	if ResourceLoader.exists(next_scene_path):
		get_tree().change_scene_to_file(next_scene_path)
	else:
		_log_label.append_text("[color=red]ERROR: Main Menu scene not found![/color]\n")
		GameManager.get_core_system("logger").info(
			"Error: " + " " + str(next_scene_path) + " " + " not found.", "UI"
		)
