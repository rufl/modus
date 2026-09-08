class_name PlayerPersistenceComponent
extends GameComponent

var _player: Player
var _health_component: HealthComponent
var _weapon_manager: WeaponManager


func setup(player: Player, health_comp: HealthComponent, weapon_mgr: WeaponManager) -> void:
	_player = player
	_health_component = health_comp
	_weapon_manager = weapon_mgr

	# Attempt restoration if on server (or in single-player)
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if is_multiplayer_authority() and is_server_or_sp:
		# Defer to ensure services are ready
		call_deferred("_restore_from_service")


## Restore player state from GameplayService.player. (Server Only)


func _restore_from_service() -> void:
	var is_server_or_sp: bool = not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if not is_server_or_sp:
		return

	var service: Node = GameManager.get_core_system("player")
	if service and service.has_method("get_player_data"):
		var peer_id: int = _player.name.to_int()
		var data: Dictionary = service.get_player_data(peer_id)
		if not data.is_empty():
			apply_persistence_data(data)
			GameManager.get_core_system("logger").info(
				"[Persistence] Restored data for peer %d" % peer_id, "PlayerPersistence"
			)


## Gather state for persistence


func get_persistence_data() -> Dictionary:
	var data: Dictionary = {}

	if _health_component:
		data["health"] = _health_component.current_health
		data["armor"] = _health_component.current_armor

	if _weapon_manager and _weapon_manager.has_method("get_ammo_data"):
		data["inventory"] = _weapon_manager.get_ammo_data()

	return data


## Apply state from persistence


func apply_persistence_data(data: Dictionary) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Restore Health
	if _health_component:
		var hp: float = data.get("health", _health_component.max_health)
		var arm: float = data.get("armor", 0.0)
		if _player.state_manager:
			_player.state_manager.restore_health(hp, arm)
		else:
			_health_component.set_health(hp, arm)

	# Restore Inventory/Ammo
	if data.has("inventory") and _weapon_manager:
		if _weapon_manager.has_method("apply_ammo_data"):
			_weapon_manager.apply_ammo_data(data["inventory"])
