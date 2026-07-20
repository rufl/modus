extends Node

signal asset_reloaded(original_path: String, new_resource: Resource)

var _overrides: Dictionary = {}
var _loaded_cache: Dictionary = {}  # Cache for hot-reload tracking


func register_overrides(overrides: Dictionary) -> void:
	for original: String in overrides:
		_overrides[original] = overrides[original]
	GameManager.get_core_system("logger").info(
		"[AssetManager] Registered %d overrides" % overrides.size(), "Core"
	)


## Get the resolved path for an asset (handling overrides)


func get_asset_path(path: String) -> String:
	return _overrides.get(path, path)


## Load a resource, checking for overrides first


func load_resource(path: String) -> Resource:
	var final_path: String = _overrides.get(path, path)

	if not ResourceLoader.exists(final_path):
		if final_path != path:
			push_warning(
				"[AssetManager] Override missing: %s -> %s. Reverting." % [path, final_path]
			)
			final_path = path  # Fallback to original

		if not ResourceLoader.exists(final_path):
			push_error("[AssetManager] Resource not found: %s" % final_path)
			return null

	var resource: Resource = load(final_path)
	_loaded_cache[path] = final_path
	return resource


## Setup for Audio specifically


func load_audio(path: String) -> AudioStream:
	var final_path: String = _overrides.get(path, path)
	return load(final_path) as AudioStream


# =============================================================================
# HOT-RELOAD SUPPORT
# =============================================================================

## Reload an asset at runtime with a new replacement.
## Emits [signal asset_reloaded] so systems can update references.
## [param original_path]: The original asset path being replaced.
## [param new_path]: The new replacement path to load.


func reload_asset(original_path: String, new_path: String) -> Resource:
	# Update override
	_overrides[original_path] = new_path

	# Force cache invalidation by clearing resource cache
	# Note: Godot's ResourceLoader caches resources, so we need to reload
	var resource: Resource = null

	if ResourceLoader.exists(new_path):
		# Use CACHE_MODE_REPLACE to force reload
		resource = ResourceLoader.load(new_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		_loaded_cache[original_path] = new_path

		if resource:
			asset_reloaded.emit(original_path, resource)
			GameManager.get_core_system("logger").info(
				"[AssetManager] Hot-reloaded: %s -> %s" % [original_path, new_path], "Core"
			)
		else:
			push_warning("[AssetManager] Hot-reload failed for: %s" % new_path)
	else:
		push_error("[AssetManager] Hot-reload path not found: %s" % new_path)

	return resource


## Clear an override and revert to original asset.


func clear_override(original_path: String) -> void:
	if _overrides.has(original_path):
		_overrides.erase(original_path)
		_loaded_cache.erase(original_path)
		GameManager.get_core_system("logger").info(
			"[AssetManager] Cleared override for: %s" % original_path, "Core"
		)


## Reload all overridden assets (useful for mod reloading).


func reload_all_overrides() -> void:
	for original: String in _overrides:
		var new_path: String = _overrides[original]
		reload_asset(original, new_path)
	GameManager.get_core_system("logger").info(
		"[AssetManager] Reloaded all %d overrides" % _overrides.size(), "Core"
	)


## Get stats for debugging.


func get_stats() -> Dictionary:
	return {"override_count": _overrides.size(), "cached_count": _loaded_cache.size()}
