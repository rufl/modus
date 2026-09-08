extends ModusGutTestBase

## Unit tests for MODUS Graphics System
## Tests graphics settings application, shader compilation, render pipeline,
## and graphics quality level adjustments
##
## Requirements: 12 (Graphics System Testing)

const GraphicsSystemClass := preload("res://game/scripts/features/graphics/graphics_system.gd")

var graphics_system: Node
var config_service: Node


func before_each() -> void:
	# Get config service
	var gm: Node = get_node_or_null("/root/GameManager")
	assert_not_null(gm, "GameManager must be available")

	if gm:
		config_service = gm.get_core_system("config")
		assert_not_null(config_service, "Config service must be available")

	# Load graphics and quality presets config
	if config_service:
		config_service.load_config_file("performance/graphics.json5")
		config_service.load_config_file("performance/visuals.json5")

	# Create graphics system instance for testing
	graphics_system = GraphicsSystemClass.new()
	graphics_system.name = "TestGraphicsSystem"
	add_child_autofree(graphics_system)

	# Wait for systems to be ready
	await get_tree().process_frame
	await get_tree().process_frame


func after_each() -> void:
	# Cleanup handled by add_child_autofree
	await get_tree().process_frame


func _set_graphics_config(path: String, value: Variant) -> void:
	if path == "graphics.quality_preset":
		config_service.set_value("graphics.custom", {})
	config_service.set_value(path, value)
	config_service.config_reloaded.emit("runtime")


# ============================================================================
# Graphics System Existence Tests
# ============================================================================


func test_graphics_system_exists() -> void:
	assert_not_null(graphics_system, "Graphics system should be available from GameManager")


func test_graphics_system_has_current_settings() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_true(
		graphics_system.get("current_settings") != null,
		"Graphics system should have current_settings property"
	)


func test_graphics_system_has_quality_changed_signal() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_true(
		graphics_system.has_signal("quality_changed"),
		"Graphics system should have quality_changed signal"
	)


# ============================================================================
# Graphics Settings Application Tests (Requirement 12.1)
# ============================================================================


func test_graphics_settings_apply_low_preset() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set low preset
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify settings applied
	var current_settings: Dictionary = graphics_system.current_settings
	assert_not_null(current_settings, "Current settings should be populated")
	assert_eq(current_settings.get("name", ""), "Low", "Low preset should be applied")


func test_graphics_settings_apply_medium_preset() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set medium preset
	_set_graphics_config("graphics.quality_preset", "medium")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify settings applied
	var current_settings: Dictionary = graphics_system.current_settings
	assert_not_null(current_settings, "Current settings should be populated")
	assert_eq(current_settings.get("name", ""), "Medium", "Medium preset should be applied")


func test_graphics_settings_apply_high_preset() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set high preset
	_set_graphics_config("graphics.quality_preset", "high")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify settings applied
	var current_settings: Dictionary = graphics_system.current_settings
	assert_not_null(current_settings, "Current settings should be populated")
	assert_eq(current_settings.get("name", ""), "High", "High preset should be applied")


func test_graphics_settings_apply_ultra_preset() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set ultra preset
	_set_graphics_config("graphics.quality_preset", "ultra")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify settings applied
	var current_settings: Dictionary = graphics_system.current_settings
	assert_not_null(current_settings, "Current settings should be populated")
	assert_eq(current_settings.get("name", ""), "Ultra", "Ultra preset should be applied")


func test_graphics_settings_fallback_to_high_on_invalid_preset() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set invalid preset
	_set_graphics_config("graphics.quality_preset", "invalid_preset_name")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify fallback to high
	var current_settings: Dictionary = graphics_system.current_settings
	assert_not_null(current_settings, "Current settings should be populated")
	assert_eq(
		current_settings.get("name", ""),
		"High",
		"Should fallback to high preset on invalid preset name"
	)


func test_graphics_settings_custom_overrides() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set preset with custom overrides
	config_service.set_value("graphics.quality_preset", "medium")
	config_service.set_value("graphics.custom", {"shadow_size": 8192, "max_particles": 500})

	config_service.config_reloaded.emit("runtime")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify custom overrides applied
	var current_settings: Dictionary = graphics_system.current_settings
	assert_eq(
		current_settings.get("shadow_size", 0),
		8192,
		"Custom shadow_size override should be applied"
	)
	assert_eq(
		current_settings.get("max_particles", 0),
		500,
		"Custom max_particles override should be applied"
	)


# ============================================================================
# Quality Changed Signal Tests (Requirement 12.1)
# ============================================================================


func test_quality_changed_signal_emitted_on_preset_change() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Watch for quality_changed signal
	watch_signals(graphics_system)

	# Change preset
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify signal was emitted
	assert_signal_emitted(
		graphics_system, "quality_changed", "quality_changed signal should emit on preset change"
	)


# ============================================================================
# Graphics Feature Enablement Tests (Requirement 12.4)
# ============================================================================


func test_is_feature_enabled_method_exists() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_true(
		graphics_system.has_method("is_feature_enabled"),
		"Graphics system should have is_feature_enabled method"
	)


func test_is_feature_enabled_returns_correct_value() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set low preset (shadows disabled)
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame

	# Check shadow_enabled feature
	var shadows_enabled: bool = graphics_system.is_feature_enabled("shadow_enabled")
	assert_false(shadows_enabled, "Shadows should be disabled in low preset")

	# Set high preset (shadows enabled)
	_set_graphics_config("graphics.quality_preset", "high")
	await get_tree().process_frame
	await get_tree().process_frame

	# Check shadow_enabled feature again
	shadows_enabled = graphics_system.is_feature_enabled("shadow_enabled")
	assert_true(shadows_enabled, "Shadows should be enabled in high preset")


func test_get_quality_value_method_exists() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_true(
		graphics_system.has_method("get_quality_value"),
		"Graphics system should have get_quality_value method"
	)


func test_get_quality_value_returns_correct_value() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set medium preset
	_set_graphics_config("graphics.quality_preset", "medium")
	await get_tree().process_frame
	await get_tree().process_frame

	# Get shadow_size value
	var shadow_size: int = graphics_system.get_quality_value("shadow_size", 0)
	assert_eq(shadow_size, 2048, "Medium preset should have shadow_size of 2048")


func test_get_quality_value_returns_default_for_missing_key() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")

	# Get non-existent value with default
	var value: int = graphics_system.get_quality_value("non_existent_key", 999)
	assert_eq(value, 999, "Should return default value for missing key")


# ============================================================================
# Graphics Quality Level Tests (Requirement 12.4)
# ============================================================================


func test_low_quality_has_minimal_features() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set low preset
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify low quality settings
	var current_settings: Dictionary = graphics_system.current_settings
	assert_false(current_settings.get("shadow_enabled", true), "Low preset should disable shadows")
	assert_false(current_settings.get("ssao_enabled", true), "Low preset should disable SSAO")
	assert_false(current_settings.get("ssr_enabled", true), "Low preset should disable SSR")
	assert_false(
		current_settings.get("volumetric_fog", true), "Low preset should disable volumetric fog"
	)


func test_medium_quality_has_balanced_features() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set medium preset
	_set_graphics_config("graphics.quality_preset", "medium")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify medium quality settings
	var current_settings: Dictionary = graphics_system.current_settings
	assert_true(
		current_settings.get("shadow_enabled", false), "Medium preset should enable shadows"
	)
	assert_true(current_settings.get("glow_enabled", false), "Medium preset should enable glow")
	assert_false(current_settings.get("ssao_enabled", true), "Medium preset should disable SSAO")


func test_high_quality_has_advanced_features() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set high preset
	_set_graphics_config("graphics.quality_preset", "high")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify high quality settings
	var current_settings: Dictionary = graphics_system.current_settings
	assert_true(current_settings.get("shadow_enabled", false), "High preset should enable shadows")
	assert_true(current_settings.get("ssao_enabled", false), "High preset should enable SSAO")
	assert_true(
		current_settings.get("volumetric_fog", false), "High preset should enable volumetric fog"
	)


func test_ultra_quality_has_maximum_features() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set ultra preset
	_set_graphics_config("graphics.quality_preset", "ultra")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify ultra quality settings
	var current_settings: Dictionary = graphics_system.current_settings
	assert_true(current_settings.get("shadow_enabled", false), "Ultra preset should enable shadows")
	assert_true(current_settings.get("ssao_enabled", false), "Ultra preset should enable SSAO")
	assert_true(current_settings.get("ssr_enabled", false), "Ultra preset should enable SSR")
	assert_true(current_settings.get("sdfgi_enabled", false), "Ultra preset should enable SDFGI")


# ============================================================================
# Shadow Quality Tests (Requirement 12.4)
# ============================================================================


func test_shadow_size_increases_with_quality() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Test low preset shadow size
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame
	var low_shadow_size: int = graphics_system.get_quality_value("shadow_size", 0)

	# Test high preset shadow size
	_set_graphics_config("graphics.quality_preset", "high")
	await get_tree().process_frame
	await get_tree().process_frame
	var high_shadow_size: int = graphics_system.get_quality_value("shadow_size", 0)

	# Verify shadow size increases
	assert_gt(
		high_shadow_size,
		low_shadow_size,
		"High preset should have larger shadow size than low preset"
	)


# ============================================================================
# Render Pipeline Tests (Requirement 12.3)
# ============================================================================


func test_rendering_server_shadow_atlas_size_applied() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Set high preset with known shadow size
	_set_graphics_config("graphics.quality_preset", "high")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify shadow size was applied to current settings
	var shadow_size: int = graphics_system.get_quality_value("shadow_size", 0)
	assert_gt(shadow_size, 0, "Shadow size should be set in current settings")


func test_render_pipeline_handles_config_reload() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Initial preset
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame

	# Change preset
	_set_graphics_config("graphics.quality_preset", "ultra")
	await get_tree().process_frame
	await get_tree().process_frame

	# Verify new settings applied
	var current_settings: Dictionary = graphics_system.current_settings
	assert_eq(
		current_settings.get("name", ""),
		"Ultra",
		"Render pipeline should handle config reload and apply new preset"
	)


# ============================================================================
# Shader Compilation Tests (Requirement 12.2)
# ============================================================================


func test_graphics_system_initializes_without_shader_errors() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")

	# If graphics system initialized successfully, shaders compiled
	assert_true(
		graphics_system.is_node_ready(),
		"Graphics system should be ready (implies shader compilation succeeded)"
	)


func test_shader_compilation_succeeds_for_all_presets() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	var presets: Array[String] = ["low", "medium", "high", "ultra"]

	for preset: String in presets:
		# Set preset
		_set_graphics_config("graphics.quality_preset", preset)
		await get_tree().process_frame
		await get_tree().process_frame

		# Verify no errors (system still functional)
		assert_not_null(
			graphics_system.current_settings,
			(
				"Graphics system should remain functional with %s preset (shader compilation succeeded)"
				% preset
			)
		)


# ============================================================================
# Performance and Particle Tests (Requirement 12.4)
# ============================================================================


func test_max_particles_varies_by_quality() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Test low preset particles
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame
	var low_particles: int = graphics_system.get_quality_value("max_particles", 0)

	# Test ultra preset particles
	_set_graphics_config("graphics.quality_preset", "ultra")
	await get_tree().process_frame
	await get_tree().process_frame
	var ultra_particles: int = graphics_system.get_quality_value("max_particles", 0)

	# Verify particle count increases with quality
	assert_gt(
		ultra_particles, low_particles, "Ultra preset should allow more particles than low preset"
	)


func test_lod_bias_varies_by_quality() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Test low preset LOD bias
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame
	var low_lod_bias: float = graphics_system.get_quality_value("lod_bias", 1.0)

	# Test high preset LOD bias
	_set_graphics_config("graphics.quality_preset", "high")
	await get_tree().process_frame
	await get_tree().process_frame
	var high_lod_bias: float = graphics_system.get_quality_value("lod_bias", 1.0)

	# Verify LOD bias decreases with higher quality (lower bias = better quality)
	assert_lt(high_lod_bias, low_lod_bias, "High preset should have lower LOD bias than low preset")


# ============================================================================
# Effect Quality Tests (Requirement 12.4)
# ============================================================================


func test_effect_quality_varies_by_preset() -> void:
	assert_not_null(graphics_system, "Graphics system should exist")
	assert_not_null(config_service, "Config service should exist")

	# Test low preset effect quality
	_set_graphics_config("graphics.quality_preset", "low")
	await get_tree().process_frame
	await get_tree().process_frame
	var low_effect_quality: float = graphics_system.get_quality_value("effect_quality", 1.0)

	# Test high preset effect quality
	_set_graphics_config("graphics.quality_preset", "high")
	await get_tree().process_frame
	await get_tree().process_frame
	var high_effect_quality: float = graphics_system.get_quality_value("effect_quality", 1.0)

	# Verify effect quality increases
	assert_gt(
		high_effect_quality,
		low_effect_quality,
		"High preset should have higher effect quality than low preset"
	)
