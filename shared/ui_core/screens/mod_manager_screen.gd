class_name ModManagerScreen
extends BaseScreen

const LEGACY_MOD_MANAGER: String = "res://game/ui/menus/mod_manager_ui.tscn"

var _mod_manager_instance: Control = null
var _back_btn: Button = null


func _on_ready() -> void:
	_build_ui()
	_load_legacy_manager()


func _on_screen_enter(_params: Dictionary) -> void:
	if _mod_manager_instance and _mod_manager_instance.has_method("show_manager"):
		_mod_manager_instance.show_manager()

	if _back_btn:
		_back_btn.grab_focus()


# ============================================================================
# UI BUILDING
# ============================================================================


func _build_ui() -> void:
	# Background overlay
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Container for content
	var container: VBoxContainer = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.anchor_left = 0.05
	container.anchor_right = 0.95
	container.anchor_top = 0.05
	container.anchor_bottom = 0.95
	container.add_theme_constant_override("separation", 16)
	add_child(container)

	# Title
	var title: Label = Label.new()
	title.text = _tr("menu_mods", "Mod Manager")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	container.add_child(title)

	# Content area for legacy manager
	var content_area: Control = Control.new()
	content_area.name = "ContentArea"
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(content_area)

	# Back button
	var btn_container: HBoxContainer = HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(btn_container)

	_back_btn = _create_button("menu_back", "Back")
	_back_btn.pressed.connect(go_back)
	btn_container.add_child(_back_btn)


func _request_back() -> void:
	# Check if we are in a modal layer
	if get_parent() and get_parent().name == "UIModalLayer":
		var ui_svc := UISystem.get_service()
		if ui_svc and ui_svc.ui_manager:
			ui_svc.ui_manager.dismiss_modal()
	else:
		super._request_back()


func _load_legacy_manager() -> void:
	if not ResourceLoader.exists(LEGACY_MOD_MANAGER):
		var placeholder: Label = Label.new()
		placeholder.text = "Mod Manager not available"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var content_area: Control = find_child("ContentArea", true, false)
		if content_area:
			content_area.add_child(placeholder)
		return

	var scene: PackedScene = load(LEGACY_MOD_MANAGER)
	if scene:
		_mod_manager_instance = scene.instantiate()

		# Add to content area
		var content_area: Control = find_child("ContentArea", true, false)
		if content_area:
			content_area.add_child(_mod_manager_instance)
			_mod_manager_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
		else:
			add_child(_mod_manager_instance)


func _create_button(loc_key: String, fallback: String) -> Button:
	var btn: Button
	if ClassDB.class_exists("CustomButton"):
		btn = CustomButton.new()
	else:
		btn = Button.new()

	btn.text = _tr(loc_key, fallback)
	btn.custom_minimum_size = Vector2(120, 40)
	return btn


func _tr(key: String, fallback: String) -> String:
	var localization: Node = GameManager.get_core_system("localization")
	if localization and localization.has_method("translate"):
		var translated: String = localization.translate(key)
		return translated if translated != key else fallback
	return fallback
