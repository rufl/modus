extends Node
class_name ModAssetLoader

signal asset_loaded(asset_path: String, from_mod: String)
signal asset_load_failed(asset_path: String)

const BASE_ASSETS_PATH: String = "res://game/art/"

var asset_cache: Dictionary = {}
var load_stats: Dictionary = {"base": 0, "mod": 0, "cached": 0, "failed": 0}

var _mod_loader: Node = null


func _ready() -> void:
	# Find ModLoader
	_mod_loader = GameManager.get_core_system("mod_loader")
	if not _mod_loader:
		push_warning("[ModAssetLoader] ModLoader not found - mod overrides disabled")


# =============================================================================
# PUBLIC API - Asset Loading
# =============================================================================


func load_texture(texture_path: String) -> Texture2D:
	## Load a texture with mod override support
	return _load_asset(texture_path, "textures") as Texture2D


func load_model(model_path: String) -> PackedScene:
	## Load a model/scene with mod override support
	return _load_asset(model_path, "models") as PackedScene


func load_audio(audio_path: String) -> AudioStream:
	## Load an audio file with mod override support
	return _load_asset(audio_path, "audio") as AudioStream


func load_material(material_path: String) -> Material:
	## Load a material with mod override support
	return _load_asset(material_path, "materials") as Material


func load_any(asset_path: String, asset_type: String) -> Resource:
	## Load any resource type with mod override support
	return _load_asset(asset_path, asset_type)


# =============================================================================
# INTERNAL LOADING
# =============================================================================


func _load_asset(asset_path: String, asset_type: String) -> Resource:
	## Load an asset, checking mods first
	# Check cache first
	var cache_key: String = asset_type + ":" + asset_path
	if asset_cache.has(cache_key):
		load_stats["cached"] += 1
		return asset_cache[cache_key]

	# Try loading from mods (in reverse load order, so last loaded mod wins)
	if _mod_loader and _mod_loader.has_method("get_mod_load_order"):
		var mod_order: Array = _mod_loader.get_mod_load_order()
		mod_order.reverse()

		for mod_name: Variant in mod_order:
			var mod_path: String = _get_mod_path(mod_name)
			var full_path: String = mod_path + "assets/" + asset_type + "/" + asset_path

			if FileAccess.file_exists(full_path) or ResourceLoader.exists(full_path):
				var asset: Resource = _try_load_resource(full_path)
				if asset:
					asset_cache[cache_key] = asset
					load_stats["mod"] += 1
					asset_loaded.emit(asset_path, str(mod_name))
					GameManager.get_core_system("logger").info(
						"[ModAssetLoader] Loaded %s from mod: %s" % [asset_path, mod_name], "Core"
					)
					return asset

	# Fall back to base game assets
	var base_path: String = BASE_ASSETS_PATH + asset_type + "/" + asset_path
	var base_asset: Resource = _try_load_resource(base_path)

	if base_asset:
		asset_cache[cache_key] = base_asset
		load_stats["base"] += 1
		return base_asset

	# Asset not found
	load_stats["failed"] += 1
	asset_load_failed.emit(asset_path)
	push_warning("[ModAssetLoader] Failed to load asset: %s" % asset_path)
	return null


func _try_load_resource(path: String) -> Resource:
	## Try to load a resource, return null on failure
	if not ResourceLoader.exists(path):
		return null

	var resource: Resource = load(path)
	if not resource:
		push_warning("[ModAssetLoader] Failed to load resource: %s" % path)
		return null

	return resource


func _get_mod_path(mod_name: Variant) -> String:
	## Get the path to a mod directory
	if _mod_loader and _mod_loader.has_method("get_mod_path"):
		return _mod_loader.get_mod_path(mod_name)
	return ""


# =============================================================================
# CACHE MANAGEMENT
# =============================================================================


func preload_asset(asset_path: String, asset_type: String) -> void:
	## Preload an asset into cache
	_load_asset(asset_path, asset_type)


func clear_cache() -> void:
	## Clear the asset cache
	asset_cache.clear()
	GameManager.get_core_system("logger").info("[ModAssetLoader] Asset cache cleared", "Core")


func remove_from_cache(asset_path: String, asset_type: String) -> void:
	## Remove a specific asset from cache
	var cache_key: String = asset_type + ":" + asset_path
	if asset_cache.has(cache_key):
		asset_cache.erase(cache_key)


func reload_asset(asset_path: String, asset_type: String) -> Resource:
	## Reload an asset (useful for hot-reloading during development)
	remove_from_cache(asset_path, asset_type)
	return _load_asset(asset_path, asset_type)


# =============================================================================
# STATISTICS
# =============================================================================


func get_load_stats() -> Dictionary:
	## Get asset loading statistics
	return load_stats.duplicate()


func print_load_stats() -> void:
	## Print asset loading statistics
	GameManager.get_core_system("logger").info("\n=== Mod Asset Loader Stats ===", "Core")
	GameManager.get_core_system("logger").info("Base game assets: %d" % load_stats["base"], "Core")
	GameManager.get_core_system("logger").info("Mod assets: %d" % load_stats["mod"], "Core")
	GameManager.get_core_system("logger").info("Cached: %d" % load_stats["cached"], "Core")
	GameManager.get_core_system("logger").info("Failed: %d" % load_stats["failed"], "Core")
	GameManager.get_core_system("logger").info(
		"Total unique assets: %d" % asset_cache.size(), "Core"
	)
	GameManager.get_core_system("logger").info("==============================", "Core")


func reset_stats() -> void:
	## Reset load statistics
	load_stats = {"base": 0, "mod": 0, "cached": 0, "failed": 0}


func get_cache_size() -> int:
	## Get number of cached assets
	return asset_cache.size()


# =============================================================================
# SOURCE LOOKUP
# =============================================================================


func get_asset_source(asset_path: String, asset_type: String) -> String:
	## Get the source of an asset (mod name or "base")
	# Check mods in reverse order
	if _mod_loader and _mod_loader.has_method("get_mod_load_order"):
		var mod_order: Array = _mod_loader.get_mod_load_order()
		mod_order.reverse()

		for mod_name: Variant in mod_order:
			var mod_path: String = _get_mod_path(mod_name)
			var full_path: String = mod_path + "assets/" + asset_type + "/" + asset_path

			if FileAccess.file_exists(full_path) or ResourceLoader.exists(full_path):
				return str(mod_name)

	# Check base game
	var base_path: String = BASE_ASSETS_PATH + asset_type + "/" + asset_path
	if ResourceLoader.exists(base_path):
		return "base"

	return "not_found"


func is_asset_from_mod(asset_path: String, asset_type: String) -> bool:
	## Check if an asset comes from a mod
	var source: String = get_asset_source(asset_path, asset_type)
	return source != "base" and source != "not_found"
