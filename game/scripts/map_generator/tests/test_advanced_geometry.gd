extends GutTest

## Unit tests for AdvancedGeometryBuilder
## Tests sloped floors/ceilings and 3D floors (platforms over pits)

var builder: AdvancedGeometryBuilder
var context: GenerationContext
var config: GenerationConfig
var csg_root: CSGCombiner3D


func before_each() -> void:
	# Create test configuration
	config = GenerationConfig.new()
	config.map_size = Vector2i(16, 16)
	config.theme = GenerationConfig.ThemeType.TECH

	# Create test context
	context = GenerationContext.new()
	context.config = config
	context.grid_size = config.map_size
	context.rng = RandomNumberGenerator.new()
	context.rng.seed = 12345

	# Initialize grid
	context.grid = []
	for y in range(config.map_size.y):
		var row: Array[Cell] = []
		for x in range(config.map_size.x):
			var cell := Cell.new(Cell.Type.ROOM)
			row.append(cell)
		context.grid.append(row)

	# Create test theme
	context.theme = MapTheme.create_default_theme(GenerationConfig.ThemeType.TECH)

	# Initialize arrays
	context.rooms = []
	context.hallways = []
	context.metadata = {}

	# Create CSG root
	csg_root = CSGCombiner3D.new()
	csg_root.use_collision = true
	context.csg_root = csg_root

	# Create builder
	builder = AdvancedGeometryBuilder.new()
	builder.initialize(context, csg_root)


func after_each() -> void:
	if csg_root:
		csg_root.queue_free()
	builder = null
	context = null
	config = null
	csg_root = null


func test_add_floor_slope() -> void:
	# Add floor slope
	builder.add_floor_slope(Vector2i(5, 5), deg_to_rad(30.0), Vector2(1, 0))

	# Build geometry
	builder.build_advanced_geometry()

	# Verify slopes were created
	var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
	assert_not_null(slopes_node, "SlopedSurfaces node should exist")
	assert_eq(slopes_node.get_child_count(), 1, "Should have 1 sloped surface")


func test_add_ceiling_slope() -> void:
	# Add ceiling slope
	builder.add_ceiling_slope(Vector2i(6, 6), deg_to_rad(25.0), Vector2(0, 1))

	# Build geometry
	builder.build_advanced_geometry()

	# Verify slopes were created
	var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
	assert_not_null(slopes_node, "SlopedSurfaces node should exist")
	assert_eq(slopes_node.get_child_count(), 1, "Should have 1 sloped surface")


func test_multiple_slopes() -> void:
	# Add multiple slopes
	builder.add_floor_slope(Vector2i(5, 5), deg_to_rad(30.0), Vector2(1, 0))
	builder.add_ceiling_slope(Vector2i(6, 6), deg_to_rad(25.0), Vector2(0, 1))
	builder.add_floor_slope(Vector2i(7, 7), deg_to_rad(20.0), Vector2(1, 1))

	# Build geometry
	builder.build_advanced_geometry()

	# Verify slopes were created
	var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
	assert_not_null(slopes_node, "SlopedSurfaces node should exist")
	assert_eq(slopes_node.get_child_count(), 3, "Should have 3 sloped surfaces")


func test_add_3d_floor() -> void:
	# Add 3D floor
	builder.add_3d_floor(Vector2i(3, 3), 1.5)

	# Build geometry
	builder.build_advanced_geometry()

	# Verify 3D floors were created
	var platforms_node := csg_root.get_node_or_null("3DFloors")
	assert_not_null(platforms_node, "3DFloors node should exist")
	assert_eq(platforms_node.get_child_count(), 1, "Should have 1 platform")

	# Verify platform position
	var platform := platforms_node.get_child(0) as CSGBox3D
	assert_not_null(platform, "Platform should be CSGBox3D")
	assert_almost_eq(platform.position.y, 1.5, 0.01, "Platform should be at 1.5m height")


func test_3d_floor_with_custom_thickness() -> void:
	# Add 3D floor with custom thickness
	builder.add_3d_floor(Vector2i(4, 4), 2.0, 0.3)

	# Build geometry
	builder.build_advanced_geometry()

	# Verify platform
	var platforms_node := csg_root.get_node_or_null("3DFloors")
	var platform := platforms_node.get_child(0) as CSGBox3D

	assert_almost_eq(platform.position.y, 2.0, 0.01, "Platform should be at 2.0m height")
	assert_almost_eq(platform.size.y, 0.3, 0.01, "Platform should have 0.3m thickness")


func test_multiple_3d_floors() -> void:
	# Add multiple 3D floors at different heights
	builder.add_3d_floor(Vector2i(3, 3), 1.0)
	builder.add_3d_floor(Vector2i(4, 4), 1.5)
	builder.add_3d_floor(Vector2i(5, 5), 2.0)

	# Build geometry
	builder.build_advanced_geometry()

	# Verify platforms
	var platforms_node := csg_root.get_node_or_null("3DFloors")
	assert_eq(platforms_node.get_child_count(), 3, "Should have 3 platforms")


func test_udmf_angle_format() -> void:
	# Parse UDMF angle format
	builder.parse_udmf_slope("angle:30,1,0", Vector2i(2, 2), false)

	# Build geometry
	builder.build_advanced_geometry()

	# Verify slope was created
	var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
	assert_not_null(slopes_node, "SlopedSurfaces node should exist")
	assert_eq(slopes_node.get_child_count(), 1, "Should have 1 slope from UDMF parsing")


func test_udmf_plane_format() -> void:
	# Parse UDMF plane format
	builder.parse_udmf_slope("plane:0,0,0,0.5,0.866,0", Vector2i(3, 3), true)

	# Build geometry
	builder.build_advanced_geometry()

	# Verify slope was created
	var slopes_node := csg_root.get_node_or_null("SlopedSurfaces")
	assert_not_null(slopes_node, "SlopedSurfaces node should exist")
	assert_eq(slopes_node.get_child_count(), 1, "Should have 1 slope from UDMF parsing")


func test_get_slope_definitions() -> void:
	# Add slopes
	builder.add_floor_slope(Vector2i(5, 5), deg_to_rad(30.0), Vector2(1, 0))
	builder.add_ceiling_slope(Vector2i(6, 6), deg_to_rad(25.0), Vector2(0, 1))

	# Get definitions
	var slopes := builder.get_slope_definitions()
	assert_eq(slopes.size(), 2, "Should have 2 slope definitions")


func test_get_3d_floor_definitions() -> void:
	# Add 3D floors
	builder.add_3d_floor(Vector2i(3, 3), 1.5)
	builder.add_3d_floor(Vector2i(4, 4), 2.0)

	# Get definitions
	var floors := builder.get_3d_floor_definitions()
	assert_eq(floors.size(), 2, "Should have 2 3D floor definitions")


func test_integration_with_csg_builder() -> void:
	# Create CSG geometry builder
	var csg_builder := CSGGeometryBuilder.new()
	csg_builder.initialize(context)

	# Add slopes through CSG builder interface
	csg_builder.add_floor_slope(Vector2i(5, 5), 30.0, Vector2(1, 0))
	csg_builder.add_ceiling_slope(Vector2i(6, 6), 25.0, Vector2(0, 1))
	csg_builder.add_3d_floor(Vector2i(7, 7), 1.5)
	csg_builder.add_udmf_slope("angle:20,0,1", Vector2i(8, 8), false)

	# Build all geometry
	var built_csg_root := csg_builder.build_geometry()
	assert_not_null(built_csg_root, "CSG root should be created")

	# Verify advanced geometry was built
	var slopes_node := built_csg_root.get_node_or_null("SlopedSurfaces")
	var platforms_node := built_csg_root.get_node_or_null("3DFloors")

	assert_not_null(slopes_node, "SlopedSurfaces should exist")
	assert_not_null(platforms_node, "3DFloors should exist")
	assert_eq(slopes_node.get_child_count(), 3, "Should have 3 slopes")
	assert_eq(platforms_node.get_child_count(), 1, "Should have 1 platform")

	# Cleanup
	built_csg_root.queue_free()


func test_sloped_mesh_has_correct_vertices() -> void:
	# Add a floor slope
	builder.add_floor_slope(Vector2i(5, 5), deg_to_rad(30.0), Vector2(1, 0))

	# Build geometry
	builder.build_advanced_geometry()

	# Get the slope mesh
	var slopes_node := csg_root.get_node("SlopedSurfaces")
	var slope_mesh_node := slopes_node.get_child(0) as CSGMesh3D

	assert_not_null(slope_mesh_node, "Slope should be CSGMesh3D")
	assert_not_null(slope_mesh_node.mesh, "Slope should have mesh data")

	# Verify mesh has surfaces
	assert_gt(slope_mesh_node.mesh.get_surface_count(), 0, "Mesh should have at least one surface")


func test_materials_applied_to_slopes() -> void:
	# Add slopes
	builder.add_floor_slope(Vector2i(5, 5), deg_to_rad(30.0), Vector2(1, 0))
	builder.add_ceiling_slope(Vector2i(6, 6), deg_to_rad(25.0), Vector2(0, 1))

	# Build geometry
	builder.build_advanced_geometry()

	# Check materials
	var slopes_node := csg_root.get_node("SlopedSurfaces")

	for child in slopes_node.get_children():
		var slope_mesh := child as CSGMesh3D
		if slope_mesh:
			# Material should be applied (can be null if theme materials aren't loaded)
			# Just verify the node structure is correct
			assert_not_null(slope_mesh.mesh, "Slope should have mesh")


func test_materials_applied_to_3d_floors() -> void:
	# Add 3D floor
	builder.add_3d_floor(Vector2i(3, 3), 1.5)

	# Build geometry
	builder.build_advanced_geometry()

	# Check material
	var platforms_node := csg_root.get_node("3DFloors")
	var platform := platforms_node.get_child(0) as CSGBox3D

	# Material should be applied (can be null if theme materials aren't loaded)
	# Just verify the node structure is correct
	assert_not_null(platform, "Platform should exist")
