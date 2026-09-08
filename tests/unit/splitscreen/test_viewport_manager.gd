extends GutTest

## Unit tests for ViewportManager class
## Tests viewport creation, layout calculation, and rendering configuration

var viewport_manager: ViewportManager
var mock_player_scene: PackedScene


func before_each() -> void:
	viewport_manager = ViewportManager.new()
	add_child_autofree(viewport_manager)

	# Create a simple mock player scene
	mock_player_scene = PackedScene.new()


func after_each() -> void:
	if viewport_manager and is_instance_valid(viewport_manager):
		viewport_manager.cleanup_all_viewports()
		viewport_manager = null
	mock_player_scene = null


## Test: Initial state has no viewports
func test_initial_state_no_viewports() -> void:
	assert_eq(viewport_manager.get_viewport_count(), 0, "Should have no viewports initially")
	assert_eq(viewport_manager.get_all_viewports().size(), 0, "Should return empty array initially")


## Test: Create viewport successfully
func test_create_viewport_success() -> void:
	var viewport: SubViewport = viewport_manager.create_viewport(0, null)

	assert_not_null(viewport, "Should return a viewport")
	assert_eq(viewport_manager.get_viewport_count(), 1, "Should have 1 viewport")
	assert_true(viewport_manager.has_viewport(0), "Should have viewport for player 0")


## Test: Create multiple viewports
func test_create_multiple_viewports() -> void:
	viewport_manager.create_viewport(0, null)
	viewport_manager.create_viewport(1, null)
	viewport_manager.create_viewport(2, null)
	viewport_manager.create_viewport(3, null)

	assert_eq(viewport_manager.get_viewport_count(), 4, "Should have 4 viewports")


## Test: Create duplicate viewport returns existing
func test_create_duplicate_viewport_returns_existing() -> void:
	var viewport1: SubViewport = viewport_manager.create_viewport(0, null)
	var viewport2: SubViewport = viewport_manager.create_viewport(0, null)
	assert_push_error("already exists")

	assert_eq(viewport1, viewport2, "Should return the same viewport instance")
	assert_eq(viewport_manager.get_viewport_count(), 1, "Should still have only 1 viewport")


## Test: Get viewport returns correct viewport
func test_get_viewport() -> void:
	var created_viewport: SubViewport = viewport_manager.create_viewport(0, null)
	var retrieved_viewport: SubViewport = viewport_manager.get_player_viewport(0)

	assert_eq(created_viewport, retrieved_viewport, "Should return the same viewport")


## Test: Get non-existent viewport returns null
func test_get_nonexistent_viewport_returns_null() -> void:
	var viewport: SubViewport = viewport_manager.get_player_viewport(99)
	assert_null(viewport, "Should return null for non-existent viewport")


## Test: Destroy viewport removes it
func test_destroy_viewport() -> void:
	viewport_manager.create_viewport(0, null)
	viewport_manager.destroy_viewport(0)

	assert_eq(
		viewport_manager.get_viewport_count(), 0, "Should have no viewports after destruction"
	)
	assert_false(viewport_manager.has_viewport(0), "Should not have viewport for player 0")


## Test: Destroy non-existent viewport does nothing
func test_destroy_nonexistent_viewport() -> void:
	viewport_manager.destroy_viewport(99)
	# Should not crash
	assert_true(true, "Should handle gracefully")


## Test: 2x2 grid layout for 4 players
func test_2x2_grid_layout_for_4_players() -> void:
	for i in range(4):
		viewport_manager.create_viewport(i, null)

	viewport_manager.arrange_viewports(4)

	assert_eq(
		viewport_manager.get_layout_type(),
		ViewportManager.LayoutType.GRID_2X2,
		"Should use 2x2 grid layout"
	)

	var rects: Array = viewport_manager.get_viewport_rects()
	assert_eq(rects.size(), 4, "Should have 4 viewport rects")

	# Check each viewport is 50% width × 50% height
	for rect: Rect2 in rects:
		assert_almost_eq(rect.size.x, 0.5, 0.01, "Viewport width should be ~50%")
		assert_almost_eq(rect.size.y, 0.5, 0.01, "Viewport height should be ~50%")


## Test: 2x3 grid layout for 5 players
func test_2x3_grid_layout_for_5_players() -> void:
	for i in range(5):
		viewport_manager.create_viewport(i, null)

	viewport_manager.arrange_viewports(5)

	assert_eq(
		viewport_manager.get_layout_type(),
		ViewportManager.LayoutType.GRID_2X3,
		"Should use 2x3 grid layout"
	)

	var rects: Array = viewport_manager.get_viewport_rects()
	assert_eq(rects.size(), 5, "Should have 5 viewport rects")

	# Five players fill the screen with equal 20% areas: three viewports in
	# the 60% top row and two in the 40% bottom row.
	for rect: Rect2 in rects:
		var area: float = rect.size.x * rect.size.y
		assert_almost_eq(area, 0.2, 0.01, "Each viewport should use 20% of the screen")
	assert_almost_eq(rects[0].size.y, 0.6, 0.01, "Top row should use 60% height")
	assert_almost_eq(rects[3].size.y, 0.4, 0.01, "Bottom row should use 40% height")


## Test: 2x3 grid layout for 6 players
func test_2x3_grid_layout_for_6_players() -> void:
	for i in range(6):
		viewport_manager.create_viewport(i, null)

	viewport_manager.arrange_viewports(6)

	assert_eq(
		viewport_manager.get_layout_type(),
		ViewportManager.LayoutType.GRID_2X3,
		"Should use 2x3 grid layout"
	)

	var rects: Array = viewport_manager.get_viewport_rects()
	assert_eq(rects.size(), 6, "Should have 6 viewport rects")


## Test: Equal viewport area distribution for 4 players
func test_equal_viewport_area_for_4_players() -> void:
	for i in range(4):
		viewport_manager.create_viewport(i, null)

	viewport_manager.arrange_viewports(4)

	var rects: Array = viewport_manager.get_viewport_rects()
	var expected_area: float = 1.0 / 4.0  # Each viewport should be 25% of total

	for rect: Rect2 in rects:
		var area: float = rect.size.x * rect.size.y
		assert_almost_eq(area, expected_area, 0.01, "Each viewport should have ~25% of total area")


## Test: Equal viewport area distribution for 6 players
func test_equal_viewport_area_for_6_players() -> void:
	for i in range(6):
		viewport_manager.create_viewport(i, null)

	viewport_manager.arrange_viewports(6)

	var rects: Array = viewport_manager.get_viewport_rects()
	var expected_area: float = 1.0 / 6.0  # Each viewport should be ~16.67% of total

	for rect: Rect2 in rects:
		var area: float = rect.size.x * rect.size.y
		assert_almost_eq(
			area, expected_area, 0.01, "Each viewport should have ~16.67% of total area"
		)


## Test: Set rendering quality high
func test_set_rendering_quality_high() -> void:
	viewport_manager.create_viewport(0, null)
	viewport_manager.set_rendering_quality(1.0)

	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_4X, "High quality should use MSAA 4X")
	assert_eq(viewport_manager.shadow_quality, "high", "High quality should use high shadows")


## Test: Set rendering quality medium
func test_set_rendering_quality_medium() -> void:
	viewport_manager.create_viewport(0, null)
	viewport_manager.set_rendering_quality(0.6)

	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_2X, "Medium quality should use MSAA 2X")
	assert_eq(viewport_manager.shadow_quality, "medium", "Medium quality should use medium shadows")


## Test: Set rendering quality low
func test_set_rendering_quality_low() -> void:
	viewport_manager.create_viewport(0, null)
	viewport_manager.set_rendering_quality(0.3)

	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_DISABLED, "Low quality should disable MSAA")
	assert_eq(viewport_manager.shadow_quality, "low", "Low quality should use low shadows")


## Test: Get all viewports returns array
func test_get_all_viewports() -> void:
	viewport_manager.create_viewport(0, null)
	viewport_manager.create_viewport(1, null)

	var viewports: Array = viewport_manager.get_all_viewports()
	assert_eq(viewports.size(), 2, "Should return 2 viewports")
	assert_typeof(viewports, TYPE_ARRAY, "Should return an array")


## Test: Has viewport check
func test_has_viewport() -> void:
	assert_false(viewport_manager.has_viewport(0), "Should not have viewport initially")

	viewport_manager.create_viewport(0, null)

	assert_true(viewport_manager.has_viewport(0), "Should have viewport after creation")


## Test: Cleanup all viewports
func test_cleanup_all_viewports() -> void:
	viewport_manager.create_viewport(0, null)
	viewport_manager.create_viewport(1, null)
	viewport_manager.create_viewport(2, null)

	viewport_manager.cleanup_all_viewports()

	assert_eq(viewport_manager.get_viewport_count(), 0, "Should have no viewports after cleanup")


## Test: Viewport created signal emitted
func test_viewport_created_signal() -> void:
	watch_signals(viewport_manager)
	viewport_manager.create_viewport(0, null)

	assert_signal_emitted(
		viewport_manager, "viewport_created", "Should emit viewport_created signal"
	)


## Test: Viewport destroyed signal emitted
func test_viewport_destroyed_signal() -> void:
	viewport_manager.create_viewport(0, null)

	watch_signals(viewport_manager)
	viewport_manager.destroy_viewport(0)

	assert_signal_emitted(
		viewport_manager, "viewport_destroyed", "Should emit viewport_destroyed signal"
	)


## Test: Layout changed signal emitted
func test_layout_changed_signal() -> void:
	for i in range(4):
		viewport_manager.create_viewport(i, null)

	watch_signals(viewport_manager)
	viewport_manager.arrange_viewports(4)

	assert_signal_emitted(viewport_manager, "layout_changed", "Should emit layout_changed signal")


## Test: Load configuration
func test_load_configuration() -> void:
	var config: Dictionary = {
		"viewport":
		{
			"msaa": "4x",
			"fxaa": false,
			"shadow_quality": "high",
			"clear_color": "#FF0000",
			"aspect_ratio_variance_threshold": 0.1
		}
	}

	viewport_manager.load_configuration(config)

	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_4X, "Should set MSAA to 4X")
	assert_false(viewport_manager.fxaa_enabled, "Should disable FXAA")
	assert_eq(viewport_manager.shadow_quality, "high", "Should set shadow quality to high")
	assert_almost_eq(
		viewport_manager.aspect_ratio_variance_threshold,
		0.1,
		0.01,
		"Should set aspect ratio threshold"
	)


## Test: Load configuration with defaults
func test_load_configuration_with_defaults() -> void:
	var config: Dictionary = {}

	viewport_manager.load_configuration(config)

	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_2X, "Should use default MSAA 2X")
	assert_true(viewport_manager.fxaa_enabled, "Should enable FXAA by default")


## Test: Parse MSAA mode strings
func test_parse_msaa_modes() -> void:
	viewport_manager.load_configuration({"viewport": {"msaa": "disabled"}})
	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_DISABLED)

	viewport_manager.load_configuration({"viewport": {"msaa": "2x"}})
	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_2X)

	viewport_manager.load_configuration({"viewport": {"msaa": "4x"}})
	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_4X)

	viewport_manager.load_configuration({"viewport": {"msaa": "8x"}})
	assert_eq(viewport_manager.msaa_mode, Viewport.MSAA_8X)


## Test: Viewport rects cover entire screen
func test_viewport_rects_cover_entire_screen() -> void:
	for i in range(4):
		viewport_manager.create_viewport(i, null)

	viewport_manager.arrange_viewports(4)

	var rects: Array = viewport_manager.get_viewport_rects()
	var total_area: float = 0.0

	for rect: Rect2 in rects:
		total_area += rect.size.x * rect.size.y

	assert_almost_eq(total_area, 1.0, 0.01, "Total viewport area should cover entire screen (100%)")


## Test: Viewport rects do not overlap for 2x2 grid
func test_viewport_rects_no_overlap_2x2() -> void:
	for i in range(4):
		viewport_manager.create_viewport(i, null)

	viewport_manager.arrange_viewports(4)

	var rects: Array = viewport_manager.get_viewport_rects()

	# Check each pair of rects for overlap
	for i in range(rects.size()):
		for j in range(i + 1, rects.size()):
			var overlap: bool = rects[i].intersects(rects[j], false)
			assert_false(overlap, "Viewports %d and %d should not overlap" % [i, j])
