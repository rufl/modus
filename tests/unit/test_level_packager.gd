extends ModusGutTestBase

const LevelPackagerScript = preload("res://shared/editor_core/data/level_packager.gd")


func test_package_rejects_manifest_paths_outside_package() -> void:
	var level := Node3D.new()
	add_child_autofree(level)

	var traversal_manifest := LevelPackagerScript.LevelManifest.new()
	traversal_manifest.id = "path_traversal"
	traversal_manifest.name = "Path Traversal"
	traversal_manifest.level_file = "../outside/level.tscn"
	traversal_manifest.thumbnail = "thumbnail.png"
	var traversal_result := LevelPackagerScript.package_level(
		level, "user://level_packager_regressions/", traversal_manifest
	)
	assert_false(traversal_result.success, "Traversal paths must not be packaged")
	assert_true(
		"relative package files" in traversal_result.error_msg,
		"Traversal rejection should explain that manifest files must stay relative"
	)

	var absolute_manifest := LevelPackagerScript.LevelManifest.new()
	absolute_manifest.id = "absolute_path"
	absolute_manifest.name = "Absolute Path"
	absolute_manifest.level_file = "/tmp/outside/level.tscn"
	absolute_manifest.thumbnail = "thumbnail.png"
	var absolute_result := LevelPackagerScript.package_level(
		level, "user://level_packager_regressions/", absolute_manifest
	)
	assert_false(absolute_result.success, "Absolute paths must not be packaged")
	assert_true(
		"relative package files" in absolute_result.error_msg,
		"Absolute-path rejection should explain that manifest files must stay relative"
	)


func test_package_rejects_manifest_file_collision() -> void:
	var level := Node3D.new()
	add_child_autofree(level)
	var manifest := LevelPackagerScript.LevelManifest.new()
	manifest.id = "manifest_collision"
	manifest.name = "Manifest Collision"
	manifest.level_file = "manifest.json"
	manifest.thumbnail = "thumbnail.png"

	var result := LevelPackagerScript.package_level(
		level, "user://level_packager_regressions/", manifest
	)

	assert_false(result.success, "A level must not replace the package manifest")
	assert_true(
		"cannot replace manifest.json" in result.error_msg,
		"Manifest collision should be reported to the package caller"
	)


func test_package_rejects_level_and_thumbnail_collision() -> void:
	var level := Node3D.new()
	add_child_autofree(level)
	var manifest := LevelPackagerScript.LevelManifest.new()
	manifest.id = "level_thumbnail_collision"
	manifest.name = "Level Thumbnail Collision"
	manifest.level_file = "content/shared.bin"
	manifest.thumbnail = "content/shared.bin"

	var result := LevelPackagerScript.package_level(
		level, "user://level_packager_regressions/", manifest
	)

	assert_false(result.success, "Level and thumbnail must occupy distinct package files")
	assert_true(
		"level_file and thumbnail must differ" in result.error_msg,
		"Level/thumbnail collision should be reported to the package caller"
	)
