@tool
class_name WorkshopManager
extends Node

# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])



signal upload_started(item_id: String)
signal upload_progress(item_id: String, progress: float)
signal upload_completed(item_id: String, success: bool)
signal download_started(item_id: String)
signal download_completed(item_id: String, success: bool, local_path: String)
signal items_loaded(items: Array[Dictionary])
signal subscription_changed(item_id: String, subscribed: bool)
signal browse_failed(query: String, reason: String)


const WORKSHOP_CACHE := "user://workshop/"
const WORKSHOP_DOWNLOADS := "user://workshop/downloads/"
const WORKSHOP_UPLOADS := "user://workshop/uploads/"
const JSONHelperClass = preload("res://game/core/json_helper.gd")

var steam_available: bool = false
var steam: Node = null  # GodotSteam reference
var cached_items: Dictionary = {}  # item_id -> metadata
var subscribed_items: Array[String] = []


func _ready() -> void:
	name = "WorkshopManager"
	_init_directories()
	_init_steam()
	_load_cached_items()


func _init_directories() -> void:
	DirAccess.make_dir_recursive_absolute(WORKSHOP_CACHE)
	DirAccess.make_dir_recursive_absolute(WORKSHOP_DOWNLOADS)
	DirAccess.make_dir_recursive_absolute(WORKSHOP_UPLOADS)


func _init_steam() -> void:
	# Check for GodotSteam singleton
	if Engine.has_singleton("Steam"):
		steam = Engine.get_singleton("Steam")
		steam_available = true
		_log("[WorkshopManager] Steam available", "Log")

		# Connect Steam signals
		if steam.has_signal("ugc_item_created"):
			steam.ugc_item_created.connect(_on_ugc_item_created)
		if steam.has_signal("ugc_item_updated"):
			steam.ugc_item_updated.connect(_on_ugc_item_updated)
	else:
		var logger: Node = GameManager.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[WorkshopManager] Steam not available, using local mode", "Log")


## Upload a level to workshop


func upload_level(
	mdsl_path: String,
	title: String,
	description: String,
	tags: PackedStringArray = [],
	visibility: int = 0  # 0=Public, 1=Friends, 2=Private
) -> String:
	if not FileAccess.file_exists(mdsl_path):
		push_error("[WorkshopManager] Level file not found: %s" % mdsl_path)
		return ""

	# Read manifest for metadata
	var manifest: LevelPackager.LevelManifest = LevelPackager.read_manifest(mdsl_path)
	if not manifest:
		push_error("[WorkshopManager] Could not read manifest")
		return ""

	var item_id: String = manifest.id
	upload_started.emit(item_id)

	if steam_available:
		# Real Steam upload
		_steam_upload(mdsl_path, title, description, tags, visibility)
	else:
		# Simulate local upload
		_local_upload(mdsl_path, manifest, title, description, tags)

	return item_id


func _steam_upload(
	mdsl_path: String, title: String, description: String, tags: PackedStringArray, visibility: int
) -> void:
	# Note: Actual implementation requires GodotSteam
	# This is the structure for when it's available

	# Get app ID
	var app_id: int = steam.get_app_id() if steam else 0

	# Create workshop item
	steam.create_item(app_id, 0)  # 0 = k_EWorkshopFileTypeCommunity

	# The rest happens in callbacks
	# Store pending upload data
	set_meta(
		"pending_upload",
		{
			"path": mdsl_path,
			"title": title,
			"description": description,
			"tags": tags,
			"visibility": visibility
		}
	)


func _local_upload(
	mdsl_path: String,
	manifest: LevelPackager.LevelManifest,
	title: String,
	description: String,
	tags: PackedStringArray
) -> void:
	# Simulate upload by copying to local "workshop"
	var dest_path: String = WORKSHOP_UPLOADS.path_join(manifest.id + ".mdsl")
	DirAccess.copy_absolute(mdsl_path, dest_path)

	# Create metadata entry
	var metadata := {
		"item_id": manifest.id,
		"title": title,
		"description": description,
		"tags": Array(tags),
		"author": manifest.author,
		"created": Time.get_unix_time_from_system(),
		"updated": Time.get_unix_time_from_system(),
		"local_path": dest_path,
		"downloads": 0,
		"rating": 0.0
	}

	cached_items[manifest.id] = metadata
	_save_cached_items()

	# Simulate upload delay
	await get_tree().create_timer(0.5).timeout

	upload_progress.emit(manifest.id, 1.0)
	upload_completed.emit(manifest.id, true)


## Download a workshop item


func download_item(item_id: String) -> void:
	download_started.emit(item_id)

	if steam_available:
		_steam_download(item_id)
	else:
		_local_download(item_id)


func _steam_download(item_id: String) -> void:
	# Note: Requires GodotSteam
	var workshop_id: int = int(item_id)
	steam.download_item(workshop_id, true)


func _local_download(item_id: String) -> void:
	# Check if item exists in uploads (simulated workshop)
	var source_path: String = WORKSHOP_UPLOADS.path_join(item_id + ".mdsl")
	var dest_path: String = WORKSHOP_DOWNLOADS.path_join(item_id + ".mdsl")

	if FileAccess.file_exists(source_path):
		DirAccess.copy_absolute(source_path, dest_path)

		# Add to subscribed
		if item_id not in subscribed_items:
			subscribed_items.append(item_id)
			_save_subscriptions()

		download_completed.emit(item_id, true, dest_path)
	else:
		download_completed.emit(item_id, false, "")


## Subscribe to a workshop item


func subscribe(item_id: String) -> void:
	if steam_available:
		steam.subscribe_item(int(item_id))

	if item_id not in subscribed_items:
		subscribed_items.append(item_id)
		_save_subscriptions()

	subscription_changed.emit(item_id, true)

	# Auto-download
	download_item(item_id)


## Unsubscribe from a workshop item


func unsubscribe(item_id: String) -> void:
	if steam_available:
		steam.unsubscribe_item(int(item_id))

	subscribed_items.erase(item_id)
	_save_subscriptions()

	# Remove downloaded file
	var local_path: String = WORKSHOP_DOWNLOADS.path_join(item_id + ".mdsl")
	if FileAccess.file_exists(local_path):
		DirAccess.remove_absolute(local_path)

	subscription_changed.emit(item_id, false)


## Get all subscribed items


func get_subscribed_items() -> Array[String]:
	return subscribed_items


## Get item metadata


func get_item_metadata(item_id: String) -> Dictionary:
	return cached_items.get(item_id, {})


## Get local path for downloaded item


func get_item_local_path(item_id: String) -> String:
	var path: String = WORKSHOP_DOWNLOADS.path_join(item_id + ".mdsl")
	if FileAccess.file_exists(path):
		return path
	return ""


## Search/browse workshop items


func browse_items(
	query: String = "", tags: PackedStringArray = [], sort_by: String = "updated"
) -> void:
	if steam_available:
		_steam_browse(query, tags, sort_by)
	else:
		_local_browse(query, tags, sort_by)


func _steam_browse(query: String, _tags: PackedStringArray, _sort_by: String) -> void:
	# This checkout does not expose a GodotSteam UGC query method or callback.
	# Never pretend that Steam browsing succeeded when only local browsing is
	# available.
	var reason := "Steam Workshop browsing is unavailable: no GodotSteam UGC query API was discovered"
	push_error("[WorkshopManager] %s" % reason)
	browse_failed.emit(query, reason)


func _local_browse(query: String, tags: PackedStringArray, _sort_by: String) -> void:
	var results: Array[Dictionary] = []

	for item_id: String in cached_items:
		var item: Dictionary = cached_items[item_id]

		# Filter by query
		if not query.is_empty():
			var title: String = item.get("title", "").to_lower()
			if query.to_lower() not in title:
				continue

		# Filter by tags
		if not tags.is_empty():
			var item_tags: Array = item.get("tags", [])
			var has_tag: bool = false
			for tag: String in tags:
				if tag in item_tags:
					has_tag = true
					break
			if not has_tag:
				continue

		results.append(item)

	items_loaded.emit(results)


## Steam callbacks


func _on_ugc_item_created(result: int, file_id: int, needs_accept: bool) -> void:
	if result != 1:  # k_EResultOK
		upload_completed.emit(str(file_id), false)
		return

	# Item created, now update it with content
	var pending: Dictionary = get_meta("pending_upload", {})
	if pending.is_empty():
		return

	# Set item content
	var update_handle: int = steam.start_item_update(steam.get_app_id(), file_id)
	steam.set_item_title(update_handle, pending.title)
	steam.set_item_description(update_handle, pending.description)
	steam.set_item_visibility(update_handle, pending.visibility)
	steam.set_item_tags(update_handle, pending.tags)
	steam.set_item_content(update_handle, pending.path.get_base_dir())

	# Extract and set preview
	var thumbnail: Image = LevelPackager.read_thumbnail(pending.path)
	if thumbnail:
		var preview_path: String = WORKSHOP_CACHE + "preview_temp.png"
		thumbnail.save_png(preview_path)
		steam.set_item_preview(update_handle, preview_path)

	# Submit update
	steam.submit_item_update(update_handle, "Initial upload")

	if needs_accept:
		_log("[WorkshopManager] Item needs legal agreement acceptance", "Log")


func _on_ugc_item_updated(result: int, needs_accept: bool) -> void:
	var pending: Dictionary = get_meta("pending_upload", {})
	var item_id: String = pending.get("item_id", "")

	if result == 1:  # k_EResultOK
		upload_completed.emit(item_id, true)
	else:
		upload_completed.emit(item_id, false)

	if needs_accept:
		_log("[WorkshopManager] Update needs legal agreement acceptance", "Log")

	remove_meta("pending_upload")


## Persistence


func _load_cached_items() -> void:
	var path: String = WORKSHOP_CACHE + "items_cache.json"
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	var json: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json)
	if parsed is Dictionary:
		cached_items = parsed

	_load_subscriptions()


func _save_cached_items() -> void:
	var path: String = WORKSHOP_CACHE + "items_cache.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSONHelperClass.safe_stringify(cached_items, "\t"))
		file.close()


func _load_subscriptions() -> void:
	var path: String = WORKSHOP_CACHE + "subscriptions.json"
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return

	var json: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json)
	if parsed is Array:
		subscribed_items.clear()
		for item: String in parsed:
			subscribed_items.append(item)


func _save_subscriptions() -> void:
	var path: String = WORKSHOP_CACHE + "subscriptions.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSONHelperClass.safe_stringify(Array(subscribed_items), "\t"))
		file.close()


## Check if item is subscribed


func is_subscribed(item_id: String) -> bool:
	return item_id in subscribed_items


## Check if Steam is available


func is_steam_available() -> bool:
	return steam_available
