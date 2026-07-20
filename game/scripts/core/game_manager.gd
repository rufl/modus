extends Node

## GameManager - Central autoload consolidating GameCore, EventBus, and GameDatabase
##
## This is the single autoload for the refactored architecture, providing:
## - State machine for game lifecycle
## - Service locator for core systems
## - Event bus for decoupled communication
## - Feature module management with toggles
## - Configuration management

# ============================================================================
# CONSTANTS (Migrated from GameCore)
# ============================================================================

# Game Version
const GAME_VERSION: String = "0.9.5-beta"

# Audio Bus Names
const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const BUS_VOICE := "Voice"
const BUS_AMBIENT := "Ambient"

# Scene Groups
const GROUP_PLAYER := "player"
const GROUP_ENEMIES := "enemies"
const GROUP_PROJECTILES := "projectiles"
const GROUP_ITEMS := "items"
const GROUP_INTERACTABLE := "interactable"
const GROUP_INTERACTABLES := "interactables"
const GROUP_LOOTABLE := "lootable"
const GROUP_DAMAGEABLE := "damageable"
const GROUP_DESTRUCTIBLE := "destructible"
const GROUP_HITTABLE := "hittable"
const GROUP_PUSHABLE := "pushable"
const GROUP_SPAWN_PLAYER := "spawn_player"
const GROUP_SPAWN_ENEMY := "spawn_enemy"
const GROUP_SPAWN_ITEM := "spawn_item"
const GROUP_PLAYER_SPAWN := "player_spawn"
const GROUP_LEVEL_ROOT := "level_root"
const GROUP_PROPS := "props"
const GROUP_CRATES := "crates"
const GROUP_SECRETS := "secrets"
const GROUP_LADDERS := "ladders"
const GROUP_ROPES := "ropes"
const GROUP_HORIZONTAL_LADDERS := "horizontal_ladders"
const GROUP_TRAVERSABLE := "traversable"
const GROUP_GIBS := "gibs"
const GROUP_ORGANS := "organs"
const GROUP_DISMEMBERED_LIMBS := "dismembered_limbs"
const GROUP_BLOOD_DROPLETS := "blood_droplets"
const GROUP_WEAPON_RACKS := "weapon_racks"
const GROUP_TREASURE_CHESTS := "treasure_chests"
const GROUP_MILITARY_CHESTS := "military_chests"
const GROUP_HIDDEN_STASHES := "hidden_stashes"
const GROUP_CORPSE_PILES := "corpse_piles"
const GROUP_BREAKABLE_PROPS := "breakable_props"
const GROUP_LOOT_PROP_SPAWNERS := "loot_prop_spawners"
const GROUP_MOUSE_STEALERS := "mouse_stealers"
const GROUP_COMPASS_BAR := "compass_bar"
const GROUP_SKILL_TREE_UI := "skill_tree_ui"
const GROUP_MOD_MANAGER_UI := "mod_manager_ui"
const GROUP_TRAVERSAL_HINT_DISPLAY := "traversal_hint_display"
const GROUP_MOD_LOADER := "mod_loader"
const GROUP_TARGETING_SYSTEM := "targeting_system"
const GROUP_LOD_MANAGER := "lod_manager"

# Resource Paths
const PATH_WEAPONS := "res://game/weapons/"
const PATH_EFFECTS := "res://game/scenes/effects/"
const PATH_ENTITIES := "res://game/entities/"
const PATH_PROJECTILES := "res://game/entities/projectiles/"
const PATH_ITEMS := "res://game/scenes/items/"
const PATH_PROPS := "res://game/world/actors/props/"
const PATH_UI := "res://game/ui/"
const PATH_AUDIO := "res://game/art/audio/"

# Config Paths (UPDATED to new locations)
const PATH_CFG := "res://game/config/"
const CFG_AUDIO := "res://game/config/gameplay/audio.json5"
const CFG_GAMEPLAY := "res://game/config/gameplay/gameplay.json5"
const CFG_VISUALS := "res://game/config/performance/visuals.json5"
const CFG_SYSTEM := "res://game/config/performance/system.json5"
const CFG_WEAPONS := "res://game/config/entities/weapons.json5"
const CFG_WEAPON_ADJUSTMENTS := "res://game/config/gameplay/weapon_adjustments.json5"

# ============================================================================

# Signals
signal state_changed(old_state: State, new_state: State)
signal feature_loaded(feature_id: String)
signal feature_unloaded(feature_id: String)
signal event_emitted(event_id: String, data: Dictionary)

# Enums
enum State { INITIALIZING, READY, RUNNING, PAUSED, SHUTTING_DOWN }

# State
var _current_state: int = State.INITIALIZING
var _initialized: bool = false


func is_initialized() -> bool:
	return _initialized

# Feature modules
var _features: Dictionary = {}  # feature_id -> FeatureModule
var _feature_enabled: Dictionary = {}  # feature_id -> bool

# Core systems (service locator)
var _core_systems: Dictionary = {}  # system_id -> Node

# Event system
var _event_listeners: Dictionary = {}  # event_id -> Array[Callable]
var _event_schemas: Dictionary = {}  # event_id -> Dictionary

# Configuration (will be managed by ConfigurationManager)
var _config_manager: ConfigurationManager = null  # ConfigurationManager instance (RefCounted)

# Feature configuration
var _feature_configs: Dictionary = {}  # feature_id -> feature config from features.json5
var _feature_dependencies: Dictionary = {}  # feature_id -> Array[String] of dependencies
var _feature_load_order: Array[String] = []  # Dependency-resolved load order

# Performance profiling
var _profiling_enabled: bool = false
var _profiling_data: Dictionary = {}  # Stores profiling metrics
var _frame_times: Array[float] = []  # Recent frame times for averaging
var _max_frame_samples: int = 60  # Number of frames to track


## Helper method for conditional logging
func _log_debug(message: String, category: String = "GameManager") -> void:
	var logger: Variant = get_core_system("logger")
	if logger and logger.has_method("debug"):
		logger.debug(message, category)
	else:
		print("[%s] %s" % [category, message])


## Helper method for info logging
func _log_info(message: String, category: String = "GameManager") -> void:
	var logger: Variant = get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


## Helper method to create and register a service
## Returns the created service instance or null on failure
func _create_and_register_service(
	service_id: String, script_path: String, node_name: String
) -> Node:
	_log_info("Creating %s..." % node_name)

	if not ResourceLoader.exists(script_path):
		push_error("Service script not found: %s" % script_path)
		return null

	var service_script: GDScript = load(script_path)
	if not service_script:
		push_error("Failed to load service script: %s" % script_path)
		return null

	var service: Node = service_script.new()
	if not service:
		push_error("Failed to instantiate service: %s" % node_name)
		return null

	service.name = node_name
	add_child(service)
	if get_core_system(service_id) == null:
		register_core_system(service_id, service)

	if service.has_method("initialize"):
		service.initialize()

	_log_info("%s created and registered" % node_name)
	return service


## Create services that are always needed, regardless of feature toggles
## These services have no dependencies and are required for basic functionality
func _create_always_on_services() -> void:
	_log_info("Creating always-on core services...")

	# LogService - Required first for logging
	_create_and_register_service("logger", "res://game/scripts/core/log_service.gd", "LogService")

	# EventService - Required for event bus
	_create_and_register_service(
		"events", "res://game/scripts/core/event_service.gd", "EventService"
	)

	# GlobalState - Required for global game state
	_create_and_register_service(
		"globals", "res://game/scripts/core/global_state.gd", "GlobalState"
	)

	# DataService - Required for loading game data (weapons, enemies, etc.)
	_create_and_register_service(
		"data", "res://game/scripts/features/data/data_service.gd", "DataService"
	)

	# AudioSystem - Required for sound and music
	_create_and_register_service(
		"audio", "res://game/scripts/features/audio/audio_service.gd", "AudioSystem"
	)

	# UISystem - Required for menus, HUD, and UI management
	_create_and_register_service("ui", "res://game/scripts/features/ui/ui_service.gd", "UISystem")

	# PerformanceService - Required for performance monitoring
	_create_and_register_service(
		"performance",
		"res://game/scripts/features/performance/performance_service.gd",
		"PerformanceService"
	)

	# LocalizationManager - Required for translations
	_create_and_register_service(
		"localization",
		"res://game/scripts/features/localization/localization_manager.gd",
		"LocalizationManager"
	)

	# EntityService - Required for entity tracking
	_create_and_register_service(
		"entities", "res://game/scripts/features/gameplay/entity_service.gd", "EntityService"
	)

	# SaveService - Required for save/load functionality
	_create_and_register_service(
		"save", "res://game/scripts/features/save/save_service.gd", "SaveService"
	)

	# ModLoader - Required for mod support
	_create_and_register_service(
		"mod_loader", "res://game/scripts/features/modding/mod_loader.gd", "ModLoader"
	)

	# ChatService - Required for multiplayer chat
	_create_and_register_service(
		"chat", "res://game/scripts/features/network/chat_service.gd", "ChatService"
	)

	# NetworkService - Infrastructure is safe to keep available even when the
	# active feature profile does not auto-start multiplayer gameplay.
	_create_and_register_service(
		"network", "res://game/scripts/features/network/network_service.gd", "NetworkService"
	)

	# AssetManager - Required for asset loading and overrides
	_create_and_register_service(
		"assets", "res://game/scripts/features/data/asset_manager.gd", "AssetManager"
	)

	# UIInputManager - Required for centralized UI input with proper precedence
	_create_and_register_service(
		"ui_input", "res://game/scripts/core/ui_input_manager.gd", "UIInputManager"
	)

	_log_info("Always-on core services created")


func _ready() -> void:
	if not _initialized:
		initialize()


func _exit_tree() -> void:
	## === SIGNAL HYGIENE: Cleanup all event listeners and prevent memory leaks ===

	# 1. Clear all event listeners
	for listeners: Array in _event_listeners.values():
		listeners.clear()
	_event_listeners.clear()
	_event_schemas.clear()

	# 2. Shutdown all features in reverse order
	var feature_ids: Array = _features.keys()
	feature_ids.reverse()
	for feature_id: String in feature_ids:
		unload_feature(feature_id)

	# 3. Clear all core systems
	_core_systems.clear()

	# 4. Clear feature data
	_features.clear()
	_feature_enabled.clear()
	_feature_configs.clear()
	_feature_dependencies.clear()
	_feature_load_order.clear()

	# 5. Clear profiling data
	_profiling_data.clear()
	_frame_times.clear()

	_log_info("GameManager cleanup complete")


## Initialize the GameManager and all enabled features
func initialize() -> void:
	if _initialized:
		push_warning("GameManager already initialized")
		return

	# Initialize configuration manager
	_config_manager = ConfigurationManager.new()
	add_child(_config_manager)
	register_core_system("config", _config_manager)

	# Load core configuration files
	_config_manager.load_config_file("performance/system.json5")
	_config_manager.load_config_file("performance/graphics.json5")
	_config_manager.load_config_file("performance/visuals.json5")
	_config_manager.load_config_file("performance/debug.json5")
	_config_manager.load_config_file("gameplay/gameplay.json5")
	_config_manager.load_config_file("gameplay/loot.json5")

	# Create always-on services (required for basic functionality, no dependencies)
	_create_always_on_services()

	# Load features configuration
	_load_features_config()

	# Load active profile if specified
	_load_active_profile()

	# Create core system services early (before lazy loading)
	_create_core_services()

	# Enable profiling if configured
	_profiling_enabled = get_config("performance.profiling_enabled", false)
	if _profiling_enabled:
		_init_profiling()

	# Resolve feature load order (but don't load yet - lazy loading)
	_feature_load_order = _resolve_dependency_order()

	# Validate dependencies if enabled
	if get_config("development.validate_dependencies", true):
		if not _validate_dependencies():
			if get_config("development.fail_on_missing_dependencies", true):
				push_error("Feature dependency validation failed")
				return

	# Measure startup time
	var startup_time := Time.get_ticks_msec()
	if get_config("performance.log_startup_time", false):
		_log_info("Startup completed in %d ms (lazy loading enabled)" % startup_time)

	# Register core events
	_register_core_events()

	_initialized = true
	change_state(State.READY)


## Shutdown the GameManager and all loaded features
func shutdown() -> void:
	change_state(State.SHUTTING_DOWN)

	# Unload all features in reverse order
	var feature_ids: Array = _features.keys()
	feature_ids.reverse()
	for feature_id: String in feature_ids:
		unload_feature(feature_id)

	# Clear all systems
	_core_systems.clear()
	_event_listeners.clear()
	_event_schemas.clear()

	_initialized = false


## Register core events used throughout the game
func _register_core_events() -> void:
	# Health and combat events
	register_event("health_changed")
	register_event("armor_changed")
	register_event("damage_dealt")
	register_event("player_died")
	register_event("player_damaged")
	register_event("player_spawned")
	register_event("enemy_died")

	# Match events
	register_event("match_started")
	register_event("match_ended")

	# Item events
	register_event("item_picked_up")
	register_event("xp_gained")

	# Weapon events
	register_event("ammo_changed")
	register_event("weapon_switched")
	register_event("reload_started")
	register_event("reload_finished")

	# AI events
	register_event("ai_movement_stuck")

	# UI events
	register_event("focus_group_changed")
	register_event("screen_opened")
	register_event("screen_closed")
	register_event("modal_shown")


## Change the game state
func change_state(new_state: int) -> void:
	if new_state == _current_state:
		return

	var old_state: int = _current_state
	_current_state = new_state
	state_changed.emit(old_state, new_state)


## Get the current game state
func get_state() -> int:
	return _current_state


## Get a feature module by ID with lazy loading
## Automatically loads the feature if it's enabled but not yet loaded
## Returns the feature instance, or null if not available
func get_feature(feature_id: String) -> Node:
	# If feature is already loaded, return it
	if _features.has(feature_id):
		return _features[feature_id]

	# If feature is enabled but not loaded, load it now (lazy loading)
	if is_feature_enabled(feature_id):
		var load_start := Time.get_ticks_msec()
		if load_feature(feature_id):
			var load_time := Time.get_ticks_msec() - load_start
			if get_config("performance.log_lazy_loading", false):
				_log_debug("Lazy-loaded feature '%s' in %d ms" % [feature_id, load_time])
			return _features.get(feature_id, null)

	return null


## Load a feature module by ID
## Returns true if the feature was loaded successfully
func load_feature(feature_id: String) -> bool:
	var load_start := Time.get_ticks_msec()

	if _features.has(feature_id):
		push_warning("Feature '%s' is already loaded" % feature_id)
		return true

	if not is_feature_enabled(feature_id):
		push_warning("Feature '%s' is not enabled in configuration" % feature_id)
		return false

	# Check if feature config exists
	if not _feature_configs.has(feature_id):
		push_error("Feature '%s' not found in features.json5" % feature_id)
		return false

	var feature_config: Dictionary = _feature_configs[feature_id]

	# Check if this is a core system (no module to load)
	if feature_config.get("core_system", false):
		# Core systems should already be created by _create_core_services()
		# Recreate missing core systems when a caller explicitly reloads one.
		if not _features.has(feature_id):
			_create_core_services()
		if not _features.has(feature_id):
			push_warning("Core system '%s' was not created during initialization" % feature_id)
			return false

		# Already loaded, just emit signal
		feature_loaded.emit(feature_id)
		return true

	# Load dependencies first
	var dependencies: Array = feature_config.get("dependencies", [])
	for dep_id: String in dependencies:
		if not _features.has(dep_id):
			if not load_feature(dep_id):
				push_error("Failed to load dependency '%s' for feature '%s'" % [dep_id, feature_id])
				return false

	# Load the feature module
	var module_path: String = feature_config.get("module_path", "")
	if module_path.is_empty():
		push_error("Feature '%s' has no module_path specified" % feature_id)
		return false

	# Check if module file exists
	if not ResourceLoader.exists(module_path):
		push_error("Feature module not found: %s" % module_path)
		return false

	# Load and instantiate the feature module
	var module_script: Script = load(module_path)
	if not module_script:
		push_error("Failed to load feature module script: %s" % module_path)
		return false

	var feature_instance: Node = module_script.new()
	if not feature_instance:
		push_error("Failed to instantiate feature module: %s" % feature_id)
		return false

	# Store and attach before initialization so feature modules can resolve
	# their owning GameManager through parent-based test fixtures.
	_features[feature_id] = feature_instance
	add_child(feature_instance)

	# Initialize the feature
	if feature_instance.has_method("initialize"):
		feature_instance.initialize()

	feature_loaded.emit(feature_id)

	# Record load time for profiling
	var load_time := Time.get_ticks_msec() - load_start
	if _profiling_enabled:
		_record_feature_load_time(feature_id, load_time)

	if get_config("development.log_feature_loading", false):
		_log_debug("Loaded feature: %s in %d ms" % [feature_id, load_time])

	return true


## Unload a feature module by ID
func unload_feature(feature_id: String) -> void:
	if not _features.has(feature_id):
		push_warning("Feature '%s' is not loaded" % feature_id)
		return

	var feature: Node = _features[feature_id]
	if feature and feature.has_method("shutdown"):
		feature.shutdown()
	if feature and is_instance_valid(feature):
		feature.queue_free()

	_features.erase(feature_id)
	feature_unloaded.emit(feature_id)


## Check whether a feature is currently loaded without triggering lazy loading.
func is_feature_loaded(feature_id: String) -> bool:
	return _features.has(feature_id)


## Check if a feature is enabled in configuration
func is_feature_enabled(feature_id: String) -> bool:
	return _feature_enabled.get(feature_id, false)


## Load all enabled features eagerly (disables lazy loading)
## Useful for production builds or when startup time is not critical
func load_all_features() -> void:
	var load_start := Time.get_ticks_msec()
	var loaded_count := 0

	for feature_id in _feature_load_order:
		if is_feature_enabled(feature_id) and not _features.has(feature_id):
			if load_feature(feature_id):
				loaded_count += 1

	var load_time := Time.get_ticks_msec() - load_start
	if get_config("performance.log_startup_time", false):
		_log_info("Loaded %d features in %d ms (eager loading)" % [loaded_count, load_time])


## Register a core system with the service locator
func register_core_system(system_id: String, system: Node) -> void:
	if _core_systems.has(system_id):
		push_warning("Core system '%s' is already registered" % system_id)
		return

	_core_systems[system_id] = system


## Get a core system from the service locator
## Returns null if the system is not registered
func get_core_system(system_id: String) -> Node:
	return _core_systems.get(system_id, null)


## Backward-compatible service-locator alias for migrated callers.
func get_service(service_id: String) -> Node:
	return get_core_system(service_id)


## Register an event type with optional schema validation
func register_event(event_id: String, schema: Dictionary = {}) -> void:
	if _event_schemas.has(event_id):
		push_warning("Event '%s' is already registered" % event_id)
		return

	_event_schemas[event_id] = schema
	_event_listeners[event_id] = []


## Subscribe to an event with a callback
## Priority determines callback order (higher priority = called first)
func subscribe(event_id: String, callback: Callable, priority: int = 0) -> void:
	if not _event_listeners.has(event_id):
		register_event(event_id)

	var listeners: Array = _event_listeners[event_id]
	listeners.append({"callback": callback, "priority": priority})

	# Sort by priority (descending)
	listeners.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a["priority"] > b["priority"]
	)


## Unsubscribe from an event
func unsubscribe(event_id: String, callback: Callable) -> void:
	if not _event_listeners.has(event_id):
		return

	var listeners: Array = _event_listeners[event_id]
	for i in range(listeners.size() - 1, -1, -1):
		if listeners[i]["callback"] == callback:
			listeners.remove_at(i)


## Emit an event to all subscribers
func emit_event(event_id: String, data: Dictionary = {}) -> void:
	if not _event_listeners.has(event_id):
		push_warning("Event '%s' is not registered" % event_id)
		return

	event_emitted.emit(event_id, data)

	var listeners: Array = _event_listeners[event_id]
	for listener: Dictionary in listeners:
		var callback: Callable = listener["callback"]
		# Safety check: skip invalid callables (freed objects)
		if callback.is_valid():
			callback.call(data)


## Get a configuration value by path (dot-separated)
## Returns default if the value is not found
func get_config(path: String, default: Variant = null) -> Variant:
	if _config_manager and _config_manager.has_method("get_value"):
		return _config_manager.get_value(path, default)
	return default


## Set a configuration value by path (dot-separated)
func set_config(path: String, value: Variant) -> void:
	if _config_manager and _config_manager.has_method("set_value"):
		_config_manager.set_value(path, value)
	else:
		push_warning("ConfigurationManager not available")


## Reload all configuration files
func reload_config() -> void:
	if _config_manager and _config_manager.has_method("reload_all"):
		_config_manager.reload_all()
	else:
		push_warning("ConfigurationManager not available")


# Private helper methods for feature management


## Load features.json5 configuration
func _load_features_config() -> void:
	var features_data: Dictionary = _config_manager.load_config_file("features.json5")

	if features_data.is_empty():
		push_error("Failed to load features.json5")
		return

	var features: Dictionary = features_data.get("features", {})

	# Store feature configurations and build dependency map
	for feature_id: String in features.keys():
		var feature_config: Dictionary = features[feature_id]
		_feature_configs[feature_id] = feature_config
		_feature_enabled[feature_id] = feature_config.get("enabled", false)
		_feature_dependencies[feature_id] = feature_config.get("dependencies", [])

	if get_config("development.log_feature_loading", false):
		_log_debug("Loaded %d feature configurations" % _feature_configs.size())


## Load and apply the active feature profile
func _load_active_profile() -> void:
	var active_profile := OS.get_environment("MODUS_FEATURE_PROFILE")
	if active_profile.is_empty():
		active_profile = get_config("active_profile", "")

	if active_profile.is_empty():
		return

	var profiles: Dictionary = get_config("profiles", {})
	if not profiles.has(active_profile):
		push_warning("Active profile '%s' not found in features.json5" % active_profile)
		return

	var profile_config: Dictionary = profiles[active_profile]
	var profile_features: Array = profile_config.get("features", [])

	# Disable all features first
	for feature_id: String in _feature_enabled.keys():
		_feature_enabled[feature_id] = false

	# Enable features in the profile
	for feature_id: String in profile_features:
		if _feature_configs.has(feature_id):
			_feature_enabled[feature_id] = true
		else:
			push_warning(
				"Profile '%s' references unknown feature '%s'" % [active_profile, feature_id]
			)

	if get_config("development.log_feature_loading", false):
		_log_debug(
			"Applied profile '%s' with %d features" % [active_profile, profile_features.size()]
		)


## Create core system services that are marked as core_system: true
## These services self-register and should be instantiated early
func _create_core_services() -> void:
	_log_info("Creating core system services...")

	# Map of core system feature IDs to their service script paths
	var core_service_scripts: Dictionary = {
		"match": "res://game/scripts/features/match/match_service.gd",
		"player": "res://game/scripts/features/player/player_service.gd",
		"gameplay": "res://game/scripts/features/gameplay/gameplay_service.gd",
	}

	# Create each enabled core service. Core features without concrete service
	# scripts get lightweight marker nodes so dependency resolution can treat
	# them as satisfied without inventing gameplay behavior.
	for feature_id: String in _feature_configs.keys():
		if not is_feature_enabled(feature_id):
			continue

		if not _feature_configs.has(feature_id):
			continue

		var feature_config: Dictionary = _feature_configs[feature_id]
		if not feature_config.get("core_system", false):
			continue

		if _features.has(feature_id):
			continue

		if not core_service_scripts.has(feature_id):
			var marker := Node.new()
			marker.name = feature_id.capitalize().replace(" ", "") + "Core"
			add_child(marker)
			_features[feature_id] = marker
			register_core_system(feature_id, marker)
			_log_info("Core marker created: %s" % feature_id)
			continue

		var script_path: String = core_service_scripts[feature_id]
		_log_info("Creating core service: %s" % feature_id)

		if not ResourceLoader.exists(script_path):
			push_error("[GameManager] Core service script not found: %s" % script_path)
			continue

		var service_script: GDScript = load(script_path)
		if not service_script:
			push_error("[GameManager] Failed to load core service script: %s" % script_path)
			continue

		var service: Node = service_script.new()
		if not service:
			push_error("[GameManager] Failed to instantiate core service: %s" % feature_id)
			continue

		service.name = feature_id.capitalize().replace(" ", "") + "Service"
		add_child(service)
		register_core_system(feature_id, service)

		# Mark as loaded in features
		_features[feature_id] = service

		_log_info("Core service created: %s" % feature_id)

	_log_info("Core system services created")


## Load all enabled features in dependency order
func _load_enabled_features() -> void:
	# Resolve load order with dependency resolution
	_feature_load_order = _resolve_dependency_order()

	if _feature_load_order.is_empty():
		push_warning("No features to load")
		return

	# Validate dependencies if enabled
	if get_config("development.validate_dependencies", true):
		if not _validate_dependencies():
			if get_config("development.fail_on_missing_dependencies", true):
				push_error("Feature dependency validation failed")
				return

	# Load features in dependency order
	for feature_id: String in _feature_load_order:
		if is_feature_enabled(feature_id):
			load_feature(feature_id)


## Resolve feature load order using topological sort
## Returns an array of feature IDs in dependency order
func _resolve_dependency_order() -> Array[String]:
	var order: Array[String] = []
	var visited: Dictionary = {}  # feature_id -> bool
	var visiting: Dictionary = {}  # feature_id -> bool (for cycle detection)

	# Helper function for depth-first search
	var visit_feature: Callable = func(feature_id: String, visit_func: Callable) -> bool:
		if visited.get(feature_id, false):
			return true

		if visiting.get(feature_id, false):
			push_error("Circular dependency detected involving feature '%s'" % feature_id)
			return false

		visiting[feature_id] = true

		# Visit dependencies first
		var dependencies: Array = _feature_dependencies.get(feature_id, [])
		for dep_id: String in dependencies:
			if not _feature_configs.has(dep_id):
				push_error("Feature '%s' depends on unknown feature '%s'" % [feature_id, dep_id])
				return false

			if not visit_func.call(dep_id, visit_func):
				return false

		visiting[feature_id] = false
		visited[feature_id] = true
		order.append(feature_id)
		return true

	# Visit all features
	for feature_id: String in _feature_configs.keys():
		if not visited.get(feature_id, false):
			if not visit_feature.call(feature_id, visit_feature):
				return []

	return order


## Validate that all enabled features have their dependencies enabled
## Returns true if all dependencies are satisfied
func _validate_dependencies() -> bool:
	var is_valid: bool = true

	for feature_id: String in _feature_configs.keys():
		if not is_feature_enabled(feature_id):
			continue

		var dependencies: Array = _feature_dependencies.get(feature_id, [])
		for dep_id: String in dependencies:
			if not is_feature_enabled(dep_id):
				push_error(
					(
						"Feature '%s' requires dependency '%s' which is not enabled"
						% [feature_id, dep_id]
					)
				)
				is_valid = false

	return is_valid


## Register a custom feature from a mod
## feature_id: Unique identifier for the feature
## feature_config: Dictionary with keys: name, module_path, dependencies, enabled
## Returns true if registration succeeded
func register_mod_feature(feature_id: String, feature_config: Dictionary) -> bool:
	if _feature_configs.has(feature_id):
		push_error("Feature '%s' is already registered" % feature_id)
		return false

	# Validate required fields
	if not feature_config.has("module_path"):
		push_error("Feature '%s' missing required 'module_path'" % feature_id)
		return false

	# Add to feature configs
	_feature_configs[feature_id] = feature_config

	# Set enabled state (default to true for mod features)
	var enabled: bool = feature_config.get("enabled", true)
	_feature_enabled[feature_id] = enabled

	# Register dependencies
	var dependencies: Array = feature_config.get("dependencies", [])
	_feature_dependencies[feature_id] = dependencies

	# If enabled, load the feature immediately
	if enabled:
		return load_feature(feature_id)

	return true


# Performance Profiling Methods


## Initialize profiling system
func _init_profiling() -> void:
	_profiling_data = {
		"startup_time": 0,
		"feature_load_times": {},
		"frame_times": [],
		"memory_usage": {},
		"enabled": true
	}

	if get_config("performance.log_profiling", false):
		_log_info("Performance profiling enabled")


## Called every frame to track frame time
func _process(delta: float) -> void:
	if not _profiling_enabled:
		return

	# Track frame times
	_frame_times.append(delta * 1000.0)  # Convert to milliseconds

	# Keep only recent samples
	if _frame_times.size() > _max_frame_samples:
		_frame_times.pop_front()

	# Log frame time periodically
	if get_config("performance.log_frame_times", false):
		if Engine.get_frames_drawn() % 60 == 0:  # Log every 60 frames
			var avg_frame_time := _get_average_frame_time()
			_log_debug(
				"Average frame time: %.2f ms (%.1f FPS)" % [avg_frame_time, 1000.0 / avg_frame_time]
			)


## Record feature load time
func _record_feature_load_time(feature_id: String, load_time_ms: int) -> void:
	if not _profiling_enabled:
		return

	if not _profiling_data.has("feature_load_times"):
		_profiling_data["feature_load_times"] = {}

	_profiling_data["feature_load_times"][feature_id] = load_time_ms

	if get_config("performance.log_feature_loading", false):
		_log_debug("Feature '%s' loaded in %d ms" % [feature_id, load_time_ms])


## Get average frame time in milliseconds
func _get_average_frame_time() -> float:
	if _frame_times.is_empty():
		return 0.0

	var sum := 0.0
	for time in _frame_times:
		sum += time

	return sum / _frame_times.size()


## Get current memory usage
func _get_memory_usage() -> Dictionary:
	return {
		"static": Performance.get_monitor(Performance.MEMORY_STATIC) / 1024.0 / 1024.0,  # MB
		"static_max": Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1024.0 / 1024.0  # MB
	}


## Get profiling data
func get_profiling_data() -> Dictionary:
	if not _profiling_enabled:
		return {}

	var data := _profiling_data.duplicate(true)
	data["current_frame_time"] = _get_average_frame_time()
	data["memory_usage"] = _get_memory_usage()
	data["fps"] = Engine.get_frames_per_second()

	return data


## Enable or disable profiling at runtime
func set_profiling_enabled(enabled: bool) -> void:
	_profiling_enabled = enabled

	if enabled and not _profiling_data.has("enabled"):
		_init_profiling()

	if get_config("performance.log_profiling", false):
		_log_info("Profiling %s" % ("enabled" if enabled else "disabled"))


## Check if profiling is enabled
func is_profiling_enabled() -> bool:
	return _profiling_enabled


## Log current profiling summary
func log_profiling_summary() -> void:
	if not _profiling_enabled:
		_log_info("Profiling is not enabled")
		return

	var data := get_profiling_data()

	_log_info("\n=== GameManager Performance Profile ===")
	_log_info("Startup Time: %d ms" % data.get("startup_time", 0))
	_log_info(
		(
			"Average Frame Time: %.2f ms (%.1f FPS)"
			% [data.get("current_frame_time", 0), data.get("fps", 0)]
		)
	)

	var memory: Dictionary = data.get("memory_usage", {})
	_log_info(
		(
			"Memory Usage: %.2f MB static (max: %.2f MB)"
			% [memory.get("static", 0), memory.get("static_max", 0)]
		)
	)

	var feature_times: Dictionary = data.get("feature_load_times", {})
	if not feature_times.is_empty():
		_log_info("\nFeature Load Times:")
		for feature_id: String in feature_times.keys():
			_log_info("  - %s: %d ms" % [feature_id, feature_times[feature_id]])

	_log_info("=====================================\n")
