class_name TestingProfilerCommands
extends RefCounted

## Console commands for TestingTimeProfiler

var profiler: TestingTimeProfiler


func _init(p_profiler: TestingTimeProfiler) -> void:
	profiler = p_profiler


## Register all testing profiler commands
static func register_commands(registry: ConsoleCommandRegistry) -> void:
	var profiler: TestingTimeProfiler = GameManager.get_core_system("testing_time_profiler")
	if not profiler:
		push_warning("[TestingProfilerCommands] TestingTimeProfiler not found")
		return

	var commands := TestingProfilerCommands.new(profiler)

	registry.register_command("test_start", commands.cmd_start_session, "Start a testing session")
	registry.register_command(
		"test_end", commands.cmd_end_session, "End the current testing session"
	)
	registry.register_command(
		"test_log", commands.cmd_log_event, "Log a testing event: test_log <type> <description>"
	)
	registry.register_command("test_stats", commands.cmd_show_stats, "Show testing statistics")
	registry.register_command(
		"test_report", commands.cmd_generate_report, "Generate testing time report"
	)
	registry.register_command("test_export", commands.cmd_export_log, "Export detailed testing log")


func cmd_start_session(args: PackedStringArray) -> String:
	var session_type: String = "manual"
	if args.size() > 0:
		session_type = args[0]

	var session_id: String = profiler.start_session(session_type)
	return "Testing session started: %s" % session_id


func cmd_end_session(_args: PackedStringArray) -> String:
	if not profiler.is_session_active:
		return "No active testing session"

	var duration: float = profiler.end_session()
	return "Testing session ended: %.2f hours" % (duration / 3600.0)


func cmd_log_event(args: PackedStringArray) -> String:
	if not profiler.is_session_active:
		return "No active testing session"

	if args.size() < 2:
		return "Usage: test_log <type> <description>"

	var event_type: String = args[0]
	var description: String = " ".join(args.slice(1))

	profiler.log_event(event_type, description)
	return "Event logged: %s - %s" % [event_type, description]


func cmd_show_stats(_args: PackedStringArray) -> String:
	var stats: Dictionary = profiler.get_statistics()

	var output: String = "=== TESTING STATISTICS ===\n"
	output += "Total Hours: %.2f\n" % stats["total_hours"]
	output += "Total Sessions: %d\n" % stats["total_sessions"]
	output += "Longest Session: %.2f hours\n" % stats["longest_session_hours"]
	output += "Average Session: %.2f hours\n" % stats["average_session_hours"]

	if stats["is_session_active"]:
		output += "\nCurrent Session: %.2f hours (active)\n" % stats["current_session_hours"]

	output += "\nMilestones Reached: %d\n" % stats["milestones_reached"]

	var next_milestone: float = stats["next_milestone"]
	if next_milestone > 0:
		var hours_remaining: float = next_milestone - stats["total_hours"]
		output += (
			"Next Milestone: %.0f hours (%.2f remaining)\n" % [next_milestone, hours_remaining]
		)
	else:
		output += "All milestones reached!\n"

	return output


func cmd_generate_report(_args: PackedStringArray) -> String:
	return profiler.generate_report()


func cmd_export_log(args: PackedStringArray) -> String:
	var filepath: String = "user://testing_time_detailed.txt"
	if args.size() > 0:
		filepath = args[0]

	var success: bool = profiler.export_detailed_log(filepath)
	if success:
		return "Detailed log exported to: %s" % filepath
	return "Failed to export log"
