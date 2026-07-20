@tool
extends Control

signal asset_selected(asset_data: Dictionary)

const LocalEditorGlobals = preload("res://shared/editor_core/core/editor_globals.gd")

var asset_registry: Node = null
var editor_state: Node = null

@onready var search_line: LineEdit = $VBox/SearchBar/SearchLine
@onready var category_tabs: TabBar = $VBox/CategoryTabs
@onready var asset_grid: GridContainer = $VBox/ScrollContainer/AssetGrid
@onready var info_label: Label = $VBox/InfoLabel


func _ready() -> void:
	custom_minimum_size = Vector2(250, 400)

	# Connect search
	if search_line:
		search_line.text_changed.connect(_on_search_changed)

	# Connect category tabs
	if category_tabs:
		category_tabs.tab_changed.connect(_on_category_changed)


## Setup with references to core systems


func setup(registry: Node, state: Node) -> void:
	asset_registry = registry
	editor_state = state

	if asset_registry:
		asset_registry.assets_loaded.connect(_on_assets_loaded)
		_populate_categories()
		_refresh_asset_grid()


func _populate_categories() -> void:
	if not category_tabs or not asset_registry:
		return

	category_tabs.clear_tabs()
	for cat_name: String in asset_registry.get_category_names():
		category_tabs.add_tab(cat_name)


func _on_assets_loaded() -> void:
	_populate_categories()
	_refresh_asset_grid()


func _on_search_changed(text: String) -> void:
	if asset_registry:
		asset_registry.set_search_filter(text)
		_refresh_asset_grid()


func _on_category_changed(tab_idx: int) -> void:
	if not asset_registry:
		return

	var cat_name := category_tabs.get_tab_title(tab_idx)
	var category: int = asset_registry.get_category_by_name(cat_name)
	asset_registry.set_category(category)
	_refresh_asset_grid()


func _refresh_asset_grid() -> void:
	if not asset_grid or not asset_registry:
		return

	# Clear existing
	for child in asset_grid.get_children():
		child.queue_free()

	# Get filtered assets
	var assets: Array = asset_registry.get_filtered_assets()

	# Update info label
	if info_label:
		info_label.text = "%d items" % assets.size()

	# Create asset buttons
	for asset: Dictionary in assets:
		var btn := _create_asset_button(asset)
		asset_grid.add_child(btn)


func _create_asset_button(asset_data: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 80)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.tooltip_text = asset_data.get("description", asset_data.name)

	# Create layout
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	btn.add_child(vbox)

	# Icon - use thumbnail if available, otherwise colored rect
	var icon_container := Control.new()
	icon_container.custom_minimum_size = Vector2(48, 48)
	icon_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_container)

	if asset_data.has("thumbnail") and asset_data.thumbnail is Texture2D:
		var tex_rect := TextureRect.new()
		tex_rect.texture = asset_data.thumbnail
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_container.add_child(tex_rect)
	else:
		var icon_rect := ColorRect.new()
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		# Color based on asset type
		if asset_data.has("material") and asset_data.material is StandardMaterial3D:
			icon_rect.color = asset_data.material.albedo_color
		elif asset_data.type == "spawn_point":
			match asset_data.get("spawn_type", ""):
				"player":
					icon_rect.color = Color(0.2, 0.5, 1.0)
				"enemy":
					icon_rect.color = Color(1.0, 0.3, 0.2)
				"item":
					icon_rect.color = Color(1.0, 0.8, 0.2)
				_:
					icon_rect.color = Color(0.5, 0.5, 0.5)
		else:
			icon_rect.color = Color(0.4, 0.4, 0.4)
		icon_container.add_child(icon_rect)

	# Name label
	var name_label := Label.new()
	name_label.text = asset_data.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 60
	vbox.add_child(name_label)

	# Connect click
	btn.pressed.connect(_on_asset_button_pressed.bind(asset_data))

	# Enable drag and drop
	btn.set_drag_forwarding(_get_asset_drag_data.bind(asset_data), Callable(), Callable())

	# Generate thumbnail if missing and possible
	# Generate thumbnail if missing and possible
	if (
		not asset_data.has("thumbnail")
		and asset_data.has("scene_path")
		and LocalEditorGlobals.is_in_editor()
	):
		_generate_thumbnail(asset_data)

	return btn


func _get_asset_drag_data(_at_position: Vector2, asset_data: Dictionary) -> Variant:
	# Create drag preview
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(64, 64)

	var preview_rect := ColorRect.new()
	preview_rect.custom_minimum_size = Vector2(64, 64)
	preview_rect.modulate.a = 0.7

	if asset_data.has("material") and asset_data.material is StandardMaterial3D:
		preview_rect.color = asset_data.material.albedo_color
	else:
		preview_rect.color = Color(0.5, 0.5, 0.7)

	preview.add_child(preview_rect)

	var label := Label.new()
	label.text = asset_data.name
	label.add_theme_font_size_override("font_size", 10)
	label.position = Vector2(0, 48)
	preview.add_child(label)

	set_drag_preview(preview)

	# Return drag data
	return {"type": "level_editor_asset", "asset_data": asset_data}


func _on_asset_button_pressed(asset_data: Dictionary) -> void:
	if editor_state:
		editor_state.set_selected_asset(asset_data)

		# Auto-select appropriate tool based on asset type
		match asset_data.type:
			"block":
				editor_state.select_tool(editor_state.ToolType.BLOCK_BRUSH)
			"scene", "interactable":
				editor_state.select_tool(editor_state.ToolType.ENTITY_PLACER)
			"spawn_point":
				editor_state.select_tool(editor_state.ToolType.SPAWN_POINT)

		editor_state.set_editing_mode(true)

	asset_selected.emit(asset_data)


## Generate thumbnail for a scene asset using EditorResourcePreview


func _generate_thumbnail(asset_data: Dictionary) -> void:
	if not asset_data.has("scene_path"):
		return

	var path: String = asset_data.scene_path
	var preview := EditorGlobals.get_resource_previewer()

	if preview:
		preview.queue_resource_preview(path, self, "_on_thumbnail_generated", asset_data)


func _on_thumbnail_generated(
	_path: String, preview: Texture2D, _thumbnail_preview: Texture2D, userdata: Variant
) -> void:
	if preview and userdata is Dictionary:
		userdata["thumbnail"] = preview
		# Refresh the grid to show updated thumbnail
		_refresh_asset_grid()
