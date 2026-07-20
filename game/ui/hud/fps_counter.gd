class_name FPSCounter
extends Label

const UPDATE_INTERVAL: float = 0.1  # 10Hz update rate for performance

var _show_fps: bool = false
var _show_ping: bool = false
var _update_timer: float = 0.0


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < UPDATE_INTERVAL:
		return
	_update_timer = 0.0

	var output_lines: PackedStringArray = []

	# FPS display
	if _show_fps:
		var fps: int = int(Engine.get_frames_per_second())
		output_lines.append("FPS: %d" % fps)

	# Network ping display
	if _show_ping:
		var ping_ms: int = _get_network_ping()
		output_lines.append("PING: %d ms" % ping_ms)

	# Debug overlay (only when debug vision enabled)
	var gs := GameManager.get_core_system("gameplay") as GameplaySvc
	if gs and gs.match_service and gs.match_service.debug_vision_enabled:
		text += " | DEBUG VISION"
		output_lines.append_array(_build_debug_info())

	text = "\n".join(output_lines)


func _get_network_ping() -> int:
	# Get round-trip time from ENet if available
	if multiplayer and multiplayer.multiplayer_peer:
		return ENetPacketPeer.PeerStatistic.PEER_ROUND_TRIP_TIME
	return 0


func _build_debug_info() -> PackedStringArray:
	var info: PackedStringArray = []
	info.append("[DEBUG]")

	# Mouse mode
	var mode_names: Dictionary = {
		Input.MOUSE_MODE_VISIBLE: "VISIBLE",
		Input.MOUSE_MODE_HIDDEN: "HIDDEN",
		Input.MOUSE_MODE_CAPTURED: "CAPTURED",
		Input.MOUSE_MODE_CONFINED: "CONFINED"
	}
	var mode_name: String = mode_names.get(Input.mouse_mode, "UNKNOWN")
	info.append("Mouse: %s" % mode_name)

	# Local player info
	var local_player: Node = _find_local_player()
	if local_player:
		info.append("Player: %s" % local_player.name)
		var input_comp: Node = local_player.get("input_component")
		if input_comp:
			info.append("Input: %s" % input_comp.get("wish_shoot"))
	else:
		info.append("Player: None")

	# Focus owner
	var focus: Control = get_viewport().gui_get_focus_owner()
	var focus_name: String = String(focus.name) if focus else "None"
	info.append("Focus: %s" % focus_name)

	return info


func _find_local_player() -> Node:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	for p: Node in players:
		if p.has_method("is_multiplayer_authority") and p.is_multiplayer_authority():
			return p
	return null


# Toggle callbacks


func toggle_fps(enabled: bool) -> void:
	_show_fps = enabled


func toggle_ping(enabled: bool) -> void:
	_show_ping = enabled


# Legacy signal handlers for backwards compatibility


func _on_fps_counter_toggled(toggled_on: bool) -> void:
	toggle_fps(toggled_on)


func _on_ping_toggled(toggled_on: bool) -> void:
	toggle_ping(toggled_on)
