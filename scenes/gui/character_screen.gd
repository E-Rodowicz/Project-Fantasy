extends Control

# Tells game_menu the player has backed out of a side, so it can take back left/right control.
signal side_exited

enum State {
	IDLE,
	STATS_ACTIVE,
	COMBAT_TABS_ACTIVE,
	SKILL_TREE_ACTIVE
}

const SELECTED_COLOUR: Color = Color.YELLOW

# --- LEFT: SKILLS ---
@onready var combat_skill_tree: Control = $left_side/combat_skill_tree
@onready var skills_frame: SelectionFrame = $left_side/skills_frame
@onready var combat_tabs_list: Array[Label] = [
	$left_side/combat_tabs/tab_red,
	$left_side/combat_tabs/tab_green,
	$left_side/combat_tabs/tab_blue,
]

# --- RIGHT: STATS ---
@onready var stats_panel: StatsPanel = $right_side/stats_panel
@onready var stats_frame: SelectionFrame = $right_side/stats_frame

var current_state: State = State.IDLE

var selected_combat_tab: int = 0
var skill_nodes: Array[Button] = []
var selected_skill_node: int = 0
var current_tree_abilities: Array = []

func _ready() -> void:
	# Picks up whatever buttons are in the tree, so skills can be added without code changes.
	for child: Node in combat_skill_tree.get_children():
		if child is Button:
			skill_nodes.append(child)

	_populate_skill_tree()
	_refresh_highlights()

# --- SIDE SELECTION ---
# Called by game_menu when the player confirms a side.
func enter_side(side: int) -> void:
	if side == GameMenuManager.Side.LEFT:
		_set_state(State.COMBAT_TABS_ACTIVE)
	elif side == GameMenuManager.Side.RIGHT:
		_set_state(State.STATS_ACTIVE)

# Called by game_menu whenever the selection changes. A selected side pulses as brackets, an
# entered side grows to a full border, and an unselected side shows no frame.
func show_side_selection(side: int, entered: bool) -> void:
	_set_frame(skills_frame, side == GameMenuManager.Side.LEFT, entered)
	_set_frame(stats_frame, side == GameMenuManager.Side.RIGHT, entered)

func _set_frame(frame: SelectionFrame, is_selected: bool, entered: bool) -> void:
	if not is_selected:
		frame.deselect()
	elif entered:
		frame.activate()
	else:
		frame.select()

# Called by game_menu whenever this tab is shown. Stats can change elsewhere, e.g. carry weight
# from equipping, so they refresh here.
func on_tab_shown() -> void:
	stats_panel.refresh()

# Marking the input handled stops Q travelling on to GameMenuManager and closing the menu.
func _exit_side() -> void:
	_set_state(State.IDLE)
	get_viewport().set_input_as_handled()
	side_exited.emit()

func _set_state(new_state: State) -> void:
	current_state = new_state
	_refresh_highlights()

# --- INPUT ---
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.is_echo():
		return

	match current_state:
		State.IDLE:
			return
		State.STATS_ACTIVE:
			_input_stats(event)
		State.COMBAT_TABS_ACTIVE:
			_input_combat_tabs(event)
		State.SKILL_TREE_ACTIVE:
			_input_skill_tree(event)

func _input_stats(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_exit_side()
		return
	stats_panel.handle_input(event)

# The tree always shows the abilities of the highlighted tab, so you can see a tree before entering it.
func _input_combat_tabs(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		selected_combat_tab = maxi(0, selected_combat_tab - 1)
		_populate_skill_tree()
		_refresh_highlights()
	if event.is_action_pressed("ui_down"):
		selected_combat_tab = mini(combat_tabs_list.size() - 1, selected_combat_tab + 1)
		_populate_skill_tree()
		_refresh_highlights()
	if event.is_action_pressed("interact") and not current_tree_abilities.is_empty():
		_set_state(State.SKILL_TREE_ACTIVE)
	if event.is_action_pressed("ui_cancel"):
		_exit_side()

# For now this moves through the abilities in a line. Proper tree movement comes once the skills
# are decided.
func _input_skill_tree(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		selected_skill_node = maxi(0, selected_skill_node - 1)
		_refresh_highlights()
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		selected_skill_node = mini(current_tree_abilities.size() - 1, selected_skill_node + 1)
		_refresh_highlights()
	if event.is_action_pressed("interact"):
		_spend_skill_point()
	if event.is_action_pressed("ui_cancel"):
		_set_state(State.COMBAT_TABS_ACTIVE)
		get_viewport().set_input_as_handled()
		return

	var slot: int = PlayerData.get_hotbar_slot_from_event(event)
	if slot != -1:
		_assign_ability_to_hotbar(slot)
		# Keys 1-4 also switch menu tabs, so the press must stop here.
		get_viewport().set_input_as_handled()

# --- HIGHLIGHTS ---
# Yellow marks where the player's cursor is, so only the part they're in is highlighted.
func _refresh_highlights() -> void:
	stats_panel.set_cursor_visible(current_state == State.STATS_ACTIVE)

	var in_skills: bool = current_state == State.COMBAT_TABS_ACTIVE or current_state == State.SKILL_TREE_ACTIVE
	for i: int in range(combat_tabs_list.size()):
		UiFade.modulate(combat_tabs_list[i], SELECTED_COLOUR if in_skills and i == selected_combat_tab else Color.WHITE)

	for i: int in range(skill_nodes.size()):
		var is_selected: bool = current_state == State.SKILL_TREE_ACTIVE and i == selected_skill_node
		UiFade.modulate(skill_nodes[i], SELECTED_COLOUR if is_selected else Color.WHITE)

# --- SKILLS ---
func _get_abilities_for_tab(tab_index: int) -> Array:
	var tree_name: String = ""
	match tab_index:
		0:
			tree_name = "red"
		1:
			tree_name = "green"
		2:
			tree_name = "blue"

	var result: Array = []
	for ability_id: String in AbilityDB.abilities.keys():
		var data: Dictionary = AbilityDB.abilities[ability_id]
		if data.get("tree", "") == tree_name:
			result.append(ability_id)
	return result

func _populate_skill_tree() -> void:
	current_tree_abilities = _get_abilities_for_tab(selected_combat_tab)
	selected_skill_node = clampi(selected_skill_node, 0, maxi(0, current_tree_abilities.size() - 1))

	for i: int in range(skill_nodes.size()):
		if i < current_tree_abilities.size():
			var ability_id: String = current_tree_abilities[i]
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			skill_nodes[i].text = data.get("name", ability_id)
			skill_nodes[i].visible = true
		else:
			skill_nodes[i].visible = false

func _get_selected_ability_id() -> String:
	if current_tree_abilities.is_empty() or selected_skill_node >= current_tree_abilities.size():
		return ""
	return current_tree_abilities[selected_skill_node]

func _assign_ability_to_hotbar(slot: int) -> void:
	var ability_id: String = _get_selected_ability_id()
	if ability_id == "":
		return
	if not PlayerData.has_ability(ability_id):
		return
	PlayerData.assign_hotbar(slot, ability_id)

# Placeholder: will check the skill point cost and spend it.
func _spend_skill_point() -> void:
	print("Spend skill point on node: ", selected_skill_node)
