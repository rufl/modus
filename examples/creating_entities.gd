extends Node
## Example: Creating Entities in MODUS Framework
##
## This script demonstrates various ways to create and configure entities
## using the MODUS Framework's entity system.

var _log: ExampleLogger = ExampleLogger.new("EntityExamples")


func _ready() -> void:
	_log.info("=== Entity Creation Examples ===\n")
	
	# Wait for services to be ready
	await get_tree().process_frame
	
	example_1_create_simple_entity()
	example_2_create_entity_from_database()
	example_3_create_entity_with_components()
	example_4_create_networked_entity()
	example_5_create_enemy_from_data()


func _exit_tree() -> void:
	# Disconnect all signal connections to prevent memory leaks
	# Note: In example_3, we connect to health and movement signals
	# These are connected to lambda functions, which are automatically cleaned up
	# when the entity is freed. However, if the entity persists, we should track
	# and disconnect these connections.
	pass  # No persistent connections in this example file


## Example 1: Create a Simple Entity
## The most basic way to create an entity with minimal configuration
func example_1_create_simple_entity() -> void:
	print("Example 1: Creating a simple entity")
	
	# Create a basic CharacterBody3D entity
	var entity = CharacterBody3D.new()
	entity.name = "SimpleEntity"
	
	# Add a collision shape
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	collision.shape = shape
	entity.add_child(collision)
	
	# Add a visual representation
	var mesh_instance = MeshInstance3D.new()
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.5
	mesh.height = 2.0
	mesh_instance.mesh = mesh
	entity.add_child(mesh_instance)
	
	# Add to scene
	add_child(entity)
	entity.global_position = Vector3(0, 1, 0)
	
	print("  Created simple entity at ", entity.global_position)
	print()


## Example 2: Create Entity from Database
## Load entity definition from the game database
func example_2_create_entity_from_database() -> void:
	print("Example 2: Creating entity from database")
	
	# Get entity definition from database
	var data_service = GameManager.get_core_system("data")
	var entity_def = data_service.get_entity_definition("enemy_soldier") if data_service else null
	
	if not entity_def:
		print("  Entity definition not found in database")
		print()
		return
	
	# Instantiate the entity scene
	var entity = entity_def.scene.instantiate()
	
	# Configure from definition
	if entity.has_method("configure_from_definition"):
		entity.configure_from_definition(entity_def)
	
	# Add to scene
	add_child(entity)
	entity.global_position = Vector3(5, 0, 0)
	
	print("  Created entity from database: ", entity.name)
	print("  Position: ", entity.global_position)
	print()


## Example 3: Create Entity with Components
## Build an entity by adding components programmatically
func example_3_create_entity_with_components() -> void:
	print("Example 3: Creating entity with components")
	
	# Create base entity
	var entity = CharacterBody3D.new()
	entity.name = "ComponentEntity"
	
	# Add collision
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	collision.shape = shape
	entity.add_child(collision)
	
	# Add health component
	var health = HealthComponent.new()
	health.max_health = 150.0
	health.max_armor = 100.0
	entity.add_child(health)
	
	# Connect to health signals
	health.health_changed.connect(func(current: float, max_health: float):
		print("  Health changed: ", current, "/", max_health)
	)
	
	health.died.connect(func(killer_id: int):
		print("  Entity died! Killer ID: ", killer_id)
	)
	
	# Add movement component
	var movement = MovementComponent.new()
	movement.speed = 5.0
	movement.can_jump = true
	movement.jump_height = 3.0
	entity.add_child(movement)
	
	# Connect to movement signals
	movement.destination_reached.connect(func():
		print("  Destination reached!")
	)
	
	# Add combat component
	var combat = CombatComponent.new()
	combat.attack_damage = 25.0
	combat.attack_range = 10.0
	combat.attack_cooldown = 1.5
	entity.add_child(combat)
	
	# Add to scene
	add_child(entity)
	entity.global_position = Vector3(-5, 0, 0)
	
	print("  Created entity with components:")
	print("    - HealthComponent (HP: ", health.max_health, ")")
	print("    - MovementComponent (Speed: ", movement.speed, ")")
	print("    - CombatComponent (Damage: ", combat.attack_damage, ")")
	print()
	
	# Demonstrate component usage
	await get_tree().create_timer(1.0).timeout
	
	# Test damage
	var damage_info = DamageInfo.new()
	damage_info.base_amount = 50.0
	damage_info.source_id = 0
	damage_info.damage_type = DamageInfo.DamageType.BULLET
	health.take_damage(damage_info)
	
	# Test movement
	movement.set_target_position(Vector3(-5, 0, 10))


## Example 4: Create Networked Entity
## Create an entity that works in multiplayer
func example_4_create_networked_entity() -> void:
	print("Example 4: Creating networked entity")
	
	# Only server should spawn entities in multiplayer
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		print("  Skipping - not server")
		print()
		return
	
	# Create entity
	var entity = CharacterBody3D.new()
	entity.name = "NetworkedEntity"
	
	# Add MultiplayerSynchronizer for state sync
	var sync = MultiplayerSynchronizer.new()
	entity.add_child(sync)
	
	# Configure what to synchronize
	sync.add_property("global_position")
	sync.add_property("rotation")
	
	# Add health component
	var health = HealthComponent.new()
	health.max_health = 100.0
	entity.add_child(health)
	
	# Add to scene
	add_child(entity)
	entity.global_position = Vector3(0, 0, 5)
	
	# Set network authority (server by default)
	entity.set_multiplayer_authority(1)  # Server ID
	
	print("  Created networked entity")
	print("  Authority: ", entity.get_multiplayer_authority())
	print()


## Example 5: Create Enemy from Data
## Use the enemy builder system to create configured enemies
func example_5_create_enemy_from_data() -> void:
	print("Example 5: Creating enemy from data")
	
	# Create enemy data
	var enemy_data = EnemyData.new()
	enemy_data.enemy_type = "soldier"
	enemy_data.health = 100.0
	enemy_data.move_speed = 4.0
	enemy_data.attack_damage = 15.0
	enemy_data.attack_range = 10.0
	enemy_data.attack_cooldown = 2.0
	enemy_data.detection_range = 20.0
	
	# Use enemy builder if available
	if not EnemyBuilder:
		print("  EnemyBuilder not available")
		print()
		return
	
	var enemy = EnemyBuilder.create_enemy(enemy_data)
	
	if enemy:
		add_child(enemy)
		enemy.global_position = Vector3(10, 0, 0)
		
		print("  Created enemy from data:")
		print("    Type: ", enemy_data.enemy_type)
		print("    Health: ", enemy_data.health)
		print("    Speed: ", enemy_data.move_speed)
		print("    Position: ", enemy.global_position)
	else:
		print("  Failed to create enemy")
	
	print()


## Bonus: Entity Factory Pattern
## Create a reusable factory for entity creation
class EntityFactory:
	## Create a basic entity with common components
	func create_basic_entity(entity_name: String, position: Vector3) -> CharacterBody3D:
		var entity = CharacterBody3D.new()
		entity.name = entity_name
		
		# Add collision
		var collision = CollisionShape3D.new()
		var shape = CapsuleShape3D.new()
		collision.shape = shape
		entity.add_child(collision)
		
		# Add visual
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = CapsuleMesh.new()
		entity.add_child(mesh_instance)
		
		# Set position
		entity.global_position = position
		
		return entity
	
	## Create a combat entity with health and combat components
	func create_combat_entity(
		entity_name: String,
		position: Vector3,
		health: float,
		damage: float
	) -> CharacterBody3D:
		var entity = create_basic_entity(entity_name, position)
		
		# Add health
		var health_comp = HealthComponent.new()
		health_comp.max_health = health
		health_comp.current_health = health
		entity.add_child(health_comp)
		
		# Add combat
		var combat_comp = CombatComponent.new()
		combat_comp.attack_damage = damage
		entity.add_child(combat_comp)
		
		return entity
	
	## Create an AI entity with movement and perception
	func create_ai_entity(
		entity_name: String,
		position: Vector3,
		speed: float
	) -> CharacterBody3D:
		var entity = create_basic_entity(entity_name, position)
		
		# Add movement
		var movement = MovementComponent.new()
		movement.speed = speed
		entity.add_child(movement)
		
		# Add perception
		var perception = PerceptionComponent.new()
		entity.add_child(perception)
		
		return entity


## Example usage of EntityFactory
func example_using_factory() -> void:
	print("Bonus: Using EntityFactory")
	
	var factory = EntityFactory.new()
	
	# Create basic entity
	var basic = factory.create_basic_entity("BasicEntity", Vector3(0, 0, -5))
	add_child(basic)
	
	# Create combat entity
	var combat = factory.create_combat_entity(
		"CombatEntity",
		Vector3(5, 0, -5),
		150.0,  # health
		25.0    # damage
	)
	add_child(combat)
	
	# Create AI entity
	var ai = factory.create_ai_entity(
		"AIEntity",
		Vector3(-5, 0, -5),
		4.5  # speed
	)
	add_child(ai)
	
	print("  Created entities using factory pattern")
	print()


## Tips for Entity Creation:
##
## 1. Always add collision shapes before adding to physics space
## 2. Configure components before adding to entity when possible
## 3. Use the database for reusable entity definitions
## 4. Connect to component signals for entity-specific behavior
## 5. Set multiplayer authority before spawning in networked games
## 6. Use factories for commonly created entity types
## 7. Consider object pooling for frequently spawned entities
## 8. Test entity creation in both single-player and multiplayer
