## RuleBase - Abstract base class for modular generation rules
##
## This class defines the interface that all rule modules must implement.
## Rule modules are loaded dynamically and executed in priority order during
## map generation to modify the generation context.
##
## **Validates: Requirements 24.2, 24.3**

class_name RuleBase
extends RefCounted


## Check if this rule can be applied in the current context
##
## This method should return true if the rule's preconditions are met
## and it should be executed. For example, a cave generation rule might
## check if cave_bias > 0.0 before applying.
##
## @param context: The current generation context containing grid, config, etc.
## @return: true if the rule can be applied, false otherwise
func can_apply(_context: GenerationContext) -> bool:
	push_error("RuleBase.can_apply() must be overridden by subclass")
	return false


## Apply the rule to modify the generation context
##
## This method performs the actual generation logic, modifying the context
## in place. It should return true if the rule was successfully applied,
## or false if it failed (which may trigger retry logic).
##
## @param context: The generation context to modify
## @return: true if the rule was successfully applied, false otherwise
func apply(_context: GenerationContext) -> bool:
	push_error("RuleBase.apply() must be overridden by subclass")
	return false


## Get the priority of this rule (higher = executed first)
##
## Rules are executed in descending priority order. Use this to control
## the order of rule execution within a phase. For example:
## - Layout rules: 1000-1999
## - Room generation: 2000-2999
## - Hallway generation: 3000-3999
## - Detail placement: 4000-4999
##
## @return: The priority value (higher values execute first)
func get_priority() -> int:
	return 0


## Get the name of this rule for logging and metadata
##
## This name is used in log messages and stored in the generation metadata
## to track which rules were used to generate a map.
##
## @return: A descriptive name for this rule
func get_rule_name() -> String:
	return "BaseRule"


## Get the generation phase this rule belongs to
##
## Valid phases include:
## - "grid_layout": Initial grid allocation
## - "shape_grammar": Room shape generation
## - "hallway_generation": Hallway pathfinding and connection
## - "outdoor_cave": Outdoor and cave area generation
## - "boss_arena": Boss arena placement
## - "csg_geometry": CSG geometry building
## - "prefab_placement": Prefab instantiation
## - "gameplay_elements": Monster, item, and key placement
## - "navigation": Navigation mesh baking
## - "validation": Final validation checks
##
## @return: The phase name this rule belongs to
func get_phase() -> String:
	return "unknown"
