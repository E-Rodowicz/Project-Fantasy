extends Node

# Player will set this at the start of the game.
var player_name: String = "Stranger"

# ============================================================
# GENERAL STATS
# These are the core stats of the game which affect combat skills, life skills, and checks.
# They cap naturally at 10 but can go beyond that with items/buffs/etc.
# ============================================================
var strength: int = 1
var vitality: int = 1
var dexterity: int = 1
var speed: int = 1
var charisma: int = 1
var intelligence: int = 1
var luck: int = 1

const NATURAL_STAT_CAP: int = 10

# ============================================================
# COMBAT SKILLS
# Holds what combat level you are and how much XP to next level.
# As to the red, green and blue, it is a representation of Warrrior, Rogue and Mage through
# their traditional colours. I didn't want to commit to class names as I might want to give the
# trees their own prestige classes.
# ============================================================
var combat_level: int = 1
var combat_xp: int = 0
var combat_xp_to_next_level: int = 100

# Skill tree points available to spend on level up
var unspent_skill_points: int = 0
# Starting with 3 for a cheeky testing session.
var unspent_stat_points: int = 3 

# Red (Warrior), Green (Rogue), and Blue (Mage) tree investment
# These store how many points have been put into each tree
var red_points: int = 0
var green_points: int = 0
var blue_points: int = 0

var learned_abilities: Array = []

var max_hp: int = 100
var current_hp: int = 100
var bp_max: int = 10
var ap_max: int = 0
# Spell Charges. Per-ability charge pools for blue tree spells.
# Key: ability_id (String), Value: current charges remaining (int).
var spell_charges: Dictionary = {}
# Status effects active on the player.
# Key: effect_id (String), Value: number of stacks (int).
var status_effects: Dictionary = {}
var mp_override: int = -1

const BASE_MP: int = 5
const MP_PER_SPEED_PER_LEVEL: float = 0.25

# ============================================================
# LIFE SKILLS
# Each has a level and an XP value.
# Levelling is use-based, unlike combat which has player choice.
# The skills are in a dictionary, each skill holding
# another dictionary inside it with the stats info.
# ============================================================
var life_skills: Dictionary = {
	"mining":        {"level": 1, "xp": 0, "xp_to_next": 100},
	"blacksmithing": {"level": 1, "xp": 0, "xp_to_next": 100},
	"fishing":       {"level": 1, "xp": 0, "xp_to_next": 100},
	"cooking":       {"level": 1, "xp": 0, "xp_to_next": 100},
	"foraging":      {"level": 1, "xp": 0, "xp_to_next": 100},
	"alchemy":       {"level": 1, "xp": 0, "xp_to_next": 100},
	"stealth":       {"level": 1, "xp": 0, "xp_to_next": 100},
	"lockpicking":   {"level": 1, "xp": 0, "xp_to_next": 100},
	"pickpocketing": {"level": 1, "xp": 0, "xp_to_next": 100},
}

const LIFE_SKILL_MAX_LEVEL: int = 50

# ============================================================
# INVENTORY
# Each item is a Dictionary with its properties.
# Total weight is checked against max_carry_weight.
# ============================================================
var inventory: Array = []
var max_carry_weight: float = 50.0
var equipped_items: Dictionary = {}
var gold: int = 0

# ============================================================
# JOURNAL
# Quests are stored here. Each quest is a Dictionary.
# Status can be: "active", "completed", "failed"
# ============================================================
var journal: Dictionary = {}

func _ready() -> void:
	learn_ability("cleave")
	hotbar[1] = "cleave"
	learn_ability("charge")
	hotbar[2] = "charge"
	learn_ability("flametouch")
	hotbar[3] = "flametouch"
	learn_ability("bolt")
	hotbar[4] = "bolt"
	learn_ability("blink")
	hotbar[5] = "blink"
	ap_max = 3
	add_quest({
		"id": "imp_in_attic",
		"title": "The Imp in the Attic",
		"status": "active",
		"description": "Gary the innkeeper has an imp living in his attic and wants it gone. He mentioned it came in through a broken window on the east side of the building. Worth checking there first."
	})
	add_quest({
		"id": "missing_shipment",
		"title": "The Missing Shipment",
		"status": "active",
		"description": "A merchant's supply cart never arrived from Dawnfield. Last seen heading through the Ashwood road. Could be bandits, could be worse."
	})
	add_quest({
		"id": "old_debts",
		"title": "Old Debts",
		"status": "completed",
		"description": "Recovered the stolen ledger for the moneylender. He paid up, though he didn't look happy about it."
	})
	add_quest({
		"id": "rat_problem",
		"title": "A Rat Problem",
		"status": "failed",
		"description": "The baker's cellar was overrun. You took too long — he hired someone else and made his feelings very clear."
	})

func get_equipped_weapon() -> Dictionary:
	var right: Dictionary = equipped_items.get("slot_right_weapon", {})
	var left: Dictionary = equipped_items.get("slot_left_weapon", {})
	
	# Return the first actual weapon found, skip shields.
	if not right.is_empty() and right.get("type") == "weapon":
		return right
	if not left.is_empty() and left.get("type") == "weapon":
		return left
	return {}
	
func get_equipped_shield() -> Dictionary:
	var right: Dictionary = equipped_items.get("slot_right_weapon", {})
	var left: Dictionary = equipped_items.get("slot_left_weapon", {})

	if not right.is_empty() and right.get("type") == "shield":
		return right
	if not left.is_empty() and left.get("type") == "shield":
		return left
	return {}
	
func is_dual_wielding() -> bool:
	var right: Dictionary = equipped_items.get("slot_right_weapon", {})
	var left: Dictionary = equipped_items.get("slot_left_weapon", {})
	return right.get("type") == "weapon" and left.get("type") == "weapon"
	
func get_offhand_weapon() -> Dictionary:
	var right: Dictionary = equipped_items.get("slot_right_weapon", {})
	var left: Dictionary = equipped_items.get("slot_left_weapon", {})
	
	# get_equipped_weapon() returns right first, so off-hand is left.
	if not right.is_empty() and right.get("type") == "weapon":
		if not left.is_empty() and left.get("type") == "weapon":
			return left
	return {}
	
# This is just so that stats can be easily passed onto ItemDB to calculate weapon damage.
func get_stats_dict() -> Dictionary:
	return {
		"strength": strength,
		"vitality": vitality,
		"dexterity": dexterity,
		"speed": speed,
		"charisma": charisma,
		"intelligence": intelligence,
	}

# ============================================================
# FUNCTIONS - COMBAT XP & LEVELLING
# ============================================================
func add_combat_xp(amount: int) -> void:
	combat_xp += amount
	while combat_xp >= combat_xp_to_next_level:
		_level_up_combat()

func _level_up_combat() -> void:
	combat_xp -= combat_xp_to_next_level
	combat_level += 1
	unspent_skill_points += 5
	# XP required increases each level
	combat_xp_to_next_level = int(combat_xp_to_next_level * 1.2)
	print("COMBAT level up! Now level: ", combat_level)

# ============================================================
# FUNCTIONS - LIFE SKILL XP & LEVELLING
# ============================================================
func add_life_skill_xp(skill_name: String, amount: int) -> void:
	if not life_skills.has(skill_name):
		print("Unknown skill: ", skill_name)
		return
	
	var skill = life_skills[skill_name]
	if skill["level"] >= LIFE_SKILL_MAX_LEVEL:
		return
	
	skill["xp"] += amount
	while skill["xp"] >= skill["xp_to_next"] and skill["level"] < LIFE_SKILL_MAX_LEVEL:
		_level_up_life_skill(skill_name)

func _level_up_life_skill(skill_name: String) -> void:
	var skill = life_skills[skill_name]
	skill["xp"] -= skill["xp_to_next"]
	skill["level"] += 1
	skill["xp_to_next"] = int(skill["xp_to_next"] * 1.2)
	print(skill_name, " levelled up! Now level: ", skill["level"])

func get_life_skill_level(skill_name: String) -> int:
	if life_skills.has(skill_name):
		return life_skills[skill_name]["level"]
	return 0

# ============================================================
# FUNCTIONS - STATS
# These return the effective stat value including bonuses
# from items, buffs etc. beyond the natural cap.
# ============================================================
func get_stat(stat_name: String) -> int:
	match stat_name:
		"strength":     return strength
		"vitality":     return vitality
		"dexterity":    return dexterity
		"speed":        return speed
		"charisma":     return charisma
		"intelligence": return intelligence
		"luck":         return luck
	return 0

# ============================================================
# FUNCTIONS - INVENTORY
# ============================================================
func add_item(item: Dictionary) -> bool:
	var total_weight = get_total_weight()
	if total_weight + item.get("weight", 0) > max_carry_weight:
		print("Cannot carry that - too heavy")
		return false
	inventory.append(item)
	return true

func remove_item(item: Dictionary) -> void:
	inventory.erase(item)

func get_total_weight() -> float:
	var total: float = 0.0
	for item in inventory:
		total += item.get("weight", 0)
	return total

# ============================================================
# FUNCTIONS - JOURNAL
# ============================================================
func add_quest(quest: Dictionary) -> void:
	journal[quest["id"]] = quest

func update_quest_status(quest_id: String, status: String) -> void:
	if journal.has(quest_id):
		journal[quest_id]["status"] = status

func get_active_quests() -> Array:
	var active = []
	for quest in journal.values():
		if quest.get("status") == "active":
			active.append(quest)
	return active

# ============================================================
# FUNCTIONS - HP
# ============================================================
func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	if current_hp == 0:
		print("Player died.")

func heal(amount: int) -> void:
	current_hp = min(max_hp, current_hp + amount)
	
# ============================================================
# FUNCTIONS - MP
# ============================================================
func get_max_mp() -> int:
	if mp_override >= 0:
		return mp_override
	# Formula for MP amount.
	var gained: int = int(speed * MP_PER_SPEED_PER_LEVEL * (combat_level - 1))
	return BASE_MP + gained
	
# ============================================================
# FUNCTIONS - ABILITIES
# ============================================================
func has_ability(ability_id: String) -> bool:
	return ability_id in learned_abilities
	
func learn_ability(ability_id: String) -> void:
	if ability_id not in learned_abilities:
		learned_abilities.append(ability_id)
		# The lines below add SC to specific spells when the abilties are acquired.
		var ability: Dictionary = AbilityDB.get_ability(ability_id)
		var max_sc: int = ability.get("max_sc", 0)
		if max_sc > 0:
			spell_charges[ability_id] = max_sc
		
# ============================================================
# HOTBAR
# 10 slots: index 0 = key 1 (locked to basic attack), index 1-9 = keys 2-0.
# Each slot holds an ability ID string, or "" if empty.
# "basic_attack" is a special ID meaning the built-in melee attack mode.
# ============================================================
var hotbar: Array = ["basic_attack", "", "", "", "", "", "", "", "", ""]

func assign_hotbar(slot: int, ability_id: String) -> void:
	if slot == 0:
		return
	# If the ability is on this slot, return.
	if hotbar[slot] == ability_id:
		hotbar[slot] = ""
		return
	# Removes the ability from its current slot (if its on any slot) then prevents the ability from
	# appearing on two slots at once.
	for i in range(hotbar.size()):
		if hotbar[i] == ability_id:
			hotbar[i] = ""
	# Places it on requested slot.
	hotbar[slot] = ability_id
	
func get_hotbar_ability(slot: int) -> String:
	if slot < 0 or slot >= hotbar.size():
		return ""
	return hotbar[slot]

func get_hotbar_slot_from_event(event: InputEvent) -> int:
	var action_map: Array = [
		"ability_1", "ability_2", "ability_3", "ability_4", "ability_5",
		"ability_6", "ability_7", "ability_8", "ability_9", "ability_0"
	]
	for i in range(action_map.size()):
		if event.is_action_pressed(action_map[i]) and not event.is_echo():
			return i
	return -1
	
# ============================================================
# FUNCTIONS - SPELL CHARGES
# ============================================================
func get_spell_charges(ability_id: String) -> int:
	if not spell_charges.has(ability_id):
		return 0
	return spell_charges[ability_id]

func use_spell_charge(ability_id: String) -> void:
	if spell_charges.has(ability_id) and spell_charges[ability_id] > 0:
		spell_charges[ability_id] -= 1
		
func restore_spell_charges(ability_id: String) -> void:
	var ability: Dictionary = AbilityDB.get_ability(ability_id)
	spell_charges[ability_id] = ability.get("max_sc", 0)
	
func restore_all_spell_charges() -> void:
	for ability_id in spell_charges.keys():
		restore_spell_charges(ability_id)

# ============================================================
# FUNCTIONS - STATUS EFFECTS
# ============================================================
func get_status_stacks(effect_id: String) -> int:
	return status_effects.get(effect_id, 0)
	
func add_status_effect(effect_id: String, stacks: int) -> void:
	status_effects[effect_id] = status_effects.get(effect_id, 0) + stacks
	
func remove_status_stacks(effect_id: String, amount: int) -> void:
	if status_effects.has(effect_id):
		status_effects[effect_id] -= amount
		if status_effects[effect_id] <= 0:
			status_effects.erase(effect_id)
			
func clear_status_effects() -> void:
	status_effects.clear()
