extends Node

signal player_registered(peer_id: int, player: Node)
signal player_unregistered(peer_id: int)
signal enemy_registered(enemy: Node)
signal enemy_unregistered(enemy: Node)

var _players_by_id: Dictionary = {}
var _players_array: Array[Node] = []
var _enemies_by_id: Dictionary = {}
var _enemies_array: Array[Node] = []


static func get_service() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		var manager: Node = tree.root.get_node("GameManager")
		if manager.has_method("get_core_system"):
			return manager.get_core_system("entities")
	return null


func initialize() -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger:
		logger.info("[EntityService] Initializing...", "EntityService")
	await get_tree().process_frame


func register_player(peer_id: int, player: Node) -> void:
	if peer_id in _players_by_id:
		return
	_players_by_id[peer_id] = player
	_players_array.append(player)
	player_registered.emit(peer_id, player)
	# FIXED C-05: Use named method instead of lambda for clarity
	player.tree_exiting.connect(_on_player_tree_exiting.bind(peer_id))


func unregister_player(peer_id: int) -> void:
	if peer_id not in _players_by_id:
		return
	var player: Node = _players_by_id[peer_id]
	_players_by_id.erase(peer_id)
	_players_array.erase(player)
	player_unregistered.emit(peer_id)


func get_player(peer_id: int) -> Node:
	return _players_by_id.get(peer_id, null)


func get_all_players() -> Array[Node]:
	return _players_array.duplicate()


func register_enemy(enemy: Node) -> void:
	var id: int = enemy.get_instance_id()
	if id in _enemies_by_id:
		return
	_enemies_by_id[id] = enemy
	_enemies_array.append(enemy)
	enemy_registered.emit(enemy)
	# FIXED C-05: Use named method instead of lambda for clarity
	enemy.tree_exiting.connect(_on_enemy_tree_exiting.bind(enemy))


func _on_player_tree_exiting(peer_id: int) -> void:
	## Called when player node is exiting tree
	unregister_player(peer_id)


func _on_enemy_tree_exiting(enemy: Node) -> void:
	## Called when enemy node is exiting tree
	unregister_enemy(enemy)


func unregister_enemy(enemy: Node) -> void:
	var id: int = enemy.get_instance_id()
	if id not in _enemies_by_id:
		return
	_enemies_by_id.erase(id)
	_enemies_array.erase(enemy)
	enemy_unregistered.emit(enemy)


func get_all_enemies() -> Array[Node]:
	return _enemies_array.duplicate()


func clear_all() -> void:
	_players_by_id.clear()
	_players_array.clear()
	_enemies_by_id.clear()
	_enemies_array.clear()
