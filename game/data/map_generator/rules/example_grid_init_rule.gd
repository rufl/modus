## ExampleGridInitRule - Example rule that initializes the grid
##
## This is an example rule module that demonstrates how to extend RuleBase.
## It runs during the grid_layout phase and initializes empty cells in the grid.

extends "res://game/scripts/map_generator/rule_base.gd"


func can_apply(context: GenerationContext) -> bool:
	# This rule can always apply if we have a valid grid size
	return context.config != null and context.config.map_size.x > 0


func apply(context: GenerationContext) -> bool:
	# Initialize the grid if it's empty
	if context.grid.is_empty():
		var map_size := context.config.map_size

		for y in range(map_size.y):
			var row: Array[Cell] = []
			for x in range(map_size.x):
				var cell := Cell.new()
				cell.type = Cell.Type.EMPTY
				row.append(cell)
			context.grid.append(row)

		context.grid_size = map_size

		print("ExampleGridInitRule: Initialized %dx%d grid" % [map_size.x, map_size.y])
		return true

	return true  # Grid already initialized, nothing to do


func get_priority() -> int:
	return 1000  # High priority - run early in grid_layout phase


func get_rule_name() -> String:
	return "ExampleGridInitRule"


func get_phase() -> String:
	return "grid_layout"
