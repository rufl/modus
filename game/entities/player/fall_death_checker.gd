extends Node
class_name FallDeathChecker

signal fell_to_death(position: Vector3)
signal respawned(position: Vector3)

@export_group("Fall Settings")
@export var death_y_threshold: float = -50.0
@export var check_interval: float = 0.5
@export_group("Respawn Settings")
@export var respawn_enabled: bool = true
@export var respawn_delay: float = 2.0
@export var respawn_height: float = 1.0

var check_timer: float = 0.0
var is_dead: bool = false
var spawn_position: Vector3 = Vector3.ZERO

var _player: Node3D = null


func _log(message: String, category: String = "FallDeathChecker") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info(message, category)
	else:
		print(message)


func _exit_tree() -> void:
	# === SIGNAL HYGIENE: Disconnect signals to prevent memory leaks ===
	var cfg: Node = GameManager.get_core_system("config")
	if cfg and cfg.config_reloaded.is_connected(_load_config):
		cfg.config_reloaded.disconnect(_load_config)


func _ready() -> void:
	_player = get_parent() as Node3D
	if not _player:
		push_error("[FallDeathChecker] Must be child of a Node3D (player)")
		return

	# Load config
	_load_config()

	# Listen for config reloads
	var cfg2: Node = GameManager.get_core_system("config")
	if cfg2:
		cfg2.config_reloaded.connect(_load_config)

	# Store initial spawn position
	spawn_position = _player.global_position
	spawn_position.y = respawn_height

	_log("[FallDeathChecker] Monitoring falls below Y = %.1f" % death_y_threshold)


func _load_config(_file_path: String = "") -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg:
		return

	var data: Dictionary = cfg.get_value("fall_death", {})
	if data.is_empty():
		return

	death_y_threshold = data.get("death_y_threshold", death_y_threshold)
	# Additional config options can be added here as needed
	# warn_y_threshold = cfg.get("warn_y_threshold", -30.0)
	# show_warning_ui = cfg.get("show_warning_ui", true)


func _process(delta: float) -> void:
	if is_dead:
		return

	# Only run on server in multiplayer (or always in singleplayer)
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	check_timer += delta
	if check_timer >= check_interval:
		check_timer = 0.0
		_check_fall_death()


func _check_fall_death() -> void:
	## Check if player has fallen below death threshold
	if not _player:
		return

	if _player.global_position.y < death_y_threshold:
		_log("[FallDeathChecker] Player fell off map at Y = %.1f" % _player.global_position.y)
		_handle_fall_death()


func _handle_fall_death() -> void:
	## Handle player falling to death
	is_dead = true

	if not _player:
		return

	var death_pos: Vector3 = _player.global_position
	_log("[FallDeathChecker] Player fell to death - bypassing godmode")

	# Kill player directly (bypasses godmode)
	var health_comp: Node = _player.get_node_or_null("HealthComponent")
	if health_comp:
		# Force death state
		if "is_dead" in health_comp:
			health_comp.is_dead = true
		if "current_health" in health_comp:
			health_comp.current_health = 0.0
		# Emit died signal
		if health_comp.has_signal("died"):
			health_comp.died.emit(null)

	# Emit event
	fell_to_death.emit(death_pos)

	# Notify game events
	if GameManager:
		# Use standard event format
		var p_id: int = _player.name.to_int()
		if p_id == 0:
			p_id = _player.get_instance_id()  # Fallback

		GameManager.emit_event(
			"player_died", {"peer_id": p_id, "killer_id": 0, "weapon_id": "void"}
		)  # Environment

	# Sync death to clients in multiplayer
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_fall_death.rpc(death_pos)

	# Respawn if enabled
	if respawn_enabled:
		_start_respawn()


@rpc("authority", "call_local", "reliable")
func _sync_fall_death(position: Vector3) -> void:
	## Sync fall death to clients
	is_dead = true
	fell_to_death.emit(position)


func _start_respawn() -> void:
	## Start respawn timer
	await get_tree().create_timer(respawn_delay).timeout

	if not is_instance_valid(_player):
		return

	_respawn_player()


func _respawn_player() -> void:
	## Respawn player at spawn point
	# Find spawn point
	var respawn_pos: Vector3 = _find_respawn_position()

	# Teleport player
	_player.global_position = respawn_pos

	# Reset velocity
	if _player is CharacterBody3D:
		var cb: CharacterBody3D = _player as CharacterBody3D
		cb.velocity = Vector3.ZERO

	# Heal player
	var health_comp: Node = _player.get_node_or_null("HealthComponent")
	if health_comp:
		if health_comp.has_method("heal"):
			health_comp.heal(9999.0)
		elif health_comp.has_method("set_health"):
			health_comp.set_health(health_comp.max_health if "max_health" in health_comp else 100.0)

		# Reset death flag
		if "is_dead" in health_comp:
			health_comp.is_dead = false

	is_dead = false
	respawned.emit(respawn_pos)
	_log("[FallDeathChecker] Player respawned at %v" % respawn_pos)

	# Sync respawn to clients
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_sync_respawn.rpc(respawn_pos)


@rpc("authority", "call_local", "reliable")
func _sync_respawn(position: Vector3) -> void:
	## Sync respawn to clients
	is_dead = false
	respawned.emit(position)


func _find_respawn_position() -> Vector3:
	## Find best respawn position
	# Check for spawn points in scene
	var spawn_points: Array[Node] = []
	spawn_points.assign(get_tree().get_nodes_in_group("player_spawn"))

	if spawn_points.size() > 0:
		var spawn_point: Node3D = spawn_points[0] as Node3D
		if spawn_point:
			return spawn_point.global_position

	# Fallback to initial spawn position
	return spawn_position


# =============================================================================
# PUBLIC API
# =============================================================================


func set_death_threshold(threshold: float) -> void:
	## Set the Y threshold for fall death
	death_y_threshold = threshold
	_log("[FallDeathChecker] Updated death threshold to Y = %.1f" % threshold)


func set_spawn_position(position: Vector3) -> void:
	## Set the spawn position for respawning
	spawn_position = position


func force_respawn() -> void:
	## Force an immediate respawn
	_respawn_player()


func is_player_dead() -> bool:
	## Check if player is currently dead from falling
	return is_dead


func trigger_death() -> void:
	## Public API to manually trigger fall death (e.g. from MapBoundary)
	_handle_fall_death()
