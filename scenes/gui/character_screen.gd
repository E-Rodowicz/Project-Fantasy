extends Control

@onready var combat_tabs = $combat_tabs
@onready var combat_skill_tree = $combat_skill_tree
@onready var info_panel = $info_panel
@onready var general_stats = $general_stats

# Combat tab labels
@onready var tab_red = $combat_tabs/tab_red
@onready var tab_green = $combat_tabs/tab_green
@onready var tab_blue = $combat_tabs/tab_blue

# Info panel
@onready var info_title = $info_panel/info_title
@onready var info_desc = $info_panel/info_desc
@onready var info_bonus = $info_panel/info_bonus

# This dictionary stores all stat descriptions.
const STAT_INFO: Dictionary = {
	"stat_name": ["Name", "Your character's name.", ""],
	"stat_level": ["Level", "Your current combat level.", ""],
	"stat_xp": ["Experience", "Progress toward your next combat level.", ""],
	"stat_hp": ["Health Points", "How much damage you can take before dying.", ""],
	"stat_strength": ["Strength", "Increases melee damage and carry weight.", "Levelable"],
	"stat_vitality": ["Vitality", "Increases max HP and defence.", "Levelable"],
	"stat_dexterity": ["Dexterity", "Increases dagger damage and hit chance.", "Levelable"],
	"stat_speed": ["Speed", "Increases dodge chance and movement.", "Levelable"],
	"stat_charisma": ["Charisma", "Affects NPC interactions and prices.", "Levelable"],
	"stat_intelligence": ["Intelligence", "Increases magic damage and mana.", "Levelable"],
	"stat_luck": ["Luck", "Affects critical hits and rare drops.", "Levelable"],
	"stat_carry_weight": ["Carry Weight", "How much you can carry before being overencumbered.", ""],
	"stat_gold": ["Gold", "Your current gold.", ""],
	"stat_damage": ["Damage", "Calculated from weapon base damage and relevant stats.", ""],
	"stat_defence": ["Defence", "Reduces incoming damage.", ""],
	"stat_hit_chance": ["Hit Chance", "Probability of landing a hit.", ""],
	"stat_dodge_chance": ["Dodge Chance", "Probability of dodging an attack.", ""],
	"stat_fire_res": ["Fire Resistance", "Reduces fire damage taken.", ""],
	"stat_lightning_res": ["Lightning Resistance", "Reduces lightning damage taken.", ""],
	"stat_ice_res": ["Ice Resistance", "Reduces ice damage taken.", ""],
	"stat_poison_res": ["Poison Resistance", "Reduces poison damage taken.", ""],
	}

enum State {
	PANEL_SELECT,
	COMBAT_TABS_ACTIVE,
	SKILL_TREE_ACTIVE,
	GENERAL_STATS_ACTIVE
}

var current_state: State = State.PANEL_SELECT
# 0 = combat, 1 = general stats.
var selected_panel: int = 0  

# Combat
var combat_tabs_list: Array = []
var selected_combat_tab: int = 0

# Skill tree
var skill_nodes: Array = []
var selected_skill_node: int = 0
var current_tree_abilities: Array = []

# General stats navigation
var stat_rows: Array = []
var selected_stat_row: int = 0
var selected_stat_col: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Gets saved panel state from menu manager.
	selected_panel = GameMenuManager.saved_character_panel
	
	combat_tabs_list = [tab_red, tab_green, tab_blue]
	
	# For now this only gets the empty buttons for the skill tree - this will let me add and remove
	# skills without further programming as its not harcoded.
	for child in combat_skill_tree.get_children():
		if child is Button:
			skill_nodes.append(child)
			
	combat_skill_tree.visible = false
	info_panel.visible = false
	
	_enter_panel_select()
	_update_general_stats_display()
	
	# Each stat is an array so that later I can add another stat, so  that they sit side by side
	# (For example XP, you would want currentXP / XP to next level).
	stat_rows = [
	[$general_stats/stat_name],
	[$general_stats/stat_level],
	[$general_stats/stat_xp],
	[$general_stats/stat_hp],
	[$general_stats/stat_strength],
	[$general_stats/stat_vitality],
	[$general_stats/stat_dexterity],
	[$general_stats/stat_speed],
	[$general_stats/stat_charisma],
	[$general_stats/stat_intelligence],
	[$general_stats/stat_luck],
	[$general_stats/stat_carry_weight],
	[$general_stats/stat_gold],
	[$general_stats/stat_damage],
	[$general_stats/stat_defence],
	[$general_stats/stat_hit_chance],
	[$general_stats/stat_dodge_chance],
	[$general_stats/stat_fire_res],
	[$general_stats/stat_lightning_res],
	[$general_stats/stat_ice_res],
	[$general_stats/stat_poison_res],
]

# These determine what happens when you enter different screens on the character screen.
func _enter_panel_select() -> void:
	current_state = State.PANEL_SELECT
	combat_skill_tree.visible = false
	info_panel.visible = false
	_clear_info_panel()
	_highlight_panel_select()

func _enter_combat_tabs_active(from_back: bool = false) -> void:
	current_state = State.COMBAT_TABS_ACTIVE
	if not from_back:
		selected_combat_tab = 0
	info_panel.visible = true
	_update_combat_tab_highlight()
	_update_info_panel_from_combat_tab()

func _enter_skill_tree_active(from_back: bool = false) -> void:
	current_state = State.SKILL_TREE_ACTIVE
	if not from_back:
		selected_skill_node = 0
	combat_skill_tree.visible = true
	_populate_skill_tree()
	_update_skill_node_highlight()
	_update_info_panel_from_skill_node()

func _enter_general_stats_active(from_back: bool = false) -> void:
	_update_general_stats_display()
	current_state = State.GENERAL_STATS_ACTIVE
	if not from_back:
		selected_stat_row = 0
		selected_stat_col = 0
	info_panel.visible = true
	_update_stat_highlight()
	_update_info_panel_from_stat()

# Fabolous highlihts for the panels.
func _highlight_panel_select() -> void:
	var combat_active: bool = selected_panel == 0
	combat_tabs.modulate = Color.WHITE if combat_active else Color.DARK_GRAY
	combat_skill_tree.modulate = Color.WHITE if combat_active else Color.DARK_GRAY
	general_stats.modulate = Color.WHITE if not combat_active else Color.DARK_GRAY
	info_panel.modulate = Color.WHITE

# Clears info panel.
func _clear_info_panel() -> void:
	info_title.text = ""
	info_desc.text = ""
	info_bonus.text = ""

# These two functions update the combat and skill tab highlights as you move over them with WASD.
func _update_combat_tab_highlight() -> void:
	for i: int in range(combat_tabs_list.size()):
		combat_tabs_list[i].modulate = Color.YELLOW if i == selected_combat_tab else Color.WHITE

func _update_skill_node_highlight() -> void:
	for i: int in range(skill_nodes.size()):
		skill_nodes[i].modulate = Color.YELLOW if i == selected_skill_node else Color.WHITE

func _update_stat_highlight() -> void:
	for r: int in range(stat_rows.size()):
		for c: int in range(stat_rows[r].size()):
			var label: Label = stat_rows[r][c]
			if r == selected_stat_row and c == selected_stat_col:
				label.modulate = Color.YELLOW
			else:
				label.modulate = Color.WHITE

func _update_info_panel_from_combat_tab() -> void:
	# Will show info about the selected combat tab
	# Placeholder for now
	pass

func _update_info_panel_from_skill_node() -> void:
	if current_tree_abilities.is_empty() or selected_skill_node >= current_tree_abilities.size():
		_clear_info_panel()
		return

	var ability_id: String = current_tree_abilities[selected_skill_node]
	var data: Dictionary = AbilityDB.get_ability(ability_id)
	var learned: bool = PlayerData.has_ability(ability_id)

	info_title.text = data.get("name", "")
	info_desc.text = data.get("description", "")

	# Build the bonus line: cost, learned status, and hotbar slot.
	var cost: Dictionary = data.get("cost", {})
	var bonus_text: String = ""
	for resource in cost.keys():
		bonus_text += str(cost[resource]) + " " + resource.to_upper() + "  "

	if not learned:
		bonus_text += "[Not Learned]"
	else:
		# Checkd if this ability is on the hotbar somewhere.
		var key_names: Array = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
		for i in range(PlayerData.hotbar.size()):
			if PlayerData.hotbar[i] == ability_id:
				bonus_text += "[Hotbar: " + key_names[i] + "]"
				break

	info_bonus.text = bonus_text
	pass

func _update_info_panel_from_stat() -> void:
	if stat_rows.is_empty():
		return
	var label: Label = stat_rows[selected_stat_row][selected_stat_col]
	var stat_name: String = label.name
	# Checks the array for statistics info so it can be displayed.
	if STAT_INFO.has(stat_name):
		var info: Array = STAT_INFO[stat_name]
		info_title.text = info[0]
		info_desc.text = info[1]
		info_bonus.text = info[2]
	else:
		_clear_info_panel()

# Input handling. This determines what controls the program is going to use dependant on the
# currently active panel state.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	match current_state:
		State.PANEL_SELECT:
			_input_panel_select(event)
		State.COMBAT_TABS_ACTIVE:
			_input_combat_tabs(event)
		State.SKILL_TREE_ACTIVE:
			_input_skill_tree(event)
		State.GENERAL_STATS_ACTIVE:
			_input_general_stats(event)

func _input_panel_select(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") and not event.is_echo():
		selected_panel = 0
		GameMenuManager.saved_character_panel = 0
		_highlight_panel_select()
	if event.is_action_pressed("ui_right") and not event.is_echo():
		selected_panel = 1
		GameMenuManager.saved_character_panel = 1
		_highlight_panel_select()
	if event.is_action_pressed("interact") and not event.is_echo():
		if selected_panel == 0:
			_enter_combat_tabs_active(true)
		else:
			_enter_general_stats_active(true)

func _input_combat_tabs(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and not event.is_echo():
		selected_combat_tab = max(0, selected_combat_tab - 1)
		_update_combat_tab_highlight()
		_update_info_panel_from_combat_tab()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		selected_combat_tab = min(combat_tabs_list.size() - 1, selected_combat_tab + 1)
		_update_combat_tab_highlight()
		_update_info_panel_from_combat_tab()
	if event.is_action_pressed("interact") and not event.is_echo():
		_enter_skill_tree_active()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_enter_panel_select()
		get_viewport().set_input_as_handled()

# Note: For now this just moves linearly, will move propely once the skills are detemined.
func _input_skill_tree(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and not event.is_echo():
		selected_skill_node = max(0, selected_skill_node - 1)
		_update_skill_node_highlight()
		_update_info_panel_from_skill_node()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		selected_skill_node = min(current_tree_abilities.size() - 1, selected_skill_node + 1)
		_update_skill_node_highlight()
		_update_info_panel_from_skill_node()
	if event.is_action_pressed("ui_left") and not event.is_echo():
		selected_skill_node = max(0, selected_skill_node - 1)
		_update_skill_node_highlight()
		_update_info_panel_from_skill_node()
	if event.is_action_pressed("ui_right") and not event.is_echo():
		selected_skill_node = min(current_tree_abilities.size() - 1, selected_skill_node + 1)
		_update_skill_node_highlight()
		_update_info_panel_from_skill_node()
	if event.is_action_pressed("interact") and not event.is_echo():
		_spend_skill_point()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		combat_skill_tree.visible = false
		_enter_combat_tabs_active(true)
		get_viewport().set_input_as_handled()
		return

	# Hotbar assignment.
	var slot: int = PlayerData.get_hotbar_slot_from_event(event)
	if slot != -1:
		_assign_ability_to_hotbar(slot)
		# This is critical: it prevents the same key press from also triggering GameMenuManager's
		# tab switching (since keys 1-4 are shared between ability_X and ui_X actions).
		get_viewport().set_input_as_handled()
			
func _assign_ability_to_hotbar(slot: int) -> void:
	var ability_id: String = _get_selected_ability_id()
	if ability_id == "":
		return
	if not PlayerData.has_ability(ability_id):
		return
	PlayerData.assign_hotbar(slot, ability_id)
	# Refreshs the info panel so the hotbar slot text updates immediately.
	_update_info_panel_from_skill_node()
	
func _get_selected_ability_id() -> String:
	if current_tree_abilities.is_empty() or selected_skill_node >= current_tree_abilities.size():
		return ""
	return current_tree_abilities[selected_skill_node]
			
func _input_general_stats(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and not event.is_echo():
		selected_stat_row = max(0, selected_stat_row - 1)
		_update_stat_highlight()
		_update_info_panel_from_stat()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		selected_stat_row = min(stat_rows.size() - 1, selected_stat_row + 1)
		_update_stat_highlight()
		_update_info_panel_from_stat()
	if event.is_action_pressed("ui_left") and not event.is_echo():
		selected_stat_col = max(0, selected_stat_col - 1)
		_update_stat_highlight()
		_update_info_panel_from_stat()
	if event.is_action_pressed("ui_right") and not event.is_echo():
		if stat_rows.size() > 0:
			selected_stat_col = min(stat_rows[selected_stat_row].size() - 1, selected_stat_col + 1)
		_update_stat_highlight()
		_update_info_panel_from_stat()
	if event.is_action_pressed("interact") and not event.is_echo():
		_level_up_stat()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_enter_panel_select()
		get_viewport().set_input_as_handled()

func _spend_skill_point() -> void:
	# Placeholder - will check skill point cost and spend if available.
	print("Spend skill point on node: ", selected_skill_node)

func _level_up_stat() -> void:
	if stat_rows.is_empty():
			return
	
	var label: Label = stat_rows[selected_stat_row][selected_stat_col]
	var stat_name: String = label.name
	
	# Checks if this stat is levelable.
	var levelable_stats: Array = [
		"stat_strength", "stat_vitality", "stat_dexterity",
		"stat_speed", "stat_charisma", "stat_intelligence", "stat_luck"
	]
	
	if not stat_name in levelable_stats:
		print("This stat cannot be levelled up")
		return
	
	# Checks if points are available.
	if PlayerData.unspent_stat_points <= 0:
		print("No stat points available")
		return
	
	# Checks if stat is below natural cap, only allows levelling if it is.
	var clean_name: String = stat_name.replace("stat_", "")
	var current_value: int = PlayerData.get_stat(clean_name)
	
	if current_value >= PlayerData.NATURAL_STAT_CAP:
		print("Stat is already at natural cap")
		return
	
	# Spends the point.
	PlayerData.unspent_stat_points -= 1
	# Note: Set is a built in godot method which lets us look for a specific thing (in this case a
	# stat) by using a string. So we send through "strength" and get the str value from PlayerData.
	PlayerData.set(clean_name, current_value + 1)
	_update_general_stats_display()
	_update_info_panel_from_stat()
	print("Levelled up ", clean_name, " to ", current_value + 1)

# Updates the stats screen with... drumroll... stats. Some stats are 0 as the system for their
# calculation is not in place yet.
func _update_general_stats_display() -> void:
	$general_stats/stat_name.text = "Name: " + PlayerData.player_name
	$general_stats/stat_level.text = "Level: " + str(PlayerData.combat_level)
	$general_stats/stat_xp.text = "XP: " + str(PlayerData.combat_xp) + " / " + str(PlayerData.combat_xp_to_next_level)
	$general_stats/stat_hp.text = "HP: " + str(PlayerData.current_hp) + " / " + str(PlayerData.max_hp)
	$general_stats/stat_strength.text = "Strength: " + str(PlayerData.strength)
	$general_stats/stat_vitality.text = "Vitality: " + str(PlayerData.vitality)
	$general_stats/stat_dexterity.text = "Dexterity: " + str(PlayerData.dexterity)
	$general_stats/stat_speed.text = "Speed: " + str(PlayerData.speed)
	$general_stats/stat_charisma.text = "Charisma: " + str(PlayerData.charisma)
	$general_stats/stat_intelligence.text = "Intelligence: " + str(PlayerData.intelligence)
	$general_stats/stat_luck.text = "Luck: " + str(PlayerData.luck)
	$general_stats/stat_carry_weight.text = "Carry Weight: " + str(PlayerData.get_total_weight()) + " / " + str(PlayerData.max_carry_weight)
	$general_stats/stat_gold.text = "Gold: " + str(PlayerData.gold)
	$general_stats/stat_damage.text = "Damage: " + str(0)
	$general_stats/stat_defence.text = "Defence: " + str(0)
	$general_stats/stat_hit_chance.text = "Hit Chance: " + str(0) + "%"
	$general_stats/stat_dodge_chance.text = "Dodge Chance: " + str(0) + "%"
	$general_stats/stat_fire_res.text = "Fire Res: " + str(0) + "%"
	$general_stats/stat_lightning_res.text = "Lightning Res: " + str(0) + "%"
	$general_stats/stat_ice_res.text = "Ice Res: " + str(0) + "%"
	$general_stats/stat_poison_res.text = "Poison Res: " + str(0) + "%"

# Sets up abilities for each tree when it is entered.
func _get_abilities_for_tab(tab_index: int) -> Array:
	var tree_name: String = ""
	match tab_index:
		0: tree_name = "red"
		1: tree_name = "green"
		2: tree_name = "blue"
		
	var result: Array = []
	for ability_id in AbilityDB.abilities.keys():
		var data: Dictionary = AbilityDB.abilities[ability_id]
		if data.get("tree", "") == tree_name:
			result.append(ability_id)
	return result

func _populate_skill_tree() -> void:
	current_tree_abilities = _get_abilities_for_tab(selected_combat_tab)

	for i in range(skill_nodes.size()):
		if i < current_tree_abilities.size():
			var ability_id: String = current_tree_abilities[i]
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			skill_nodes[i].text = data.get("name", ability_id)
			skill_nodes[i].visible = true
		else:
			skill_nodes[i].visible = false
