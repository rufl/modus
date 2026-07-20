extends SceneTree

## Simple test for MagicNumberDetector

func _init() -> void:
	print("=== Testing MagicNumberDetector ===\n")
	
	# Create test file
	var test_file := "res://test_simple_magic.gd"
	var content := """extends Node

var health: int = 100
var damage: float = 25.5
var name: String = "Player"
"""
	
	var file := FileAccess.open(test_file, FileAccess.WRITE)
	file.store_string(content)
	file.close()
	
	# Load and test detector
	var MagicNumberDetector = load("res://tools/analyzer/magic_number_detector.gd")
	var detector = MagicNumberDetector.new()
	
	var result = detector.analyze_script(test_file)
	
	print("File analyzed: ", result.file_path)
	print("Magic numbers found: ", result.magic_numbers.size())
	
	for magic in result.magic_numbers:
		print("  - Type: ", magic.value_type, ", Value: ", magic.value, ", Line: ", magic.line_number)
	
	# Generate report
	print("\n" + detector.generate_report([result]))
	
	# Cleanup
	DirAccess.remove_absolute(test_file)
	
	print("\n=== Test Complete ===")
	quit()
