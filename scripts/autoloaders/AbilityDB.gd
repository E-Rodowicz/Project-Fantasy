extends Node

var abilities: Dictionary = {
	# ------------ RED ------------
	# The warrior-barbarian.
	# ------------ LEVEL 2 ------------
	"charge": {
		"id": "charge",
		"name": "Charge",
		"icon": preload("res://assets/sprites/gui/ability_red_charge.png"),
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
	"cleave": {
		"id": "cleave",
		"name": "Cleave",
		"icon": preload("res://assets/sprites/gui/ability_red_cleave.png"),
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
	# ------------ GREEN ------------
	# The rogue-ninja.
	# ------------ LEVEL 2 ------------
	"blink": {
		"id": "blink",
		"name": "Blink",
		"icon": preload("res://assets/sprites/gui/ability_green_blink.png"),
		"tree": "green",
		"level_req": 2,
		"cost": {"ap": 1, "mp": 3},
		"sp_cost": 3,
		"targeting": "blink",
		"blink_range": 5,
		"damage_percent": 1.5,
		"hit_modifier": 0.0,
		"description": "Teleport near an enemy and strike for 150% damage. Gain 33% dodge on next attack."
		},
	"focus": {
		"id": "focus",
		"name": "Focus",
		"icon": preload("res://assets/sprites/gui/ability_green_focus.png"),
		"tree": "green",
		"level_req": 2,
		"cost": {"ap": 1},
		"sp_cost": 3,
		"targeting": "ranged",
		"penetration": 0,
		"damage_percent": 2.0,
		"crit_chance": 0.10,
		"crit_percent": 5.0,
		"hit_modifier": 0.0,
		"ends_turn": true,
		"description": "Steady aim on a target. Fires a 200% shot at start of next turn. 10% chance for 500% critical."
		},

	# ------------ BLUE ------------
	# The mage-trickster.
	# ------------ LEVEL 2 ------------
	"bolt": {
		"id": "bolt",
		"name": "Bolt",
		"icon": preload("res://assets/sprites/gui/ability_blue_bolt.png"),
		"tree": "blue",
		"level_req": 2,
		"cost": {"bp": 1, "sc": 1},
		"sp_cost": 3,
		"targeting": "line",
		"range_ortho": 3,
		"range_diag": 2,
		"damage_percent": 1.0,
		"hit_modifier": 0.0,
		"bounce_range": 5,
		"max_sc": 6,
		"description": "Fire a bolt of lightning. Bounces between targets with decreasing damage."
		},
	"flametouch": {
		"id": "flametouch",
		"name": "Flametouch",
		"icon": preload("res://assets/sprites/gui/ability_blue_flametouch.png"),
		"tree": "blue",
		"level_req": 2,
		"cost": {"bp": 1, "sc": 1},
		"sp_cost": 3,
		"targeting": "touch",
		"damage_percent": 2.0,
		"hit_modifier": 0.0,
		"max_sc": 8,
		"description": "Touch an opponent, setting them aflame for 200% damage. Applies Fire (1)."
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
		"flametouch":
			instance = FlameTouchAbility.new()
		"bolt":
			instance = BoltAbility.new()
		"blink":
			instance = BlinkAbility.new()
		"focus":
			instance = FocusAbility.new()
	
	if instance != null:
		instance.setup(abilities[ability_id])
	return instance
