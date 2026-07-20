extends GutTest

## Unit tests for configuration validation
## Tests that all JSON5 files are valid and contain required fields
## Validates: Requirements 12.3

const ConfigurationManager = preload("res://game/scripts/core/configuration_manager.gd")

const CONFIG_DIR = "res://game/config/"
var config_manager: ConfigurationManager


func before_each():
	config_manager = autofree(ConfigurationManager.new()) as ConfigurationManager


func test_features_json5_exists_and_valid():
	var config_path = CONFIG_DIR + "features.json5"
	assert_file_exists(config_path)

	var config = config_manager.load_config_file(config_path)
	assert_false(config.is_empty(), "features.json5 should be valid JSON5")


func test_features_json5_has_required_fields():
	var config_path = CONFIG_DIR + "features.json5"
	var config = config_manager.load_config_file(config_path)

	assert_true(config.has("features"), "features.json5 should have 'features' field")
	assert_true(config.has("profiles"), "features.json5 should have 'profiles' field")


func test_features_json5_features_are_valid():
	var config_path = CONFIG_DIR + "features.json5"
	var config = config_manager.load_config_file(config_path)

	if config.has("features"):
		var features = config.get("features")
		assert_true(features is Dictionary, "features should be a Dictionary")

		# Check that each feature has required fields
		for feature_name in features.keys():
			var feature = features[feature_name]
			assert_true(feature is Dictionary, "Each feature should be a Dictionary")
			assert_true(feature.has("enabled"), "Feature '%s' should have 'enabled' field" % feature_name)


func test_gameplay_json5_exists_and_valid():
	var config_path = CONFIG_DIR + "gameplay/gameplay.json5"
	assert_file_exists(config_path)
	var config = config_manager.load_config_file(config_path)
	assert_false(config.is_empty(), "gameplay.json5 should be valid JSON5")


func test_combat_json5_exists_and_valid():
	var config_path = CONFIG_DIR + "gameplay/combat.json5"
	assert_file_exists(config_path)
	var config = config_manager.load_config_file(config_path)
	assert_false(config.is_empty(), "combat.json5 should be valid JSON5")


func test_performance_json5_exists_and_valid():
	var config_path = CONFIG_DIR + "performance/system.json5"
	assert_file_exists(config_path)
	var config = config_manager.load_config_file(config_path)
	assert_false(config.is_empty(), "performance system JSON5 should be valid")


func test_all_json5_files_in_config_dir_are_valid():
	# Test that all JSON5 files in game/config/ are syntactically valid
	var dir = DirAccess.open(CONFIG_DIR)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			if file_name.ends_with(".json5"):
				var config_path = CONFIG_DIR + file_name
				var config = config_manager.load_config_file(config_path)

				assert_false(config.is_empty(), "File '%s' should be valid JSON5" % file_name)

			file_name = dir.get_next()

		dir.list_dir_end()


func test_config_files_have_no_syntax_errors():
	# Test that configuration files can be parsed without errors
	var test_files = [
		"features.json5",
		"gameplay/gameplay.json5",
		"gameplay/combat.json5",
		"performance/system.json5"
	]

	for file_name in test_files:
		var config_path = CONFIG_DIR + file_name

		if FileAccess.file_exists(config_path):
			var config = config_manager.load_config_file(config_path)

			# If file exists, it should parse successfully
			assert_false(config.is_empty(), "File '%s' should parse without errors" % file_name)


func test_features_json5_profiles_are_valid():
	var config_path = CONFIG_DIR + "features.json5"
	var config = config_manager.load_config_file(config_path)

	if config.has("profiles"):
		var profiles = config.get("profiles")
		assert_true(profiles is Dictionary, "profiles should be a Dictionary")

		# Check that standard profile exists
		assert_true(profiles.has("standard"), "Should have 'standard' profile")
		assert_true(profiles.has("multiplayer_demo"), "Should have 'multiplayer_demo' profile")
		if profiles.has("multiplayer_demo"):
			var multiplayer_features: Array = profiles["multiplayer_demo"].get("features", [])
			assert_true(
				"network" in multiplayer_features,
				"multiplayer_demo profile should enable the network feature"
			)

		# Check that each profile has a features array
		for profile_name in profiles.keys():
			var profile = profiles[profile_name]
			assert_true(profile is Dictionary, "Profile '%s' should be a Dictionary" % profile_name)
			assert_true(profile.has("features"), "Profile '%s' should have 'features' field" % profile_name)


func test_feature_dependencies_are_valid():
	var config_path = CONFIG_DIR + "features.json5"
	var config = config_manager.load_config_file(config_path)

	if config.has("features"):
		var features = config.get("features")

		# Check that dependencies reference existing features
		for feature_name in features.keys():
			var feature = features[feature_name]

			if feature.has("dependencies"):
				var dependencies = feature.get("dependencies")
				assert_true(dependencies is Array, "Dependencies should be an Array")

				for dep in dependencies:
					assert_true(
						features.has(dep),
						"Dependency '%s' of feature '%s' should exist" % [dep, feature_name]
					)


func test_config_manager_validates_on_load():
	# Test that ConfigurationManager validates files on load
	var config_path = CONFIG_DIR + "features.json5"
	var config = config_manager.load_config_file(config_path)

	# If load succeeds, validation passed
	assert_false(config.is_empty(), "Valid config should load successfully")


func test_invalid_json5_returns_empty_dict():
	# Test that invalid JSON5 returns empty dictionary
	var invalid_path = "res://nonexistent/invalid.json5"
	var config = config_manager.load_config_file(invalid_path)
	assert_push_error("Configuration file not found")

	assert_true(config.is_empty(), "Invalid file should return empty dict")


func test_config_files_use_correct_types():
	var config_path = CONFIG_DIR + "features.json5"
	var config = config_manager.load_config_file(config_path)

	if config.has("features"):
		var features = config.get("features")

		for feature_name in features.keys():
			var feature = features[feature_name]

			# enabled should be boolean
			if feature.has("enabled"):
				var enabled = feature.get("enabled")
				assert_eq(typeof(enabled), TYPE_BOOL, "Feature '%s' enabled should be boolean" % feature_name)

			# dependencies should be array
			if feature.has("dependencies"):
				var deps = feature.get("dependencies")
				assert_true(deps is Array, "Feature '%s' dependencies should be array" % feature_name)


func test_required_features_are_present():
	var config_path = CONFIG_DIR + "features.json5"
	var config = config_manager.load_config_file(config_path)

	if config.has("features"):
		var features = config.get("features")

		# Check for core features that should exist
		var required_features = ["combat", "inventory", "physics", "audio"]

		for required in required_features:
			assert_true(features.has(required), "Required feature '%s' should be present" % required)
