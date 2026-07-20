class_name GameColors
extends Object

static var _colors_loaded: bool = false
static var _color_data: Dictionary = {}
static var RARITY_COMMON: Color
static var RARITY_UNCOMMON: Color
static var RARITY_RARE: Color
static var RARITY_EPIC: Color
static var RARITY_LEGENDARY: Color
static var RARITY_COLORS: Dictionary = {}
static var TIER_BASIC: Color
static var TIER_IMPROVED: Color
static var TIER_ELITE: Color
static var TIER_BOSS: Color
static var TIER_COLORS: Dictionary = {}
static var ELEMENT_FIRE: Color
static var ELEMENT_ICE: Color
static var ELEMENT_POISON: Color
static var ELEMENT_LIGHTNING: Color
static var ELEMENT_DARK: Color
static var ELEMENT_BLOOD: Color
static var THEME_DAMAGE: Color
static var THEME_SPEED: Color
static var THEME_PRECISION: Color
static var THEME_TANK: Color
static var THEME_VAMPIRIC: Color
static var THEME_EXPLOSIVE: Color
static var THEME_UTILITY: Color
static var UI_HEALTH: Color
static var UI_ARMOR: Color
static var UI_WARNING: Color
static var UI_CRITICAL: Color
static var UI_POSITIVE: Color
static var UI_NEGATIVE: Color
static var UI_NEUTRAL: Color


static func load_colors() -> void:
	if _colors_loaded:
		return

	var path: String = "res://game/data/colors.json"

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GameColors] Failed to load colors.json, using defaults")
		_load_defaults()
		_colors_loaded = true
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("[GameColors] Failed to parse colors.json: " + json.get_error_message())
		_load_defaults()
		_colors_loaded = true
		return

	_color_data = json.data
	_apply_colors()
	_colors_loaded = true
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[GameColors] Loaded colors from: " + " " + str(path), "Core")


## Apply loaded color data to static variables


static func _apply_colors() -> void:
	# Rarity colors
	RARITY_COMMON = _parse_color(
		_color_data.get("rarity", {}).get("common", {}), Color(0.6, 0.6, 0.6)
	)
	RARITY_UNCOMMON = _parse_color(
		_color_data.get("rarity", {}).get("uncommon", {}), Color(0.0, 0.8, 0.0)
	)
	RARITY_RARE = _parse_color(_color_data.get("rarity", {}).get("rare", {}), Color(0.3, 0.5, 1.0))
	RARITY_EPIC = _parse_color(_color_data.get("rarity", {}).get("epic", {}), Color(0.6, 0.2, 0.8))
	RARITY_LEGENDARY = _parse_color(
		_color_data.get("rarity", {}).get("legendary", {}), Color(1.0, 0.84, 0.0)
	)

	RARITY_COLORS = {
		0: RARITY_COMMON, 1: RARITY_UNCOMMON, 2: RARITY_RARE, 3: RARITY_EPIC, 4: RARITY_LEGENDARY
	}

	# Enemy tier colors
	TIER_BASIC = _parse_color(
		_color_data.get("enemy_tier", {}).get("basic", {}), Color(0.9, 0.9, 0.9)
	)
	TIER_IMPROVED = _parse_color(
		_color_data.get("enemy_tier", {}).get("improved", {}), Color(0.7, 0.85, 1.0)
	)
	TIER_ELITE = _parse_color(
		_color_data.get("enemy_tier", {}).get("elite", {}), Color(1.0, 0.5, 0.0)
	)
	TIER_BOSS = _parse_color(
		_color_data.get("enemy_tier", {}).get("boss", {}), Color(0.9, 0.1, 0.1)
	)

	TIER_COLORS = {1: TIER_BASIC, 2: TIER_IMPROVED, 3: TIER_ELITE, 4: TIER_BOSS}

	# Elemental colors
	ELEMENT_FIRE = _parse_color(_color_data.get("element", {}).get("fire", {}), Color.ORANGE)
	ELEMENT_ICE = _parse_color(_color_data.get("element", {}).get("ice", {}), Color.LIGHT_BLUE)
	ELEMENT_POISON = _parse_color(
		_color_data.get("element", {}).get("poison", {}), Color.LIME_GREEN
	)
	ELEMENT_LIGHTNING = _parse_color(
		_color_data.get("element", {}).get("lightning", {}), Color.YELLOW
	)
	ELEMENT_DARK = _parse_color(_color_data.get("element", {}).get("dark", {}), Color.DARK_MAGENTA)
	ELEMENT_BLOOD = _parse_color(_color_data.get("element", {}).get("blood", {}), Color.DARK_RED)

	# Combat theme colors
	THEME_DAMAGE = _parse_color(_color_data.get("combat_theme", {}).get("damage", {}), Color.RED)
	THEME_SPEED = _parse_color(_color_data.get("combat_theme", {}).get("speed", {}), Color.YELLOW)
	THEME_PRECISION = _parse_color(
		_color_data.get("combat_theme", {}).get("precision", {}), Color.CYAN
	)
	THEME_TANK = _parse_color(_color_data.get("combat_theme", {}).get("tank", {}), Color.SLATE_GRAY)
	THEME_VAMPIRIC = _parse_color(
		_color_data.get("combat_theme", {}).get("vampiric", {}), Color.DARK_MAGENTA
	)
	THEME_EXPLOSIVE = _parse_color(
		_color_data.get("combat_theme", {}).get("explosive", {}), Color.ORANGE_RED
	)
	THEME_UTILITY = _parse_color(
		_color_data.get("combat_theme", {}).get("utility", {}), Color.AQUAMARINE
	)

	# UI colors
	UI_HEALTH = _parse_color(_color_data.get("ui", {}).get("health", {}), Color.GREEN)
	UI_ARMOR = _parse_color(_color_data.get("ui", {}).get("armor", {}), Color.DODGER_BLUE)
	UI_WARNING = _parse_color(_color_data.get("ui", {}).get("warning", {}), Color.ORANGE)
	UI_CRITICAL = _parse_color(_color_data.get("ui", {}).get("critical", {}), Color.RED)
	UI_POSITIVE = _parse_color(_color_data.get("ui", {}).get("positive", {}), Color.LIME_GREEN)
	UI_NEGATIVE = _parse_color(_color_data.get("ui", {}).get("negative", {}), Color.CRIMSON)
	UI_NEUTRAL = _parse_color(_color_data.get("ui", {}).get("neutral", {}), Color.LIGHT_GRAY)


## Parse color from JSON dict {r, g, b, a}


static func _parse_color(data: Dictionary, fallback: Color) -> Color:
	if data.is_empty():
		return fallback

	var r: float = data.get("r", fallback.r)
	var g: float = data.get("g", fallback.g)
	var b: float = data.get("b", fallback.b)
	var a: float = data.get("a", fallback.a)
	return Color(r, g, b, a)


## Load default hardcoded colors if JSON fails


static func _load_defaults() -> void:
	_color_data = {}
	# Apply defaults (same as JSON fallbacks)
	_apply_colors()
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[GameColors] Using default hardcoded colors", "Core")


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

## Get rarity color by index (0-4)


static func get_rarity_color(rarity: int) -> Color:
	if not _colors_loaded:
		load_colors()
	return RARITY_COLORS.get(rarity, RARITY_COMMON)


## Get tier color by tier number (1-4)


static func get_tier_color(tier: int) -> Color:
	if not _colors_loaded:
		load_colors()
	return TIER_COLORS.get(tier, TIER_BASIC)


## Get rarity name as string


static func get_rarity_name(rarity: int) -> String:
	match rarity:
		0:
			return "Common"
		1:
			return "Uncommon"
		2:
			return "Rare"
		3:
			return "Epic"
		4:
			return "Legendary"
	return "Unknown"


## Get tier name as string


static func get_tier_name(tier: int) -> String:
	match tier:
		1:
			return "Basic"
		2:
			return "Improved"
		3:
			return "Elite"
		4:
			return "Boss"
	return "Unknown"
