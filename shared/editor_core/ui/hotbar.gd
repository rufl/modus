@tool
extends HBoxContainer

signal slot_selected(slot_index: int, asset_data: Dictionary)
signal bar_switched(bar_index: int)
signal category_changed(category: int)

enum Bar { PRIMARY = 0, SECONDARY = 1 }

const MAX_SLOTS := 9

var active_bar: int = Bar.PRIMARY
var current_category: int = 0  # HotbarCategory.Category.BLOCKS
var editor_state: Node = null
var asset_registry: Node = null
var primary_slots: Array[Dictionary] = []
var secondary_slots: Array[Dictionary] = []
var primary_selected: int = 0
var secondary_selected: int = 0
var primary_container: HBoxContainer
var secondary_container: HBoxContainer
var primary_buttons: Array[Button] = []
var secondary_buttons: Array[Button] = []
var bar_indicator_label: Label
var category_label: Label

var _alt_held: bool = false


func _ready() -> void:
	_init_slots()
	_create_ui()


func _init_slots() -> void:
	primary_slots.clear()
	secondary_slots.clear()
	for i: int in range(MAX_SLOTS):
		primary_slots.append({})
		secondary_slots.append({})


func setup(state: Node, registry: Node = null) -> void:
	editor_state = state
	asset_registry = registry


func _create_ui() -> void:
	# Clear existing
	for child: Node in get_children():
		child.queue_free()
	primary_buttons.clear()
	secondary_buttons.clear()

	# Main container spans full width
	add_theme_constant_override("separation", 8)

	# Left: Category indicator
	var cat_panel := PanelContainer.new()
	cat_panel.custom_minimum_size = Vector2(80, 0)
	add_child(cat_panel)

	var cat_vbox := VBoxContainer.new()
	cat_panel.add_child(cat_vbox)

	category_label = Label.new()
	category_label.text = "Blocks"
	category_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	category_label.add_theme_font_size_override("font_size", 11)
	cat_vbox.add_child(category_label)

	var alt_hint := Label.new()
	alt_hint.text = "ALT+Scroll"
	alt_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alt_hint.add_theme_font_size_override("font_size", 9)
	alt_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	cat_vbox.add_child(alt_hint)

	# Center: Dual hotbar stack
	var bars_vbox := VBoxContainer.new()
	bars_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars_vbox.add_theme_constant_override("separation", 2)
	add_child(bars_vbox)

	# Secondary bar (top, dimmed when inactive)
	secondary_container = HBoxContainer.new()
	secondary_container.add_theme_constant_override("separation", 2)
	secondary_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bars_vbox.add_child(secondary_container)

	for i: int in range(MAX_SLOTS):
		var slot := _create_slot_button(i, Bar.SECONDARY)
		secondary_container.add_child(slot)
		secondary_buttons.append(slot.get_child(0).get_child(0) as Button)

	# Primary bar (bottom, active by default)
	primary_container = HBoxContainer.new()
	primary_container.add_theme_constant_override("separation", 2)
	primary_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bars_vbox.add_child(primary_container)

	for i: int in range(MAX_SLOTS):
		var slot := _create_slot_button(i, Bar.PRIMARY)
		primary_container.add_child(slot)
		primary_buttons.append(slot.get_child(0).get_child(0) as Button)

	# Right: Bar indicator
	var indicator_panel := PanelContainer.new()
	indicator_panel.custom_minimum_size = Vector2(70, 0)
	add_child(indicator_panel)

	var indicator_vbox := VBoxContainer.new()
	indicator_panel.add_child(indicator_vbox)

	bar_indicator_label = Label.new()
	bar_indicator_label.text = "PRIMARY"
	bar_indicator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_indicator_label.add_theme_font_size_override("font_size", 11)
	indicator_vbox.add_child(bar_indicator_label)

	var swap_hint := Label.new()
	swap_hint.text = "Press ALT"
	swap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	swap_hint.add_theme_font_size_override("font_size", 9)
	swap_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	indicator_vbox.add_child(swap_hint)

	_update_bar_visual()


func _create_slot_button(index: int, bar: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(44, 44)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)

	# Button
	var btn := Button.new()
	btn.name = "Button"
	btn.custom_minimum_size = Vector2(38, 32)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.toggle_mode = true
	btn.pressed.connect(_on_slot_pressed.bind(index, bar))
	vbox.add_child(btn)

	# Icon placeholder
	var icon := ColorRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(28, 28)
	icon.color = Color(0.3, 0.3, 0.3, 0.5)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	# Number label
	var num_label := Label.new()
	num_label.text = str(index + 1)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.add_theme_font_size_override("font_size", 9)
	num_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(num_label)

	return panel


func _on_slot_pressed(index: int, bar: int) -> void:
	# Switch to this bar if not active
	if active_bar != bar:
		active_bar = bar

	# Select the slot
	if bar == Bar.PRIMARY:
		primary_selected = index
	else:
		secondary_selected = index

	_update_bar_visual()

	# Get asset and notify
	var asset: Dictionary = get_current_asset()
	if not asset.is_empty() and editor_state:
		editor_state.set_selected_asset(asset)
	slot_selected.emit(index, asset)


func _input(event: InputEvent) -> void:
	# Track ALT key state
	if event is InputEventKey:
		if event.keycode == KEY_ALT:
			var was_held: bool = _alt_held
			_alt_held = event.pressed

			# Toggle bar on ALT release (tap)
			if was_held and not _alt_held:
				_toggle_bar()

	# ALT+Scroll for category cycling
	if event is InputEventMouseButton and _alt_held:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_category(1)
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_category(-1)
				get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return

	# Number keys 1-9 select slot in active bar
	var key: int = event.keycode
	if key >= KEY_1 and key <= KEY_9:
		var slot_index: int = key - KEY_1
		_on_slot_pressed(slot_index, active_bar)
		get_viewport().set_input_as_handled()


## Toggle between primary and secondary bars


func _toggle_bar() -> void:
	if active_bar == Bar.PRIMARY:
		active_bar = Bar.SECONDARY
	else:
		active_bar = Bar.PRIMARY


## Cycle category (for ALT+scroll)


func _cycle_category(direction: int) -> void:
	# HotbarCategory enum has 8 values (0-7)
	var new_cat: int = current_category + direction
	if new_cat < 0:
		new_cat = 7  # Wrap to CUSTOM
	elif new_cat > 7:
		new_cat = 0  # Wrap to BLOCKS
	current_category = new_cat
	_update_category_label()


func _update_category_label() -> void:
	if not category_label:
		return

	# Get category name (matching HotbarCategory enum order)
	var names: Array[String] = [
		"Blocks", "Props", "Entities", "Triggers", "Effects", "Hazards", "Movers", "Custom"
	]
	var colors: Array[Color] = [
		Color(0.4, 0.6, 0.8),
		Color(0.6, 0.5, 0.4),
		Color(0.8, 0.4, 0.4),
		Color(0.4, 0.8, 0.4),
		Color(0.8, 0.8, 0.4),
		Color(0.9, 0.3, 0.1),
		Color(0.6, 0.4, 0.8),
		Color(0.5, 0.5, 0.5)
	]

	if current_category >= 0 and current_category < names.size():
		category_label.text = names[current_category]
		category_label.add_theme_color_override("font_color", colors[current_category])


func _update_bar_visual() -> void:
	if not primary_container or not secondary_container:
		return

	# Update bar opacity based on active state
	var active_alpha: float = 1.0
	var inactive_alpha: float = 0.4

	primary_container.modulate.a = active_alpha if active_bar == Bar.PRIMARY else inactive_alpha
	secondary_container.modulate.a = active_alpha if active_bar == Bar.SECONDARY else inactive_alpha

	# Update indicator
	if bar_indicator_label:
		bar_indicator_label.text = "PRIMARY" if active_bar == Bar.PRIMARY else "SECONDARY"
		var is_primary: bool = active_bar == Bar.PRIMARY
		var color: Color = Color(0.4, 0.7, 1.0) if is_primary else Color(0.8, 0.4, 0.4)
		bar_indicator_label.add_theme_color_override("font_color", color)

	# Update slot highlights
	_update_all_slot_visuals()


func _update_all_slot_visuals() -> void:
	for i: int in range(MAX_SLOTS):
		_update_slot_visual(i, Bar.PRIMARY)
		_update_slot_visual(i, Bar.SECONDARY)


func _update_slot_visual(index: int, bar: int) -> void:
	var buttons: Array[Button] = primary_buttons if bar == Bar.PRIMARY else secondary_buttons
	var slots: Array[Dictionary] = primary_slots if bar == Bar.PRIMARY else secondary_slots
	var selected: int = primary_selected if bar == Bar.PRIMARY else secondary_selected

	if index >= buttons.size():
		return

	var btn: Button = buttons[index]
	var icon: ColorRect = btn.get_node_or_null("Icon") as ColorRect
	if not icon:
		return

	var asset: Dictionary = slots[index]
	var is_active: bool = bar == active_bar
	var is_selected: bool = index == selected

	# Icon color
	if asset.is_empty():
		icon.color = Color(0.3, 0.3, 0.3, 0.5)
		btn.tooltip_text = "Empty (Press %d)" % (index + 1)
	else:
		if asset.has("material") and asset.material is StandardMaterial3D:
			icon.color = asset.material.albedo_color
		elif asset.get("type") == "spawn_point":
			match asset.get("spawn_type", ""):
				"player":
					icon.color = Color(0.2, 0.5, 1.0)
				"enemy":
					icon.color = Color(1.0, 0.3, 0.2)
				"item":
					icon.color = Color(1.0, 0.8, 0.2)
				_:
					icon.color = Color(0.5, 0.5, 0.5)
		else:
			icon.color = Color(0.5, 0.5, 0.5)
		btn.tooltip_text = "%s (Press %d)" % [asset.get("name", "Unknown"), index + 1]

	# Selection highlight
	btn.button_pressed = is_selected and is_active
	var panel: PanelContainer = btn.get_parent().get_parent() as PanelContainer
	if panel:
		if is_selected and is_active:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.6, 0.5)
			style.border_color = Color(0.4, 0.7, 1.0)
			style.set_border_width_all(2)
			style.set_corner_radius_all(4)
			panel.add_theme_stylebox_override("panel", style)
		else:
			panel.remove_theme_stylebox_override("panel")


## Get the currently active slots array


func _get_active_slots() -> Array[Dictionary]:
	return primary_slots if active_bar == Bar.PRIMARY else secondary_slots


## Get the selected index for active bar


func _get_active_selected() -> int:
	return primary_selected if active_bar == Bar.PRIMARY else secondary_selected


## Set selected index for active bar


func _set_active_selected(index: int) -> void:
	if active_bar == Bar.PRIMARY:
		primary_selected = index
	else:
		secondary_selected = index


## Get currently selected asset from active bar


func get_current_asset() -> Dictionary:
	var slots_arr: Array[Dictionary] = _get_active_slots()
	var selected: int = _get_active_selected()
	if selected >= 0 and selected < slots_arr.size():
		return slots_arr[selected]
	return {}


## Add asset to active hotbar


func add_asset(asset_data: Dictionary) -> int:
	var slots_arr: Array[Dictionary] = _get_active_slots()

	# Check if already exists
	for i: int in range(MAX_SLOTS):
		if slots_arr[i].get("id") == asset_data.get("id"):
			_set_active_selected(i)
			_update_bar_visual()
			return i

	# Find empty slot
	for i: int in range(MAX_SLOTS):
		if slots_arr[i].is_empty():
			set_slot(i, asset_data, active_bar)
			return i

	# Replace current
	var selected: int = _get_active_selected()
	set_slot(selected, asset_data, active_bar)
	return selected


## Set asset in specific slot


func set_slot(index: int, asset_data: Dictionary, bar: int = Bar.PRIMARY) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return

	if bar == Bar.PRIMARY:
		primary_slots[index] = asset_data.duplicate()
	else:
		secondary_slots[index] = asset_data.duplicate()

	_update_slot_visual(index, bar)


## Clear a slot


func clear_slot(index: int, bar: int = Bar.PRIMARY) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return

	if bar == Bar.PRIMARY:
		primary_slots[index] = {}
	else:
		secondary_slots[index] = {}

	_update_slot_visual(index, bar)


## Clear all slots in a bar


func clear_bar(bar: int) -> void:
	for i: int in range(MAX_SLOTS):
		clear_slot(i, bar)


## Clear all slots in both bars


func clear_all() -> void:
	clear_bar(Bar.PRIMARY)
	clear_bar(Bar.SECONDARY)


## Select a slot by index in active bar


func select_slot(index: int) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	_set_active_selected(index)
	_update_bar_visual()


## Get all slots data for saving


func get_slots_data() -> Dictionary:
	return {
		"primary": primary_slots.duplicate(),
		"secondary": secondary_slots.duplicate(),
		"primary_selected": primary_selected,
		"secondary_selected": secondary_selected,
		"active_bar": active_bar,
		"current_category": current_category
	}


## Load slots data


func load_slots_data(data: Dictionary) -> void:
	if data.has("primary"):
		for i: int in range(mini(data.primary.size(), MAX_SLOTS)):
			primary_slots[i] = data.primary[i] if i < data.primary.size() else {}

	if data.has("secondary"):
		for i: int in range(mini(data.secondary.size(), MAX_SLOTS)):
			secondary_slots[i] = data.secondary[i] if i < data.secondary.size() else {}

	primary_selected = data.get("primary_selected", 0)
	secondary_selected = data.get("secondary_selected", 0)
	active_bar = data.get("active_bar", Bar.PRIMARY)
	current_category = data.get("current_category", 0)

	_update_bar_visual()
	_update_category_label()
