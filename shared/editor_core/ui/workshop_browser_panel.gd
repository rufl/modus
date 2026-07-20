@tool
extends PanelContainer

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])



signal level_selected(item_id: String)
signal level_loaded(local_path: String)

var workshop_manager: Node = null
var level_packager_class: Script = null
var search_input: LineEdit
var tag_filter: OptionButton
var sort_option: OptionButton
var view_toggle: Button
var items_container: Control
var item_details_panel: Control
var upload_button: Button
var refresh_button: Button
var selected_item_id: String = ""
var is_grid_view: bool = true
var current_items: Array[Dictionary] = []
var available_tags: PackedStringArray = [
	"",
	"Action",
	"Puzzle",
	"Horror",
	"Adventure",
	"Multiplayer",
	"Singleplayer",
	"Short",
	"Long",
]


func _ready() -> void:
	name = "WorkshopBrowserPanel"
	_create_ui()


func setup(manager: Node) -> void:
	workshop_manager = manager

	if workshop_manager:
		if workshop_manager.has_signal("items_loaded"):
			workshop_manager.items_loaded.connect(_on_items_loaded)
		if workshop_manager.has_signal("download_completed"):
			workshop_manager.download_completed.connect(_on_download_completed)
		if workshop_manager.has_signal("upload_completed"):
			workshop_manager.upload_completed.connect(_on_upload_completed)


func _create_ui() -> void:
	custom_minimum_size = Vector2(600, 500)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.98)
	style.border_color = Color(0.25, 0.25, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "🌐 Level Workshop"
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	upload_button = Button.new()
	upload_button.text = "📤 Upload Level"
	upload_button.pressed.connect(_on_upload_pressed)
	header.add_child(upload_button)

	# Search and filters
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 8)
	vbox.add_child(filter_row)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search levels..."
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.text_submitted.connect(_on_search_submitted)
	filter_row.add_child(search_input)

	tag_filter = OptionButton.new()
	tag_filter.custom_minimum_size.x = 120
	for tag: String in available_tags:
		tag_filter.add_item("All Tags" if tag.is_empty() else tag)
	tag_filter.item_selected.connect(_on_filter_changed)
	filter_row.add_child(tag_filter)

	sort_option = OptionButton.new()
	sort_option.add_item("Recent")
	sort_option.add_item("Popular")
	sort_option.add_item("Rating")
	sort_option.item_selected.connect(_on_sort_changed)
	filter_row.add_child(sort_option)

	view_toggle = Button.new()
	view_toggle.text = "☷"
	view_toggle.tooltip_text = "Toggle Grid/List View"
	view_toggle.pressed.connect(_toggle_view)
	filter_row.add_child(view_toggle)

	refresh_button = Button.new()
	refresh_button.text = "🔄"
	refresh_button.tooltip_text = "Refresh"
	refresh_button.pressed.connect(_refresh_items)
	filter_row.add_child(refresh_button)

	# Content area (split: items + details)
	var hsplit := HSplitContainer.new()
	hsplit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hsplit)

	# Items scroll container
	var items_scroll := ScrollContainer.new()
	items_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	items_scroll.custom_minimum_size.x = 350
	hsplit.add_child(items_scroll)

	items_container = GridContainer.new()
	items_container.columns = 2
	items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_scroll.add_child(items_container)

	# Details panel
	item_details_panel = _create_details_panel()
	item_details_panel.custom_minimum_size.x = 220
	hsplit.add_child(item_details_panel)

	# Initial load
	call_deferred("_refresh_items")


func _create_details_panel() -> Control:
	var panel := PanelContainer.new()

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	panel_style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Thumbnail placeholder
	var thumb := TextureRect.new()
	thumb.name = "Thumbnail"
	thumb.custom_minimum_size = Vector2(200, 150)
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(thumb)

	# Title
	var title_label := Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Select a level"
	title_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title_label)

	# Author
	var author_label := Label.new()
	author_label.name = "AuthorLabel"
	author_label.text = ""
	author_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(author_label)

	# Description
	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.text = ""
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size.y = 80
	vbox.add_child(desc_label)

	# Stats
	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = ""
	stats_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(stats_label)

	# Buttons
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	var subscribe_btn := Button.new()
	subscribe_btn.name = "SubscribeBtn"
	subscribe_btn.text = "Subscribe"
	subscribe_btn.pressed.connect(_on_subscribe_pressed)
	btn_container.add_child(subscribe_btn)

	var play_btn := Button.new()
	play_btn.name = "PlayBtn"
	play_btn.text = "▶ Play"
	play_btn.pressed.connect(_on_play_pressed)
	play_btn.visible = false
	btn_container.add_child(play_btn)

	return panel


func _refresh_items() -> void:
	if workshop_manager and workshop_manager.has_method("browse_items"):
		var query: String = search_input.text if search_input else ""
		var tag_idx: int = tag_filter.selected if tag_filter else 0
		var tag: String = available_tags[tag_idx] if tag_idx > 0 else ""
		var tags: PackedStringArray = [tag] if not tag.is_empty() else []

		var sort_options: Array[String] = ["updated", "downloads", "rating"]
		var sort_idx: int = sort_option.selected if sort_option else 0
		var sort_by: String = sort_options[sort_idx]

		workshop_manager.browse_items(query, tags, sort_by)


func _on_items_loaded(items: Array[Dictionary]) -> void:
	current_items = []
	for item: Dictionary in items:
		current_items.append(item)
	_populate_items()


func _populate_items() -> void:
	# Clear existing
	for child: Node in items_container.get_children():
		child.queue_free()

	if current_items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No levels found.\nUpload one or check back later!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_container.add_child(empty_label)
		return

	for item: Dictionary in current_items:
		var card: Control = _create_item_card(item)
		items_container.add_child(card)


func _create_item_card(item: Dictionary) -> Control:
	var card := Button.new()
	card.custom_minimum_size = Vector2(160, 120) if is_grid_view else Vector2(320, 60)
	card.toggle_mode = true

	var item_id: String = item.get("item_id", "")
	card.set_meta("item_id", item_id)
	card.pressed.connect(_on_item_selected.bind(item_id))

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)

	var title := Label.new()
	title.text = item.get("title", "Untitled")
	title.add_theme_font_size_override("font_size", 12)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(title)

	var author := Label.new()
	author.text = "by " + item.get("author", "Unknown")
	author.add_theme_font_size_override("font_size", 10)
	author.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(author)

	# Check if subscribed
	if workshop_manager and workshop_manager.has_method("is_subscribed"):
		if workshop_manager.is_subscribed(item_id):
			var subscribed := Label.new()
			subscribed.text = "✓ Subscribed"
			subscribed.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
			vbox.add_child(subscribed)

	return card


func _on_item_selected(item_id: String) -> void:
	selected_item_id = item_id
	_update_details_panel()
	level_selected.emit(item_id)


func _update_details_panel() -> void:
	if selected_item_id.is_empty():
		return

	var item: Dictionary = {}
	for i: Dictionary in current_items:
		if i.get("item_id") == selected_item_id:
			item = i
			break

	if item.is_empty():
		return

	# Update UI elements
	var title_label: Label = item_details_panel.find_child("TitleLabel", true, false)
	if title_label:
		title_label.text = item.get("title", "")

	var author_label: Label = item_details_panel.find_child("AuthorLabel", true, false)
	if author_label:
		author_label.text = "by " + item.get("author", "Unknown")

	var desc_label: Label = item_details_panel.find_child("DescLabel", true, false)
	if desc_label:
		desc_label.text = item.get("description", "No description")

	var stats_label: Label = item_details_panel.find_child("StatsLabel", true, false)
	if stats_label:
		var downloads: int = item.get("downloads", 0)
		var rating: float = item.get("rating", 0.0)
		stats_label.text = "⬇ %d | ★ %.1f" % [downloads, rating]

	# Update buttons
	var subscribe_btn: Button = item_details_panel.find_child("SubscribeBtn", true, false)
	var play_btn: Button = item_details_panel.find_child("PlayBtn", true, false)

	var is_subscribed: bool = false
	if workshop_manager and workshop_manager.has_method("is_subscribed"):
		is_subscribed = workshop_manager.is_subscribed(selected_item_id)

	if subscribe_btn:
		subscribe_btn.text = "Unsubscribe" if is_subscribed else "Subscribe"

	if play_btn:
		play_btn.visible = is_subscribed


func _on_subscribe_pressed() -> void:
	if selected_item_id.is_empty() or not workshop_manager:
		return

	var is_subscribed: bool = workshop_manager.is_subscribed(selected_item_id)
	if is_subscribed:
		workshop_manager.unsubscribe(selected_item_id)
	else:
		workshop_manager.subscribe(selected_item_id)

	_update_details_panel()
	_populate_items()


func _on_play_pressed() -> void:
	if selected_item_id.is_empty() or not workshop_manager:
		return

	var local_path: String = workshop_manager.get_item_local_path(selected_item_id)
	if not local_path.is_empty():
		level_loaded.emit(local_path)


func _on_upload_pressed() -> void:
	# Show upload dialog
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = ["*.mdsl ; Level Packages"]
	dialog.title = "Select Level to Upload"
	dialog.file_selected.connect(_on_upload_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2(600, 400))


func _on_upload_file_selected(path: String) -> void:
	if not workshop_manager:
		return

	# Read manifest for defaults
	var manifest: LevelPackager.LevelManifest = LevelPackager.read_manifest(path)
	if manifest:
		_show_upload_details_dialog(path, manifest)


func _show_upload_details_dialog(level_path: String, manifest: LevelPackager.LevelManifest) -> void:
	## Show dialog to edit upload metadata before uploading
	var dialog := AcceptDialog.new()
	dialog.title = "Upload to Workshop"
	dialog.dialog_text = ""
	dialog.min_size = Vector2(500, 450)
	
	# Create form layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	dialog.add_child(vbox)
	
	# Add warning about local-only mode if Steam not available
	if not workshop_manager.steam_available:
		var warning_panel := PanelContainer.new()
		var warning_label := Label.new()
		warning_label.text = (
			"⚠️ Steam Workshop not available - uploading to local workshop only.\n"
			+ "Real Steam Workshop upload requires Steam integration (planned for v1.1)."
		)
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))  # Yellow warning
		warning_panel.add_child(warning_label)
		vbox.add_child(warning_panel)
	
	# Title field
	var title_label := Label.new()
	title_label.text = "Title:"
	vbox.add_child(title_label)
	
	var title_edit := LineEdit.new()
	title_edit.text = manifest.name
	title_edit.placeholder_text = "Enter level title"
	vbox.add_child(title_edit)
	
	# Description field
	var desc_label := Label.new()
	desc_label.text = "Description:"
	vbox.add_child(desc_label)
	
	var desc_edit := TextEdit.new()
	desc_edit.text = manifest.description
	desc_edit.placeholder_text = "Enter level description"
	desc_edit.custom_minimum_size = Vector2(0, 100)
	vbox.add_child(desc_edit)
	
	# Tags field
	var tags_label := Label.new()
	tags_label.text = "Tags (comma-separated):"
	vbox.add_child(tags_label)
	
	var tags_edit := LineEdit.new()
	tags_edit.text = ",".join(manifest.tags)
	tags_edit.placeholder_text = "e.g. deathmatch, arena, small"
	vbox.add_child(tags_edit)
	
	# Visibility option
	var visibility_label := Label.new()
	visibility_label.text = "Visibility:"
	vbox.add_child(visibility_label)
	
	var visibility_option := OptionButton.new()
	visibility_option.add_item("Public", 0)
	visibility_option.add_item("Friends Only", 1)
	visibility_option.add_item("Private", 2)
	vbox.add_child(visibility_option)
	
	# Connect OK button
	dialog.confirmed.connect(func() -> void:
		var title: String = title_edit.text.strip_edges()
		var description: String = desc_edit.text.strip_edges()
		var tags_str: String = tags_edit.text.strip_edges()
		var tags: Array[String] = []
		
		# Parse tags
		if not tags_str.is_empty():
			for tag in tags_str.split(","):
				var clean_tag := tag.strip_edges()
				if not clean_tag.is_empty():
					tags.append(clean_tag)
		
		# Validate
		if title.is_empty():
			push_error("[WorkshopBrowser] Title cannot be empty")
			return
		
		# Upload with metadata
		workshop_manager.upload_level(level_path, title, description, tags)
		_log("[WorkshopBrowser] Uploading: %s" % title, "Log")
	)
	
	add_child(dialog)
	dialog.popup_centered()


func _on_download_completed(item_id: String, success: bool, _local_path: String) -> void:
	if success:
		_log(str("[WorkshopBrowser] Downloaded: %s" % item_id), "Log")
		_update_details_panel()
		_populate_items()


func _on_upload_completed(item_id: String, success: bool) -> void:
	if success:
		_log(str("[WorkshopBrowser] Uploaded: %s" % item_id), "Log")
		_refresh_items()


func _on_search_submitted(_text: String) -> void:
	_refresh_items()


func _on_filter_changed(_index: int) -> void:
	_refresh_items()


func _on_sort_changed(_index: int) -> void:
	_refresh_items()


func _toggle_view() -> void:
	is_grid_view = not is_grid_view
	if items_container is GridContainer:
		items_container.columns = 2 if is_grid_view else 1
	_populate_items()
