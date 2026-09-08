extends PropertyBasedTesting

## Property-Based Test: Configuration Caching
## Feature: architecture-refactoring, Property 35: Configuration caching
## **Validates: Requirements 11.2**

const ConfigurationManagerClass = preload("res://game/scripts/core/configuration_manager.gd")


func test_property_second_load_uses_cache() -> void:
	# Property: For any JSON5 configuration file, loading it a second time
	# should use the cached parsed data instead of re-parsing the file

	await run_enhanced_property_test(
		"Second load uses cache",
		_test_second_load_uses_cache,
		100,
		SamplingStrategy.MIXED,
		"Configuration files should be cached after first load"
	)


func _test_second_load_uses_cache(test_data: Dictionary) -> bool:
	var config_manager: ConfigurationManagerClass = add_child_autofree(
		ConfigurationManagerClass.new()
	)

	# Load a configuration file for the first time
	var first_load := config_manager.load_config_file("features.json5")

	# Get the cache before second load
	var cache_before := config_manager.get_all_config()
	var cache_size_before := cache_before.size()

	# Load the same file again
	var second_load := config_manager.load_config_file("features.json5")

	# Get the cache after second load
	var cache_after := config_manager.get_all_config()
	var cache_size_after := cache_after.size()

	# Property: Cache size should not increase (file was already cached)
	var cache_not_duplicated: bool = cache_size_before == cache_size_after

	# Property: Both loads should return the same data
	var same_data: bool = first_load == second_load

	# Property: Both should be non-empty (file exists and was parsed)
	var data_valid: bool = not first_load.is_empty() and not second_load.is_empty()

	return cache_not_duplicated and same_data and data_valid


func test_property_cache_invalidation_on_reload() -> void:
	# Property: Calling reload_file() should invalidate the cache and
	# re-parse the file

	await run_enhanced_property_test(
		"Cache invalidation on reload",
		_test_cache_invalidation_on_reload,
		100,
		SamplingStrategy.MIXED,
		"Reloading should invalidate cache and re-parse file"
	)


func _test_cache_invalidation_on_reload(test_data: Dictionary) -> bool:
	var config_manager: ConfigurationManagerClass = add_child_autofree(
		ConfigurationManagerClass.new()
	)

	# Load a configuration file
	var first_load := config_manager.load_config_file("features.json5")

	# Reload the file (should invalidate cache)
	config_manager.reload_file("features.json5")

	# Load again
	var after_reload := config_manager.load_config_file("features.json5")

	# Property: Data should still be the same (file hasn't changed)
	var same_data: bool = first_load == after_reload

	# Property: Both should be non-empty
	var data_valid: bool = not first_load.is_empty() and not after_reload.is_empty()

	return same_data and data_valid


func test_property_reload_all_clears_cache() -> void:
	# Property: Calling reload_all() should clear the entire cache
	# and reload all previously loaded files

	await run_enhanced_property_test(
		"Reload all clears cache",
		_test_reload_all_clears_cache,
		100,
		SamplingStrategy.MIXED,
		"reload_all() should clear and rebuild cache"
	)


func _test_reload_all_clears_cache(test_data: Dictionary) -> bool:
	var config_manager: ConfigurationManagerClass = add_child_autofree(
		ConfigurationManagerClass.new()
	)

	# Load multiple configuration files
	var features := config_manager.load_config_file("features.json5")
	var gameplay := config_manager.load_config_file("gameplay/gameplay.json5")

	# Get cache size before reload
	var cache_before := config_manager.get_all_config()
	var cache_size_before := cache_before.size()

	# Reload all
	config_manager.reload_all()

	# Get cache size after reload
	var cache_after := config_manager.get_all_config()
	var cache_size_after := cache_after.size()

	# Property: Cache should be rebuilt with same number of files
	# (reload_all reloads all previously cached files)
	var cache_rebuilt: bool = cache_size_before == cache_size_after

	# Property: Data should still be accessible
	var features_after := config_manager.load_config_file("features.json5")
	var data_valid: bool = not features_after.is_empty()

	return cache_rebuilt and data_valid


func test_property_cache_persists_across_get_value_calls() -> void:
	# Property: Calling get_value() should not trigger re-parsing,
	# it should use cached data

	await run_enhanced_property_test(
		"Cache persists across get_value calls",
		_test_cache_persists_across_get_value_calls,
		100,
		SamplingStrategy.MIXED,
		"get_value() should use cached data"
	)


func _test_cache_persists_across_get_value_calls(test_data: Dictionary) -> bool:
	var config_manager: ConfigurationManagerClass = add_child_autofree(
		ConfigurationManagerClass.new()
	)

	# Load a configuration file
	config_manager.load_config_file("features.json5")

	# Get cache size
	var cache_before := config_manager.get_all_config()
	var cache_size_before := cache_before.size()

	# Call get_value multiple times
	var value1 = config_manager.get_value("features.combat.enabled", false)
	var value2 = config_manager.get_value("features.inventory.enabled", false)
	var value3 = config_manager.get_value("features.loot.enabled", false)

	# Get cache size after get_value calls
	var cache_after := config_manager.get_all_config()
	var cache_size_after := cache_after.size()

	# Property: Cache size should not change (no re-parsing)
	var cache_unchanged: bool = cache_size_before == cache_size_after

	return cache_unchanged


func test_property_clear_cache_removes_all_entries() -> void:
	# Property: Calling clear_cache() should remove all cached entries

	await run_enhanced_property_test(
		"Clear cache removes all entries",
		_test_clear_cache_removes_all_entries,
		100,
		SamplingStrategy.MIXED,
		"clear_cache() should empty the cache"
	)


func _test_clear_cache_removes_all_entries(test_data: Dictionary) -> bool:
	var config_manager: ConfigurationManagerClass = add_child_autofree(
		ConfigurationManagerClass.new()
	)

	# Load multiple configuration files
	config_manager.load_config_file("features.json5")
	config_manager.load_config_file("gameplay/gameplay.json5")

	# Verify cache has entries
	var cache_before := config_manager.get_all_config()
	var has_entries_before: bool = cache_before.size() > 0

	# Clear cache
	config_manager.clear_cache()

	# Verify cache is empty
	var cache_after := config_manager.get_all_config()
	var is_empty_after: bool = cache_after.size() == 0

	return has_entries_before and is_empty_after
