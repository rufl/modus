extends Node

signal language_changed(lang_code: String)

const LANG_DIR: String = "res://game/data/lang/"
const DEFAULT_LANG: String = "en"

var current_language: String = DEFAULT_LANG

var _translations: Dictionary = {}
var _available_languages: Dictionary = {}


func _ready() -> void:
	_scan_languages()
	_load_settings()
	load_language(current_language)
	GameManager.get_core_system("logger").info(
		"[LocalizationManager] Initialized. Language: %s" % current_language, "Core"
	)


## Translate a key


func translate(key: String) -> String:
	if _translations.has(key):
		return _translations[key]
	return key  # Fallback to key if not found


## Load a specific language


func load_language(lang_code: String) -> void:
	if not _available_languages.has(lang_code):
		push_warning("[LocalizationManager] Language not found: %s" % lang_code)
		if lang_code != DEFAULT_LANG:
			load_language(DEFAULT_LANG)
		return

	var path: String = LANG_DIR + lang_code + ".json"
	var file_content: String = FileAccess.get_file_as_string(path)

	if file_content.is_empty():
		push_error("[LocalizationManager] Failed to load language file: %s" % path)
		return

	var json: JSON = JSON.new()
	var err: Error = json.parse(file_content)
	if err == OK:
		_translations = json.data
		current_language = lang_code
		language_changed.emit(lang_code)
		_save_settings()
		GameManager.get_core_system("logger").info(
			"[LocalizationManager] Loaded language: %s" % lang_code, "Core"
		)
	else:
		push_error(
			"[LocalizationManager] JSON parse error in %s: %s" % [path, json.get_error_message()]
		)

	# Load translations from enabled mods
	_load_mod_translations(lang_code)

	current_language = lang_code
	language_changed.emit(lang_code)
	_save_settings()
	GameManager.get_core_system("logger").info(
		"[LocalizationManager] Loaded language: %s" % lang_code, "Core"
	)


## Load translations from enabled mods


func _load_mod_translations(lang_code: String) -> void:
	# Get ModLoader from GameCore if available
	var mod_loader_service: Node = null
	if GameManager and GameManager.has_method("get_service"):
		mod_loader_service = GameManager.get_core_system("mod_loader")

	if not mod_loader_service:
		return

	var loaded_mods: Array = mod_loader_service.get_loaded_mods()
	for mod: Dictionary in loaded_mods:
		var mod_lang_path: String = mod.path.path_join("lang").path_join(lang_code + ".json")

		if FileAccess.file_exists(mod_lang_path):
			var content: String = FileAccess.get_file_as_string(mod_lang_path)
			var json: JSON = JSON.new()
			var err: Error = json.parse(content)

			if err == OK:
				if typeof(json.data) == TYPE_DICTIONARY:
					_merge_translations(json.data)
					var logger: Node = GameManager.get_core_system("logger")
					if logger:
						logger.info(
							(
								"[LocalizationManager] Loaded mod translations for %s from %s"
								% [lang_code, mod.name]
							),
							"Core"
						)
			else:
				push_warning(
					"[LocalizationManager] Failed to parse mod lang file: %s" % [mod_lang_path]
				)


## Merge new translations into existing dictionary


func _merge_translations(new_data: Dictionary) -> void:
	for key: String in new_data:
		_translations[key] = new_data[key]


## Get list of available language codes


func get_available_languages() -> Array:
	return _available_languages.keys()


## Get display name for a language code


func get_language_name(code: String) -> String:
	return _available_languages.get(code, code)


## Scan game/lang directory for json files


func _scan_languages() -> void:
	_available_languages.clear()
	var dir: DirAccess = DirAccess.open(LANG_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				var code: String = file_name.get_basename()
				# Map code to display name (could be enhanced with a proper mapping)
				var display_name: String = code.to_upper()
				if code == "en":
					display_name = "English"
				elif code == "es":
					display_name = "Español"
				elif code == "fr":
					display_name = "Français"
				elif code == "de":
					display_name = "Deutsch"
				elif code == "pt":
					display_name = "Português"

				_available_languages[code] = display_name
			file_name = dir.get_next()
	else:
		push_error("[LocalizationManager] Could not open language directory: %s" % LANG_DIR)


## Save language preference


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load("user://options.cfg")  # Load existing to preserve other settings
	config.set_value("general", "language", current_language)
	config.save("user://options.cfg")


## Load language preference


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var err: Error = config.load("user://options.cfg")
	if err == OK:
		current_language = config.get_value("general", "language", DEFAULT_LANG)
