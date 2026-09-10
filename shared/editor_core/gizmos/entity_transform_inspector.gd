@tool
extends EditorInspectorPlugin

var entity_transform_control: Control = null


func _can_handle(object: Object) -> bool:
	if not object is Node3D:
		return false

	# Handle nodes placed by level editor
	if object.has_meta("level_editor_placed"):
		return true

	# Handle SpawnPoints
	if object.get_script():
		var path: String = object.get_script().resource_path
		if path.contains("spawn_point.gd"):
			return true

	return false


func _parse_begin(object: Object) -> void:
	if not object is Node3D:
		return

	entity_transform_control = _create_transform_control(object as Node3D)
	add_custom_control(entity_transform_control)


func _create_transform_control(node: Node3D) -> Control:
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# Title
	var title := Label.new()
	title.text = "🎯 Quick Transform"
	title.add_theme_font_size_override("font_size", 12)
	container.add_child(title)

	# Rotation section
	var rot_label := Label.new()
	rot_label.text = "Rotation"
	rot_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	rot_label.add_theme_font_size_override("font_size", 11)
	container.add_child(rot_label)

	var rot_hbox := HBoxContainer.new()
	rot_hbox.add_theme_constant_override("separation", 2)
	container.add_child(rot_hbox)

	# Rotation preset buttons
	var angles := [0, 45, 90, 135, 180, 225, 270, 315]
	for angle in angles:
		var btn := Button.new()
		btn.text = "%d°" % angle
		btn.custom_minimum_size = Vector2(32, 24)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_on_rotation_preset.bind(node, angle))
		rot_hbox.add_child(btn)

	# Rotation fine control
	var rot_fine := HBoxContainer.new()
	container.add_child(rot_fine)

	var rot_minus := Button.new()
	rot_minus.text = "↺ -15°"
	rot_minus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_minus.pressed.connect(_on_rotate.bind(node, -15))
	rot_fine.add_child(rot_minus)

	var rot_plus := Button.new()
	rot_plus.text = "+15° ↻"
	rot_plus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_plus.pressed.connect(_on_rotate.bind(node, 15))
	rot_fine.add_child(rot_plus)

	# Scale section
	container.add_child(HSeparator.new())

	var scale_label := Label.new()
	scale_label.text = "Scale Presets"
	scale_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	scale_label.add_theme_font_size_override("font_size", 11)
	container.add_child(scale_label)

	var scale_hbox := HBoxContainer.new()
	scale_hbox.add_theme_constant_override("separation", 2)
	container.add_child(scale_hbox)

	# Scale preset buttons
	var scales := [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
	for s in scales:
		var btn := Button.new()
		btn.text = "%.2fx" % s if s != 1.0 else "1x"
		btn.custom_minimum_size = Vector2(40, 24)
		btn.add_theme_font_size_override("font_size", 10)
		btn.pressed.connect(_on_scale_preset.bind(node, s))
		scale_hbox.add_child(btn)

	# Uniform scale slider
	var slider_hbox := HBoxContainer.new()
	container.add_child(slider_hbox)

	var slider_label := Label.new()
	slider_label.text = "Uniform:"
	slider_hbox.add_child(slider_label)

	var scale_slider := HSlider.new()
	scale_slider.min_value = 0.1
	scale_slider.max_value = 3.0
	scale_slider.step = 0.1
	scale_slider.value = node.scale.x
	scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_slider.value_changed.connect(_on_scale_slider.bind(node))
	slider_hbox.add_child(scale_slider)

	var scale_value := Label.new()
	scale_value.text = "%.1f" % node.scale.x
	scale_value.custom_minimum_size.x = 30
	scale_value.name = "ScaleValue"
	slider_hbox.add_child(scale_value)

	# Flip buttons
	var flip_hbox := HBoxContainer.new()
	container.add_child(flip_hbox)

	var flip_x := Button.new()
	flip_x.text = "Flip X"
	flip_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flip_x.pressed.connect(_on_flip.bind(node, Vector3(-1, 1, 1)))
	flip_hbox.add_child(flip_x)

	var flip_z := Button.new()
	flip_z.text = "Flip Z"
	flip_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flip_z.pressed.connect(_on_flip.bind(node, Vector3(1, 1, -1)))
	flip_hbox.add_child(flip_z)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_on_reset_transform.bind(node))
	flip_hbox.add_child(reset_btn)

	return container


static func _on_rotation_preset(node: Node3D, angle: int) -> void:
	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Set Rotation")
	undo.add_do_property(node, "rotation_degrees", Vector3(0, angle, 0))
	undo.add_undo_property(node, "rotation_degrees", node.rotation_degrees)
	undo.commit_action()


func _on_rotate(node: Node3D, delta: int) -> void:
	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	var new_rot := node.rotation_degrees + Vector3(0, delta, 0)
	undo.create_action("Rotate")
	undo.add_do_property(node, "rotation_degrees", new_rot)
	undo.add_undo_property(node, "rotation_degrees", node.rotation_degrees)
	undo.commit_action()


static func _on_scale_preset(node: Node3D, scale_value: float) -> void:
	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Set Scale")
	undo.add_do_property(node, "scale", Vector3.ONE * scale_value)
	undo.add_undo_property(node, "scale", node.scale)
	undo.commit_action()


func _on_scale_slider(value: float, node: Node3D) -> void:
	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Scale")
	undo.add_do_property(node, "scale", Vector3.ONE * value)
	undo.add_undo_property(node, "scale", node.scale)
	undo.commit_action()

	# Update label
	if entity_transform_control:
		var label := entity_transform_control.find_child("ScaleValue", true, false)
		if label is Label:
			label.text = "%.1f" % value


static func _on_flip(node: Node3D, axis: Vector3) -> void:
	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Flip")
	undo.add_do_property(node, "scale", node.scale * axis)
	undo.add_undo_property(node, "scale", node.scale)
	undo.commit_action()


static func _on_reset_transform(node: Node3D) -> void:
	var undo: UndoRedo = EditorGlobals.get_undo_redo()
	undo.create_action("Reset Transform")
	undo.add_do_property(node, "rotation_degrees", Vector3.ZERO)
	undo.add_do_property(node, "scale", Vector3.ONE)
	undo.add_undo_property(node, "rotation_degrees", node.rotation_degrees)
	undo.add_undo_property(node, "scale", node.scale)
	undo.commit_action()
