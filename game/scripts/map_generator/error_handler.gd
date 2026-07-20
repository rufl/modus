extends RefCounted
class_name ErrorHandler

## ErrorHandler
## Manages error handling, retry logic, and constraint relaxation for map generation
## Retries failed phases up to 3 times with progressively relaxed constraints

const MAX_RETRY_ATTEMPTS: int = 3


## Error context for tracking failures
class ErrorContext:
	var phase_name: String = ""
	var attempt_number: int = 0
	var error_message: String = ""
	var stack_trace: String = ""
	var timestamp: int = 0

	func _init(phase: String = "", attempt: int = 0, error: String = "") -> void:
		phase_name = phase
		attempt_number = attempt
		error_message = error
		timestamp = Time.get_ticks_msec()
		stack_trace = _capture_stack_trace()

	func _capture_stack_trace() -> String:
		var stack: Array = get_stack()
		var trace := ""
		for frame_data: Variant in stack:
			var frame: Dictionary = frame_data as Dictionary
			if not frame:
				continue
			trace += (
				"  at %s:%d in %s()\n"
				% [
					frame.get("source", "unknown"),
					frame.get("line", 0),
					frame.get("function", "unknown")
				]
			)
		return trace


## Run a phase with retry logic and constraint relaxation
func run_phase_with_retry(
	phase_name: String,
	phase_callable: Callable,
	context: RefCounted,
	max_attempts: int = MAX_RETRY_ATTEMPTS
) -> bool:
	for attempt: int in range(max_attempts):
		# Log attempt
		_log_attempt(phase_name, attempt + 1, max_attempts)

		# Execute phase
		var success: bool = phase_callable.call()

		if success:
			if attempt > 0:
				_log_success_after_retry(phase_name, attempt + 1)
			return true

		# Log failure
		var error_ctx := ErrorContext.new(phase_name, attempt + 1, "Phase execution failed")
		_log_error(error_ctx)

		# Don't relax constraints on last attempt (no point)
		if attempt < max_attempts - 1:
			_relax_phase_constraints(phase_name, context, attempt)

	# All attempts failed
	_log_final_failure(phase_name, max_attempts)
	return false


## Relax constraints for a specific phase based on attempt number
func _relax_phase_constraints(phase_name: String, context: RefCounted, attempt: int) -> void:
	_log_constraint_relaxation(phase_name, attempt + 1)

	match phase_name:
		"grid_layout":
			_relax_grid_layout_constraints(context, attempt)
		"shape_grammar":
			_relax_shape_grammar_constraints(context, attempt)
		"hallway_generation":
			_relax_hallway_constraints(context, attempt)
		"cave_generation":
			_relax_cave_constraints(context, attempt)
		"navigation_baking":
			_relax_navigation_constraints(context, attempt)
		"prefab_placement":
			_relax_prefab_constraints(context, attempt)
		_:
			push_warning("No constraint relaxation defined for phase: %s" % phase_name)


## Relax grid layout constraints
func _relax_grid_layout_constraints(context: RefCounted, _attempt: int) -> void:
	# Reduce minimum room count
	if context.has("min_room_count"):
		var original: int = context.min_room_count
		context.min_room_count = max(3, context.min_room_count - 2)
		_log_relaxation_detail("min_room_count", original, context.min_room_count)


## Relax shape grammar constraints
func _relax_shape_grammar_constraints(context: RefCounted, _attempt: int) -> void:
	# Allow simpler room shapes
	if context.config and context.config.has("prefab_detail_level"):
		var original: float = context.config.prefab_detail_level
		context.config.prefab_detail_level = max(0.3, context.config.prefab_detail_level * 0.8)
		_log_relaxation_detail("prefab_detail_level", original, context.config.prefab_detail_level)

	# Reduce L-system iterations for simpler shapes
	if context.has("lsystem_iterations"):
		var original: int = context.lsystem_iterations
		context.lsystem_iterations = max(1, context.lsystem_iterations - 1)
		_log_relaxation_detail("lsystem_iterations", original, context.lsystem_iterations)


## Relax hallway generation constraints
func _relax_hallway_constraints(context: RefCounted, _attempt: int) -> void:
	# Allow wider hallways
	if context.has("hallway_min_width"):
		var original: int = context.hallway_min_width
		context.hallway_min_width = max(1, context.hallway_min_width - 1)
		_log_relaxation_detail("hallway_min_width", original, context.hallway_min_width)

	# Increase pathfinding tolerance
	if context.has("pathfinding_max_iterations"):
		var original: int = context.pathfinding_max_iterations
		var new_value: int = int(context.pathfinding_max_iterations * 1.5)
		context.pathfinding_max_iterations = new_value
		_log_relaxation_detail("pathfinding_max_iterations", original, new_value)


## Relax cave generation constraints
func _relax_cave_constraints(context: RefCounted, _attempt: int) -> void:
	# Reduce cellular automata iterations
	if context.has("cave_iterations"):
		var original: int = context.cave_iterations
		context.cave_iterations = max(2, context.cave_iterations - 1)
		_log_relaxation_detail("cave_iterations", original, context.cave_iterations)

	# Adjust birth/survive thresholds for more open caves
	if context.has("cave_birth_threshold"):
		var original: int = context.cave_birth_threshold
		context.cave_birth_threshold = max(3, context.cave_birth_threshold - 1)
		_log_relaxation_detail("cave_birth_threshold", original, context.cave_birth_threshold)


## Relax navigation mesh constraints
func _relax_navigation_constraints(context: RefCounted, _attempt: int) -> void:
	# Increase cell size for faster baking
	if context.has("navmesh_cell_size"):
		var original: float = context.navmesh_cell_size
		context.navmesh_cell_size = min(0.5, context.navmesh_cell_size * 1.2)
		_log_relaxation_detail("navmesh_cell_size", original, context.navmesh_cell_size)

	# Reduce agent height for more permissive navigation
	if context.has("navmesh_agent_height"):
		var original: float = context.navmesh_agent_height
		context.navmesh_agent_height = max(1.5, context.navmesh_agent_height * 0.9)
		_log_relaxation_detail("navmesh_agent_height", original, context.navmesh_agent_height)


## Relax prefab placement constraints
func _relax_prefab_constraints(context: RefCounted, _attempt: int) -> void:
	# Reduce prefab density
	if context.config and context.config.has("prop_density"):
		var original: float = context.config.prop_density
		context.config.prop_density = max(0.2, context.config.prop_density * 0.7)
		_log_relaxation_detail("prop_density", original, context.config.prop_density)

	# Increase collision tolerance
	if context.has("prefab_collision_tolerance"):
		var original: float = context.prefab_collision_tolerance
		context.prefab_collision_tolerance = min(2.0, context.prefab_collision_tolerance * 1.3)
		_log_relaxation_detail(
			"prefab_collision_tolerance", original, context.prefab_collision_tolerance
		)


## Log attempt information
func _log_attempt(phase_name: String, attempt: int, max_attempts: int) -> void:
	if attempt == 1:
		print("MapGenerator: Starting phase '%s'" % phase_name)
	else:
		print(
			(
				"MapGenerator: Retrying phase '%s' (attempt %d/%d)"
				% [phase_name, attempt, max_attempts]
			)
		)


## Log error with context
func _log_error(error_ctx: ErrorContext) -> void:
	push_error(
		(
			"MapGenerator: Phase '%s' failed (attempt %d): %s"
			% [error_ctx.phase_name, error_ctx.attempt_number, error_ctx.error_message]
		)
	)

	if error_ctx.stack_trace != "":
		print("Stack trace:\n%s" % error_ctx.stack_trace)


## Log constraint relaxation
func _log_constraint_relaxation(phase_name: String, attempt: int) -> void:
	print("MapGenerator: Relaxing constraints for phase '%s' (attempt %d)" % [phase_name, attempt])


## Log specific relaxation detail
func _log_relaxation_detail(param_name: String, old_value: Variant, new_value: Variant) -> void:
	print("  - %s: %s -> %s" % [param_name, str(old_value), str(new_value)])


## Log success after retry
func _log_success_after_retry(phase_name: String, attempt: int) -> void:
	print("MapGenerator: Phase '%s' succeeded after %d attempt(s)" % [phase_name, attempt])


## Log final failure after all retries
func _log_final_failure(phase_name: String, max_attempts: int) -> void:
	push_error(
		(
			"MapGenerator: Phase '%s' failed after %d attempts. Aborting generation."
			% [phase_name, max_attempts]
		)
	)


## Create error report for debugging
func create_error_report(error_contexts: Array[ErrorContext]) -> Dictionary:
	var report := {
		"timestamp": Time.get_ticks_msec(), "total_errors": error_contexts.size(), "errors": []
	}

	for ctx in error_contexts:
		report["errors"].append(
			{
				"phase": ctx.phase_name,
				"attempt": ctx.attempt_number,
				"message": ctx.error_message,
				"timestamp": ctx.timestamp,
				"stack_trace": ctx.stack_trace
			}
		)

	return report


## Save error report to file
func save_error_report(report: Dictionary, output_path: String) -> bool:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save error report to: %s" % output_path)
		return false

	file.store_string(JSON.stringify(report, "\t"))
	file.close()

	print("MapGenerator: Error report saved to: %s" % output_path)
	return true
