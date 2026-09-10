class_name PlayerCombatComponent
extends GameComponent

const GlobalEnums = preload("res://game/core/enums.gd")

var last_hit_dir: Vector3 = Vector3.BACK

var _player: CharacterBody3D
var _health_component: Node
var _match_service: Node
var _screen_shake: Node
var _blood_hit_spawner: Node
var _hud_bridge: Node
var _damage_indicator: Control
var _anim_player: AnimationPlayer
var _camera: Camera3D


func setup(
	player: CharacterBody3D,
	health_comp: Node,
	match_service: Node,
	screen_shake_sys: Node,
	blood_spawner: Node,
	hud_bridge_node: Node,
	anim_player_node: AnimationPlayer,
	camera_node: Camera3D
) -> void:
	_player = player
	_health_component = health_comp
	_match_service = match_service
	_screen_shake = screen_shake_sys
	_blood_hit_spawner = blood_spawner
	_hud_bridge = hud_bridge_node
	_anim_player = anim_player_node
	_camera = camera_node

	# Fallback: find damage indicator if bridge is missing
	if not _hud_bridge:
		_damage_indicator = _player.get_node_or_null("HUDLayer/DamageIndicatorManager")

	# Connect signals
	if _health_component:
		_health_component.died.connect(_on_died)
		_health_component.damage_received.connect(_on_damage_received)


func _exit_tree() -> void:
	# Cleanup signals
	if _health_component:
		if _health_component.died.is_connected(_on_died):
			_health_component.died.disconnect(_on_died)
		if _health_component.damage_received.is_connected(_on_damage_received):
			_health_component.damage_received.disconnect(_on_damage_received)


# --- Damage reception (RPC) ---

@rpc("authority", "call_local", "reliable")
func receive_damage(
	damage: int = 1, attacker_id: int = 0, attacker_pos: Vector3 = Vector3.ZERO
) -> void:
	if not _player:
		return

	# Client-owned Player nodes still accept damage only from the server.
	var sender_id: int = _player.multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != 1:
		return

	# Godmode check via service
	if (
		_player.is_multiplayer_authority()
		and _match_service
		and _match_service.has_method("is_godmode_active")
	):
		if _match_service.is_godmode_active():
			return

	# Server Authority for Logic (or Singleplayer)
	if not _player.multiplayer.has_multiplayer_peer() or _player.multiplayer.is_server():
		if _health_component:
			var info: DamageInfo = DamageInfo.new()
			info.base_amount = float(damage)
			info.source_id = attacker_id
			_health_component.take_damage(info)

	if attacker_pos != Vector3.ZERO:
		last_hit_dir = (_player.global_position - attacker_pos).normalized()

	# Visuals (Local or Proxy)
	if _player.is_multiplayer_authority() and attacker_pos != Vector3.ZERO:
		if _hud_bridge:
			_hud_bridge.show_damage_indicator(attacker_pos)
		elif _damage_indicator:
			_damage_indicator.show_damage_from(
				attacker_pos, _player.global_position, _player.rotation.y
			)

	GameManager.get_core_system("logger").trace(
		"[PlayerCombat] Received damage request: %d from %d" % [damage, attacker_id], "Player"
	)


func _on_damage_received(amount: float, _source_id: int, _type: int) -> void:
	if not _player:
		return

	# Apply knockback based on damage
	if last_hit_dir != Vector3.ZERO:
		var knockback_force: float = amount * 0.3  # Scale knockback with damage
		var knockback_velocity: Vector3 = last_hit_dir * knockback_force
		knockback_velocity.y = knockback_force * 0.2  # Slight upward component
		apply_knockback(knockback_velocity)

	# Screen shake
	if _screen_shake:
		if last_hit_dir != Vector3.ZERO:
			_screen_shake.add_directional_trauma(amount / 50.0, last_hit_dir)
		else:
			_screen_shake.add_damage_trauma(amount, float(_health_component.max_health))

	# Spawn Blood (Gore)
	if _blood_hit_spawner:
		# Use last hit direction or generic up
		var normal: Vector3 = Vector3.UP
		if last_hit_dir != Vector3.ZERO:
			normal = last_hit_dir

		_blood_hit_spawner.spawn_blood(
			_player.global_position + Vector3(0, 1.0, 0), normal, int(amount)
		)

	# Blood overlay - red screen flash with intensity based on damage
	if _hud_bridge:
		_hud_bridge.update_blood_overlay(amount)
	else:
		# Fallback/Default Flash
		trigger_screen_flash(Color(1.0, 0.0, 0.0), 0.5)


## Generic screen flash for feedback (Damage, Pickups, etc.)


func trigger_screen_flash(color: Color, duration: float = 0.3) -> void:
	if _hud_bridge:
		_hud_bridge.trigger_screen_flash(color, duration)
		return

	# Note: Full flash implementation is in HUDBridge

	# Play hurt animation (remote players only - local is in FPS)
	if not _player.is_multiplayer_authority() and _player.has_node("PlayerVisuals"):
		var visuals: Node = _player.get_node("PlayerVisuals")
		if visuals.has_method("play_hurt"):
			visuals.play_hurt()


func _on_died(_source_id: int) -> void:
	if _player and _player.state_manager:
		_player.state_manager.enter_downed()


## Apply external knockback (used for rocket/grenade jumping)


func apply_knockback(impulse: Vector3) -> void:
	# Add impulse to current velocity (Quake-style)
	if _player:
		_player.velocity += impulse


# Melee


func melee_attack() -> void:
	# _melee_cooldown handled in Player.gd or WeaponManager?
	# Player.gd had _melee_cooldown. We might need to move that here.
	# For now, let's keep it simple and just do the raycast logic.

	if _anim_player:
		_anim_player.stop()
		_anim_player.play("Punch_Jab")

	var melee_range: float = 2.0
	var melee_damage: float = 25.0

	if not _camera:
		return

	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		_camera.global_position,
		_camera.global_position - _camera.global_transform.basis.z * melee_range,
		CollisionLayers.MASK_INTERACTION,
		[_player.get_rid()]
	)

	var result: Dictionary = space.intersect_ray(query)
	if result:
		var collider: Object = result["collider"]

		var combat_service: Node = GameManager.get_core_system("combat")
		if not combat_service:
			return

		var target_id: int = 0
		if collider is Node:
			target_id = collider.get_instance_id()

		if _player.multiplayer.is_server():
			combat_service.apply_damage(
				collider,
				melee_damage,
				_player,
				DamageInfo.DamageType.MELEE,
				null,
				false,
				-1,
				result["position"],
				result["normal"]
			)
		else:
			combat_service.request_damage.rpc_id(
				1,
				target_id,
				melee_damage,
				_player.get_instance_id(),
				_player.global_position,
				DamageInfo.DamageType.MELEE,
				result["position"]
			)
