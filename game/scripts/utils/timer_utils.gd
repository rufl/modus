class_name TimerUtils
extends RefCounted

## Utility functions for safe timer usage to prevent memory leaks
##
## SceneTreeTimer instances can leak if nodes are freed before timers complete.
## These utilities ensure proper cleanup.


## Create a one-shot timer that auto-disconnects after firing
## This prevents memory leaks when nodes are freed before timer completes
static func create_timer_oneshot(tree: SceneTree, time: float, callback: Callable) -> void:
	if not is_instance_valid(tree):
		return
	tree.create_timer(time).timeout.connect(callback, CONNECT_ONE_SHOT)


## Create a timer for auto-cleanup of a node
## Safely queues the node for deletion after the specified time
static func auto_cleanup(tree: SceneTree, node: Node, time: float) -> void:
	if not is_instance_valid(tree) or not is_instance_valid(node):
		return
	tree.create_timer(time).timeout.connect(
		func() -> void:
			if is_instance_valid(node):
				node.queue_free(),
		CONNECT_ONE_SHOT
	)


## Await a timer with proper cleanup
## Use this instead of: await get_tree().create_timer(X).timeout
static func wait(tree: SceneTree, time: float) -> Signal:
	if not is_instance_valid(tree):
		# Return a dummy signal that completes immediately
		var dummy := Node.new()
		dummy.tree_exited.emit()
		dummy.free()
		return dummy.tree_exited
	return tree.create_timer(time).timeout
