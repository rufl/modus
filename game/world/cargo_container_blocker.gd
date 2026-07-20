extends Node3D

## Adds invisible collision volumes to closed cargo containers
## to prevent enemy spawning inside them


func _ready() -> void:
	call_deferred("_add_spawn_blockers")


func _add_spawn_blockers() -> void:
	# Find all cargo containers in the scene
	var cargo_nodes := _find_cargo_containers(get_tree().root)

	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(
			"[CargoBlocker] Found " + " " + str(cargo_nodes.size()) + " " + " cargo containers",
			"World"
		)

	for cargo in cargo_nodes:
		# Only block closed containers (not "open" in name)
		var cargo_name := cargo.name.to_lower()
		if "open" in cargo_name:
			continue

		# Add spawn blocker collision
		_add_blocker_to_cargo(cargo)


func _find_cargo_containers(node: Node) -> Array[Node]:
	var result: Array[Node] = []

	if node.name.begins_with("Cargo") or node.name.begins_with("cargo"):
		result.append(node)

	for child in node.get_children():
		result.append_array(_find_cargo_containers(child))

	return result


func _add_blocker_to_cargo(cargo: Node) -> void:
	# Create a StaticBody3D with collision to block spawning
	var blocker := StaticBody3D.new()
	blocker.name = "SpawnBlocker"

	# Set collision layers - only block enemy spawning, not bullets/players
	blocker.collision_layer = 32  # LAYER_TRIGGERS (bit 6)
	blocker.collision_mask = 0  # Don't collide with anything

	# Add to "no_spawn" group so spawn system avoids it
	blocker.add_to_group("no_spawn")

	# Create box collision shape (standard cargo container size)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 2.4, 6.0)  # Standard 20ft container dimensions
	collision.shape = box

	blocker.add_child(collision)
	cargo.add_child(blocker)

	var logger = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info("[CargoBlocker] Added spawn blocker to: " + " " + str(cargo.name), "World")
