@tool
extends EditorScript


# Helper function to safely log messages
func _log(message: String, category: String = "Game") -> void:
	var logger: Node = GameManager.get_core_system("logger")
	if logger and logger.has_method("info"):
		logger.info(message, category)
	else:
		print("[%s] %s" % [category, message])


## Quick test script to verify blood pool shader setup
## Run this from the Godot editor: File > Run Script


func _run():
	_log("=== Blood Pool Shader Test ===", "Log")

	# Check if shader file exists
	var shader_path = "res://shared/shaders/blood_pool.gdshader"
	if ResourceLoader.exists(shader_path):
		_log("✓ Shader file found: " + " " + str(shader_path), "Log")
	else:
		_log("✗ Shader file NOT found: " + " " + str(shader_path), "Log")
		return

	# Check if script file exists
	var script_path = "res://shared/shaders/blood_pool.gd"
	if ResourceLoader.exists(script_path):
		_log("✓ Script file found: " + " " + str(script_path), "Log")
	else:
		_log("✗ Script file NOT found: " + " " + str(script_path), "Log")
		return

	# Check if demo scene exists
	var demo_path = "res://shared/shaders/blood_pool_complete_demo.tscn"
	if ResourceLoader.exists(demo_path):
		_log("✓ Demo scene found: " + " " + str(demo_path), "Log")
		_log("\nTo test the shader:", "Log")
		_log("1. Open: " + " " + str(demo_path), "Log")
		_log("2. Press F6 to run the scene", "Log")
		_log("3. Left-click to spawn blood drops", "Log")
		_log("4. Right-click and drag to create trails", "Log")
	else:
		_log("✗ Demo scene NOT found: " + " " + str(demo_path), "Log")

	_log("\n=== Setup Instructions ===", "Log")
	_log("1. Add a MeshInstance3D with PlaneMesh to your scene", "Log")
	_log("2. Attach blood_pool.gd script", "Log")
	_log("3. Create ShaderMaterial with blood_pool.gdshader", "Log")
	_log("4. Generate blood texture using BloodTextureGenerator", "Log")
	_log("5. Call blood_pool.drop_at(Vector2(x, y)) to spawn blood", "Log")

	_log("\n=== Test Complete ===", "Log")
