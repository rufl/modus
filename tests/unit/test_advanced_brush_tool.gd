extends ModusGutTestBase

const AdvancedBrushToolScript := preload("res://game/editor/advanced_brush_tool.gd")

var brush: AdvancedBrushTool


func before_each() -> void:
	brush = AdvancedBrushToolScript.new()
	add_child(brush)


func after_each() -> void:
	brush.free()


func test_hollow_primitives_build_union_and_subtraction_tree() -> void:
	brush.hollow_brush = true
	brush.hollow_thickness = 0.1
	brush.brush_size = Vector3(4.0, 2.0, 4.0)
	var material := StandardMaterial3D.new()
	brush.brush_material = material

	for type in [
		AdvancedBrushTool.BrushType.CUBE,
		AdvancedBrushTool.BrushType.SPHERE,
		AdvancedBrushTool.BrushType.CYLINDER,
		AdvancedBrushTool.BrushType.CONE,
		AdvancedBrushTool.BrushType.TORUS
	]:
		brush.brush_type = type
		var placed := brush._place_brush_object(Vector3(2.0, 3.0, 4.0))
		assert_true(placed, "Hollow primitive %s should be placed" % type)
		var hollow := brush.get_child(brush.get_child_count() - 1) as CSGCombiner3D
		assert_not_null(hollow, "Hollow primitive %s should use a CSG combiner" % type)
		assert_eq(hollow.get_child_count(), 2, "Hollow primitive %s should have two CSG operands" % type)
		var outer := hollow.get_child(0) as CSGShape3D
		var inner := hollow.get_child(1) as CSGShape3D
		assert_eq(hollow.operation, CSGShape3D.OPERATION_UNION)
		assert_eq(outer.operation, CSGShape3D.OPERATION_UNION)
		assert_eq(inner.operation, CSGShape3D.OPERATION_SUBTRACTION)
		assert_eq(hollow.position, Vector3(2.0, 3.0, 4.0))
		assert_eq(outer.material, material)
		assert_eq(inner.material, material)
		hollow.free()


func test_hollow_torus_reduces_tube_by_wall_thickness() -> void:
	brush.brush_type = AdvancedBrushTool.BrushType.TORUS
	brush.brush_size = Vector3(4.0, 2.0, 4.0)
	brush.hollow_brush = true
	brush.hollow_thickness = 0.1

	var hollow := brush._create_brush_shape(brush.brush_type)
	assert_true(hollow is CSGCombiner3D)
	var outer := hollow.get_child(0) as CSGTorus3D
	var inner := hollow.get_child(1) as CSGTorus3D
	assert_almost_eq(inner.inner_radius, outer.inner_radius + 0.1, 0.00001)
	assert_almost_eq(inner.outer_radius, outer.outer_radius - 0.1, 0.00001)
	hollow.free()


func test_hollow_preserves_primitive_transform_and_material() -> void:
	brush.brush_type = AdvancedBrushTool.BrushType.CUBE
	brush.hollow_thickness = 0.1
	var material := StandardMaterial3D.new()
	var outer := CSGBox3D.new()
	outer.size = Vector3(4.0, 4.0, 4.0)
	outer.position = Vector3(1.0, 2.0, 3.0)
	outer.rotation = Vector3(0.1, 0.2, 0.3)
	outer.scale = Vector3(2.0, 1.0, 0.5)
	outer.material = material

	var hollow := brush._create_hollow_shape(outer) as CSGCombiner3D
	var inner := hollow.get_child(1) as CSGBox3D
	assert_eq(inner.transform, outer.transform)
	assert_eq(inner.material, material)
	assert_eq(hollow.material, material)
	hollow.free()


func test_hollow_polygon_and_custom_mesh_fail_without_orphan_nodes() -> void:
	brush.hollow_brush = true
	brush.hollow_thickness = 0.1
	brush.brush_size = Vector3(4.0, 2.0, 4.0)
	var initial_child_count := brush.get_child_count()

	for type in [
		AdvancedBrushTool.BrushType.PYRAMID,
		AdvancedBrushTool.BrushType.WEDGE,
		AdvancedBrushTool.BrushType.STAIRCASE,
		AdvancedBrushTool.BrushType.ARCH,
		AdvancedBrushTool.BrushType.CAPSULE
	]:
		brush.brush_type = type
		assert_false(brush._place_brush_object(Vector3.ZERO), "Unsupported hollow type %s should fail" % type)
		assert_eq(
			brush.get_child_count(),
			initial_child_count,
			"Unsupported hollow type %s should not add an orphan node" % type
		)
