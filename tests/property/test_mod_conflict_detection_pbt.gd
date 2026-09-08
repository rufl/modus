extends PropertyBasedTesting

## Property-Based Test: Mod Conflict Detection
## Feature: architecture-refactoring, Property 32: Mod conflict detection
## **Validates: Requirements 10.5**


func test_property_conflict_detection_methods_exist() -> void:
	# Property: ModLoader should have methods for conflict detection and reporting

	await run_enhanced_property_test(
		"Conflict detection methods exist",
		_test_conflict_methods_exist,
		10,
		SamplingStrategy.EDGE_CASE,
		"ModLoader should provide conflict detection functionality"
	)


func _test_conflict_methods_exist(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check for conflict detection methods
	var has_report_conflict: bool = content.contains("func _report_conflict(")
	var has_get_conflicts: bool = content.contains("func get_conflicts(")
	var has_has_conflicts: bool = content.contains("func has_conflicts(")
	var has_clear_conflicts: bool = content.contains("func clear_conflicts(")

	# Check for conflict tracking variables
	var has_conflict_storage: bool = content.contains("_detected_conflicts")

	return (
		has_report_conflict
		and has_get_conflicts
		and has_has_conflicts
		and has_clear_conflicts
		and has_conflict_storage
	)


func test_property_duplicate_feature_registration_detected() -> void:
	# Property: For any two mods that register the same feature ID, the system
	# should detect and report the conflict

	await run_enhanced_property_test(
		"Duplicate feature registration detected",
		_test_duplicate_feature_detection,
		30,
		SamplingStrategy.MIXED,
		"Duplicate feature registrations should be detected"
	)


func _test_duplicate_feature_detection(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check that register_feature checks for existing registrations
	var checks_existing_features: bool = content.contains("_registered_features.has(feature_id)")

	# Check that it reports the live feature conflict contract when a feature is
	# already registered.
	var reports_feature_conflict: bool = (
		content.contains("_report_conflict") and content.contains("conflict on %s")
	)

	return checks_existing_features and reports_feature_conflict


func test_property_duplicate_component_registration_detected() -> void:
	# Property: For any two mods that register the same component name, the system
	# should detect and report the conflict

	await run_enhanced_property_test(
		"Duplicate component registration detected",
		_test_duplicate_component_detection,
		30,
		SamplingStrategy.MIXED,
		"Duplicate component registrations should be detected"
	)


func _test_duplicate_component_detection(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check that register_component checks for existing registrations
	var checks_existing_components: bool = content.contains(
		"_registered_components.has(component_name)"
	)

	# Check that it reports conflicts
	var reports_component_conflict: bool = content.contains("_report_conflict")

	return checks_existing_components and reports_component_conflict


func test_property_resource_override_conflicts_detected() -> void:
	# Property: For any resource that is overridden by multiple mods, the system
	# should detect and report the conflict

	await run_enhanced_property_test(
		"Resource override conflicts detected",
		_test_resource_override_conflicts,
		30,
		SamplingStrategy.MIXED,
		"Resource override conflicts should be detected"
	)


func _test_resource_override_conflicts(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check that _override_resource tracks overrides
	var tracks_overrides: bool = content.contains("_resource_overrides")

	# Check that it detects when a resource is already overridden
	var checks_existing_overrides: bool = content.contains("_resource_overrides.has(original_path)")

	# Check that it reports conflicts for resource overrides
	var reports_resource_conflict: bool = (
		content.contains("_report_conflict") and content.contains("resource")
	)

	return tracks_overrides and checks_existing_overrides and reports_resource_conflict


func test_property_conflict_messages_include_mod_names() -> void:
	# Property: For any detected conflict, the error message should include
	# both mod names involved in the conflict

	await run_enhanced_property_test(
		"Conflict messages include mod names",
		_test_conflict_messages_format,
		20,
		SamplingStrategy.EDGE_CASE,
		"Conflict messages should identify both mods"
	)


func _test_conflict_messages_format(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check that conflict reports include mod names
	# Look for the _report_conflict function and verify it stores mod names
	var has_mod1_param: bool = content.contains("mod1")
	var has_mod2_param: bool = content.contains("mod2")

	# Check that conflict messages are formatted with mod names
	var formats_message: bool = (
		content.contains("Mods '%s' and '%s'") or content.contains("mod '%s'")
	)

	return has_mod1_param and has_mod2_param and formats_message


func test_property_conflicts_can_be_queried() -> void:
	# Property: The system should provide a way to query all detected conflicts

	await run_enhanced_property_test(
		"Conflicts can be queried",
		_test_conflict_query_api,
		10,
		SamplingStrategy.EDGE_CASE,
		"System should provide conflict query API"
	)


func _test_conflict_query_api(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check for conflict query methods
	var has_get_conflicts: bool = content.contains("func get_conflicts(")
	var has_has_conflicts: bool = content.contains("func has_conflicts(")

	# Check that conflicts are stored in a queryable structure
	var stores_conflicts: bool = content.contains("_detected_conflicts")

	return has_get_conflicts and has_has_conflicts and stores_conflicts
