extends ModusGutTestBase

## Unit tests for MapGenerator seed-based deterministic RNG system
## Tests Requirements 16.1, 16.2, 16.3, 16.5, 1.3, 1.5

const MapGeneratorScript: GDScript = preload("res://game/scripts/map_generator/map_generator.gd")
var map_generator: Node

func before_each() -> void:
	map_generator = MapGeneratorScript.new()
	add_child_autofree(map_generator)

func after_each() -> void:
	if map_generator:
		map_generator.cancel_generation()
		map_generator = null

## Test that hash_seed() produces consistent 64-bit integers from strings
func test_hash_seed_produces_consistent_output() -> void:
	var seed_str := "test_seed_123"
	var hash1: int = map_generator.hash_seed(seed_str)
	var hash2: int = map_generator.hash_seed(seed_str)
	
	assert_eq(hash1, hash2, "Same seed string should produce identical hash values")
	assert_is_int(hash1, "Hash should be an integer")

## Test that different seeds produce different hashes
func test_different_seeds_produce_different_hashes() -> void:
	var seed1 := "seed_one"
	var seed2 := "seed_two"
	
	var hash1: int = map_generator.hash_seed(seed1)
	var hash2: int = map_generator.hash_seed(seed2)
	
	assert_ne(hash1, hash2, "Different seed strings should produce different hash values")

## Test that empty seed generates random seed from time
func test_empty_seed_uses_time_based_seed() -> void:
	var config := GenerationConfig.new()
	
	# Generate with empty seed
	map_generator.generate_map("", config)
	await get_tree().process_frame
	
	var context: Variant = map_generator.generation_context
	assert_not_null(context, "Generation context should be created")
	assert_is_int(context.seed_hash, "Seed hash should be an integer")
	assert_ne(context.seed_hash, 0, "Seed hash should not be zero")

## Test that RNG is initialized with hashed seed in GenerationContext
func test_rng_initialized_in_context() -> void:
	var config := GenerationConfig.new()
	var seed_str := "deterministic_seed"
	
	map_generator.generate_map(seed_str, config)
	await get_tree().process_frame
	
	var context: Variant = map_generator.generation_context
	assert_not_null(context, "Generation context should be created")
	assert_not_null(context.rng, "RNG should be initialized in context")
	
	var expected_hash: int = map_generator.hash_seed(seed_str)
	assert_eq(context.seed_hash, expected_hash, "Context should store the hashed seed")
	assert_eq(context.rng.seed, expected_hash, "RNG should be seeded with hashed value")

## Test that MapGenerator's RNG is also initialized with same seed
func test_map_generator_rng_initialized() -> void:
	var config := GenerationConfig.new()
	var seed_str := "test_rng_sync"
	
	map_generator.generate_map(seed_str, config)
	await get_tree().process_frame
	
	var expected_hash: int = map_generator.hash_seed(seed_str)
	assert_eq(
		map_generator.rng.seed,
		expected_hash,
		"MapGenerator RNG should be seeded with same hash"
	)

## Test deterministic generation property: same seed produces same RNG sequence
func test_deterministic_rng_sequence() -> void:
	var seed_str := "deterministic_test"
	var expected_hash: int = map_generator.hash_seed(seed_str)
	
	# First generation
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = expected_hash
	var sequence1 := []
	for i in range(10):
		sequence1.append(rng1.randi())
	
	# Second generation with same seed
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = expected_hash
	var sequence2 := []
	for i in range(10):
		sequence2.append(rng2.randi())
	
	assert_eq(sequence1, sequence2, "Same seed should produce identical RNG sequences")

## Test that hash function handles various string inputs
func test_hash_seed_handles_various_inputs() -> void:
	var test_cases := [
		"simple",
		"with spaces",
		"with-dashes-and_underscores",
		"123456789",
		"MixedCaseString",
		"special!@#$%^&*()",
		"very_long_seed_string_that_contains_many_characters_to_test_hashing_behavior"
	]
	
	for seed_str in test_cases:
		var hash: int = map_generator.hash_seed(seed_str)
		assert_is_int(hash, "Hash should be integer for seed: %s" % seed_str)
		assert_ne(hash, 0, "Hash should not be zero for seed: %s" % seed_str)

## Test that RNG is used consistently across generation context
func test_rng_consistency_in_context() -> void:
	var config := GenerationConfig.new()
	var seed_str := "consistency_test"
	
	map_generator.generate_map(seed_str, config)
	await get_tree().process_frame
	
	var context: Variant = map_generator.generation_context
	
	# Generate some random numbers from context RNG
	var num1: int = context.rng.randi()
	var num2: float = context.rng.randf()
	
	assert_is_int(num1, "RNG should generate integers")
	assert_is_float(num2, "RNG should generate floats")
	
	# Verify RNG state is maintained
	var num3: int = context.rng.randi()
	assert_ne(num1, num3, "RNG should produce different values in sequence")
