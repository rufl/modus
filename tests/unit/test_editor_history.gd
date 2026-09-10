extends ModusGutTestBase

const EditorGlobalsScript := preload("res://shared/editor_core/core/editor_globals.gd")
const PaintBrushScript := preload("res://shared/editor_core/tools/paint_brush.gd")
const TransformInspectorScript := preload(
	"res://shared/editor_core/gizmos/entity_transform_inspector.gd"
)

const SelectionManagerScript := preload("res://shared/editor_core/core/selection_manager.gd")
const EditorStateScript := preload("res://shared/editor_core/core/editor_state.gd")
const LevelSaveSystemScript := preload("res://shared/editor_core/data/level_save_system.gd")
const VisualScriptEditorScript := preload(
	"res://shared/editor_core/scripting/visual_script_editor.gd"
)
const EmbeddedLevelEditorScript := preload("res://game/editor/embedded_level_editor.gd")
const ToolbarDockScript := preload("res://shared/editor_core/ui/toolbar_dock.gd")
const HotbarScript := preload("res://shared/editor_core/ui/hotbar.gd")



func before_each() -> void:
	await modus_setup()
	EditorGlobalsScript._runtime_undo_redo = null


func after_each() -> void:
	EditorGlobalsScript._runtime_undo_redo = null
	modus_teardown()


func test_standalone_block_placement_supports_undo_and_redo() -> void:
	var level_root := Node3D.new()
	add_child_autofree(level_root)
	var brush: BlockBrush = BlockBrush.new()

	var block: CSGShape3D = brush.place_block(Vector3.ZERO, level_root)
	assert_not_null(block, "Standalone placement should create a block")
	assert_eq(level_root.get_child_count(), 1, "Placement should add one live block")

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Standalone placement should create an undo action")
	undo.undo()
	assert_eq(level_root.get_child_count(), 0, "Undo should remove the placed block")
	assert_true(undo.has_redo(), "Undo should expose redo")
	undo.redo()
	assert_eq(level_root.get_child_count(), 1, "Redo should restore the placed block")

	brush = null


func test_standalone_erase_supports_undo() -> void:
	var level_root := Node3D.new()
	add_child_autofree(level_root)
	var target := Node3D.new()
	level_root.add_child(target)
	var eraser: EraserBrush = EraserBrush.new()

	eraser._erase_node(target)
	assert_eq(level_root.get_child_count(), 0, "Erase should remove the target")

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Standalone erase should create an undo action")
	undo.undo()
	assert_eq(level_root.get_child_count(), 1, "Undo should restore the erased target")


func test_standalone_paint_supports_undo_and_redo() -> void:
	var target := CSGBox3D.new()
	add_child_autofree(target)
	var brush: PaintBrush = PaintBrush.new()
	brush.set_material(StandardMaterial3D.new())

	brush._apply_material(target, Vector3.UP)
	assert_not_null(target.material, "Paint should apply a material")

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Standalone paint should create an undo action")
	undo.undo()
	assert_null(target.material, "Undo should restore the original material")
	undo.redo()
	assert_not_null(target.material, "Redo should restore the painted material")


func test_standalone_transform_preset_supports_undo_and_redo() -> void:
	var target := Node3D.new()
	add_child_autofree(target)
	TransformInspectorScript._on_rotation_preset(target, 90)
	assert_eq(target.rotation_degrees.y, 90.0, "Transform preset should apply rotation")
	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Transform preset should create an undo action")
	undo.undo()
	assert_eq(target.rotation_degrees, Vector3.ZERO, "Undo should restore the original rotation")
	undo.redo()
	assert_eq(target.rotation_degrees.y, 90.0, "Redo should restore the preset rotation")


func test_standalone_scale_flip_and_reset_support_history() -> void:
	var target := Node3D.new()
	add_child_autofree(target)

	TransformInspectorScript._on_scale_preset(target, 2.0)
	assert_eq(target.scale, Vector3.ONE * 2.0)
	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.undo()
	assert_eq(target.scale, Vector3.ONE)
	undo.redo()
	assert_eq(target.scale, Vector3.ONE * 2.0)

	TransformInspectorScript._on_flip(target, Vector3(-1, 1, 1))
	assert_eq(target.scale, Vector3(-2, 2, 2))
	undo.undo()
	assert_eq(target.scale, Vector3.ONE * 2.0)

	target.rotation_degrees = Vector3(10, 20, 30)
	TransformInspectorScript._on_reset_transform(target)
	assert_eq(target.rotation_degrees, Vector3.ZERO)
	assert_eq(target.scale, Vector3.ONE)
	undo.undo()
	assert_true(
		target.rotation_degrees.is_equal_approx(Vector3(10, 20, 30)),
		"Undo should restore the prior rotation"
	)
	assert_eq(target.scale, Vector3.ONE * 2.0)


func test_standalone_selection_move_and_delete_support_history() -> void:
	var level_root := Node3D.new()
	add_child_autofree(level_root)
	var target := Node3D.new()
	level_root.add_child(target)
	var manager: Node = SelectionManagerScript.new()
	add_child_autofree(manager)

	manager.select(target)
	manager.move_selection(Vector3(2, 0, 0))
	assert_eq(target.position, Vector3(2, 0, 0))

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.undo()
	assert_eq(target.position, Vector3.ZERO, "Undo should restore the selected node position")
	undo.redo()
	assert_eq(target.position, Vector3(2, 0, 0), "Redo should restore the move")

	manager.delete_selected()
	assert_eq(level_root.get_child_count(), 0, "Delete should remove the selected node")
	undo.undo()
	assert_eq(level_root.get_child_count(), 1, "Undo should restore the deleted node")


func test_standalone_paste_uses_clipboard_centroid_and_history() -> void:
	var source_root := Node3D.new()
	add_child_autofree(source_root)
	var first := CSGBox3D.new()
	first.position = Vector3(10, 0, 0)
	source_root.add_child(first)
	var second := CSGBox3D.new()
	second.position = Vector3(20, 0, 0)
	source_root.add_child(second)
	var manager: Node = SelectionManagerScript.new()
	add_child_autofree(manager)

	var selected: Array[Node3D] = [first, second]
	manager.select_multiple(selected)
	manager.copy()
	var pasted: Array[Node3D] = manager.paste(Vector3(100, 0, 0), source_root)
	await get_tree().process_frame
	assert_true(pasted[0].global_position.is_equal_approx(Vector3(95, 0, 0)))
	assert_true(pasted[1].global_position.is_equal_approx(Vector3(105, 0, 0)))

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	assert_true(undo.has_undo(), "Paste should create an undo action")
	undo.undo()
	assert_eq(source_root.get_child_count(), 2, "Undo should remove all pasted nodes")
	manager.clear_selection()
	await get_tree().process_frame


func test_standalone_duplicate_uses_offset_and_history() -> void:
	var source_root := Node3D.new()
	add_child_autofree(source_root)
	var first := CSGBox3D.new()
	first.position = Vector3(10, 0, 0)
	source_root.add_child(first)
	var second := CSGBox3D.new()
	second.position = Vector3(20, 0, 0)
	source_root.add_child(second)
	var manager: Node = SelectionManagerScript.new()
	add_child_autofree(manager)
	var selected: Array[Node3D] = [first, second]
	manager.select_multiple(selected)

	var duplicated: Array[Node3D] = manager.duplicate_selection(Vector3(1, 0, 1))
	await get_tree().process_frame
	assert_eq(duplicated.size(), 2, "Duplicate should create both selected nodes")
	assert_true(duplicated[0].global_position.is_equal_approx(Vector3(11, 0, 1)))
	assert_true(duplicated[1].global_position.is_equal_approx(Vector3(21, 0, 1)))
	assert_eq(source_root.get_child_count(), 4)

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.undo()
	manager.clear_selection()
	await get_tree().process_frame
	assert_eq(source_root.get_child_count(), 2, "Undo should remove duplicated nodes")


func test_editor_state_block_placement_uses_runtime_history() -> void:
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	EditorGlobalsScript.set_runtime_root(scene_root)
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	state.selected_asset = {"id": "block"}
	state.hover_position = Vector3(3, 0, 0)

	assert_eq(state._apply_block_brush(), 1)
	await get_tree().process_frame
	assert_eq(scene_root.get_child_count(), 1, "EditorState should place one block")

	var undo: UndoRedo = EditorGlobalsScript.get_undo_redo()
	undo.undo()
	assert_eq(scene_root.get_child_count(), 0, "Undo should remove the EditorState block")
	EditorGlobalsScript.set_runtime_root(null)


func test_level_save_load_requires_editor_interface_in_runtime() -> void:
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	var save_system: RefCounted = LevelSaveSystemScript.new()
	save_system.setup(scene_root)
	assert_true(save_system.save_level(LevelSaveSystemScript.QUICKSAVE_PATH, false))
	assert_false(save_system.quick_load(), "Runtime mode must not call EditorInterface")
	assert_false(save_system.load_level(LevelSaveSystemScript.QUICKSAVE_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LevelSaveSystemScript.QUICKSAVE_PATH))


func test_visual_script_selection_is_runtime_safe() -> void:
	var editor: Control = VisualScriptEditorScript.new()
	add_child_autofree(editor)
	await get_tree().process_frame
	var source := Node.new()
	add_child_autofree(source)
	editor.connection_list.add_item("runtime")
	editor.connection_list.set_item_metadata(0, {"source": source, "channel": "test"})

	var selected: Array[Dictionary] = []
	editor.connection_selected.connect(func(meta: Dictionary) -> void: selected.append(meta))
	editor._on_connection_selected(0)

	assert_eq(selected.size(), 1)
	assert_eq(selected[0].source, source)


func test_editor_state_entity_placement_uses_history() -> void:
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	EditorGlobalsScript.set_runtime_root(scene_root)
	var template := Node3D.new()
	var packed := PackedScene.new()
	assert_eq(packed.pack(template), OK)
	template.free()

	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	state.selected_asset = {"id": "crate", "scene": packed}
	state.hover_position = Vector3(4, 0, 0)
	state._preview_rotation = PI / 2.0

	assert_eq(state._apply_entity_placer(), 1)
	await get_tree().process_frame
	assert_eq(scene_root.get_child_count(), 1)
	assert_true(scene_root.get_child(0).get_meta("level_editor_placed"))
	assert_true(scene_root.get_child(0).position.is_equal_approx(Vector3(4, 0, 0)))
	EditorGlobalsScript.get_undo_redo().undo()
	assert_eq(scene_root.get_child_count(), 0)
	EditorGlobalsScript.set_runtime_root(null)


func test_editor_state_spawn_point_history_and_invalid_type() -> void:
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	EditorGlobalsScript.set_runtime_root(scene_root)
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	state.selected_asset = {"spawn_type": "player"}
	state._apply_spawn_point()
	await get_tree().process_frame
	assert_eq(scene_root.get_child_count(), 1)
	assert_eq(scene_root.get_child(0).name, "PlayerSpawn")
	EditorGlobalsScript.get_undo_redo().undo()
	assert_eq(scene_root.get_child_count(), 0)

	state.selected_asset = {"spawn_type": "unknown"}
	assert_eq(state._apply_spawn_point(), 0)
	assert_eq(scene_root.get_child_count(), 0)
	EditorGlobalsScript.set_runtime_root(null)


func test_editor_state_tool_navigation_emits_changes() -> void:
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	var emitted: Array[int] = []
	state.tool_changed.connect(
		func(tool_type: EditorStateScript.ToolType) -> void: emitted.append(tool_type)
	)

	state.select_tool(EditorStateScript.ToolType.BLOCK_BRUSH)
	state.next_tool()
	state.previous_tool()

	assert_eq(
		emitted,
		[
			EditorStateScript.ToolType.BLOCK_BRUSH,
			EditorStateScript.ToolType.PAINT_BRUSH,
			EditorStateScript.ToolType.BLOCK_BRUSH
		]
	)


func test_editor_state_brush_size_shortcut_stays_positive() -> void:
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	state.select_tool(EditorStateScript.ToolType.BLOCK_BRUSH)
	state.set_editing_mode(true)

	var decrease := InputEventKey.new()
	decrease.pressed = true
	decrease.keycode = KEY_BRACKETLEFT
	state.handle_3d_input(null, decrease, null)
	assert_eq(state.brush_size, Vector3i.ONE)

	var increase := InputEventKey.new()
	increase.pressed = true
	increase.keycode = KEY_BRACKETRIGHT
	state.handle_3d_input(null, increase, null)
	assert_eq(state.brush_size, Vector3i(2, 2, 2))


func test_editor_state_escape_clears_tool_and_emits_change() -> void:
	var state: Node = EditorStateScript.new()
	add_child_autofree(state)
	var emitted: Array[int] = []
	state.tool_changed.connect(
		func(tool_type: EditorStateScript.ToolType) -> void: emitted.append(tool_type)
	)
	state.select_tool(EditorStateScript.ToolType.BLOCK_BRUSH)
	state.set_editing_mode(true)

	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	state.handle_3d_input(null, escape, null)

	assert_eq(state.current_tool, EditorStateScript.ToolType.NONE)
	assert_eq(emitted.back(), EditorStateScript.ToolType.NONE)


func test_embedded_editor_save_load_round_trip() -> void:
	var editor: Node = EmbeddedLevelEditorScript.new()
	var level_root := Node3D.new()
	editor.level_root = level_root
	add_child_autofree(level_root)

	var saved: Array[String] = []
	var loaded: Array[String] = []
	editor.level_saved.connect(func(path: String) -> void: saved.append(path))
	editor.level_loaded.connect(func(path: String) -> void: loaded.append(path))

	var path := "user://embedded_editor_lifecycle_test.tscn"
	editor.save_level(path)
	assert_eq(saved, [path])
	level_root.add_child(Node3D.new())
	editor.load_level(path)
	assert_eq(loaded, [path])
	assert_eq(level_root.get_child_count(), 0)
	editor.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_editor_toolbar_and_hotbar_build_runtime_controls() -> void:
	var toolbar: HBoxContainer = ToolbarDockScript.new()
	toolbar._create_toolbar()
	assert_eq(toolbar.tool_buttons.size(), 7)
	assert_not_null(toolbar.get_node_or_null("GridSizeLabel"))
	toolbar.free()

	var hotbar: HBoxContainer = HotbarScript.new()
	hotbar._init_slots()
	hotbar._create_ui()
	assert_eq(hotbar.primary_buttons.size(), HotbarScript.MAX_SLOTS)
	assert_eq(hotbar.secondary_buttons.size(), HotbarScript.MAX_SLOTS)
	assert_eq(hotbar.primary_buttons[0].name, "Button")
	hotbar.free()
