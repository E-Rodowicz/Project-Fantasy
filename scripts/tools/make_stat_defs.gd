@tool
extends EditorScript

# Run once from the script editor: File → Run (Ctrl+Shift+X). Creates a .tres for each stat with
# its text filled in, and its icon too if the PNG exists. It never overwrites a file that already
# exists, so your colour picks are safe if you run it again.
const FOLDER: String = "res://data/stats/"
const ICON_FOLDER: String = "res://assets/sprites/gui/stats/"

# id, short name, full name, description, is a percentage
const STATS: Array = [
	["strength", "Str", "Strength", "Increases melee damage and carry weight.", false],
	["vitality", "Vit", "Vitality", "Increases max HP and defence.", false],
	["dexterity", "Dex", "Dexterity", "Increases dagger damage and hit chance.", false],
	["speed", "Spd", "Speed", "Increases dodge chance and movement.", false],
	["charisma", "Cha", "Charisma", "Affects NPC interactions and prices.", false],
	["intelligence", "Int", "Intelligence", "Increases magic damage and mana.", false],
	["hp", "HP", "Health Points", "How much damage you can take before dying.", false],
	["mp", "MP", "Movement Points", "", false],
	["bp", "BP", "Bonus Points", "", false],
	["ap", "AP", "Action Points", "", false],
	["damage", "Dmg", "Damage", "Calculated from weapon base damage and relevant stats.", false],
	["defence", "Def", "Defence", "Reduces incoming damage.", false],
	["hit_chance", "Hit", "Hit Chance", "Probability of landing a hit.", true],
	["dodge_chance", "Ddg", "Dodge Chance", "Probability of dodging an attack.", true],
	["fire_res", "Fir", "Fire Resistance", "Reduces fire damage taken.", true],
	["lightning_res", "Lgh", "Lightning Resistance", "Reduces lightning damage taken.", true],
	["ice_res", "Ice", "Ice Resistance", "Reduces ice damage taken.", true],
	["poison_res", "Psn", "Poison Resistance", "Reduces poison damage taken.", true],
]

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	for entry: Array in STATS:
		var path: String = FOLDER + entry[0] + ".tres"
		if ResourceLoader.exists(path):
			continue
		var def: StatDef = StatDef.new()
		def.id = entry[0]
		def.short_name = entry[1]
		def.display_name = entry[2]
		def.description = entry[3]
		def.is_percent = entry[4]
		var icon_path: String = ICON_FOLDER + entry[0] + ".png"
		if ResourceLoader.exists(icon_path):
			def.icon = load(icon_path)
		ResourceSaver.save(def, path)
	# Tells the FileSystem dock to show the new files straight away.
	EditorInterface.get_resource_filesystem().scan()
	print("Stat definitions created in ", FOLDER)
