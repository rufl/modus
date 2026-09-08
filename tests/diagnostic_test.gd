#!/usr/bin/env -S godot --headless --script
# Diagnostic script to test GameManager availability
extends SceneTree


func _init() -> void:
	print("=== DIAGNOSTIC TEST START ===")
	print("Testing GameManager availability...")

	# Test 1: Check if GameManager autoload exists
	var gm: Node = get_root().get_node_or_null("GameManager")
	if gm:
		print("✓ GameManager autoload found")
		print("  Type: ", typeof(gm))
		print("  Has get_core_system: ", gm.has_method("get_core_system"))
	else:
		print("✗ GameManager autoload NOT found")

	# Test 2: Check if MapGenerator autoload exists
	var mg: Node = get_root().get_node_or_null("MapGenerator")
	if mg:
		print("✓ MapGenerator autoload found")
	else:
		print("✗ MapGenerator autoload NOT found")

	# Test 3: List all autoloads
	print("\nAll root children:")
	var children: Array[Node] = get_root().get_children()
	for child: Node in children:
		print("  - ", child.name, " (", child.get_class(), ")")

	print("\n=== DIAGNOSTIC TEST END ===")
	quit(0)
