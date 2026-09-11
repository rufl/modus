class_name PlayerStatusComponent
extends GameComponent

const GlobalEnums = preload("res://game/core/enums.gd")

var afk_threshold: float = 30.0

var _player: Player
var _input_component: PlayerInputComponent
var _match_service: Node
var _health_component: Node  # Typed as Node to avoid cyclic dependency issues
var _status_update_timer: float = 0.0
var _status_update_interval: float = 1.0
var _is_in_menu: bool = false


func setup(
	player: Player, input_comp: PlayerInputComponent, health_comp: Node, match_service: Node
) -> void:
	_player = player
	_input_component = input_comp
	_health_component = health_comp
	_match_service = match_service

	# Load initial config if available
	_load_config()


func configure(afk_time: float, update_interval: float) -> void:
	afk_threshold = afk_time
	_status_update_interval = update_interval


func set_in_menu(in_menu: bool) -> void:
	_is_in_menu = in_menu


func _process(delta: float) -> void:
	# Check authority - in single player (no peer), always process for local player
	var is_local: bool = (
		not _player
		or (not multiplayer.has_multiplayer_peer() or _player.is_multiplayer_authority())
	)
	if not is_local:
		return

	_update_player_status(delta)


func _update_player_status(delta: float) -> void:
	var time_now: float = Time.get_ticks_msec() / 1000.0
	var status: int = GlobalEnums.PlayerState.ALIVE

	# Determine status
	if _player.is_dead:
		status = GlobalEnums.PlayerState.DEAD
	elif _player.is_downed:
		status = GlobalEnums.PlayerState.DOWNED
	elif _is_in_menu:
		status = GlobalEnums.PlayerState.MENU
	elif _is_editing_mode():
		status = GlobalEnums.PlayerState.EDITING
	elif _input_component and (time_now - _input_component.last_input_time > afk_threshold):
		status = GlobalEnums.PlayerState.AFK

	# Periodic update
	_status_update_timer -= delta
	if _status_update_timer <= 0:
		_status_update_timer = _status_update_interval

		# Allow reading health safely
		var hp: float = 100.0
		if _health_component and "current_health" in _health_component:
			hp = _health_component.current_health

		# Only send update if we are the authority and service exists
		if _match_service:
			if _match_service.has_method("update_player_status"):
				# Check authority - Fixed: Use _player.is_multiplayer_authority()
				# instead of _match_service.is_multiplayer_authority()
				if _player.is_multiplayer_authority():
					if (
						_match_service.multiplayer
						and _match_service.multiplayer.has_multiplayer_peer()
						and not _match_service.multiplayer.is_server()
					):
						_match_service.update_player_status.rpc_id(
							1, _player.get_multiplayer_authority(), hp, status
						)
					else:
						_match_service.update_player_status(
							_player.get_multiplayer_authority(), hp, status
						)


func _is_editing_mode() -> bool:
	var ne: Node = get_node_or_null("/root/NetworkEditor")
	return ne and "is_edit_mode" in ne and ne.is_edit_mode


func _load_config() -> void:
	var cfg: Node = GameManager.get_core_system("config")
	if not cfg or not cfg.has_method("get_value"):
		return

	var status_cfg: Variant = cfg.get_value("player_modes.status", {})
	if status_cfg is Dictionary and not status_cfg.is_empty():
		configure(
			status_cfg.get("afk_threshold_seconds", afk_threshold),
			status_cfg.get("status_update_interval", _status_update_interval)
		)
