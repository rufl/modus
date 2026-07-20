extends ModusGutTestBase

const Validator = preload("res://game/scripts/features/modding/mod_package_validator.gd")


func test_valid_sample_manifest_passes() -> void:
	var validator := Validator.new()
	var manifest_file := FileAccess.open("res://mods/modus_sdk_sample/mod.json", FileAccess.READ)
	assert_not_null(manifest_file)
	if not manifest_file:
		return
	var manifest: Dictionary = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	var result: Dictionary = validator.validate_manifest(manifest, "modus_sdk_sample")
	assert_true(result.valid, "The reference sample manifest should validate")
	assert_true(result.errors.is_empty())


func test_missing_fields_and_disabled_state_are_reported() -> void:
	var validator := Validator.new()
	var result: Dictionary = validator.validate_manifest({"enabled": false}, "invalid_mod")
	assert_false(result.valid)
	assert_gt(result.errors.size(), 0)
	assert_true(result.warnings.any(func(warning: String) -> bool: return "disabled" in warning))


func test_missing_dependency_is_reported() -> void:
	var validator := Validator.new()
	var result: Dictionary = validator.validate_packages([
		{"id": "dependent", "name": "Dependent", "version": "1.0.0", "dependencies": ["missing"]}
	])
	assert_false(result.valid)
	assert_true(result.errors.any(func(error: String) -> bool: return "missing dependency" in error))


func test_duplicate_override_is_reported() -> void:
	var validator := Validator.new()
	var result: Dictionary = validator.validate_packages([
		{
			"id": "first", "name": "First", "version": "1.0.0", "enabled": true,
			"config_overrides": {"weapons": {"pistol": {"damage": 12}}}
		},
		{
			"id": "second", "name": "Second", "version": "1.0.0", "enabled": true,
			"config_overrides": {"weapons": {"pistol": {"damage": 20}}}
		}
	])
	assert_false(result.valid)
	assert_true(result.errors.any(func(error: String) -> bool: return "override conflict" in error))
