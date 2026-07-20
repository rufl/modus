class_name ProgressReporter
extends RefCounted

## Generates migration progress reports showing completion percentage
## and remaining work.
##
## **Validates: Requirements 8.5**

var tracker: MigrationTracker


func _init(migration_tracker: MigrationTracker = null) -> void:
	if migration_tracker:
		tracker = migration_tracker
	else:
		tracker = MigrationTracker.new()


## Calculate migration percentage
func calculate_percentage() -> float:
	return tracker.get_migration_percentage()


## Generate a detailed migration report
func generate_report() -> String:
	var report = ""
	report += "============================================================" + "\n"
	report += "MIGRATION PROGRESS REPORT\n"
	report += "============================================================" + "\n\n"
	
	# Summary statistics
	var total = tracker.get_total_files()
	var migrated = tracker.get_migrated_count()
	var remaining = tracker.get_unmigrated_count()
	var percentage = calculate_percentage()
	
	report += "Summary:\n"
	report += "------------------------------------------------------------" + "\n"
	report += "  Total Files:      %d\n" % total
	report += "  Migrated:         %d\n" % migrated
	report += "  Remaining:        %d\n" % remaining
	report += "  Progress:         %.2f%%\n" % percentage
	report += "\n"
	
	# Progress bar
	report += "Progress Bar:\n"
	report += "------------------------------------------------------------" + "\n"
	report += _generate_progress_bar(percentage) + "\n\n"
	
	# Migrated files by category
	report += "Migrated Files by Category:\n"
	report += "------------------------------------------------------------" + "\n"
	var migrated_by_category = _categorize_files(tracker.get_migrated_files())
	for category in migrated_by_category:
		report += "  %s: %d files\n" % [category, migrated_by_category[category].size()]
	report += "\n"
	
	# Remaining files by category
	report += "Remaining Files by Category:\n"
	report += "------------------------------------------------------------" + "\n"
	var remaining_by_category = _categorize_files(tracker.get_unmigrated_files())
	for category in remaining_by_category:
		report += "  %s: %d files\n" % [category, remaining_by_category[category].size()]
	report += "\n"
	
	# Detailed remaining work
	if remaining > 0:
		report += "Detailed Remaining Work:\n"
		report += "------------------------------------------------------------" + "\n"
		for category in remaining_by_category:
			report += "\n%s (%d files):\n" % [category, remaining_by_category[category].size()]
			for file_path in remaining_by_category[category]:
				report += "  - %s\n" % file_path
		report += "\n"
	
	report += "============================================================" + "\n"
	report += "END OF REPORT\n"
	report += "============================================================" + "\n"
	
	return report


## Generate a compact summary report
func generate_summary() -> String:
	var total = tracker.get_total_files()
	var migrated = tracker.get_migrated_count()
	var remaining = tracker.get_unmigrated_count()
	var percentage = calculate_percentage()
	
	var summary = "Migration Progress: %d/%d files (%.2f%%) - %d remaining" % [
		migrated,
		total,
		percentage,
		remaining
	]
	
	return summary


## Generate a JSON report
func generate_json_report() -> Dictionary:
	var total = tracker.get_total_files()
	var migrated = tracker.get_migrated_count()
	var remaining = tracker.get_unmigrated_count()
	var percentage = calculate_percentage()
	
	var migrated_by_category = _categorize_files(tracker.get_migrated_files())
	var remaining_by_category = _categorize_files(tracker.get_unmigrated_files())
	
	return {
		"summary": {
			"total_files": total,
			"migrated_files": migrated,
			"remaining_files": remaining,
			"percentage": percentage
		},
		"migrated_by_category": _category_dict_to_counts(migrated_by_category),
		"remaining_by_category": _category_dict_to_counts(remaining_by_category),
		"remaining_files": remaining_by_category,
		"timestamp": Time.get_unix_time_from_system()
	}


## Save report to file
func save_report_to_file(file_path: String) -> bool:
	var report = generate_report()
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create report file: " + str(FileAccess.get_open_error()))
		return false
	
	file.store_string(report)
	file.close()
	return true


## Save JSON report to file
func save_json_report_to_file(file_path: String) -> bool:
	var report = generate_json_report()
	var json_string = JSONHelper.safe_stringify(report, "\t")
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create JSON report file: " + str(FileAccess.get_open_error()))
		return false
	
	file.store_string(json_string)
	file.close()
	return true


## Print report to console
func print_report() -> void:
	print(generate_report())


## Print summary to console
func print_summary() -> void:
	print(generate_summary())


## Generate a visual progress bar
func _generate_progress_bar(percentage: float, width: int = 50) -> String:
	var filled = int((percentage / 100.0) * width)
	var empty = width - filled
	
	var bar = "["
	for i in range(filled):
		bar += "="
	for i in range(empty):
		bar += " "
	bar += "] %.2f%%" % percentage
	
	return bar


## Categorize files by their directory
func _categorize_files(files: Array[String]) -> Dictionary:
	var categories = {}
	
	for file_path in files:
		var category = _get_file_category(file_path)
		if not categories.has(category):
			categories[category] = []
		categories[category].append(file_path)
	
	return categories


## Get category for a file based on its path
func _get_file_category(file_path: String) -> String:
	if file_path.begins_with("game/core/autoload"):
		return "Autoloads"
	elif file_path.begins_with("game/core/services"):
		return "Services"
	elif file_path.begins_with("game/core/systems"):
		return "Subsystems"
	elif file_path.begins_with("game/core/components"):
		return "Core Components"
	elif file_path.begins_with("game/entities/components"):
		return "Entity Components"
	elif file_path.begins_with("game/entities"):
		return "Entities"
	elif file_path.begins_with("game/weapons"):
		return "Weapons"
	elif file_path.begins_with("game/data"):
		return "Data/Config"
	elif file_path.begins_with("game/scripts"):
		return "New Structure (Scripts)"
	elif file_path.begins_with("game/config"):
		return "New Structure (Config)"
	else:
		return "Other"


## Convert category dictionary to counts only
func _category_dict_to_counts(category_dict: Dictionary) -> Dictionary:
	var counts = {}
	for category in category_dict:
		counts[category] = category_dict[category].size()
	return counts


## Get estimated time remaining (based on average migration time)
func estimate_time_remaining(avg_time_per_file: float) -> float:
	var remaining = tracker.get_unmigrated_count()
	return remaining * avg_time_per_file


## Get migration velocity (files per day)
func calculate_migration_velocity(days_elapsed: float) -> float:
	if days_elapsed <= 0:
		return 0.0
	var migrated = tracker.get_migrated_count()
	return migrated / days_elapsed


## Generate a markdown report
func generate_markdown_report() -> String:
	var report = ""
	report += "# Migration Progress Report\n\n"
	
	# Summary
	var total = tracker.get_total_files()
	var migrated = tracker.get_migrated_count()
	var remaining = tracker.get_unmigrated_count()
	var percentage = calculate_percentage()
	
	report += "## Summary\n\n"
	report += "| Metric | Value |\n"
	report += "|--------|-------|\n"
	report += "| Total Files | %d |\n" % total
	report += "| Migrated | %d |\n" % migrated
	report += "| Remaining | %d |\n" % remaining
	report += "| Progress | %.2f%% |\n\n" % percentage
	
	# Progress bar
	report += "## Progress\n\n"
	report += "```\n"
	report += _generate_progress_bar(percentage) + "\n"
	report += "```\n\n"
	
	# Migrated by category
	report += "## Migrated Files by Category\n\n"
	var migrated_by_category = _categorize_files(tracker.get_migrated_files())
	for category in migrated_by_category:
		report += "- **%s**: %d files\n" % [category, migrated_by_category[category].size()]
	report += "\n"
	
	# Remaining by category
	report += "## Remaining Files by Category\n\n"
	var remaining_by_category = _categorize_files(tracker.get_unmigrated_files())
	for category in remaining_by_category:
		report += "- **%s**: %d files\n" % [category, remaining_by_category[category].size()]
	report += "\n"
	
	# Detailed remaining work
	if remaining > 0:
		report += "## Detailed Remaining Work\n\n"
		for category in remaining_by_category:
			report += "### %s (%d files)\n\n" % [category, remaining_by_category[category].size()]
			for file_path in remaining_by_category[category]:
				report += "- `%s`\n" % file_path
			report += "\n"
	
	return report


## Save markdown report to file
func save_markdown_report_to_file(file_path: String) -> bool:
	var report = generate_markdown_report()
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to create markdown report file: " + str(FileAccess.get_open_error()))
		return false
	
	file.store_string(report)
	file.close()
	return true
