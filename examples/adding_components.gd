extends Node
## Example: Adding Components to Entities
##
## This script demonstrates various ways to add and configure components
## in the MODUS Framework.

var _log: ExampleLogger = ExampleLogger.new("ComponentExamples")


func _ready() -> void:
	_log.info("=== Component Addition Examples ===\n")
	
	await get_tree().process_frame
	
	example_1_add_component_in_editor()
	example_2_add_component_programmatically()
	example_3_configure_component_from_data()
	example_4_component_communication()
	example_5_dynamic_component_management()
	example_6_custom_component_creation()


func _exit_tree() -> void:
	# Disconnect all signal connections to prevent memory leaks
	# Note: In example_4 and example_6, we connect to component signals
	# These are connected to lambda functions on child entities that get freed,
	# so they're automatically cleaned up when the entities are destroyed.
	# The CustomExampleComponent uses GameManager.subscribe which handles cleanup internally.
	pass  # No persistent connections in this example file


## Example 1: Adding Components in the Editor
## Components can be added through the Godot editor
func example_1_add_component_in_editor() -> void:
	print("Example 1: Adding components in editor")
	print("  1. Select your entity node in the scene tree")
	print("  2. Click 'Attach Child Node' (+)")
	print("  3. Search for component (e.g., 'HealthComponent')")
	print("  4. Configure exported properties in Inspector")
	print("  5. Save the scene")
	print()


## Example 2: Adding Components Programmatically
## Add components through code for dynamic entity creation
func example_2_add_component_programmatically() -> void:
	print("Example 2: Adding components programmatically")
	
	# Create entity
	var entity = CharacterBody3D.new()
	entity.name = "DynamicEntity"
	add_child(entity)
	
	# Method 1: Create and configure before adding
	var health = HealthComponent.new()
	health.max_health = 200.0
	health.max_armor = 150.0
	health.armor_absorption = 0.75
	entity.add_child(health)
	print("  Added HealthComponent with max_health:", health.max_health)
	
	# Method 2: Create, add, then configure
	var movement = MovementComponent.new()
	entity.add_child(movement)
	movement.speed = 6.0
	movement.can_jump = true
	movement.jump_height = 4.0
	print("  Added MovementComponent with speed: ", movement.speed)
	
	# Method 3: Use configuration method
	var combat = CombatComponent.new()
	entity.add_child(combat)
	combat.configure_from_data(30.0, 15.0, 1.0)  # damage, range, cooldown
	print("  Added CombatComponent with damage: ", combat.attack_damage)
	
	print()


## Example 3: Configure Components from Data
## Load component configuration from external data
func example_3_configure_component_from_data() -> void:
	print("Example 3: Configuring components from data")
	
	# Create entity
	var entity = CharacterBody3D.new()
	entity.name = "ConfiguredEntity"
	add_child(entity)
	
	# Example data (could come from JSON, database, etc.)
	var entity_data = {
		"health": {
			"max_health": 150.0,
			"max_armor": 100.0,
			"armor_absorption": 0.66
		},
		"movement": {
			"speed": 5.5,
			"can_jump": true,
			"jump_height": 3.5,
			"can_dash": true,
			"dash_speed": 12.0
		},
		"combat": {
			"damage": 25.0,
			"range": 12.0,
			"cooldown": 1.5
		}
	}
	
	# Add and configure health component
	if "health" in entity_data:
		var health = HealthComponent.new()
		entity.add_child(health)
		
		var health_data = entity_data.health
		health.max_health = health_data.get("max_health", 100.0)
		health.max_armor = health_data.get("max_armor", 0.0)
		health.armor_absorption = health_data.get("armor_absorption", 0.66)
		
		print("  Configured HealthComponent from data")
	
	# Add and configure movement component
	if "movement" in entity_data:
		var movement = MovementComponent.new()
		entity.add_child(movement)
		
		var move_data = entity_data.movement
		movement.speed = move_data.get("speed", 4.0)
		movement.can_jump = move_data.get("can_jump", false)
		movement.jump_height = move_data.get("jump_height", 2.0)
		movement.can_dash = move_data.get("can_dash", false)
		movement.dash_speed = move_data.get("dash_speed", 10.0)
		
		print("  Configured MovementComponent from data")
	
	# Add and configure combat component
	if "combat" in entity_data:
		var combat = CombatComponent.new()
		entity.add_child(combat)
		
		var combat_data = entity_data.combat
		combat.configure_from_data(
			combat_data.get("damage", 10.0),
			combat_data.get("range", 5.0),
			combat_data.get("cooldown", 1.0)
		)
		
		print("  Configured CombatComponent from data")
	
	print()


## Example 4: Component Communication
## Components can communicate through signals and direct calls
func example_4_component_communication() -> void:
	print("Example 4: Component communication")
	
	# Create entity with components
	var entity = CharacterBody3D.new()
	entity.name = "CommunicatingEntity"
	add_child(entity)
	
	# Add health component
	var health = HealthComponent.new()
	health.max_health = 100.0
	entity.add_child(health)
	
	# Add blood impact handler
	var blood_handler = BloodImpactHandler.new()
	blood_handler.enabled = true
	blood_handler.base_intensity = 1.5
	entity.add_child(blood_handler)
	
	# Connect health damage signal to blood handler
	health.damage_received.connect(func(amount: float, source_id: int, type: int):
		print("  Health component received damage: ", amount)
		
		# Trigger blood effect
		if entity is Node3D:
			blood_handler.handle_hit(
				entity.global_position,
				amount,
				Vector3.DOWN
			)
			print("  Blood handler created blood effect")
	)
	
	# Connect health death signal
	health.died.connect(func(killer_id: int):
		print("  Entity died, creating death blood pool")
		if entity is Node3D:
			blood_handler.handle_death(entity.global_position)
	)
	
	# Simulate damage after a delay
	await get_tree().create_timer(1.0).timeout
	var damage_info = DamageInfo.new()
	damage_info.base_amount = 30.0
	damage_info.source_id = 0
	health.take_damage(damage_info)
	
	print()


## Example 5: Dynamic Component Management
## Add and remove components at runtime
func example_5_dynamic_component_management() -> void:
	print("Example 5: Dynamic component management")
	
	# Create entity
	var entity = CharacterBody3D.new()
	entity.name = "DynamicComponentEntity"
	add_child(entity)
	
	# Add initial components
	var health = HealthComponent.new()
	health.name = "HealthComponent"
	entity.add_child(health)
	print("  Added HealthComponent")
	
	# Check if component exists
	var has_health = entity.has_node("HealthComponent")
	print("  Has HealthComponent: ", has_health)
	
	# Get component reference
	var health_ref = entity.get_node_or_null("HealthComponent")
	if health_ref:
		print("  Retrieved HealthComponent reference")
	
	# Add component conditionally
	if not entity.has_node("MovementComponent"):
		var movement = MovementComponent.new()
		movement.name = "MovementComponent"
		entity.add_child(movement)
		print("  Added MovementComponent conditionally")
	
	# Remove component
	await get_tree().create_timer(1.0).timeout
	if entity.has_node("MovementComponent"):
		var movement = entity.get_node("MovementComponent")
		movement.queue_free()
		print("  Removed MovementComponent")
	
	# Replace component
	await get_tree().create_timer(1.0).timeout
	if entity.has_node("HealthComponent"):
		var old_health = entity.get_node("HealthComponent")
		var current_hp = old_health.current_health
		old_health.queue_free()
		
		# Add new health component with upgraded values
		var new_health = HealthComponent.new()
		new_health.name = "HealthComponent"
		new_health.max_health = 200.0  # Upgraded!
		new_health.current_health = current_hp
		entity.add_child(new_health)
		print("  Replaced HealthComponent with upgraded version")
	
	print()


## Example 6: Custom Component Creation
## Create your own custom components
func example_6_custom_component_creation() -> void:
	print("Example 6: Custom component creation")
	
	# Create entity
	var entity = CharacterBody3D.new()
	entity.name = "CustomComponentEntity"
	add_child(entity)
	
	# Add custom component
	var custom = CustomExampleComponent.new()
	custom.custom_value = 42.0
	custom.custom_string = "Hello, Components!"
	entity.add_child(custom)
	
	# Connect to custom component signals
	custom.value_updated.connect(func(new_value: float):
		print("  Custom component value updated: ", new_value)
	)
	
	custom.threshold_reached.connect(func():
		print("  Custom component threshold reached!")
	)
	
	# Use custom component
	await get_tree().create_timer(1.0).timeout
	custom.increment_value(10.0)
	custom.increment_value(50.0)  # Should trigger threshold
	
	print()


## Custom Component Example
## Demonstrates how to create a custom component
class CustomExampleComponent extends GameComponent:
	## Custom component for demonstration
	
	# Signals
	signal value_updated(new_value: float)
	signal threshold_reached
	
	# Exported properties
	@export var custom_value: float = 0.0
	@export var custom_string: String = ""
	@export var threshold: float = 100.0
	
	# Internal state
	var is_active: bool = false
	
	func _ready() -> void:
		# Note: GameComponent doesn't have _ready(), so no super call needed
		initialize()
	
	func initialize() -> void:
		# Setup component
		is_active = true
		print("  CustomExampleComponent initialized")
		
		# Connect to events using safe_connect
		# Note: GameManager doesn't expose signals directly, use subscribe instead
		GameManager.subscribe("game_started", _on_game_started)
	
	func _on_game_started() -> void:
		print("  CustomExampleComponent: Game started")
	
	## Increment the custom value
	func increment_value(amount: float) -> void:
		custom_value += amount
		value_updated.emit(custom_value)
		
		if custom_value >= threshold:
			threshold_reached.emit()
	
	## Reset the custom value
	func reset_value() -> void:
		custom_value = 0.0
		value_updated.emit(custom_value)


## Helper: Component Utility Functions
class ComponentUtils:
	## Get all components of a specific type from an entity
	static func get_components_of_type(entity: Node, component_type: String) -> Array:
		var components: Array = []
		for child in entity.get_children():
			if child.get_class() == component_type:
				components.append(child)
		return components
	
	## Check if entity has component of specific type
	static func has_component_type(entity: Node, component_type: String) -> bool:
		for child in entity.get_children():
			if child.get_class() == component_type:
				return true
		return false
	
	## Get first component of specific type
	static func get_component(entity: Node, component_type: String) -> Node:
		for child in entity.get_children():
			if child.get_class() == component_type:
				return child
		return null
	
	## Remove all components of specific type
	static func remove_components_of_type(entity: Node, component_type: String) -> void:
		for child in entity.get_children():
			if child.get_class() == component_type:
				child.queue_free()


## Example usage of ComponentUtils
func example_using_component_utils() -> void:
	print("Bonus: Using ComponentUtils")
	
	# Create entity with multiple components
	var entity = CharacterBody3D.new()
	add_child(entity)
	
	entity.add_child(HealthComponent.new())
	entity.add_child(MovementComponent.new())
	entity.add_child(CombatComponent.new())
	
	# Check for component
	var has_health = ComponentUtils.has_component_type(entity, "HealthComponent")
	print("  Has HealthComponent: ", has_health)
	
	# Get component
	var health = ComponentUtils.get_component(entity, "HealthComponent")
	if health:
		print("  Retrieved HealthComponent")
	
	# Get all components of type
	var all_components = ComponentUtils.get_components_of_type(entity, "GameComponent")
	print("  Found ", all_components.size(), " GameComponent instances")
	
	print()


## Tips for Adding Components:
##
## 1. Always extend GameComponent for automatic signal cleanup
## 2. Call super._ready() in component _ready() method
## 3. Use safe_connect() for signal connections
## 4. Configure components before adding when possible
## 5. Use descriptive names for components
## 6. Connect to component signals for entity-specific behavior
## 7. Check for component existence before accessing
## 8. Use get_node_or_null() for safe component retrieval
## 9. Consider component dependencies and initialization order
## 10. Test component addition in both editor and runtime
