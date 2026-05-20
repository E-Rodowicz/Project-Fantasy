extends Node

var items: Dictionary = {
	# ============================================================
	# WEAPONS
	# slot: "weapon" fits either weapon slot
	# ============================================================
	"iron_sword": {
		"id": "iron_sword",
		"name": "Iron Sword",
		"type": "weapon",
		"slot": "weapon",
		"weight": 3.5,
		"value": 50,
		"desc": "Good old iron sword."
	},
	"iron_dagger": {
		"id": "iron_dagger",
		"name": "Iron Dagger",
		"type": "weapon",
		"slot": "weapon",
		"weight": 1.0,
		"value": 20,
		"desc": "Small and fast. Good for a quick stab."
	},
	"wooden_staff": {
		"id": "wooden_staff",
		"name": "Wooden Staff",
		"type": "weapon",
		"slot": "weapon",
		"weight": 2.5,
		"value": 30,
		"desc": "A sturdy walking stick that doubles as a weapon."
	},
	"iron_shield": {
		"id": "iron_shield",
		"name": "Iron Shield",
		"type": "weapon",
		"slot": "weapon",
		"weight": 5.0,
		"value": 40,
		"desc": "Heavy but reliable. Fits either hand."
	},
	# ============================================================
	# ARMOUR - HEAD
	# slot: "head" fits only head slot
	# ============================================================
	"iron_helmet": {
		"id": "iron_helmet",
		"name": "Iron Helmet",
		"type": "armour",
		"slot": "head",
		"weight": 2.0,
		"value": 35,
		"desc": "A solid iron helmet. Dents easily but better than nothing."
	},
	"leather_cap": {
		"id": "leather_cap",
		"name": "Leather Cap",
		"type": "armour",
		"slot": "head",
		"weight": 0.5,
		"value": 15,
		"desc": "Light and comfortable. Minimal protection."
	},
	# ============================================================
	# ARMOUR - AMULET
	# slot: "amulet" fits only amulet slot
	# ============================================================
	"silver_amulet": {
		"id": "silver_amulet",
		"name": "Silver Amulet",
		"type": "armour",
		"slot": "amulet",
		"weight": 0.1,
		"value": 120,
		"desc": "A finely crafted silver amulet. Warm to the touch."
	},
	# ============================================================
	# ARMOUR - SHOULDER
	# slot: "shoulder" fits either shoulder slot
	# ============================================================
	"iron_pauldron": {
		"id": "iron_pauldron",
		"name": "Iron Pauldron",
		"type": "armour",
		"slot": "shoulder",
		"weight": 1.5,
		"value": 25,
		"desc": "A single iron shoulder guard. Fits either shoulder."
	},
	"leather_spaulder": {
		"id": "leather_spaulder",
		"name": "Leather Spaulder",
		"type": "armour",
		"slot": "shoulder",
		"weight": 0.5,
		"value": 12,
		"desc": "Light leather shoulder protection."
	},
	# ============================================================
	# ARMOUR - ARM
	# slot: "arm" fits either arm slot
	# ============================================================
	"iron_vambrace": {
		"id": "iron_vambrace",
		"name": "Iron Vambrace",
		"type": "armour",
		"slot": "arm",
		"weight": 1.0,
		"value": 20,
		"desc": "Iron forearm protection. Fits either arm."
	},
	# ============================================================
	# ARMOUR - HANDS (side specific)
	# slot: "left_hand" or "right_hand"
	# ============================================================
	"left_iron_gauntlet": {
		"id": "left_iron_gauntlet",
		"name": "Left Iron Gauntlet",
		"type": "armour",
		"slot": "left_hand",
		"weight": 0.8,
		"value": 18,
		"desc": "An iron gauntlet for the left hand only."
	},
	"right_iron_gauntlet": {
		"id": "right_iron_gauntlet",
		"name": "Right Iron Gauntlet",
		"type": "armour",
		"slot": "right_hand",
		"weight": 0.8,
		"value": 18,
		"desc": "An iron gauntlet for the right hand only."
	},
	# ============================================================
	# ARMOUR - CHEST
	# slot: "chest" fits only chest slot
	# ============================================================
	"iron_chestplate": {
		"id": "iron_chestplate",
		"name": "Iron Chestplate",
		"type": "armour",
		"slot": "chest",
		"weight": 6.0,
		"value": 80,
		"desc": "Heavy iron chest protection. Slows you down a bit."
	},
	"leather_vest": {
		"id": "leather_vest",
		"name": "Leather Vest",
		"type": "armour",
		"slot": "chest",
		"weight": 2.0,
		"value": 30,
		"desc": "Light and flexible. Good for rogues."
	},
	# ============================================================
	# ARMOUR - CAPE
	# slot: "cape" fits only cape slot
	# ============================================================
	"travellers_cape": {
		"id": "travellers_cape",
		"name": "Traveller's Cape",
		"type": "armour",
		"slot": "cape",
		"weight": 0.5,
		"value": 20,
		"desc": "A worn but warm travelling cape."
	},
	# ============================================================
	# ARMOUR - RINGS
	# slot: "ring" fits either ring slot
	# ============================================================
	"golden_ring": {
		"id": "golden_ring",
		"name": "Golden Ring",
		"type": "armour",
		"slot": "ring",
		"weight": 0.1,
		"value": 300,
		"desc": "Wow, it's shiny. Wow!"
	},
	"iron_ring": {
		"id": "iron_ring",
		"name": "Iron Ring",
		"type": "armour",
		"slot": "ring",
		"weight": 0.1,
		"value": 10,
		"desc": "A plain iron ring. Nothing special."
	},
	# ============================================================
	# ARMOUR - THIGH
	# slot: "thigh" fits either thigh slot
	# ============================================================
	"iron_tasset": {
		"id": "iron_tasset",
		"name": "Iron Tasset",
		"type": "armour",
		"slot": "thigh",
		"weight": 1.5,
		"value": 22,
		"desc": "Iron thigh protection. Fits either leg."
	},
	# ============================================================
	# ARMOUR - CALF
	# slot: "calf" fits either calf slot
	# ============================================================
	"iron_greave": {
		"id": "iron_greave",
		"name": "Iron Greave",
		"type": "armour",
		"slot": "calf",
		"weight": 1.2,
		"value": 18,
		"desc": "Iron lower leg protection. Fits either leg."
	},
	# ============================================================
	# ARMOUR - BOOTS (side specific)
	# slot: "left_boot" or "right_boot"
	# ============================================================
	"left_iron_boot": {
		"id": "left_iron_boot",
		"name": "Left Iron Boot",
		"type": "armour",
		"slot": "left_boot",
		"weight": 1.5,
		"value": 20,
		"desc": "A heavy iron boot for the left foot."
	},
	"right_iron_boot": {
		"id": "right_iron_boot",
		"name": "Right Iron Boot",
		"type": "armour",
		"slot": "right_boot",
		"weight": 1.5,
		"value": 20,
		"desc": "A heavy iron boot for the right foot."
	},
	# ============================================================
	# CONSUMABLES
	# ============================================================
	"health_potion": {
		"id": "health_potion",
		"name": "Health Potion",
		"type": "consumable",
		"slot": "",
		"weight": 0.5,
		"value": 15,
		"desc": "The hurty hurty fixy potion. Restores 20% health."
	},
	"stamina_potion": {
		"id": "stamina_potion",
		"name": "Stamina Potion",
		"type": "consumable",
		"slot": "",
		"weight": 0.5,
		"value": 12,
		"desc": "Restores stamina. Good for long fights."
	},
	# ============================================================
	# MATERIALS
	# ============================================================
	"iron_ore": {
		"id": "iron_ore",
		"name": "Iron Ore",
		"type": "material",
		"slot": "",
		"weight": 2.0,
		"value": 5,
		"desc": "Raw iron ore. Smelt it into bars."
	},
	"iron_bar": {
		"id": "iron_bar",
		"name": "Iron Bar",
		"type": "material",
		"slot": "",
		"weight": 1.5,
		"value": 12,
		"desc": "A smelted iron bar. Used in blacksmithing."
	},
	"wood": {
		"id": "wood",
		"name": "Wood",
		"type": "material",
		"slot": "",
		"weight": 1.0,
		"value": 3,
		"desc": "A piece of wood. Useful for crafting."
	},
	# ============================================================
	# MISC
	# ============================================================
	"old_coin": {
		"id": "old_coin",
		"name": "Old Coin",
		"type": "misc",
		"slot": "",
		"weight": 0.1,
		"value": 3,
		"desc": "A worn coin of unknown origin."
	},
	"strange_key": {
		"id": "strange_key",
		"name": "Strange Key",
		"type": "misc",
		"slot": "",
		"weight": 0.1,
		"value": 0,
		"desc": "A key that doesn't seem to fit anything obvious."
	}
}

# Checks if item exists and returns its duplicate.
func get_item(item_id: String) -> Dictionary:
	if not items.has(item_id):
		push_error("ItemDB: Unknown item ID: " + item_id)
		return {}
	# Allows multiple copies of the same item to exist, as it creates copies instead of using
	# just the declared item as the only item.
	return items[item_id].duplicate()

# Checks if item exists and returns bool.
func item_exists(item_id: String) -> bool:
	return items.has(item_id)
