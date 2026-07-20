class_name HealthComponent
extends GameComponent

signal health_changed(current: float, max: float)
signal armor_changed(current: float, max: float)
signal damage_received(amount: float, source_id: int, type: int)
signal died(source_id: int)

@export var max_health: float = 100.0
@export var max_armor: float = 200.0
@export var armor_absorption: float = 0.66  # 2/3 damage to armor (Quake/HL style)

var invincible: bool = false
var current_armor: float = 0.0
var last_weapon_id: String = ""
var current_health: float = 100.0

@onready var parent: Node = get_parent()

var _initialized: bool = false
var _is_dead: bool = false
var is_dead: bool:
	get:
		return _is_dead


func _ready() -> void:
	_initialized = true
	current_health = max_health

	# Register to global list if needed
	if parent and parent.is_in_group("player"):
		# Initial sync
		health_changed.emit(current_health, max_health)
		armor_changed.emit(current_armor, max_armor)
		_emit_bus_update(true, true)


## Self-configuring method with difficulty scaling


func configure_from_data(base_health: float, apply_difficulty: bool = true) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	if apply_difficulty and gs and gs.difficulty:
		max_health = gs.difficulty.get_scaled_health(base_health)
	else:
		max_health = base_health

	current_health = max_health
	health_changed.emit(current_health, max_health)
	_emit_bus_update(true, false)


## Public setter for health/armor (Server Authority)


func set_health(hp: float, armor: float = -1.0) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		push_warning("[HealthComponent] set_health called on client, ignoring")
		return

	var new_armor: float = armor if armor >= 0 else current_armor
	_sync_health_state.rpc(hp, new_armor)


@rpc("authority", "call_remote", "reliable")
func _sync_health_state(new_health: float, new_armor: float, source_id: int = -1) -> void:
	var old_health: float = current_health

	current_health = new_health
	current_armor = new_armor

	health_changed.emit(current_health, max_health)
	armor_changed.emit(current_armor, max_armor)
	_emit_bus_update(true, true)

	# If health dropped, emit damage_received locally for feedback
	if current_health < old_health:
		var dmg_amount: float = old_health - current_health
		damage_received.emit(dmg_amount, source_id, 0)

		var gm: Node = get_node_or_null("/root/GameManager")
		if gm:
			gm.emit_event(
				"damage_dealt",
				{
					"target": parent,
					"amount": dmg_amount,
					"source_id": source_id,
					"source": instance_from_id(source_id)
				}
			)

	if current_health <= 0 and old_health > 0:
		die(source_id)


func take_damage(info: DamageInfo) -> void:
	if _is_dead:
		return
	if invincible:
		return

	# Capture weapon ID for kill feed
	if not info.weapon_id.is_empty():
		last_weapon_id = info.weapon_id
	elif info.weapon_source and "id" in info.weapon_source:
		last_weapon_id = info.weapon_source.id

	# Server Authority
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Get GameManager once for the entire function
	var gm: Node = get_node_or_null("/root/GameManager")

	# Check godmode - ONLY applies to players
	if parent and parent.is_in_group("player"):
		var gs: Node = gm.get_core_system("gameplay") if gm else null
		if (
			gs
			and gs.match_service
			and gs.match_service.has_method("is_godmode_active")
			and gs.match_service.is_godmode_active()
		):
			return

	var damage: float = info.base_amount
	var absorbed: float = 0.0

	# Armor calculation
	if current_armor > 0:
		var armor_damage: float = damage * armor_absorption
		if armor_damage > current_armor:
			absorbed = current_armor
			current_armor = 0
			damage = damage - absorbed
		else:
			absorbed = armor_damage
			current_armor -= armor_damage
			damage -= armor_damage

	var final_health: float = current_health - damage
	current_health = clamp(final_health, 0, max_health)

	health_changed.emit(current_health, max_health)
	armor_changed.emit(current_armor, max_armor)
	_emit_bus_update(true, true)

	damage_received.emit(info.base_amount, info.source_id, info.damage_type)

	if parent and parent.is_in_group("player"):
		var source_pos: Vector3 = Vector3.ZERO
		if info.source and "global_position" in info.source:
			source_pos = info.source.global_position

		if gm:
			gm.emit_event(
				"player_damaged",
				{
					"amount": info.base_amount,
					"source_id": info.source_id,
					"source_position": source_pos,
					"is_critical": info.is_critical,
					"peer_id": parent.get_multiplayer_authority()
				}
			)

		var gs2: Node = gm.get_core_system("gameplay") if gm else null
		if gs2 and gs2.effects and gs2.effects.has_method("screen_flash"):
			var flash_color: Color = Color(0.8, 0.1, 0.1, 0.3)
			if info.is_critical:
				flash_color = Color(1, 0, 0, 0.5)
			gs2.effects.screen_flash(flash_color, 0.15)

	if gm:
		gm.emit_event(
			"damage_dealt",
			{
				"target": parent,
				"amount": info.base_amount,
				"source_id": info.source_id,
				"source": info.source,
				"type": info.damage_type,
				"is_critical": info.is_critical,
				"weapon_id": last_weapon_id
			}
		)

	_sync_health_state.rpc(current_health, current_armor, info.source_id)

	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger and logger.current_level == logger.LogLevel.TRACE:
		logger.trace(
			(
				"[Health] Took %.1f dmg (Absorbed: %.1f). HP: %.1f, Armor: %.1f"
				% [info.base_amount, absorbed, current_health, current_armor]
			),
			"HealthComponent"
		)

	if current_health <= 0:
		die(info.source_id)


func die(killer_id: int) -> void:
	if _is_dead:
		return
	_is_dead = true

	var gm: Node = get_node_or_null("/root/GameManager")
	var logger: Node = gm.get_core_system("logger") if gm else null
	if logger:
		logger.info(
			(
				"[Health] Entity %s died. Killer: %d, Weapon: %s"
				% [parent.name, killer_id, last_weapon_id]
			),
			"HealthComponent"
		)

	died.emit(killer_id)

	if parent and parent.is_in_group("player"):
		if gm:
			gm.emit_event(
				"player_died",
				{
					"peer_id": parent.get_multiplayer_authority(),
					"killer_id": killer_id,
					"weapon_id": last_weapon_id
				}
			)
	# NOTE: enemy_died is emitted by EnemyDamageHandler, not here
	# This prevents duplicate kill counting


func heal(amount: float) -> void:
	if _is_dead:
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	var actual_heal: float = min(amount, max_health - current_health)
	if actual_heal <= 0:
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	_emit_bus_update(true, false)

	if parent is Node3D:
		_sync_heal_visual.rpc(parent.global_position, actual_heal)

	_sync_health_state.rpc(current_health, current_armor)


@rpc("authority", "call_local", "reliable")
func _sync_heal_visual(pos: Vector3, amount: float) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	var gs: Node = gm.get_core_system("gameplay") if gm else null
	if gs and gs.effects and gs.effects.has_method("spawn_heal_effect"):
		gs.effects.spawn_heal_effect(pos, amount)


func add_armor(amount: float) -> void:
	if _is_dead:
		return

	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	current_armor = min(current_armor + amount, max_armor)
	armor_changed.emit(current_armor, max_armor)
	_emit_bus_update(false, true)

	_sync_health_state.rpc(current_health, current_armor)


func reset_death_state() -> void:
	_is_dead = false


func _emit_bus_update(is_health: bool = true, is_armor: bool = true) -> void:
	if not is_instance_valid(parent):
		return

	var gm: Node = get_node_or_null("/root/GameManager")
	if not gm:
		return

	if is_health:
		gm.emit_event(
			"health_changed",
			{"entity_id": parent.get_instance_id(), "current": current_health, "max": max_health}
		)

	if is_armor:
		gm.emit_event(
			"armor_changed",
			{"entity_id": parent.get_instance_id(), "current": current_armor, "max": max_armor}
		)
