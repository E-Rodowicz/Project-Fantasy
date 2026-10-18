extends Control

# The character screen's stats side. Builds its columns from COLUMNS, using each stat's StatDef
# (from StatDB) for its icon, short name and colour, keeps the values up to date, and moves a
# cursor around them. character_screen passes it the arrow keys while the stats side is entered.
class_name StatsPanel

# Test switch: shows the widest values each stat can have, to check the layout holds them.
const TEST_WIDEST_VALUES: bool = true
const TEST_VALUES: Dictionary = {
	"strength": 0, "vitality": 8, "dexterity": 2,
	"speed": 4, "charisma": 5, "intelligence": 10,
	"hp": 999, "mp": 999, "bp": 999, "ap": 999,
	"damage": 999, "defence": 999, "hit_chance": -100, "dodge_chance": -100,
	"fire_res": -100, "lightning_res": -100, "ice_res": -100, "poison_res": -100,
}

const SELECTED_COLOUR: Color = Color.YELLOW
const ICON_SIZE: int = 8
# Gap between the icon, the name and the number, in the panel's own pixels.
const ICON_GAP: int = 2
# Extra space between a stat's name and its number.Y
const NAME_GAP: int = 3
# The two rows above the columns, as cursor positions. Columns start at row 0.
const HEADER_ROW: int = -2
const XP_ROW: int = -1

@export var title_colour: Color = Color("ffc439")
@export var xp_fill_colour: Color = Color("ffc439")

# Left to right. Each column is a list of sections, each with a title and its stat ids, top to
# bottom. "at_bottom" pushes a section down to the bottom of its column.
const COLUMNS: Array = [
	[
		{"title": "Attributes", "stats": ["strength", "vitality", "dexterity", "speed", "intelligence", "charisma"]},
	],
	[
		{"title": "Resources", "stats": ["hp", "mp", "bp", "ap"]},
	],
	[
		{"title": "Combat", "stats": ["damage", "defence", "hit_chance", "dodge_chance"]},
	],
	[
		{"title": "Resistances", "stats": ["fire_res", "lightning_res", "ice_res", "poison_res"]},
	],
]

@onready var header_label: Label = $header_label
@onready var xp_bar: Control = $xp_bar
@onready var xp_fill: ColorRect = $xp_bar/xp_fill
@onready var xp_text: Label = $xp_bar/xp_text
@onready var column_nodes: Array[Control] = [
	$columns/attributes_column,
	$columns/resources_column,
	$columns/combat_column,
	$columns/resistances_column,
]

# The stat ids in each column, top to bottom, used for moving the cursor.
var nav_columns: Array = []
# Each stat's number label, by id.
var cell_labels: Dictionary = {}
# Each stat's short-name label, by id.
var cell_name_labels: Dictionary = {}
# The colour each number should be when not selected: white, or green/red for percentages.
var value_colours: Dictionary = {}
# Width of the widest short name, so every number starts at the same x.
# Each stat's icon, by id.
var cell_icons: Dictionary = {}
var name_width: int = 0
var selected_col: int = 0
var selected_row: int = 0
var cursor_visible: bool = false

func _ready() -> void:
	xp_fill.color = xp_fill_colour
	name_width = _measure_widest_name()
	_build_columns()
	refresh()
	_update_highlight()

# --- BUILDING ---
func _build_columns() -> void:
	for col: int in range(COLUMNS.size()):
		var column_node: Control = column_nodes[col]
		var ids: Array[String] = []
		for section: Dictionary in COLUMNS[col]:
			if section.get("at_bottom", false):
				var spacer: Control = Control.new()
				# EXPAND_FILL makes the spacer take all the spare height in the column, pushing
				# everything after it to the bottom.
				spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
				column_node.add_child(spacer)
			column_node.add_child(_make_title(section["title"]))
			for stat_id: String in section["stats"]:
				column_node.add_child(_make_cell(stat_id))
				ids.append(stat_id)
		nav_columns.append(ids)

func _make_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	# Each title fills its column's width, so centring the text centres it over the column.
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", title_colour)
	return label

# One cell: icon, short name, then the number. The icon and name take the stat's colour. The
# name label is fixed at the widest name's width, so the numbers line up down each column.
func _make_cell(stat_id: String) -> Control:
	var def: StatDef = StatDB.get_stat(stat_id)
	if def == null:
		push_error("StatsPanel: no StatDef for '" + stat_id + "' in " + StatDB.STATS_FOLDER)

	var cell: HBoxContainer = HBoxContainer.new()
	cell.add_theme_constant_override("separation", ICON_GAP)

	var icon: TextureRect = TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	# SHRINK_CENTER keeps the icon at its own 8 tall and centres it on the text line.
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if def != null:
		icon.texture = def.icon

	var name_label: Label = Label.new()
	name_label.text = def.short_name if def != null else stat_id
	name_label.custom_minimum_size.x = name_width + NAME_GAP

	var value_label: Label = Label.new()

	cell.add_child(icon)
	cell.add_child(name_label)
	cell.add_child(value_label)
	cell_labels[stat_id] = value_label
	cell_name_labels[stat_id] = name_label
	cell_icons[stat_id] = icon
	return cell

# get_theme_font finds the font a Label here would use (your m3x6 from the menu theme), and
# get_string_size measures how wide a piece of text is in it.
func _measure_widest_name() -> int:
	var font: Font = get_theme_font("font", "Label")
	var font_size: int = get_theme_font_size("font_size", "Label")
	var widest: float = 0.0
	for column: Array in COLUMNS:
		for section: Dictionary in column:
			for stat_id: String in section["stats"]:
				var def: StatDef = StatDB.get_stat(stat_id)
				var text: String = def.short_name if def != null else stat_id
				widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return ceili(widest)

# --- VALUES ---
# Called when the tab is shown, so values are current.
func refresh() -> void:
	header_label.text = PlayerData.player_name + " - Lv " + str(PlayerData.combat_level)

	var xp: int = PlayerData.combat_xp
	var xp_needed: int = maxi(1, PlayerData.combat_xp_to_next_level)
	var ratio: float = clampf(float(xp) / xp_needed, 0.0, 1.0)
	xp_fill.size.x = roundi(xp_bar.size.x * ratio)
	xp_text.text = _short_number(xp) + "/" + _short_number(xp_needed)

	for stat_id: String in cell_labels.keys():
		var def: StatDef = StatDB.get_stat(stat_id)
		var is_percent: bool = def != null and def.is_percent
		var value: int = _get_value(stat_id)
		var label: Label = cell_labels[stat_id]
		# Percentages stay exact. Other numbers of 1000 or more shorten, e.g. 1234 → 1.2k.
		label.text = str(value) + "%" if is_percent else _short_number(value)
		value_colours[stat_id] = StatDB.value_colour(def, value)
	_update_highlight()

# Anything 1000 or over is shortened: 1000 → 1.0k, 12500 → 12.5k.
func _short_number(value: int) -> String:
	if value >= 1000:
		return "%.1fk" % (value / 1000.0)
	return str(value)

# The raw number for each stat. Percentages are whole percent, e.g. -100 for -100%.
# Values that don't have a system behind them yet are 0.
func _get_value(stat_id: String) -> int:
	if TEST_WIDEST_VALUES and TEST_VALUES.has(stat_id):
		return TEST_VALUES[stat_id]
	match stat_id:
		"strength":
			return PlayerData.strength
		"vitality":
			return PlayerData.vitality
		"dexterity":
			return PlayerData.dexterity
		"speed":
			return PlayerData.speed
		"charisma":
			return PlayerData.charisma
		"intelligence":
			return PlayerData.intelligence
		"hp":
			return PlayerData.max_hp
		"mp":
			return PlayerData.get_max_mp()
		"bp":
			return PlayerData.bp_max
		"ap":
			return PlayerData.ap_max
	return 0

# --- CURSOR ---
# Returns true if it used the key, so character_screen knows the key was dealt with.
func handle_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		_move(0, -1)
		return true
	if event.is_action_pressed("ui_down"):
		_move(0, 1)
		return true
	if event.is_action_pressed("ui_left"):
		_move(-1, 0)
		return true
	if event.is_action_pressed("ui_right"):
		_move(1, 0)
		return true
	return false

# Up from the top of a column goes to the XP bar, then the header. Down from them goes back into
# the column you were in. Left and right keep the same row where the next column is long enough.
func _move(dx: int, dy: int) -> void:
	if dy < 0:
		if selected_row == HEADER_ROW:
			return
		selected_row -= 1
	elif dy > 0:
		if selected_row < 0:
			selected_row += 1
		else:
			selected_row = mini(selected_row + 1, nav_columns[selected_col].size() - 1)
	elif dx != 0 and selected_row >= 0:
		selected_col = clampi(selected_col + dx, 0, nav_columns.size() - 1)
		selected_row = mini(selected_row, nav_columns[selected_col].size() - 1)
	_update_highlight()

# Shows the yellow cursor only while the player is inside the stats side.
func set_cursor_visible(is_visible: bool) -> void:
	cursor_visible = is_visible
	_update_highlight()

# The selected stat's name and number turn yellow. Otherwise the name keeps the stat's colour and
# the number keeps its value colour. Icons always keep the stat's colour.
func _update_highlight() -> void:
	_set_colour(header_label, Color.WHITE, cursor_visible and selected_row == HEADER_ROW)
	_set_colour(xp_text, Color.WHITE, cursor_visible and selected_row == XP_ROW)
	for col: int in range(nav_columns.size()):
		for row: int in range(nav_columns[col].size()):
			var stat_id: String = nav_columns[col][row]
			var is_selected: bool = cursor_visible and col == selected_col and row == selected_row
			var def: StatDef = StatDB.get_stat(stat_id)
			var name_colour: Color = def.colour if def != null else Color.WHITE
			_set_colour(cell_name_labels[stat_id], name_colour, is_selected)
			_set_colour(cell_labels[stat_id], value_colours.get(stat_id, Color.WHITE), is_selected)
			UiFade.modulate(cell_icons[stat_id], SELECTED_COLOUR if is_selected else name_colour)

func _set_colour(label: Label, normal_colour: Color, is_selected: bool) -> void:
	UiFade.label_colour(label, SELECTED_COLOUR if is_selected else normal_colour)

# What the cursor is on: "header", "xp", or a stat id. For the info box later.
func get_selected_id() -> String:
	if selected_row == HEADER_ROW:
		return "header"
	if selected_row == XP_ROW:
		return "xp"
	return nav_columns[selected_col][selected_row]
