extends Node

## Global blood effects singleton
## Add to Project Settings > Autoload as "BloodEffects"
## Provides easy access to blood spawning from anywhere in the game

var blood_pool_manager: BloodPoolManager = null
var enabled: bool = true


func _ready() -> void:
	# Wait for scene tree to be ready
	await get_tree().process_frame
	_find_blood_manager()


func _find_blood_manager() -> void:
	# Try to find blood pool manager in current scene
	var managers: Array[Node] = get_tree().get_nodes_in_group("blood_manager")
	if not managers.is_empty():
		blood_pool_manager = managers[0]
	else:
		# Look for any BloodPoolManager node
		var root: Node = get_tree().current_scene
		if root:
			blood_pool_manager = _find_manager_recursive(root)


func _find_manager_recursive(node: Node) -> BloodPoolManager:
	if node is BloodPoolManager:
		return node
	for child in node.get_children():
		var result: BloodPoolManager = _find_manager_recursive(child)
		if result:
			return result
	return null


## Spawn blood at a world position
func spawn_blood(position: Vector3) -> bool:
	if not enabled or not blood_pool_manager:
		return false
	return blood_pool_manager.spawn_blood_at_world_position(position)


## Spawn blood trail between two positions
func spawn_trail(start: Vector3, end: Vector3, drops: int = 5) -> void:
	if not enabled or not blood_pool_manager:
		return
	blood_pool_manager.spawn_blood_trail(start, end, drops)


## Spawn blood splatter (multiple drops in radius)
func spawn_splatter(position: Vector3, intensity: float = 1.0) -> void:
	if not enabled or not blood_pool_manager:
		return
	var radius: float = 0.3 + (intensity * 0.5)
	var drops: int = int(5 + (intensity * 10))
	blood_pool_manager.spawn_blood_splatter(position, radius, drops)


## Register a blood pool manager (call this when scene changes)
func register_manager(manager: BloodPoolManager) -> void:
	blood_pool_manager = manager


## Enable or disable blood effects globally
func set_enabled(value: bool) -> void:
	enabled = value


## Check if blood effects are available
func is_available() -> bool:
	return enabled and blood_pool_manager != null
