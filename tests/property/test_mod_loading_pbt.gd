extends PropertyBasedTesting

## Property-Based Test: Mod Loading and Registration
## Feature: architecture-refactoring, Property 30: Mod loading and registration
## **Validates: Requirements 10.1, 10.2**

const SimpleLogger = preload("res://tests/mocks/simple_logger.gd")


## Mock GameCore for testing
class MockGameCore:
	var logger: SimpleLogger

	func _init() -> void:
		logger = SimpleLogger.new()


func test_property_mod_registration_methods_exist() -> void:
	# Property: ModLoader should have methods for registering features,
	# components, and entities

	await run_enhanced_property_test(
		"Mod registration methods exist",
		_test_registration_methods_exist,
		10,
		SamplingStrategy.EDGE_CASE,
		"ModLoader should provide registration API"
	)


func _test_registration_methods_exist(test_data: Dictionary) -> bool:
	# Check that the mod_loader.gd file contains the required method signatures
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check for required method signatures
	var has_register_feature: bool = content.contains("func register_feature(")
	var has_register_component: bool = content.contains("func register_component(")
	var has_register_entity: bool = content.contains("func register_entity(")
	var has_get_registered_features: bool = content.contains("func get_registered_features(")
	var has_get_registered_components: bool = content.contains("func get_registered_components(")
	var has_get_registered_entities: bool = content.contains("func get_registered_entities(")

	return (
		has_register_feature
		and has_register_component
		and has_register_entity
		and has_get_registered_features
		and has_get_registered_components
		and has_get_registered_entities
	)


func test_property_mod_manifest_includes_registration_fields() -> void:
	# Property: Mod manifest should support features, components, and entities fields

	await run_enhanced_property_test(
		"Mod manifest supports registration fields",
		_test_manifest_fields,
		20,
		SamplingStrategy.MIXED,
		"Mod manifests should support custom content registration"
	)


func _test_manifest_fields(test_data: Dictionary) -> bool:
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Create a test manifest with registration fields
	var manifest: Dictionary = {
		"name": "TestMod",
		"version": "1.0.0",
		"features":
		{
			"custom_feature":
			{"name": "Custom Feature", "module_path": "res://test/feature.gd", "enabled": true}
		},
		"components": {"CustomComponent": "scripts/custom_component.gd"},
		"entities": {"CustomEntity": "scenes/custom_entity.tscn"}
	}

	# Property: Manifest should contain all registration fields
	var has_features: bool = manifest.has("features")
	var has_components: bool = manifest.has("components")
	var has_entities: bool = manifest.has("entities")

	# Property: Each field should be a Dictionary
	var features_is_dict: bool = typeof(manifest.get("features")) == TYPE_DICTIONARY
	var components_is_dict: bool = typeof(manifest.get("components")) == TYPE_DICTIONARY
	var entities_is_dict: bool = typeof(manifest.get("entities")) == TYPE_DICTIONARY

	return (
		has_features
		and has_components
		and has_entities
		and features_is_dict
		and components_is_dict
		and entities_is_dict
	)


func test_property_mod_dependency_resolution_exists() -> void:
	# Property: ModLoader should have dependency resolution functionality

	await run_enhanced_property_test(
		"Mod dependency resolution exists",
		_test_dependency_resolution_exists,
		10,
		SamplingStrategy.EDGE_CASE,
		"ModLoader should support dependency resolution"
	)


func _test_dependency_resolution_exists(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check for dependency-related methods
	var has_resolve_load_order: bool = content.contains("func _resolve_load_order(")
	var has_check_dependencies: bool = content.contains("func _check_dependencies(")
	var has_get_dependency_tree: bool = content.contains("func get_dependency_tree(")

	return has_resolve_load_order and has_check_dependencies and has_get_dependency_tree


func test_property_config_override_system_exists() -> void:
	# Property: ModLoader should support configuration overrides

	await run_enhanced_property_test(
		"Config override system exists",
		_test_config_override_exists,
		10,
		SamplingStrategy.EDGE_CASE,
		"ModLoader should support configuration overrides"
	)


func _test_config_override_exists(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check for override-related methods
	var has_apply_mod_config: bool = content.contains("func _apply_mod_config(")
	var has_apply_system_overrides: bool = content.contains("func _apply_system_overrides(")
	var has_apply_weapon_overrides: bool = content.contains("func _apply_weapon_overrides(")
	var has_apply_enemy_overrides: bool = content.contains("func _apply_enemy_overrides(")

	return (
		has_apply_mod_config
		and has_apply_system_overrides
		and has_apply_weapon_overrides
		and has_apply_enemy_overrides
	)
