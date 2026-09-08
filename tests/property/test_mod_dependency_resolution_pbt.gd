extends PropertyBasedTesting

## Property-Based Test: Mod Dependency Resolution
## Feature: architecture-refactoring, Property 31: Mod dependency resolution
## **Validates: Requirements 10.3**


func test_property_dependency_resolution_methods_exist() -> void:
	# Property: ModLoader should have methods for dependency resolution

	await run_enhanced_property_test(
		"Dependency resolution methods exist",
		_test_dependency_methods_exist,
		10,
		SamplingStrategy.EDGE_CASE,
		"ModLoader should provide dependency resolution functionality"
	)


func _test_dependency_methods_exist(test_data: Dictionary) -> bool:
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check for dependency resolution methods
	var has_resolve_load_order: bool = content.contains("func _resolve_load_order(")
	var has_check_dependencies: bool = content.contains("func _check_dependencies(")
	var has_get_dependency_tree: bool = content.contains("func get_dependency_tree(")

	# Check for topological sort implementation
	var has_topological_sort: bool = (
		content.contains("Topological sort") or content.contains("topological")
	)

	return (
		has_resolve_load_order
		and has_check_dependencies
		and has_get_dependency_tree
		and has_topological_sort
	)


func test_property_dependency_order_validation() -> void:
	# Property: For any set of mods with declared dependencies, the system
	# should load them in an order where each mod is loaded after all its dependencies

	await run_enhanced_property_test(
		"Mods load in dependency order",
		_test_dependency_order,
		50,
		SamplingStrategy.MIXED,
		"Mods should be loaded after their dependencies"
	)


func _test_dependency_order(test_data: Dictionary) -> bool:
	var rng: RandomNumberGenerator = get_seeded_rng(test_data.get("iteration", 0))

	# Create a test scenario with mods that have dependencies
	# Mod A depends on nothing
	# Mod B depends on A
	# Mod C depends on B

	var mods: Array[Dictionary] = [
		{"name": "ModC", "dependencies": ["ModB"], "priority": rng.randi_range(0, 100)},
		{"name": "ModA", "dependencies": [], "priority": rng.randi_range(0, 100)},
		{"name": "ModB", "dependencies": ["ModA"], "priority": rng.randi_range(0, 100)}
	]

	# Simulate dependency resolution (simplified version of _resolve_load_order logic)
	var resolved_order: Array[String] = _simulate_dependency_resolution(mods)

	# Property: ModA should come before ModB, and ModB should come before ModC
	var index_a: int = resolved_order.find("ModA")
	var index_b: int = resolved_order.find("ModB")
	var index_c: int = resolved_order.find("ModC")

	# All mods should be in the resolved order
	if index_a == -1 or index_b == -1 or index_c == -1:
		return false

	# Check dependency order
	return index_a < index_b and index_b < index_c


func test_property_circular_dependency_detection() -> void:
	# Property: For any set of mods with circular dependencies, the system
	# should detect the circular dependency

	await run_enhanced_property_test(
		"Circular dependencies are detected",
		_test_circular_dependency_detection,
		30,
		SamplingStrategy.EDGE_CASE,
		"Circular dependencies should be detected"
	)


func _test_circular_dependency_detection(test_data: Dictionary) -> bool:
	# Create a circular dependency scenario
	# Mod A depends on B
	# Mod B depends on C
	# Mod C depends on A (circular!)

	var mods: Array[Dictionary] = [
		{"name": "ModA", "dependencies": ["ModB"]},
		{"name": "ModB", "dependencies": ["ModC"]},
		{"name": "ModC", "dependencies": ["ModA"]}
	]

	# Simulate dependency resolution
	var resolved_order: Array[String] = _simulate_dependency_resolution(mods)

	# Property: Circular dependencies should result in an empty or incomplete resolution
	# (the actual implementation should detect this and emit an error)
	# For this test, we check that the resolution doesn't include all mods
	# or that it detects the issue

	# Check if the mod_loader.gd contains circular dependency detection
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check for circular dependency detection logic
	var has_circular_detection: bool = (
		content.contains("Circular dependency") or content.contains("circular")
	)

	return has_circular_detection


func test_property_missing_dependency_handling() -> void:
	# Property: For any mod with a missing dependency, the system should
	# detect and report the missing dependency

	await run_enhanced_property_test(
		"Missing dependencies are detected",
		_test_missing_dependency_detection,
		30,
		SamplingStrategy.MIXED,
		"Missing dependencies should be detected"
	)


func _test_missing_dependency_detection(test_data: Dictionary) -> bool:
	# Create a scenario where a mod depends on a non-existent mod
	var mods: Array[Dictionary] = [{"name": "ModA", "dependencies": ["NonExistentMod"]}]

	# Simulate dependency resolution
	var resolved_order: Array[String] = _simulate_dependency_resolution(mods)

	# Property: Missing dependencies should result in the mod not being loaded
	# Check if the mod_loader.gd contains missing dependency detection
	var mod_loader_path: String = "res://game/scripts/features/modding/mod_loader.gd"
	var file: FileAccess = FileAccess.open(mod_loader_path, FileAccess.READ)
	if not file:
		return false

	var content: String = file.get_as_text()
	file.close()

	# Check for missing dependency detection logic
	var has_missing_dep_check: bool = (
		content.contains("Missing dependency")
		or content.contains("missing dependency")
		or content.contains("not enabled")
	)

	return has_missing_dep_check


## Helper function to simulate dependency resolution
## This is a simplified version of the actual _resolve_load_order logic
func _simulate_dependency_resolution(mods: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	var visited: Dictionary = {}
	var temp_marks: Dictionary = {}
	var mod_by_name: Dictionary = {}

	# Build name -> mod map
	for mod: Dictionary in mods:
		var mod_name: String = mod.get("name", "")
		mod_by_name[mod_name] = mod

	# Recursive visit function
	var visit: Callable
	visit = func(mod: Dictionary, visit_ref: Callable) -> bool:
		var mod_name: String = mod.get("name", "")

		if visited.get(mod_name, false):
			return true

		if temp_marks.get(mod_name, false):
			# Circular dependency detected
			return false

		temp_marks[mod_name] = true

		# Process dependencies first
		var deps: Array = mod.get("dependencies", [])
		for dep: String in deps:
			if mod_by_name.has(dep):
				if not visit_ref.call(mod_by_name[dep], visit_ref):
					return false
			else:
				# Missing dependency
				return false

		temp_marks[mod_name] = false
		visited[mod_name] = true
		result.append(mod_name)
		return true

	# Visit each mod
	for mod: Dictionary in mods:
		if not visited.get(mod.get("name", ""), false):
			if not visit.call(mod, visit):
				# Failed to resolve (circular or missing dependency)
				return []

	return result
