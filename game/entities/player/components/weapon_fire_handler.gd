class_name WeaponFireHandler
extends GameComponent

## Handles weapon firing logic, cooldowns, and spin-up mechanics
## Extracted from WeaponManager for better separation of concerns

signal weapon_fired(weapon_name: String, position: Vector3, direction: Vector3)
signal barrel_spinning(speed: float)

var camera: Camera3D
var player: CharacterBody3D
var gunshot_sound: AudioStreamPlayer3D
var spin_sound: AudioStreamPlayer3D

var _weapon_inventory: WeaponInventory
var _ammo_system: WeaponAmmoSystem
var _fire_cooldown: float = 0.0
var _spin_speed: float = 0.0
var _is_firing: bool = false


func setup(
	cam: Camera3D,
	p_player: CharacterBody3D,
	audio: AudioStreamPlayer3D,
	inventory: WeaponInventory,
	ammo: WeaponAmmoSystem
) -> void:
	camera = cam
	player = p_player
	gunshot_sound = audio
	_weapon_inventory = inventory
	_ammo_system = ammo

	# Create spin sound player
	spin_sound = AudioStreamPlayer3D.new()
	spin_sound.bus = "SFX"
	add_child(spin_sound)


func _physics_process(delta: float) -> void:
	if _fire_cooldown > 0:
		_fire_cooldown -= delta


func update_spin(delta: float) -> void:
	var weapon: WeaponData = _weapon_inventory.get_current_weapon()
	if not weapon or not weapon.has_spin_up:
		if _spin_speed > 0:
			_spin_speed = 0.0
			barrel_spinning.emit(0.0)
		return

	var ammo: Array = _ammo_system.get_current_ammo()

	if _is_firing and ammo[0] > 0 and not _ammo_system.is_reloading:
		_spin_speed = minf(_spin_speed + delta / weapon.spin_up_time, 1.0)
	else:
		_spin_speed = maxf(_spin_speed - delta / weapon.spin_down_time, 0.0)

	barrel_spinning.emit(_spin_speed)

	# Handle spin audio
	if weapon.spin_audio and spin_sound:
		if _spin_speed > 0.01:
			if not spin_sound.playing or spin_sound.stream != weapon.spin_audio:
				spin_sound.stream = weapon.spin_audio
				spin_sound.play()
			spin_sound.pitch_scale = lerpf(0.5, weapon.spin_audio_pitch_max, _spin_speed)
		else:
			if spin_sound.playing:
				spin_sound.stop()


func can_fire() -> bool:
	return _fire_cooldown <= 0 and _ammo_system.can_fire()


func fire(input_pressed: bool, input_just_pressed: bool) -> bool:
	var weapon: WeaponData = _weapon_inventory.get_current_weapon()
	if not weapon:
		return false

	var wants_to_shoot: bool = input_pressed if weapon.is_automatic else input_just_pressed

	# Track firing state for spin-up
	if wants_to_shoot != _is_firing:
		_is_firing = wants_to_shoot
		if multiplayer.has_multiplayer_peer():
			_set_firing_state.rpc(_is_firing)

	if wants_to_shoot and can_fire():
		# Break godmode invisibility
		if player and "is_invisible" in player and player.is_invisible:
			var gs := GameManager.get_core_system("gameplay") as GameplaySvc
			if (
				gs
				and gs.match_service
				and gs.match_service.has_method("is_godmode_active")
				and gs.match_service.is_godmode_active()
			):
				player.is_invisible = false

		# Apply cooldown
		_apply_local_cooldown(weapon)

		# Optimistic ammo decrement (client-side prediction)
		if player.is_multiplayer_authority() and not multiplayer.is_server():
			_ammo_system.consume_ammo(_weapon_inventory.current_weapon_index)

		# Play sound
		if gunshot_sound and gunshot_sound.stream:
			gunshot_sound.play()
		elif GameManager and GameManager.get_core_system("audio"):
			GameManager.get_core_system("audio").play_event("shoot", player.global_position)

		# Emit signal for effects
		weapon_fired.emit(
			weapon.weapon_name, camera.global_position, -camera.global_transform.basis.z
		)

		return true

	return false


func reset_spin() -> void:
	_spin_speed = 0.0
	_is_firing = false
	barrel_spinning.emit(0.0)
	if spin_sound:
		spin_sound.stop()


func assign_weapon_audio(weapon: WeaponData) -> void:
	if not gunshot_sound:
		return

	if weapon.fire_audio:
		gunshot_sound.stream = weapon.fire_audio
	else:
		if GameManager and GameManager.get_core_system("audio"):
			var stream: AudioStream = GameManager.get_core_system("audio").get_event_stream("shoot")
			if stream:
				gunshot_sound.stream = stream
			else:
				gunshot_sound.stream = SoundGenerator.generate_shoot_sound(weapon.audio_pitch)


func _apply_local_cooldown(weapon: WeaponData) -> void:
	if weapon.has_spin_up:
		var current_rate: float = lerpf(weapon.min_fire_rate, weapon.max_fire_rate, _spin_speed)
		_fire_cooldown = 1.0 / current_rate
	else:
		_fire_cooldown = weapon.fire_rate


@rpc("authority", "call_remote", "reliable")
func _set_firing_state(firing: bool) -> void:
	_is_firing = firing
