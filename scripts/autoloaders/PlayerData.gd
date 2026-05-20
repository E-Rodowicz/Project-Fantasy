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

# Red (Warrior), Green (Rogue), and Blue (Mage) tree investment
# These store how many points have been put into each tree
var red_points: int = 0
var green_points: int = 0
var blue_points: int = 0

# HP
var max_hp: int = 10
var current_hp: int = 10

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

var gold: int = 0

# ============================================================
# JOURNAL
# Quests are stored here. Each quest is a Dictionary.
# Status can be: "active", "completed", "failed"
# ============================================================
var journal: Dictionary = {}

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
