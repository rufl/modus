extends Node


func initialize() -> void:
	# EventService is a lightweight wrapper around EventBus
	# No initialization needed, but method required by GameCore
	pass


## Subscribe to an event (Wrapper for EventBus)


func subscribe(event_id: String, callback: Callable, priority: int = 0) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("EventBus"):
		var bus: Node = tree.root.get_node("EventBus")
		bus.subscribe(event_id, callback, priority)


## Unsubscribe from an event (Wrapper for EventBus)


func unsubscribe(event_id: String, callback: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("EventBus"):
		var bus: Node = tree.root.get_node("EventBus")
		bus.unsubscribe(event_id, callback)
