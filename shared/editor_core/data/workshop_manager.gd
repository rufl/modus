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
var steam: Object = null  # GodotSteam singleton
var steam_ugc_available: bool = false
var cached_items: Dictionary = {}  # item_id -> metadata
var subscribed_items: Array[String] = []
var _active_browse_query_handle: int = 0
var _active_browse_query_text: String = ""
var _steam_ugc_unavailable_reason: String = ""

const _STEAM_UGC_QUERY_METHODS: Array[String] = [
	"createQueryAllUGCRequest",
	"sendQueryUGCRequest",
	"getQueryUGCResult",
	"releaseQueryUGCRequest",
	"setSearchText",
	"addRequiredTag",
	"setMatchAnyTag",
]


func _ready() -> void:
	name = "WorkshopManager"
	_init_directories()
	_init_steam()
	_load_cached_items()


func _exit_tree() -> void:
	_release_active_browse_query()
	if steam and steam.has_signal("ugc_query_completed"):
		var query_callback := Callable(self, "_on_ugc_query_completed")
		if steam.is_connected("ugc_query_completed", query_callback):
			steam.disconnect("ugc_query_completed", query_callback)
	if steam and steam.has_signal("steam_shutdown"):
		var shutdown_callback := Callable(self, "_on_steam_shutdown")
		if steam.is_connected("steam_shutdown", shutdown_callback):
			steam.disconnect("steam_shutdown", shutdown_callback)


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
		if steam.has_signal("steam_shutdown"):
			var shutdown_callback := Callable(self, "_on_steam_shutdown")
			if not steam.is_connected("steam_shutdown", shutdown_callback):
				steam.connect("steam_shutdown", shutdown_callback)
		steam_ugc_available = _detect_steam_ugc_capability()
		if steam_ugc_available:
			var query_callback := Callable(self, "_on_ugc_query_completed")
			if not steam.is_connected("ugc_query_completed", query_callback):
				steam.connect("ugc_query_completed", query_callback)
		else:
			_log("[WorkshopManager] %s" % _steam_ugc_unavailable_reason, "Warning")
	else:
		var logger: Node = GameManager.get_core_system("logger")
		if logger and logger.has_method("info"):
			logger.info("[WorkshopManager] Steam not available, using local mode", "Log")


func _detect_steam_ugc_capability() -> bool:
	_steam_ugc_unavailable_reason = ""
	if not steam:
		_steam_ugc_unavailable_reason = "Steam Workshop browsing is unavailable: the Steam singleton is missing"
		return false

	var missing_methods: Array[String] = []
	for method_name: String in _STEAM_UGC_QUERY_METHODS:
		if not steam.has_method(method_name):
			missing_methods.append(method_name)
	if not missing_methods.is_empty():
		_steam_ugc_unavailable_reason = (
			(
				"Steam Workshop browsing is unavailable: GodotSteam is missing UGC methods: %s. "
				+ "Install a GodotSteam build with ISteamUGC query support."
			)
			% ", ".join(missing_methods)
		)
		return false
	if not steam.has_signal("ugc_query_completed"):
		_steam_ugc_unavailable_reason = (
			"Steam Workshop browsing is unavailable: GodotSteam is missing the "
			+ "ugc_query_completed callback signal. Install a GodotSteam build with UGC query support."
		)
		return false
	return true


func _steam_get_app_id() -> int:
	if not steam:
		return 0
	for method_name: String in ["get_current_app_id", "getAppID", "get_app_id"]:
		if steam.has_method(method_name):
			return int(steam.call(method_name))
	return 0


func _steam_constant(name: String, fallback: int) -> int:
	if steam and name in steam:
		return int(steam.get(name))
	return fallback


func _release_active_browse_query() -> void:
	if _active_browse_query_handle != 0 and steam and steam.has_method("releaseQueryUGCRequest"):
		steam.call("releaseQueryUGCRequest", _active_browse_query_handle)
	_active_browse_query_handle = 0
	_active_browse_query_text = ""


func _on_steam_shutdown() -> void:
	steam_ugc_available = false
	_steam_ugc_unavailable_reason = ("Steam Workshop browsing is unavailable: Steam shut down while the Workshop request was active")
	if _active_browse_query_handle != 0:
		_fail_browse(_active_browse_query_text, _steam_ugc_unavailable_reason)


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


func _steam_browse(query: String, tags: PackedStringArray, sort_by: String) -> void:
	if not steam_ugc_available:
		var reason := _steam_ugc_unavailable_reason
		if reason.is_empty():
			reason = "Steam Workshop browsing is unavailable: GodotSteam UGC capability was not detected"
		_fail_browse(query, reason)
		return

	_release_active_browse_query()
	var app_id := _steam_get_app_id()
	if app_id <= 0:
		_fail_browse(
			query,
			(
				"Steam Workshop browsing is unavailable: GodotSteam reports no current app ID. "
				+ "Initialize Steam with the configured Workshop app ID before browsing."
			)
		)
		return

	var query_type := _steam_constant("UGC_QUERY_RANKED_BY_LAST_UPDATED_DATE", 19)
	match sort_by:
		"downloads":
			query_type = _steam_constant("UGC_QUERY_RANKED_BY_TOTAL_UNIQUE_SUBSCRIPTIONS", 12)
		"rating":
			query_type = _steam_constant("UGC_QUERY_RANKED_BY_VOTE", 0)
		"updated":
			query_type = _steam_constant("UGC_QUERY_RANKED_BY_LAST_UPDATED_DATE", 19)
		_:
			query_type = _steam_constant("UGC_QUERY_RANKED_BY_LAST_UPDATED_DATE", 19)

	var matching_type := _steam_constant("UGC_MATCHING_UGC_TYPE_ITEMS_READY_TO_USE", 2)
	var handle_variant: Variant = steam.call(
		"createQueryAllUGCRequest", query_type, matching_type, app_id, app_id, 1
	)
	var query_handle := int(handle_variant)
	if query_handle <= 0:
		_fail_browse(
			query,
			(
				"Steam Workshop browsing could not create a UGC query. "
				+ "Verify the configured app ID and Workshop configuration."
			)
		)
		return

	_active_browse_query_handle = query_handle
	_active_browse_query_text = query

	if not query.is_empty():
		var search_result: Variant = steam.call("setSearchText", query_handle, query)
		if search_result is bool and not search_result:
			_fail_browse(
				query, "Steam rejected the Workshop search text; use a shorter non-empty query."
			)
			return

	for tag: String in tags:
		var clean_tag := tag.strip_edges()
		if clean_tag.is_empty():
			continue
		var tag_result: Variant = steam.call("addRequiredTag", query_handle, clean_tag)
		if tag_result is bool and not tag_result:
			_fail_browse(
				query,
				(
					"Steam rejected Workshop tag '%s'. Check that the tag is non-empty and supported by the app."
					% clean_tag
				)
			)
			return

	if tags.size() > 1:
		var match_result: Variant = steam.call("setMatchAnyTag", query_handle, true)
		if match_result is bool and not match_result:
			_fail_browse(
				query,
				"Steam could not configure multi-tag Workshop matching for this GodotSteam build."
			)
			return

	var send_result: Variant = steam.call("sendQueryUGCRequest", query_handle)
	# GodotSteam's documented binding returns void; some bindings expose a
	# SteamAPICall_t instead. Zero or a negative value means the request failed.
	if send_result is bool and not send_result:
		_fail_browse(query, "Steam rejected the Workshop UGC query request.")
	elif send_result is int and send_result <= 0:
		_fail_browse(
			query,
			"Steam could not start the Workshop UGC query. Verify that Steam is running and try again."
		)


func _fail_browse(query: String, reason: String) -> void:
	_release_active_browse_query()
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


func _on_ugc_query_completed(
	query_handle: int,
	result: int,
	results_returned: int,
	_total_matching: int,
	_cached: bool,
	_next_cursor: String = ""
) -> void:
	if query_handle != _active_browse_query_handle:
		# A replaced query was already released. Do not release this stale callback
		# again because some Steam runtimes invalidate released handles immediately.
		return

	var query := _active_browse_query_text
	var ok_result := _steam_constant("RESULT_OK", 1)
	if result != ok_result:
		_release_active_browse_query()
		_fail_browse(
			query,
			(
				"Steam Workshop UGC query failed with result code %d. "
				+ (
					"Verify Steam is running, the app is authorized, and Workshop is enabled."
					% result
				)
			)
		)
		return

	var items: Array[Dictionary] = []
	for index: int in range(maxi(results_returned, 0)):
		var raw_item: Variant = steam.call("getQueryUGCResult", query_handle, index)
		if raw_item is Dictionary and not raw_item.is_empty():
			items.append(_convert_steam_ugc_metadata(raw_item))

	_release_active_browse_query()
	items_loaded.emit(items)


func _convert_steam_ugc_metadata(raw_item: Dictionary) -> Dictionary:
	var tags: Array[String] = []
	var raw_tags: Variant = raw_item.get("tags", [])
	if raw_tags is String:
		for tag: String in raw_tags.split(",", false):
			var clean_tag := tag.strip_edges()
			if not clean_tag.is_empty():
				tags.append(clean_tag)
	elif raw_tags is Array or raw_tags is PackedStringArray:
		for tag: Variant in raw_tags:
			var clean_tag := str(tag).strip_edges()
			if not clean_tag.is_empty():
				tags.append(clean_tag)

	var file_id := int(raw_item.get("file_id", 0))
	var score_variant: Variant = raw_item.get("score", 0.0)
	var score := float(score_variant) if score_variant is float or score_variant is int else 0.0
	return {
		"item_id": str(file_id),
		"title": str(raw_item.get("title", "")),
		"description": str(raw_item.get("description", "")),
		"tags": tags,
		"author": str(raw_item.get("steam_id_owner", "")),
		"created": int(raw_item.get("time_created", 0)),
		"updated": int(raw_item.get("time_updated", 0)),
		"local_path": "",
		"downloads":
		int(
			raw_item.get("total_unique_subscriptions", raw_item.get("num_unique_subscriptions", 0))
		),
		"rating": score,
		"preview_url": str(raw_item.get("preview_url", "")),
		"steam_data": raw_item,
	}


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
