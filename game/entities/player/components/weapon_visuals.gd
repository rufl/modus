class_name WeaponVisuals
extends GameComponent

const DEFAULT_HOLDER_POS := Vector3(0.25, -0.25, -0.5)

var sway_amount: float = 0.015
var sway_smooth: float = 10.0
var sway_max: float = 0.06

var _weapon_holder: Node3D
var _camera: Camera3D
var _player: CharacterBody3D
var _weapon_manager: WeaponManager
var _mouse_input: Vector2 = Vector2.ZERO
var _current_sway: Vector2 = Vector2.ZERO
var _current_bob_time: float = 0.0
var _current_recoil_y: float = 0.0
var _target_recoil_y: float = 0.0
var _global_offset: Vector3 = Vector3.ZERO
var _global_rotation: Vector3 = Vector3.ZERO
var _bob_intensity: float = 1.0
var _sway_intensity: float = 1.0


func setup(
	weapon_manager: WeaponManager, weapon_holder: Node3D, camera: Camera3D, player: CharacterBody3D
) -> void:
	_weapon_manager = weapon_manager
	_weapon_holder = weapon_holder
	_camera = camera
	_player = player

	# Load config settings
	_load_config()


func _load_config() -> void:
	if not GameManager.get_core_system("config"):
		return

	sway_amount = GameManager.get_core_system("config").get_value(
		"balance.weapon_feel.sway_amount", 0.015
	)
	sway_smooth = GameManager.get_core_system("config").get_value(
		"balance.weapon_feel.sway_smooth", 10.0
	)
	sway_max = GameManager.get_core_system("config").get_value("balance.weapon_feel.sway_max", 0.06)

	# Load visual overrides
	var vis_config: Dictionary = GameManager.get_core_system("config").get_value(
		"visuals.weapon_visuals", {}
	)
	if not vis_config.is_empty():
		var off: Dictionary = vis_config.get("global_offset", {})
		_global_offset = Vector3(off.get("x", 0.0), off.get("y", 0.0), off.get("z", 0.0))

		var rot: Dictionary = vis_config.get("global_rotation", {})
		_global_rotation = Vector3(rot.get("x", 0.0), rot.get("y", 0.0), rot.get("z", 0.0))

		_bob_intensity = vis_config.get("bob_intensity", 1.0)
		_sway_intensity = vis_config.get("sway_intensity", 1.0)

		# Apply intensities to base values
		sway_amount *= _sway_intensity


func handle_mouse_input(relative: Vector2) -> void:
	## Call this from weapon_manager._unhandled_input() when mouse motion is received
	_mouse_input = relative


func process_visuals(delta: float) -> void:
	## Main update function - call from weapon_manager._process()
	if not _weapon_holder or not _player:
		return

	# 1. Weapon Sway (Mouse Lag)
	var target_sway: Vector2 = Vector2(
		clamp(_mouse_input.x * -sway_amount, -sway_max, sway_max),
		clamp(_mouse_input.y * sway_amount, -sway_max, sway_max)
	)
	_current_sway = _current_sway.lerp(target_sway, delta * sway_smooth)
	_mouse_input = Vector2.ZERO

	# 2. View Bobbing (Movement)
	var bob_pos: Vector3 = Vector3.ZERO
	var weapon: WeaponData = _weapon_manager.get_current_weapon()
	if weapon and _player.is_on_floor() and _player.velocity.length() > 0.1:
		var speed_scale: float = clamp(_player.velocity.length() / 5.0, 0.0, 1.5)
		_current_bob_time += delta * weapon.weapon_bob_freq * 5.0 * speed_scale
		bob_pos.y = sin(_current_bob_time) * weapon.weapon_bob_amount * speed_scale * _bob_intensity
		bob_pos.x = (
			cos(_current_bob_time * 0.5)
			* weapon.weapon_bob_amount
			* 0.5
			* speed_scale
			* _bob_intensity
		)
	else:
		# Decay bob
		_current_bob_time = 0.0

	# 3. Recoil (Procedural Kick) - kicks weapon UPWARD
	if weapon:
		_current_recoil_y = lerpf(_current_recoil_y, _target_recoil_y, delta * 20.0)
		_target_recoil_y = move_toward(_target_recoil_y, 0.0, delta * weapon.visual_recoil_recovery)

	# Apply - combine with base offset from weapon data
	var base_pos: Vector3 = DEFAULT_HOLDER_POS
	var base_rot: Vector3 = Vector3.ZERO

	if weapon:
		base_pos = weapon.view_model_offset
		base_rot = weapon.view_model_rotation

		# Check for UIService overrides (per-weapon tweakability)
		var ui_svc: Node = GameManager.get_core_system("ui")
		if ui_svc:
			var config_offset: Vector3 = ui_svc.get_weapon_offset(
				weapon.weapon_name, "viewModelOffset"
			)
			if config_offset != Vector3.ZERO:
				base_pos = config_offset

			var config_rot: Vector3 = ui_svc.get_weapon_offset(
				weapon.weapon_name, "viewModelRotation"
			)
			if config_rot != Vector3.ZERO:
				base_rot = config_rot

		_weapon_holder.scale = weapon.view_model_scale
	else:
		_weapon_holder.scale = Vector3.ONE

	# Rotation: Weapon should always point forward (same as camera)
	# Since weapon_holder is child of camera, local rotation (0,0,0) = camera forward
	# Only apply small sway and recoil adjustments

	# 4. Final Position
	# CRITICAL FIX: If parented to a BoneAttachment (True FPS), avoid view-model offsets
	# as they are designed for camera-space rendering and will push the weapon out of the hand.
	var is_in_hand: bool = _weapon_holder.get_parent() is BoneAttachment3D
	var bob_offset := Vector3(bob_pos.x, bob_pos.y + _current_recoil_y, 0.0)

	if is_in_hand:
		# In hand: only apply small procedural sway/bob, but NO base_pos (view-model offset)
		# because base_pos is meant for the camera-space viewmodel!
		_weapon_holder.position = _global_offset + bob_offset * 0.2  # Scale down bob in hand
		_weapon_holder.rotation.x = _current_sway.y + (_current_recoil_y * 0.01)
		_weapon_holder.rotation.y = _current_sway.x
	else:
		# On camera: full view-model positioning
		_weapon_holder.rotation_degrees = base_rot
		_weapon_holder.rotation.x += _current_sway.y + (_current_recoil_y * 0.01)
		_weapon_holder.rotation.y += _current_sway.x
		_weapon_holder.position = base_pos + _global_offset + bob_offset


func apply_visual_recoil() -> void:
	## Called when weapon fires to add recoil kick
	var weapon: WeaponData = _weapon_manager.get_current_weapon()
	if weapon:
		_target_recoil_y = weapon.visual_recoil_amount  # Kick weapon UP
		_current_sway.y -= 0.03  # Also rotate slightly upward


func reset() -> void:
	## Reset all visual states (e.g., when switching weapons)
	_current_sway = Vector2.ZERO
	_current_bob_time = 0.0
	_current_recoil_y = 0.0
	_target_recoil_y = 0.0
	_mouse_input = Vector2.ZERO
