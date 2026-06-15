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
		"hit_modifier": -0.1,
		"dismember_one_hand": 0.025,
		"dismember_two_hand": 0.05,
		"description": "Attacks in a horizontal line of 4 tiles for 50% damage. Small chance to insta-kill each target."
		},
	"charge": {
		"id": "charge",
		"name": "Charge",
		"tree": "red",
		"level_req": 2,
		"cost": {"ap": 1},
		"sp_cost": 3,
		"targeting": "line",
		"ortho_range": 3,
		"diag_range": 2,
		"path_damage_percent": 0.5,
		"endpoint_damage_percent": 1.0,
		"no_push_damage_percent": 3.0,
		"hit_modifier": 0.0,
		"description": "Charges in a line, hitting targets along the way for 50% damage. Endpoint target takes 100% and is pushed. No room to push? 300% crush damage instead."
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
		"charge":
			instance = ChargeAbility.new()
	
	if instance != null:
		instance.setup(abilities[ability_id])
	return instance
