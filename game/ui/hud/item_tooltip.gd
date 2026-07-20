extends Control
class_name ItemTooltip

const RARITY_DATA: Dictionary = {
	0: {"name": "Common", "color": Color(0.7, 0.7, 0.7)},
	1: {"name": "Uncommon", "color": Color(0.3, 0.8, 0.3)},
	2: {"name": "Rare", "color": Color(0.3, 0.5, 1.0)},
	3: {"name": "Epic", "color": Color(0.7, 0.3, 0.9)},
	4: {"name": "Legendary", "color": Color(1.0, 0.6, 0.1)},
}

@onready var background: Panel = $Background
@onready var item_name: Label = $VBox/ItemName
@onready var item_type: Label = $VBox/ItemType
@onready var description: Label = $VBox/Description
@onready var stats_container: VBoxContainer = $VBox/Stats


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Apply tooltip styling from configuration
	# Check if config is available, otherwise connect to reload signal for late initialization
	if GameManager and GameManager.get_core_system("config"):
		_apply_tooltip_config()
		# Connect to config reload signal to handle late loading of config
		if GameManager.get_core_system("config").config_reloaded.is_connected(
			_apply_tooltip_config
		):
			GameManager.get_core_system("config").config_reloaded.disconnect(_apply_tooltip_config)
		GameManager.get_core_system("config").config_reloaded.connect(_apply_tooltip_config)


func show_item(item: InventoryItem, at_position: Vector2) -> void:
	if not item:
		hide()
		return

	# Set name with rarity color
	item_name.text = item.name
	var rarity: int = item.rarity if "rarity" in item else 0
	if RARITY_DATA.has(rarity):
		item_name.add_theme_color_override("font_color", RARITY_DATA[rarity]["color"])

	# Set item type
	var type_text: String = _get_type_string(item)
	if RARITY_DATA.has(rarity):
		type_text = RARITY_DATA[rarity]["name"] + " " + type_text
	item_type.text = type_text

	# Set description
	if item.description and item.description != "":
		description.text = item.description
		description.show()
	else:
		description.hide()

	# Clear and populate stats
	_clear_stats()
	_populate_stats(item)

	# Position tooltip near mouse but keep on screen
	global_position = _clamp_to_screen(at_position + Vector2(20, 10))

	show()


func hide_tooltip() -> void:
	hide()


func _get_type_string(item: InventoryItem) -> String:
	if "item_type" in item:
		match item.item_type:
			0:
				return "Weapon"
			1:
				return "Armor"
			2:
				return "Consumable"
			3:
				return "Material"
			4:
				return "Key Item"
			_:
				return "Item"
	return "Item"


func _clear_stats() -> void:
	for child in stats_container.get_children():
		child.queue_free()


func _populate_stats(item: InventoryItem) -> void:
	# Add damage stat if weapon
	if "damage" in item and item.damage > 0:
		_add_stat_line("Damage", str(item.damage), Color(1.0, 0.4, 0.4))

	# Add defense stat if armor
	if "defense" in item and item.defense > 0:
		_add_stat_line("Defense", str(item.defense), Color(0.4, 0.6, 1.0))

	# Add heal amount if consumable
	if "heal_amount" in item and item.heal_amount > 0:
		_add_stat_line("Heals", str(item.heal_amount), Color(0.4, 1.0, 0.4))

	# Add value
	if "value" in item and item.value > 0:
		_add_stat_line("Value", str(item.value) + "g", Color(1.0, 0.85, 0.0))

	# Add stack info if stackable
	if item.max_stack > 1:
		var stack_text: String = "%d / %d" % [item.current_stack, item.max_stack]
		_add_stat_line("Stack", stack_text, Color(0.7, 0.7, 0.7))


func _add_stat_line(stat_name: String, stat_value: String, value_color: Color) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()

	var name_label: Label = Label.new()
	name_label.text = stat_name + ":"
	name_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(name_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var value_label: Label = Label.new()
	value_label.text = stat_value
	value_label.add_theme_color_override("font_color", value_color)
	hbox.add_child(value_label)

	stats_container.add_child(hbox)


func _clamp_to_screen(pos: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = size

	# Clamp X
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = viewport_size.x - tooltip_size.x - 10

	# Clamp Y
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = viewport_size.y - tooltip_size.y - 10

	return pos


func _apply_tooltip_config(_file_path: String = "") -> void:
	## Apply typography and styling from hud.json5
	if not GameManager or not GameManager.get_core_system("config"):
		return

	var config_result: Variant = GameManager.get_core_system("config").get_value("visuals.hud")
	if not config_result is Dictionary:
		return

	var hud_config: Dictionary = config_result
	if hud_config.is_empty() or not hud_config.has("typography"):
		return

	var typo: Dictionary = hud_config.typography
	if not typo.has("item_tooltip"):
		return

	var tooltip_config: Dictionary = typo.item_tooltip
	var fonts: Dictionary = typo.get("fonts", {})

	# Apply name label font/size
	if item_name:
		if tooltip_config.has("name_font") and fonts.has(tooltip_config.name_font):
			var font_path: String = fonts[tooltip_config.name_font]
			if font_path != "default" and ResourceLoader.exists(font_path):
				item_name.add_theme_font_override("font", load(font_path))

		if tooltip_config.has("name_size"):
			item_name.add_theme_font_size_override("font_size", tooltip_config.name_size)

	# Apply body font/size to other labels
	for label: Label in [item_type, description]:
		if not label:
			continue

		if tooltip_config.has("body_font") and fonts.has(tooltip_config.body_font):
			var font_path: String = fonts[tooltip_config.body_font]
			if font_path != "default" and ResourceLoader.exists(font_path):
				label.add_theme_font_override("font", load(font_path))

		if tooltip_config.has("body_size"):
			label.add_theme_font_size_override("font_size", tooltip_config.body_size)

	# Apply background styling
	if background and tooltip_config.has("background_color"):
		var bg_style: StyleBoxFlat = StyleBoxFlat.new()
		var bg_color: Dictionary = tooltip_config.background_color
		if bg_color.has("r") and bg_color.has("g") and bg_color.has("b") and bg_color.has("a"):
			bg_style.bg_color = Color(bg_color.r, bg_color.g, bg_color.b, bg_color.a)

			if tooltip_config.has("border_width"):
				var width: int = tooltip_config.border_width
				bg_style.border_width_left = width
				bg_style.border_width_right = width
				bg_style.border_width_top = width
				bg_style.border_width_bottom = width

			if tooltip_config.has("border_color"):
				var border: Dictionary = tooltip_config.border_color
				if border.has("r") and border.has("g") and border.has("b") and border.has("a"):
					bg_style.border_color = Color(border.r, border.g, border.b, border.a)

			background.add_theme_stylebox_override("panel", bg_style)
