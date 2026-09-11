class_name PlayerHUDBridge
extends GameComponent

var _player: CharacterBody3D
var _camera: Camera3D
var _interaction_component: Node
var _raycast: RayCast3D
var _hud_layer: CanvasLayer
var _damage_indicator: Control
var _flash_rect: ColorRect
var _screen_effects_rect: ColorRect
var _tooltip_label: Label
var _blood_overlay: Control
var _target_info: Control
var _current_target_node: Node = null


func _log(message: String, category: String = "PlayerHUDBridge") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


func setup(
	player: CharacterBody3D, camera: Camera3D, raycast: RayCast3D, interaction_component: Node
) -> void:
	_player = player
	_camera = camera
	_raycast = raycast
	_interaction_component = interaction_component

	_setup_hud_layer()
	_create_interaction_tooltip()

	# Blood overlay (legacy support if scene has it)
	_blood_overlay = _hud_layer.get_node_or_null("BloodOverlay")
	_damage_indicator = _hud_layer.get_node_or_null("DamageIndicatorManager")


func _setup_hud_layer() -> void:
	# Ensure we have a valid CanvasLayer for UI
	_hud_layer = _player.get_node_or_null("HUDLayer")
	if not _hud_layer:
		_hud_layer = CanvasLayer.new()
		_hud_layer.name = "HUDLayer"
		_player.add_child(_hud_layer)

	# Create generic screen flash rect
	_flash_rect = ColorRect.new()
	_flash_rect.name = "ScreenFlash"
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(1, 0, 0, 0)  # Transparent start
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_flash_rect)

	# Create Screen Effects Rect (Shader)
	_screen_effects_rect = ColorRect.new()
	_screen_effects_rect.name = "ScreenEffects"
	_screen_effects_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen_effects_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = load("res://game/art/shaders/screen_effects.gdshader")
	_screen_effects_rect.material = shader_mat

	_hud_layer.add_child(_screen_effects_rect)

	# Target Info UI
	var target_info_scene: PackedScene = load("res://game/ui/hud/target_info_ui.tscn")
	if target_info_scene:
		_target_info = target_info_scene.instantiate()
		_target_info.name = "TargetInfoUI"
		_hud_layer.add_child(_target_info)


func setup_extended_hud() -> void:
	# Ensure extended HUD elements (Minimap, Inventory, Progression, Status) are present
	if not _hud_layer:
		return

	# Minimap is owned by the authored HUD scene; this bridge must not invent one.
	if not _hud_layer.has_node("Minimap"):
		_log("[PlayerHUDBridge] Minimap not present in HUD scene", "HUD")
	else:
		_log("[PlayerHUDBridge] Minimap found", "HUD")

	# Progression HUD
	if not _hud_layer.has_node("ProgressionHUD"):
		var scene: PackedScene = load("res://game/ui/hud/progression_hud.tscn")
		if scene:
			var node: Control = scene.instantiate()
			node.name = "ProgressionHUD"
			_hud_layer.add_child(node)
			_log("[PlayerHUDBridge] Added ProgressionHUD", "HUD")

	# Status Effects HUD
	if not _hud_layer.has_node("StatusEffectsHUD"):
		var scene: PackedScene = load("res://game/ui/hud/status_effects_hud.tscn")
		if scene:
			var node: Control = scene.instantiate()
			node.name = "StatusEffectsHUD"
			_hud_layer.add_child(node)
			_log("[PlayerHUDBridge] Added StatusEffectsHUD", "HUD")

	# Skill Tree UI
	if not _hud_layer.has_node("SkillTreeUI"):
		var scene: PackedScene = load("res://game/ui/skill_tree_ui.tscn")
		if scene:
			var node: Control = scene.instantiate()
			node.name = "SkillTreeUI"
			node.visible = false
			_hud_layer.add_child(node)
			_log("[PlayerHUDBridge] Added SkillTreeUI", "HUD")

	# Inventory UI is supplied by the authored HUD scene; no runtime path is
	# available here, so leave the optional element absent.
	if not _hud_layer.has_node("InventoryUI"):
		_log("[PlayerHUDBridge] InventoryUI not present in HUD scene", "HUD")


func _create_interaction_tooltip() -> void:
	_tooltip_label = Label.new()
	_tooltip_label.name = "InteractionTooltip"
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tooltip_label.add_theme_font_size_override("font_size", 18)
	_tooltip_label.add_theme_color_override("font_color", Color.WHITE)
	_tooltip_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_tooltip_label.add_theme_constant_override("shadow_offset_x", 2)
	_tooltip_label.add_theme_constant_override("shadow_offset_y", 2)

	# Position at bottom center of screen
	_tooltip_label.anchor_left = 0.5
	_tooltip_label.anchor_right = 0.5
	_tooltip_label.anchor_top = 0.7
	_tooltip_label.anchor_bottom = 0.7
	_tooltip_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tooltip_label.visible = false

	_hud_layer.add_child(_tooltip_label)


# === LOGIC ===


func update_interaction_tooltip() -> void:
	if not _tooltip_label or not _camera:
		return

	# Raycast for interactables - space state may be null before world is ready
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	if not space:
		return

	var range_dist: float = 3.0
	if _interaction_component and "pickup_range" in _interaction_component:
		range_dist = _interaction_component.pickup_range

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		_camera.global_position,
		_camera.global_position - _camera.global_transform.basis.z * range_dist,
		CollisionLayers.LAYER_INTERACTABLES,
		[_player.get_rid()]
	)

	var result: Dictionary = space.intersect_ray(query)
	if result:
		var collider: Object = result["collider"]
		# Check for Interactable component
		var interactable: Node = null
		if collider is Node:
			interactable = collider.get_node_or_null("Interactable")

		if interactable and "prompt_text" in interactable:
			_tooltip_label.text = "[E] " + interactable.prompt_text
			_tooltip_label.visible = true
			return
		if collider is RigidBody3D:
			_tooltip_label.text = "[E] Pick Up"
			_tooltip_label.visible = true
			return

	_tooltip_label.visible = false


func update_crosshair_target() -> void:
	if not _raycast:
		return
	if _raycast.is_colliding():
		var c: Object = _raycast.get_collider()
		# Add null check and verify it's a Node (has is_in_group)
		var is_enemy: bool = false
		if c and c.has_method("is_in_group"):
			is_enemy = c.is_in_group("enemies")

		# Handle specific targeting logic (Healthbars, Outlines)
		if c != _current_target_node:
			if _current_target_node and _current_target_node.has_method("set_targeted"):
				_current_target_node.set_targeted(false)

			_current_target_node = c
			if _current_target_node and _current_target_node.has_method("set_targeted"):
				_current_target_node.set_targeted(true)

		GameManager.emit_event("crosshair_target_changed", {"active": true, "is_enemy": is_enemy})
	else:
		if _current_target_node:
			if _current_target_node.has_method("set_targeted"):
				_current_target_node.set_targeted(false)
			_current_target_node = null

		GameManager.emit_event("crosshair_target_changed", {"active": false, "is_enemy": false})


func trigger_screen_flash(color: Color, duration: float = 0.3) -> void:
	if not _flash_rect:
		return

	# Create a new tween for the flash
	var tween: Tween = create_tween()

	# Start slightly transparent
	color.a = clampf(color.a, 0.0, 0.6)  # improved max opacity handling

	# Immediate set or tween in?
	# For impacts, immediate is better. For status, maybe tween in.
	# Let's do a quick attack, slow decay
	_flash_rect.color = color
	_flash_rect.color.a = 0.0

	tween.tween_property(_flash_rect, "color:a", color.a, duration * 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash_rect, "color:a", 0.0, duration * 0.8).set_ease(Tween.EASE_IN)

	# Play hurt animation (remotes only) if it's a damage flash (red-ish)
	if color.r > 0.8 and color.g < 0.2:
		if not _player.is_multiplayer_authority() and _player.has_node("PlayerVisuals"):
			var visuals: Node = _player.get_node("PlayerVisuals")
			if visuals.has_method("play_hurt"):
				visuals.play_hurt()


func flash_damage(intensity: float = 1.0) -> void:
	var dur: float = clampf(0.3 * intensity, 0.2, 0.8)
	var alpha: float = clampf(0.4 * intensity, 0.2, 0.8)
	trigger_screen_flash(Color(1.0, 0.0, 0.0, alpha), dur)


func flash_pickup() -> void:
	trigger_screen_flash(Color(0.2, 1.0, 0.2, 0.3), 0.4)  # Greenish


func flash_weapon_pickup() -> void:
	trigger_screen_flash(Color(1.0, 0.8, 0.0, 0.3), 0.5)  # Gold


func flash_powerup() -> void:
	trigger_screen_flash(Color(0.4, 0.2, 1.0, 0.3), 0.6)  # Purple


func show_damage_indicator(attacker_pos: Vector3) -> void:
	if _damage_indicator and attacker_pos != Vector3.ZERO:
		_damage_indicator.show_damage_from(
			attacker_pos, _player.global_position, _player.rotation.y
		)


func update_blood_overlay(amount: float) -> void:
	if _blood_overlay and _blood_overlay.has_method("show_damage"):
		# Scale intensity by damage relative to base (e.g. 20 is serious)
		var intensity: float = clampf(amount / 25.0, 0.2, 1.0)

		# Get hit direction from combat component if possible
		var hit_dir: Vector3 = Vector3.ZERO
		var combat := _player.get_node_or_null("PlayerCombatComponent")
		if combat and "last_hit_dir" in combat:
			hit_dir = combat.last_hit_dir

		_blood_overlay.show_damage(intensity, hit_dir)
	else:
		trigger_screen_flash(Color(1.0, 0.0, 0.0, 0.5), 0.5)


func update_screen_effects(active_effects: Dictionary) -> void:
	if not _screen_effects_rect or not _screen_effects_rect.material:
		return

	var mat: ShaderMaterial = _screen_effects_rect.material as ShaderMaterial

	# Poison
	if active_effects.has("poison"):
		mat.set_shader_parameter("is_poisoned", true)
		mat.set_shader_parameter("poison_intensity", active_effects["poison"])
	else:
		mat.set_shader_parameter("is_poisoned", false)
		mat.set_shader_parameter("poison_intensity", 0.0)

	# Burn
	if active_effects.has("burn"):
		mat.set_shader_parameter("is_burning", true)
		mat.set_shader_parameter("burn_intensity", active_effects["burn"])
	else:
		mat.set_shader_parameter("is_burning", false)
		mat.set_shader_parameter("burn_intensity", 0.0)

	# Drowning
	if active_effects.has("drowning"):
		mat.set_shader_parameter("is_drowning", true)
		mat.set_shader_parameter("drowning_intensity", active_effects["drowning"])
	else:
		mat.set_shader_parameter("is_drowning", false)
		mat.set_shader_parameter("drowning_intensity", 0.0)

	# Bleeding
	if active_effects.has("bleed"):
		mat.set_shader_parameter("is_bleeding", true)
		mat.set_shader_parameter("bleed_intensity", active_effects["bleed"])
	else:
		mat.set_shader_parameter("is_bleeding", false)
		mat.set_shader_parameter("bleed_intensity", 0.0)
