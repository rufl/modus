extends ModScript

var received_sample_event := false
var hook_calls: Array[String] = []


func _mod_init() -> void:
	install(get_node_or_null("/root/GameManager"))


func install(game_manager: Node) -> void:
	if game_manager and game_manager.has_method("subscribe"):
		game_manager.subscribe("modus_sample_ping", _on_sample_ping)


func _on_sample_ping(_data: Dictionary) -> void:
	received_sample_event = true


func on_enemy_spawn(_enemy: Node, enemy_type: String) -> void:
	hook_calls.append("enemy_spawn:%s" % enemy_type)


func get_sample_status() -> Dictionary:
	return {
		"event_received": received_sample_event,
		"hook_calls": hook_calls.duplicate()
	}
