## RuleModuleLoader - Loads and manages rule modules for map generation
##
## This class is responsible for discovering, loading, and managing rule modules
## from the designated rules directory. It supports hot-reloading during development
## and maintains a registry of loaded rules organized by phase.
##
## **Validates: Requirements 24.1, 24.6**

class_name RuleModuleLoader
extends RefCounted

# Preload RuleBase to avoid type resolution issues
const RuleBase = preload("res://game/scripts/map_generator/rule_base.gd")

## Path to the rules directory
const RULES_DIR := "res://game/data/map_generator/rules/"

## Registry of loaded rule modules organized by phase
var _rules_by_phase: Dictionary = {}

## All loaded rule instances
var _all_rules: Array = []  # Array of RuleBase instances

## File modification times for hot-reload detection
var _file_mtimes: Dictionary = {}

## Logger reference
var _logger: Node = null


func _init() -> void:
	# Get logger if available
	if GameManager and GameManager.has_method("get_core_system"):
		_logger = GameManager.get_core_system("logger")


## Load all rule modules from the rules directory
##
## Scans the rules directory recursively for .gd files, loads them,
## and instantiates rule objects. Rules are organized by phase for
## efficient execution.
##
## @return: true if rules were loaded successfully, false otherwise
func load_rules() -> bool:
	_log_info("Loading rule modules from: %s" % RULES_DIR)

	# Clear existing rules
	_rules_by_phase.clear()
	_all_rules.clear()
	_file_mtimes.clear()

	# Check if rules directory exists
	if not DirAccess.dir_exists_absolute(RULES_DIR):
		_log_warning("Rules directory does not exist: %s" % RULES_DIR)
		return false

	# Scan directory for rule scripts
	var rule_files := _scan_directory_recursive(RULES_DIR)

	if rule_files.is_empty():
		_log_info("No rule modules found in rules directory")
		return true

	# Load each rule file
	var loaded_count := 0
	for file_path: String in rule_files:
		if _load_rule_file(file_path):
			loaded_count += 1

	# Sort rules by priority within each phase
	_sort_rules_by_priority()

	_log_info("Loaded %d rule modules across %d phases" % [loaded_count, _rules_by_phase.size()])
	return true


## Get all rules for a specific generation phase
##
## @param phase: The phase name (e.g., "shape_grammar", "hallway_generation")
## @return: Array of RuleBase instances for the specified phase, sorted by priority
func get_rules_for_phase(phase: String) -> Array:
	if _rules_by_phase.has(phase):
		return _rules_by_phase[phase]
	return []


## Get all loaded rules across all phases
##
## @return: Array of all loaded RuleBase instances
func get_all_rules() -> Array:
	return _all_rules.duplicate()


## Get names of all loaded rules for metadata tracking
##
## @return: Array of rule names
func get_rule_names() -> Array[String]:
	var names: Array[String] = []
	for rule in _all_rules:
		names.append(rule.get_rule_name())
	return names


## Check for modified rule files and reload them (hot-reload support)
##
## This method checks file modification times and reloads any rules
## that have been modified since the last load. Useful during development.
##
## @return: true if any rules were reloaded, false otherwise
func check_and_reload_modified_rules() -> bool:
	var reloaded := false

	for file_path in _file_mtimes.keys():
		var current_mtime := FileAccess.get_modified_time(file_path)

		if current_mtime > _file_mtimes[file_path]:
			_log_info("Detected modification in rule file: %s" % file_path)

			# Remove old rule instances from this file
			_remove_rules_from_file(file_path)

			# Reload the file
			if _load_rule_file(file_path):
				_file_mtimes[file_path] = current_mtime
				reloaded = true

	if reloaded:
		_sort_rules_by_priority()
		_log_info("Hot-reloaded modified rule modules")

	return reloaded


## Scan directory recursively for .gd files
##
## @param dir_path: Directory path to scan
## @return: Array of file paths to rule scripts
func _scan_directory_recursive(dir_path: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(dir_path)

	if dir == null:
		_log_error("Failed to open directory: %s" % dir_path)
		return files

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var file_path := dir_path.path_join(file_name)

		if dir.current_is_dir():
			# Recursively scan subdirectories
			if file_name != "." and file_name != "..":
				files.append_array(_scan_directory_recursive(file_path))
		elif file_name.ends_with(".gd"):
			# Found a GDScript file
			files.append(file_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return files


## Load a single rule file and instantiate rule objects
##
## @param file_path: Path to the rule script file
## @return: true if loaded successfully, false otherwise
func _load_rule_file(file_path: String) -> bool:
	# Load the script
	var script := load(file_path) as GDScript

	if script == null:
		_log_error("Failed to load rule script: %s" % file_path)
		return false

	# Check if script extends RuleBase
	if not _is_rule_base_subclass(script):
		_log_warning("Script does not extend RuleBase, skipping: %s" % file_path)
		return false

	# Instantiate the rule
	var rule: RuleBase = script.new()

	if rule == null:
		_log_error("Failed to instantiate rule from: %s" % file_path)
		return false

	# Get rule metadata
	var rule_name: String = rule.get_rule_name()
	var phase: String = rule.get_phase()
	var priority: int = rule.get_priority()

	_log_info("Loaded rule: %s (phase=%s, priority=%d)" % [rule_name, phase, priority])

	# Add to registry
	if not _rules_by_phase.has(phase):
		_rules_by_phase[phase] = []

	_rules_by_phase[phase].append(rule)
	_all_rules.append(rule)

	# Track file modification time
	_file_mtimes[file_path] = FileAccess.get_modified_time(file_path)

	return true


## Check if a script extends RuleBase
##
## @param script: The GDScript to check
## @return: true if the script extends RuleBase, false otherwise
func _is_rule_base_subclass(script: GDScript) -> bool:
	var base := script.get_base_script()

	while base != null:
		if base.resource_path.ends_with("rule_base.gd"):
			return true
		base = base.get_base_script()

	return false


## Remove all rule instances loaded from a specific file
##
## @param _file_path: Path to the rule file
func _remove_rules_from_file(_file_path: String) -> void:
	# This is a simplified implementation - in a real system you'd need to
	# track which file each rule came from
	_log_warning("Hot-reload requires full reload - clearing all rules")
	_rules_by_phase.clear()
	_all_rules.clear()


## Sort rules by priority within each phase (higher priority first)
func _sort_rules_by_priority() -> void:
	for phase: String in _rules_by_phase.keys():
		var rules: Array = _rules_by_phase[phase]
		rules.sort_custom(
			func(a: RuleBase, b: RuleBase) -> bool: return a.get_priority() > b.get_priority()
		)


## Logging helpers
func _log_info(message: String) -> void:
	if _logger and _logger.has_method("info"):
		_logger.info("RuleModuleLoader", message)
	else:
		print("[RuleModuleLoader] INFO: ", message)


func _log_warning(message: String) -> void:
	if _logger and _logger.has_method("warning"):
		_logger.warning("RuleModuleLoader", message)
	else:
		push_warning("[RuleModuleLoader] WARNING: " + message)


func _log_error(message: String) -> void:
	if _logger and _logger.has_method("error"):
		_logger.error("RuleModuleLoader", message)
	else:
		push_error("[RuleModuleLoader] ERROR: " + message)
