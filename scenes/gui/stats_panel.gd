extends Control

# The character screen's stats side. Builds its columns from COLUMNS, using each stat's StatDef
# (from StatDB) for its icon, short name and colour, keeps the values up to date, and moves a
# cursor around them. character_screen passes it the arrow keys while the stats side is entered.
class_name StatsPanel

# Test switch: set between 0.0 and 1.0 to preview the XP bar that full (0.5 = half). -1 uses real XP.
const TEST_XP_RATIO: float = 0.5
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
# Extra space between a stat's name and its number.
const NAME_GAP: int = 3
# The two rows above the columns, as cursor positions. Columns start at row 0.
const HEADER_ROW: int = -2
const XP_ROW: int = -1
# How long E has to be held on a stat to open its info window. A shorter press is a tap.
# Holding E on a stat: nothing for the delay (so taps never flash), then it turns white character
# by character over the charge time, and the info window opens.
const INFO_CHARGE_DELAY: float = 0.2
const INFO_CHARGE_TIME: float = 0.3
# How long the stat stays fully white before the window opens, so the last character is seen.
const INFO_FULL_HOLD: float = 0.12
# Length of each step of the white/yellow flash when the window opens.
const FLASH_STEP: float = 0.06
# How many white/yellow flashes play when the window opens.
const FLASH_COUNT: int = 4

@export var title_colour: Color = Color("ffc439")
# The XP bar sits outside this panel so its art isn't shrunk by the panel's 0.75 scale. These
# exported slots take the nodes directly: drag them in from the scene tree in the Inspector.
@export var xp_bar: TextureProgressBar = null
@export var xp_text: Label = null

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
# Each stat's icon, by id.
var cell_icons: Dictionary = {}
# Width of the widest short name, so every number starts at the same x.
var name_width: int = 0
var selected_col: int = 0
var selected_row: int = 0
var cursor_visible: bool = false
# Each stat's whole cell (icon, name and number), by id. The info window grows out of it.
var cell_nodes: Dictionary = {}
# What's charging right now: its id, its icon (if it has one) and its labels, with the white
# copies laid over them.
var charging_id: String = ""
var charge_icon: TextureRect = null
var charge_labels: Array[Label] = []
var charge_clips: Array[Control] = []
# How long E has been held, or -1 when it isn't being held.
var info_hold_timer: float = -1.0

func _ready() -> void:
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
	cell_nodes[stat_id] = cell
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

	var xp_needed: int = maxi(1, PlayerData.combat_xp_to_next_level)
	var xp: int = PlayerData.combat_xp
	if TEST_XP_RATIO >= 0.0:
		xp = roundi(xp_needed * TEST_XP_RATIO)
	var ratio: float = clampf(float(xp) / xp_needed, 0.0, 1.0)

	# max_value is the fill art's width in pixels, so each point of value is exactly one pixel.
	var fill_width: int = xp_bar.texture_progress.get_width() if xp_bar.texture_progress != null else int(xp_bar.size.x)
	xp_bar.max_value = fill_width
	var fill_pixels: int = roundi(fill_width * ratio)
	# Any XP at all shows at least one pixel, so a fresh level never looks completely empty.
	if xp > 0:
		fill_pixels = maxi(fill_pixels, 1)
	xp_bar.value = fill_pixels

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
	if event.is_action_pressed("interact"):
		info_hold_timer = 0.0
		return true
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
	_end_charge()
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

# Puts the cursor back on the first stat. Called when the player leaves the tab.
func reset_cursor() -> void:
	_end_charge()
	selected_col = 0
	selected_row = 0
	_update_highlight()

# Shows the yellow cursor only while the player is inside the stats side.
func set_cursor_visible(show_cursor: bool) -> void:
	cursor_visible = show_cursor
	_update_highlight()

# The selected stat's name and number turn yellow. Otherwise the name keeps the stat's colour and
# the number keeps its value colour. Icons always keep the stat's colour.
func _update_highlight() -> void:
	_set_colour(header_label, Color.WHITE, cursor_visible and selected_row == HEADER_ROW)
	_set_colour(xp_text, Color.WHITE, cursor_visible and selected_row == XP_ROW)
	UiFade.pop(header_label, cursor_visible and selected_row == HEADER_ROW)
	UiFade.pop(xp_text, cursor_visible and selected_row == XP_ROW)
	for col: int in range(nav_columns.size()):
		for row: int in range(nav_columns[col].size()):
			var stat_id: String = nav_columns[col][row]
			var is_selected: bool = cursor_visible and col == selected_col and row == selected_row
			var def: StatDef = StatDB.get_stat(stat_id)
			var name_colour: Color = def.colour if def != null else Color.WHITE
			_set_colour(cell_name_labels[stat_id], name_colour, is_selected)
			_set_colour(cell_labels[stat_id], value_colours.get(stat_id, Color.WHITE), is_selected)
			UiFade.modulate(cell_icons[stat_id], SELECTED_COLOUR if is_selected else name_colour)
			UiFade.pop(cell_nodes[stat_id], is_selected)

func _set_colour(label: Label, normal_colour: Color, is_selected: bool) -> void:
	UiFade.label_colour(label, SELECTED_COLOUR if is_selected else normal_colour)

# What the cursor is on: "header", "xp", or a stat id. For the info box later.
func get_selected_id() -> String:
	if selected_row == HEADER_ROW:
		return "header"
	if selected_row == XP_ROW:
		return "xp"
	return nav_columns[selected_col][selected_row]

# --- INFO WINDOW ---
# Counts how long E is held. Let go early and it was a tap, which does nothing yet; stat
# upgrading will hook in there. Hold through the charge and the info window opens.
func _process(delta: float) -> void:
	if info_hold_timer < 0.0:
		return
	if not Input.is_action_pressed("interact") or not cursor_visible:
		_end_charge()
		return
	info_hold_timer += delta
	if info_hold_timer < INFO_CHARGE_DELAY:
		return
	if charging_id == "":
		_begin_charge()
	var charge_elapsed: float = info_hold_timer - INFO_CHARGE_DELAY
	var progress: float = clampf(charge_elapsed / INFO_CHARGE_TIME, 0.0, 1.0)
	_apply_charge(progress)
	if charge_elapsed >= INFO_CHARGE_TIME + INFO_FULL_HOLD:
		_complete_charge()

func _begin_charge() -> void:
	charging_id = get_selected_id()
	charge_icon = null
	if charging_id == "header":
		charge_labels = [header_label]
	elif charging_id == "xp":
		charge_labels = [xp_text]
	else:
		charge_icon = cell_icons[charging_id]
		charge_labels = [cell_name_labels[charging_id], cell_labels[charging_id]]
	if charge_icon != null:
		_kill_fade(charge_icon)
		charge_icon.modulate = SELECTED_COLOUR
	for label: Label in charge_labels:
		charge_clips.append(_make_white_overlay(label))

# Works out how many "steps" are lit: the icon counts as one, then every character in order.
func _apply_charge(progress: float) -> void:
	var total: int = 1 if charge_icon != null else 0
	for label: Label in charge_labels:
		total += label.text.length()
	# +1 lights the first step straight away; mini stops it going past the end.
	var lit: int = mini(total, floori(progress * total) + 1)

	if charge_icon != null:
		charge_icon.modulate = Color.WHITE if lit >= 1 else SELECTED_COLOUR
		lit -= 1
	for i: int in range(charge_labels.size()):
		var label: Label = charge_labels[i]
		var count: int = clampi(lit, 0, label.text.length())
		charge_clips[i].size.x = _text_width_to(label, count)
		lit -= label.text.length()

# Cancelled (let go early, or moved): removes the white copies and fades back to normal.
func _end_charge() -> void:
	var was_charging: bool = charging_id != ""
	_clear_charge()
	if was_charging:
		_update_highlight()

# Charge finished: flash, then open the window.
func _complete_charge() -> void:
	var icon: TextureRect = charge_icon
	var labels: Array[Label] = charge_labels.duplicate()
	_clear_charge()
	_flash(icon, labels)
	_open_info()

func _clear_charge() -> void:
	info_hold_timer = -1.0
	for clip: Control in charge_clips:
		clip.queue_free()
	charge_clips.clear()
	if charge_icon != null and charge_icon.has_meta("fade_target"):
		charge_icon.remove_meta("fade_target")
	charging_id = ""
	charge_icon = null
	charge_labels = []

# White, yellow, white, yellow, each held for FLASH_STEP. Callbacks switch the colour instantly
# and intervals hold it, so it reads as a flash rather than a fade.
func _flash(icon: TextureRect, labels: Array[Label]) -> void:
	if icon != null:
		_kill_fade(icon)
	for label: Label in labels:
		_kill_fade(label)
	var tween: Tween = create_tween()
	for i: int in range(FLASH_COUNT):
		tween.tween_callback(_set_parts_colour.bind(icon, labels, Color.WHITE))
		tween.tween_interval(FLASH_STEP)
		tween.tween_callback(_set_parts_colour.bind(icon, labels, SELECTED_COLOUR))
		tween.tween_interval(FLASH_STEP)
	tween.tween_callback(_update_highlight)

func _set_parts_colour(icon: TextureRect, labels: Array[Label], colour: Color) -> void:
	if icon != null:
		icon.modulate = colour
	for label: Label in labels:
		label.add_theme_color_override("font_color", colour)

# A white copy of the label inside a box that clips it. clip_contents hides everything outside
# the box, so widening the box reveals the white text one character at a time over the original.
func _make_white_overlay(label: Label) -> Control:
	var clip: Control = Control.new()
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.size = Vector2(0, label.size.y)

	var copy: Label = Label.new()
	copy.text = label.text
	copy.horizontal_alignment = label.horizontal_alignment
	copy.vertical_alignment = label.vertical_alignment
	copy.size = label.size
	copy.add_theme_color_override("font_color", Color.WHITE)

	clip.add_child(copy)
	label.add_child(clip)
	return clip

# How wide the box must be to show the first `count` characters. For centred labels the text
# starts partway in, so that offset is added first.
func _text_width_to(label: Label, count: int) -> float:
	if count <= 0:
		return 0.0
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var start: float = 0.0
	if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
		var full_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		start = floorf((label.size.x - full_width) / 2.0)
	var part_width: float = font.get_string_size(label.text.substr(0, count), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return ceilf(start + part_width)

# Stops any UiFade running on a node, so the charge can set its colour directly.
func _kill_fade(item: CanvasItem) -> void:
	if item.has_meta("fade_tween"):
		var tween: Tween = item.get_meta("fade_tween")
		if tween != null and tween.is_valid():
			tween.kill()
	if item.has_meta("fade_target"):
		item.remove_meta("fade_target")

func _open_info() -> void:
	var selected: String = get_selected_id()
	if selected == "header":
		SkillInfoScreen.open_info(_screen_rect(header_label), null, Color.WHITE,
			PlayerData.player_name, "Level " + str(PlayerData.combat_level))
	elif selected == "xp":
		var xp: int = PlayerData.combat_xp
		var xp_needed: int = PlayerData.combat_xp_to_next_level
		var body_text: String = "XP: " + str(xp) + " / " + str(xp_needed) + "\n" \
			+ str(maxi(0, xp_needed - xp)) + " more to reach level " + str(PlayerData.combat_level + 1) + "."
		SkillInfoScreen.open_info(_screen_rect(xp_bar), null, Color.WHITE, "Experience", body_text)
	else:
		var def: StatDef = StatDB.get_stat(selected)
		if def == null:
			return
		var label: Label = cell_labels[selected]
		var value_colour: Color = value_colours.get(selected, Color.WHITE)
		var body_text: String = "Current: [color=#" + value_colour.to_html(false) + "]" + label.text + "[/color]\n" + def.description
		SkillInfoScreen.open_info(_screen_rect(cell_nodes[selected]), def.icon, def.colour,
			def.display_name, body_text)

# Where a node sits on the screen in real pixels, with every scale above it included (the
# menu's 4x, this panel's 0.75), which is what the info window expects to grow out of.
func _screen_rect(node: Control) -> Rect2:
	var xform: Transform2D = node.get_global_transform_with_canvas()
	return Rect2(xform.origin, node.size * xform.get_scale())
