extends Resource
class_name CombatantStats

@export var character_name: String = "Unknown"

# Core stats
@export_group("Core Stats")
@export var strength: int = 1
@export var vitality: int = 1
@export var dexterity: int = 1
@export var speed: int = 1
@export var charisma: int = 1
@export var intelligence: int = 1

# Level
@export_group("Progression")
@export var level: int = 1

# Overrides
@export_group("Overrides")
@export var override_hp: bool = false
@export var custom_hp: int = 10

@export var override_movement_points: bool = false
@export var custom_movement_points: int = 5

@export var override_dodge_chance: bool = false
@export var custom_dodge_chance: float = 0.05

# Behaviour
@export_group("Behaviour")
@export_enum("melee", "ranged", "caster", "support") var behaviour: String = "melee"

@export_group("Combat")
@export var base_damage_min: int = 3
@export var base_damage_max: int = 5

# Derived stats
func get_max_hp() -> int:
	if override_hp:
		return custom_hp
	return 2 * vitality * level

func get_movement_points() -> int:
	if override_movement_points:
		return custom_movement_points
	var earned: float = 0.25 * speed * level
	return 5 + int(earned)

func get_dodge_chance() -> float:
	if override_dodge_chance:
		return custom_dodge_chance
	return 0.05 * dexterity

func get_hit_chance(target_dodge: float) -> float:
	return 1.0 - target_dodge
	
