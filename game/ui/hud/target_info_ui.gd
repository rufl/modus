class_name TargetInfoUI
extends Control

@onready var container: PanelContainer = %Container
@onready var name_label: Label = %NameLabel
@onready var health_bar: ProgressBar = %HealthBar
@onready var distance_label: Label = %DistanceLabel
@onready var level_label: Label = %LevelLabel

var _targeting_system: Node = null  # TargetingSystem
var _player: CharacterBody3D = null


func _ready() -> void:
	# Prevent blocking mouse input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if container:
		container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Apply layout from configuration (fixes positioning and z-index)
	_apply_layout_config()

	# Hide by default
	if container:
		container.hide()

	# Defer system lookup to _process to handle initialization order race condition
	# where Player creates TargetingSystem AFTER TargetInfoUI._ready()


func _process(_delta: float) -> void:
	# Initialization Phase
	if not _targeting_system:
		_find_targeting_system()
		return

	if not _targeting_system.has_target():
		return

	_update_target_info()


func _find_targeting_system() -> void:
	# 1. Find owning Player
	if not _player:
		var node: Node = self
		while node:
			if node is CharacterBody3D:  # Assuming Player is CharacterBody3D
				_player = node
				break
			node = node.get_parent()

	# 2. Get TargetingSystem from Player
	if _player and "targeting_system" in _player and _player.targeting_system:
		_targeting_system = _player.targeting_system

		# Connect signals
		_targeting_system.target_acquired.connect(_on_target_acquired)
		_targeting_system.target_lost.connect(_on_target_lost)

		# Initial check: If we already have a target, show the UI immediately
		if _targeting_system.has_target():
			_on_target_acquired(_targeting_system.current_target)


func _on_target_acquired(_target: Node3D) -> void:
	if container:
		container.show()
	_update_target_info()


func _on_target_lost(_target: Node3D) -> void:
	if container:
		container.hide()


func _update_target_info() -> void:
	if not _targeting_system:
		return

	var info: Dictionary = _targeting_system.get_target_info()
	if info.is_empty():
		return

	# Update name
	if name_label:
		name_label.text = info.get("name", "Unknown")

	# Update health bar
	if health_bar:
		var max_hp: int = info.get("max_health", 100)
		var hp: int = info.get("health", 100)
		health_bar.max_value = max_hp
		health_bar.value = hp

	# Update distance
	if distance_label:
		var dist: float = info.get("distance", 0.0)
		distance_label.text = "%.0fm" % dist

	# Update level
	if level_label:
		var level: int = info.get("level", 1)
		level_label.text = "Lv.%d" % level

	# Update Tier
	if %TierLabel:
		var tier: int = info.get("tier", 1)
		if tier > 1:
			%TierLabel.visible = true
			var tier_names: Dictionary = {2: "ELITE", 3: "CHAMPION", 4: "BOSS"}
			var tier_colors: Dictionary = {
				2: Color(1, 0.8, 0.2), 3: Color(1, 0.5, 0), 4: Color(0.8, 0.2, 1)
			}
			%TierLabel.text = tier_names.get(tier, "ELITE")
			%TierLabel.modulate = tier_colors.get(tier, Color.WHITE)
		else:
			%TierLabel.visible = false

	# Update State
	if %StateLabel:
		var state: String = info.get("state", "").to_upper()
		%StateLabel.text = "[%s]" % state

		# Hide HUD if dead
		if state == "DEAD":
			container.hide()

	# Update Infighting Status (Debug Info)
	if %InfightingLabel:
		var is_infighting: bool = info.get("is_infighting", false)
		if is_infighting:
			%InfightingLabel.visible = true
			var infight_target: String = info.get("infight_target_name", "Unknown")
			%InfightingLabel.text = "[INFIGHTING: %s]" % infight_target
			%InfightingLabel.modulate = Color(1.0, 0.4, 0.0)  # Orange color for infighting
		else:
			%InfightingLabel.visible = false


func _apply_layout_config() -> void:
	## Apply positioning, z-index, typography, and dimensions from hud.json5
	var config_system: Node = GameManager.get_core_system("config")
	if not config_system or not config_system.has_method("get_value"):
		return

	var config_var: Variant = config_system.get_value("visuals.hud")
	if not config_var is Dictionary:
		return
	var config: Dictionary = config_var

	if config.is_empty():
		return

	# Apply layout (positioning/z-index)
	if config.has("layout") and config.layout.has("target_info"):
		var target_layout: Dictionary = config.layout.target_info

		# Apply anchor preset
		if target_layout.has("anchor_preset"):
			var preset_name: String = target_layout.anchor_preset
			set_anchors_preset(_get_preset_enum(preset_name))

		# Apply position offsets
		if target_layout.has("position"):
			var pos: Dictionary = target_layout.position
			if pos.has("offset_x"):
				position.x = pos.offset_x
			if pos.has("offset_y"):
				position.y = pos.offset_y

		# Apply z_index (CRITICAL for visibility above compass)
		if target_layout.has("z_index"):
			z_index = target_layout.z_index
			if OS.is_debug_build():
				var logger: Node = GameManager.get_core_system("logger")
				if logger and logger.has_method("info"):
					logger.info("[TargetInfoUI] z_index set to %d" % z_index, "UI")

	# NEW: Apply typography
	if config.has("typography"):
		_apply_typography(config.typography)

	# NEW: Apply dimensions
	if config.has("dimensions") and config.dimensions.has("target_info"):
		_apply_dimensions(config.dimensions.target_info)


func _get_preset_enum(preset_name: String) -> Control.LayoutPreset:
	## Convert string preset name to Godot enum
	match preset_name:
		"TOP_LEFT":
			return Control.PRESET_TOP_LEFT
		"TOP_CENTER":  # Manual: Use TOP_WIDE and center via offsets
			set_anchors_preset(Control.PRESET_TOP_WIDE)
			grow_horizontal = Control.GROW_DIRECTION_BOTH
			return Control.PRESET_TOP_WIDE
		"TOP_RIGHT":
			return Control.PRESET_TOP_RIGHT
		"CENTER_LEFT":
			return Control.PRESET_CENTER_LEFT
		"CENTER":
			return Control.PRESET_CENTER
		"CENTER_RIGHT":
			return Control.PRESET_CENTER_RIGHT
		"BOTTOM_LEFT":
			return Control.PRESET_BOTTOM_LEFT
		"BOTTOM_CENTER":  # Manual: Use BOTTOM_WIDE and center via offsets
			set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			grow_horizontal = Control.GROW_DIRECTION_BOTH
			return Control.PRESET_BOTTOM_WIDE
		"BOTTOM_RIGHT":
			return Control.PRESET_BOTTOM_RIGHT
		"TOP_WIDE":
			return Control.PRESET_TOP_WIDE
		"BOTTOM_WIDE":
			return Control.PRESET_BOTTOM_WIDE
		"LEFT_WIDE":
			return Control.PRESET_LEFT_WIDE
		"RIGHT_WIDE":
			return Control.PRESET_RIGHT_WIDE
		"FULL_RECT":
			return Control.PRESET_FULL_RECT
		_:
			return Control.PRESET_CENTER  # Default fallback


func _apply_typography(typo_config: Dictionary) -> void:
	## Apply font families, sizes, and colors to labels
	if not typo_config.has("target_info"):
		return

	var target_typo: Dictionary = typo_config.target_info
	var fonts: Dictionary = typo_config.get("fonts", {})

	# Apply name label font/size
	if name_label:
		if target_typo.has("name_font") and fonts.has(target_typo.name_font):
			var font_path: String = fonts[target_typo.name_font]
			if font_path != "default" and ResourceLoader.exists(font_path):
				var font: Font = load(font_path)
				name_label.add_theme_font_override("font", font)

		if target_typo.has("name_size"):
			name_label.add_theme_font_size_override("font_size", target_typo.name_size)

	# Apply to other labels (distance, level, etc.)
	_apply_label_typography([distance_label, level_label], target_typo, fonts)


func _apply_label_typography(labels: Array, target_typo: Dictionary, fonts: Dictionary) -> void:
	## Apply typography to an array of labels
	for label: Label in labels:
		if not label:
			continue

		if target_typo.has("label_font") and fonts.has(target_typo.label_font):
			var font_path: String = fonts[target_typo.label_font]
			if font_path != "default" and ResourceLoader.exists(font_path):
				var font: Font = load(font_path)
				label.add_theme_font_override("font", font)

		if target_typo.has("label_size"):
			label.add_theme_font_size_override("font_size", target_typo.label_size)

		if target_typo.has("label_color"):
			var c: Dictionary = target_typo.label_color
			label.add_theme_color_override("font_color", Color(c.r, c.g, c.b, c.a))


func _apply_dimensions(dim_config: Dictionary) -> void:
	## Apply width/height sizing
	if dim_config.has("width") and str(dim_config.width) != "auto":
		custom_minimum_size.x = dim_config.width

	if dim_config.has("height") and str(dim_config.height) != "auto":
		custom_minimum_size.y = dim_config.height
