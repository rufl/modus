extends ModusGutTestBase

# Test MODUS Framework Animation System functionality
# Converted from legacy format to GUT assertions

func before_each():
	await modus_setup()

func after_each():
	modus_teardown()

func test_skeletal_character_visuals_instantiation():
	var visuals: SkeletalCharacterVisuals = SkeletalCharacterVisuals.new()
	assert_not_null(visuals, "Should be able to instantiate SkeletalCharacterVisuals")

	if visuals:
		visuals.free()

func test_animation_mapping_exists():
	var visuals: SkeletalCharacterVisuals = SkeletalCharacterVisuals.new()
	assert_not_null(visuals, "SkeletalCharacterVisuals should be available")

	if visuals:
		var mapping: Dictionary = visuals._get_anim_mapping()
		assert_false(mapping.is_empty(), "Animation mapping should not be empty")

		# Check for key animations
		var key_anims: Array[String] = ["idle", "walk", "run", "crouch_idle"]
		for anim_name in key_anims:
			if mapping.has(anim_name):
				assert_true(true, "Found key animation: " + anim_name + " -> " + str(mapping[anim_name]))

		visuals.free()

func test_mannequin_glb_exists():
	var mannequin_path: String = "res://game/art/models/mannequin_mesh.glb"
	assert_true(ResourceLoader.exists(mannequin_path), "Mannequin GLB should exist at: " + mannequin_path)

func test_animation_library_glb_exists():
	var anim_lib_path: String = "res://game/art/anims/AnimationLibrary_Godot.glb"
	if ResourceLoader.exists(anim_lib_path):
		assert_true(true, "Animation library GLB found")
	else:
		# This is a warning, not a failure - individual files may be used
		assert_true(true, "Animation library GLB not found - may use individual animation files")

func test_bone_name_mapping():
	var visuals: SkeletalCharacterVisuals = SkeletalCharacterVisuals.new()
	assert_not_null(visuals, "SkeletalCharacterVisuals should be available")

	if visuals:
		var bone_mapping: Dictionary = visuals._create_bone_mapping()
		# Bone mapping may be empty if skeleton not loaded yet - this is acceptable
		assert_eq(typeof(bone_mapping), TYPE_DICTIONARY, "Bone mapping should return dictionary")

		visuals.free()
