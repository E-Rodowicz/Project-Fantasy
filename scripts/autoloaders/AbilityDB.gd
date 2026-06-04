extends Node

var abilities: Dictionary = {
	"cleave": {
		"id": "cleave",
		"name": "Cleave",
		"tree": "red",
		"level_req": 2,
		"cost": {"ap": 1},
		"sp_cost": 3,
		"targeting": "direction",
		"range": 3,
		"damage_percent": 0.66,
		"dismember_one_hand": 0.025,
		"dismember_two_hand": 0.05,
		"description": "Attacks in a horizontal line of 4 tiles for 50% damage. Small chance to insta-kill each target."
		},
}

func get_ability(ability_id: String) -> Dictionary:
	if not abilities.has(ability_id):
		push_error("AbilityDB: Unknown Ability: " + ability_id)
		return {}
	return abilities[ability_id]

func create_ability(ability_id: String) -> BaseAbility:
	if not abilities.has(ability_id):
		push_error("AbilityDB: Unknown ability: " + ability_id)
		return null
	
	var instance: BaseAbility = null
	match ability_id:
		"cleave":
			instance = CleaveAbility.new()
	
	if instance != null:
		instance.setup(abilities[ability_id])
	return instance
