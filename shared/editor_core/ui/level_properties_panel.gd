@tool
extends Control

signal properties_changed

var level_root: Node = null

@onready var name_edit: LineEdit
@onready var author_edit: LineEdit
@onready var description_edit: TextEdit
@onready var tags_edit: LineEdit
@onready var grid_size_spin: SpinBox
@onready var theme_option: OptionButton
@onready var validate_btn: Button
@onready var validation_label: Label


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	custom_minimum_size = Vector2(250, 300)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "📋 Level Properties"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Level Name
	vbox.add_child(_create_label("Level Name"))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "My Awesome Level"
	name_edit.text_changed.connect(_on_name_changed)
	vbox.add_child(name_edit)

	# Author
	vbox.add_child(_create_label("Author"))
	author_edit = LineEdit.new()
	author_edit.placeholder_text = "Your Name"
	author_edit.text_changed.connect(_on_author_changed)
	vbox.add_child(author_edit)

	# Description
	vbox.add_child(_create_label("Description"))
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 80
	description_edit.placeholder_text = "Describe your level..."
	description_edit.text_changed.connect(_on_description_changed)
	vbox.add_child(description_edit)

	# Tags
	vbox.add_child(_create_label("Tags (comma-separated)"))
	tags_edit = LineEdit.new()
	tags_edit.placeholder_text = "action, puzzle, short"
	tags_edit.text_changed.connect(_on_tags_changed)
	vbox.add_child(tags_edit)

	# Separator
	vbox.add_child(HSeparator.new())

	# Grid Size
	var grid_hbox := HBoxContainer.new()
	vbox.add_child(grid_hbox)

	var grid_label := Label.new()
	grid_label.text = "Default Grid Size"
	grid_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_hbox.add_child(grid_label)

	grid_size_spin = SpinBox.new()
	grid_size_spin.min_value = 0.25
	grid_size_spin.max_value = 4.0
	grid_size_spin.step = 0.25
	grid_size_spin.value = 1.0
	grid_size_spin.value_changed.connect(_on_grid_size_changed)
	grid_hbox.add_child(grid_size_spin)

	# MapTheme
	vbox.add_child(_create_label("Default MapTheme"))
	theme_option = OptionButton.new()
	theme_option.add_item("Default")
	theme_option.add_item("Industrial")
	theme_option.add_item("Medieval")
	theme_option.add_item("Sci-Fi")
	theme_option.add_item("Nature")
	theme_option.item_selected.connect(_on_theme_changed)
	vbox.add_child(theme_option)

	# Separator
	vbox.add_child(HSeparator.new())

	# Validation
	validate_btn = Button.new()
	validate_btn.text = "✓ Validate Level"
	validate_btn.pressed.connect(_on_validate_pressed)
	vbox.add_child(validate_btn)

	validation_label = Label.new()
	validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	validation_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(validation_label)


func _create_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	label.add_theme_font_size_override("font_size", 11)
	return label


## Setup with level root reference


func setup(root: Node) -> void:
	set_level_root(root)


## Set the level root to edit


func set_level_root(root: Node) -> void:
	level_root = root
	_load_from_level_root()


func _load_from_level_root() -> void:
	if not level_root:
		_clear_fields()
		return

	if name_edit:
		name_edit.text = level_root.get("level_name") if "level_name" in level_root else ""
	if author_edit:
		author_edit.text = level_root.get("level_author") if "level_author" in level_root else ""
	if description_edit:
		var desc: String = ""
		if "level_description" in level_root:
			desc = level_root.get("level_description")
		description_edit.text = desc
	if tags_edit:
		var tags: Array = level_root.get("level_tags") if "level_tags" in level_root else []
		tags_edit.text = ", ".join(tags)
	if grid_size_spin:
		grid_size_spin.value = level_root.get("grid_size") if "grid_size" in level_root else 1.0
	if theme_option:
		var theme_name := "default"
		if "default_theme" in level_root:
			theme_name = level_root.get("default_theme")
		for i in range(theme_option.item_count):
			if theme_option.get_item_text(i).to_lower() == theme_name.to_lower():
				theme_option.select(i)
				break


func _clear_fields() -> void:
	if name_edit:
		name_edit.text = ""
	if author_edit:
		author_edit.text = ""
	if description_edit:
		description_edit.text = ""
	if tags_edit:
		tags_edit.text = ""
	if grid_size_spin:
		grid_size_spin.value = 1.0
	if theme_option:
		theme_option.select(0)
	if validation_label:
		validation_label.text = ""


func _on_name_changed(text: String) -> void:
	if level_root and "level_name" in level_root:
		level_root.level_name = text
		properties_changed.emit()


func _on_author_changed(text: String) -> void:
	if level_root and "level_author" in level_root:
		level_root.level_author = text
		properties_changed.emit()


func _on_description_changed() -> void:
	if level_root and "level_description" in level_root:
		level_root.level_description = description_edit.text
		properties_changed.emit()


func _on_tags_changed(text: String) -> void:
	if level_root and "level_tags" in level_root:
		var tags: Array[String] = []
		for tag in text.split(","):
			var trimmed := tag.strip_edges()
			if not trimmed.is_empty():
				tags.append(trimmed)
		level_root.level_tags = tags
		properties_changed.emit()


func _on_grid_size_changed(value: float) -> void:
	if level_root and "grid_size" in level_root:
		level_root.grid_size = value
		properties_changed.emit()


func _on_theme_changed(index: int) -> void:
	if level_root and "default_theme" in level_root:
		level_root.default_theme = theme_option.get_item_text(index).to_lower()
		properties_changed.emit()


func _on_validate_pressed() -> void:
	if not level_root:
		validation_label.text = "⚠️ No LevelRoot selected"
		validation_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		return

	if not level_root.has_method("validate_level"):
		validation_label.text = "⚠️ LevelRoot missing validate_level()"
		validation_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
		return

	var result: Dictionary = level_root.validate_level()

	if result.valid:
		var msg := "✓ Level is valid!"
		if result.warnings.size() > 0:
			msg += "\n\nWarnings:\n• " + "\n• ".join(result.warnings)
		validation_label.text = msg
		validation_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	else:
		var msg := "✗ Level has errors:\n• " + "\n• ".join(result.errors)
		if result.warnings.size() > 0:
			msg += "\n\nWarnings:\n• " + "\n• ".join(result.warnings)
		validation_label.text = msg
		validation_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
