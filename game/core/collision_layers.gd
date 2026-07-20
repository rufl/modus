class_name CollisionLayers
extends RefCounted

const LAYER_WORLD: int = 1  # Layer 1
const LAYER_PLAYERS: int = 2  # Layer 2
const LAYER_ENEMIES: int = 4  # Layer 3
const LAYER_PROJECTILES: int = 8  # Layer 4
const LAYER_INTERACTABLES: int = 16  # Layer 5
const LAYER_TRIGGERS: int = 32  # Layer 6
const LAYER_DEBRIS: int = 64  # Layer 7
const MASK_WORLD_ONLY: int = LAYER_WORLD
const MASK_DAMAGEABLE: int = LAYER_PLAYERS | LAYER_ENEMIES
const MASK_HITSCAN: int = LAYER_WORLD | LAYER_PLAYERS | LAYER_ENEMIES | LAYER_DEBRIS
const MASK_PLAYER_HITSCAN: int = LAYER_WORLD | LAYER_ENEMIES | LAYER_DEBRIS
const MASK_ENEMY_HITSCAN: int = LAYER_WORLD | LAYER_PLAYERS
const MASK_EXPLOSION: int = LAYER_PLAYERS | LAYER_ENEMIES | LAYER_DEBRIS
const MASK_INTERACTION: int = LAYER_WORLD | LAYER_INTERACTABLES | LAYER_ENEMIES
const MASK_GRENADE: int = LAYER_WORLD | LAYER_PLAYERS | LAYER_ENEMIES
const MASK_SHELL: int = LAYER_WORLD


static func get_layer_name(layer: int) -> String:
	match layer:
		LAYER_WORLD:
			return "World"
		LAYER_PLAYERS:
			return "Players"
		LAYER_ENEMIES:
			return "Enemies"
		LAYER_PROJECTILES:
			return "Projectiles"
		LAYER_INTERACTABLES:
			return "Interactables"
		LAYER_TRIGGERS:
			return "Triggers"
		LAYER_DEBRIS:
			return "Debris"
		_:
			return "Unknown(%d)" % layer


# Check if a mask contains a specific layer


static func has_layer(mask: int, layer: int) -> bool:
	return (mask & layer) != 0
