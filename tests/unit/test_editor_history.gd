extends ModusGutTestBase

const EditorGlobalsScript := preload("res://shared/editor_core/core/editor_globals.gd")
const PaintBrushScript := preload("res://shared/editor_core/tools/paint_brush.gd")
const TransformInspectorScript := preload(
	"res://shared/editor_core/gizmos/entity_transform_inspector.gd"
)

const SelectionManagerScript := preload("res://shared/editor_core/core/selection_manager.gd")


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
