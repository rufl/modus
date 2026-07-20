#!/usr/bin/env -S godot --headless --script
## Simple validation script for AdvancedGeometryBuilder
## Tests basic functionality without requiring full GUT framework

extends SceneTree

var _passed := 0
var _failed := 0


func _init() -> void:
	print("\n=== Validating Advanced Geometry Builder ===\n")

	test_basic_slope_creation()
	test_3d_floor_creation()
	test_udmf_parsing()
	test_csg_integration()
	test_navigation_mesh_integration()

	print("\n=== Validation Results ===")
	print("Passed: ", _passed)
	print("Failed: ", _failed)

	if _failed == 0:
		print("✓ All validation tests passed!")
		quit(0)
	else:
		print("✗ Some tests failed")
		quit(1)


func test_basic_slope_creation() -> void:
	print("Test: Basic Slope Creation")

	var context := _create_test_context()
	var csg_root := CSGCombiner3D.new()

	var builder := AdvancedGeometryBuilder.new()
	builder.initialize(context, csg_root)

	# Add slopes
	builder.add_floor_slope(Vector2i(5, 5), deg_to_rad(30.0), Vector2(1, 0))
	builder.add_ceiling_slope(Vector2i(6, 6), deg_to_rad(25.0), Vector2(0, 1))

	# Build
	builder.build_advanced_geometry()

	# Verify
	var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
	if slopes_node and slopes_node.get_child_count() == 2:
		print("  ✓ Slopes created successfully")
		_passed += 1
	else:
		print("  ✗ Failed to create slopes")
		_failed += 1

	csg_root.free()


func test_3d_floor_creation() -> void:
	print("Test: 3D Floor Creation")

	var context := _create_test_context()
	var csg_root := CSGCombiner3D.new()

	var builder := AdvancedGeometryBuilder.new()
	builder.initialize(context, csg_root)

	# Add 3D floors
	builder.add_3d_floor(Vector2i(3, 3), 1.5)
	builder.add_3d_floor(Vector2i(4, 4), 2.0, 0.3)

	# Build
	builder.build_advanced_geometry()

	# Verify
	var platforms_node := csg_root.get_node_or_null("3DFloors")
	if platforms_node and platforms_node.get_child_count() == 2:
		var platform1 := platforms_node.get_child(0) as CSGBox3D
		var platform2 := platforms_node.get_child(1) as CSGBox3D

		if (
			platform1
			and platform2
			and abs(platform1.position.y - 1.5) < 0.01
			and abs(platform2.position.y - 2.0) < 0.01
		):
			print("  ✓ 3D floors created successfully")
			_passed += 1
		else:
			print("  ✗ 3D floor positions incorrect")
			_failed += 1
	else:
		print("  ✗ Failed to create 3D floors")
		_failed += 1

	csg_root.free()


func test_udmf_parsing() -> void:
	print("Test: UDMF Parsing")

	var context := _create_test_context()
	var csg_root := CSGCombiner3D.new()

	var builder := AdvancedGeometryBuilder.new()
	builder.initialize(context, csg_root)

	# Parse UDMF formats
	builder.parse_udmf_slope("angle:30,1,0", Vector2i(2, 2), false)
	builder.parse_udmf_slope("plane:0,0,0,0.5,0.866,0", Vector2i(3, 3), true)

	# Build
	builder.build_advanced_geometry()

	# Verify
	var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
	if slopes_node and slopes_node.get_child_count() == 2:
		print("  ✓ UDMF parsing successful")
		_passed += 1
	else:
		print("  ✗ UDMF parsing failed")
		_failed += 1

	csg_root.free()


func test_csg_integration() -> void:
	print("Test: CSG Builder Integration")

	var context := _create_test_context()

	var csg_builder := CSGGeometryBuilder.new()
	csg_builder.initialize(context)

	# Add through CSG builder interface
	csg_builder.add_floor_slope(Vector2i(5, 5), 30.0, Vector2(1, 0))
	csg_builder.add_3d_floor(Vector2i(7, 7), 1.5)

	# Build
	var csg_root := csg_builder.build_geometry()

	# Verify
	if csg_root:
		var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
		var platforms_node := csg_root.get_node_or_null("3DFloors")

		if (
			slopes_node
			and platforms_node
			and slopes_node.get_child_count() == 1
			and platforms_node.get_child_count() == 1
		):
			print("  ✓ CSG integration successful")
			_passed += 1
		else:
			print("  ✗ CSG integration failed - geometry not created")
			_failed += 1

		csg_root.free()
	else:
		print("  ✗ CSG integration failed - no root")
		_failed += 1


func test_navigation_mesh_integration() -> void:
	print("Test: Navigation Mesh Integration")

	var context := _create_test_context()

	var csg_builder := CSGGeometryBuilder.new()
	csg_builder.initialize(context)
	csg_builder.add_floor_slope(Vector2i(5, 5), 30.0, Vector2(1, 0))

	var csg_root := csg_builder.build_geometry()

	if csg_root:
		# Create navigation mesh baker
		var nav_baker := NavigationMeshBaker.new()
		nav_baker.initialize(context)

		# Check that navigation mesh can be configured
		var nav_mesh := nav_baker.get_navigation_mesh()
		if nav_mesh:
			print("  ✓ Navigation mesh integration successful")
			_passed += 1
		else:
			print("  ✗ Navigation mesh integration failed")
			_failed += 1

		csg_root.free()
	else:
		print("  ✗ Navigation mesh integration failed - no geometry")
		_failed += 1


func _create_test_context() -> GenerationContext:
	var context := GenerationContext.new()

	var grid_size := Vector2i(16, 16)
	context.grid_size = grid_size
	context.grid = []

	for y in range(grid_size.y):
		var row: Array[Cell] = []
		for x in range(grid_size.x):
			var cell := Cell.new(Cell.Type.ROOM)
			row.append(cell)
		context.grid.append(row)

	var config := GenerationConfig.new()
	config.map_size = grid_size
	config.theme = GenerationConfig.ThemeType.TECH
	context.config = config

	context.theme = MapTheme.create_default_theme(GenerationConfig.ThemeType.TECH)
	context.rooms = []
	context.hallways = []
	context.metadata = {}
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	return context
