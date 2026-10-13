extends Control

enum State {
	LIST_ACTIVE,
	TEXT_ACTIVE
}

# --- COLOURS ---
# Swap these for palette hex values, e.g. Color("a8d8a0").
const QUEST_COLOURS: Dictionary = {
	"Active Quests": Color.WHITE,
	"Completed Quests": Color(0.7, 1.0, 0.7),
	"Failed Quests": Color(1.0, 0.7, 0.7),
}
const HEADER_COLOURS: Dictionary = {
	"Active Quests": Color.WHITE,
	"Completed Quests": Color(0.45, 0.8, 0.45),
	"Failed Quests": Color(0.85, 0.4, 0.4),
}
const COUNT_COLOURS: Dictionary = {
	"Active Quests": Color.YELLOW,
	"Completed Quests": Color(0.45, 0.8, 0.45),
	"Failed Quests": Color(0.85, 0.4, 0.4),
}
const SELECTED_COLOUR: Color = Color.YELLOW

# --- LIST LAYOUT ---
# Space under each entry, in native pixels. Takes the place of the VBoxContainer's separation.
const ROW_GAP: int = 4

# --- QUEST ENTRIES ---
const ENTRY_DIVIDER: String = "----------"
# Quest text scroll speed while up or down is held, in native pixels per second.
const ENTRY_SCROLL_SPEED: float = 160.0

# --- TIMINGS ---
const HIGHLIGHT_FADE_TIME: float = 0.1
const TEXT_FADE_OUT_TIME: float = 0.06
const TEXT_FADE_IN_TIME: float = 0.12
# How long each quest row takes to open or close. Rows go one after another.
const ROW_UNROLL_TIME: float = 0.06
# The most frames to wait for the quest text's layout to settle before scrolling anyway.
const LAYOUT_SETTLE_MAX_FRAMES: int = 10

@onready var quest_list_scroll: ScrollContainer = $left_side/quest_list_panel/quest_list_scroll
@onready var quest_list_container: Control = $left_side/quest_list_panel/quest_list_scroll/quest_list_container
@onready var quest_desc_panel: Control = $right_side/quest_desc_panel
@onready var quest_title: Label = $right_side/quest_desc_panel/quest_title
@onready var quest_entries_scroll: ScrollContainer = $right_side/quest_desc_panel/quest_entries_margin/quest_entries_scroll
@onready var quest_entries: Control = $right_side/quest_desc_panel/quest_entries_margin/quest_entries_scroll/quest_entries
@onready var header_summary_centre: Control = $right_side/header_summary_centre
@onready var header_summary: RichTextLabel = $right_side/header_summary_centre/header_summary
@onready var left_side: Control = $left_side

var current_state: State = State.LIST_ACTIVE

var sections: Dictionary = {
	"Active Quests": false,
	"Completed Quests": true,
	"Failed Quests": true,
}

var nav_list: Array = []
var selected_index: int = 0

# One row and one label per nav_list entry, in the same order.
var entry_rows: Array[Control] = []
var entry_labels: Array[Label] = []
# Each row's full height, so it knows what to grow back to.
var row_heights: Array[int] = []

# Which list entry is currently yellow, so it can fade back when the selection moves.
var highlighted_index: int = -1
# One colour tween per list label, so a fade can be cancelled if the selection comes back mid-fade.
var label_tweens: Array[Tween] = []
var details_tween: Tween = null
var list_fade_tween: Tween = null
# True while the tab is waiting for the first scroll before fading in.
var reveal_tab_after_scroll: bool = false
# True while the right side is waiting for a new quest's scroll before fading back in.
var reveal_details_after_scroll: bool = false
# True while a section is opening or closing. Input waits until it's done.
var is_rolling: bool = false
# Goes up every time the quest text is rebuilt, so a delayed scroll for an old quest can tell
# it's out of date and give up.
var entries_version: int = 0
# Empty space after the last entry, sized so the latest entry can always reach the top.
var entries_spacer: Control = null
# The exact scroll position as a decimal. scroll_vertical only holds whole pixels, so moving it
# by tiny amounts each frame would round away to nothing.
var entry_scroll_position: float = 0.0
# The scroll that should happen for the current quest, kept until the journal is visible to do it.
var entries_scroll_target: Control = null
var entries_scroll_pending: bool = false
var entries_reveal_tween: Tween = null

func _ready() -> void:
	# Rows carry their own gap, so the container adds none. Otherwise a closed row would still leave
	# a gap, and the headers below would jump instead of slide.
	quest_list_container.add_theme_constant_override("separation", 0)

	_build_nav_list()
	_populate_quest_list()

	selected_index = 0
	for i: int in range(nav_list.size()):
		if nav_list[i]["type"] == "quest":
			selected_index = i
			break

	_apply_list_colours_instantly()
	_scroll_to_selected()
	_show_details()

# Input.get_axis returns -1 while the first action is held, 1 for the second, and 0 for neither.
func _process(delta: float) -> void:
	if current_state != State.TEXT_ACTIVE:
		return
	var direction: float = Input.get_axis("ui_up", "ui_down")
	if direction == 0.0:
		return
	entry_scroll_position += direction * ENTRY_SCROLL_SPEED * delta
	quest_entries_scroll.scroll_vertical = roundi(entry_scroll_position)
	# The ScrollContainer won't go past either end. Reading back what it accepted stops the decimal
	# position drifting beyond the end, where releasing and reversing would feel unresponsive.
	if quest_entries_scroll.scroll_vertical != roundi(entry_scroll_position):
		entry_scroll_position = float(quest_entries_scroll.scroll_vertical)

# --- STATE ---
# The selection animation for the active side will be triggered from here later.
func _set_state(new_state: State) -> void:
	current_state = new_state
	if new_state == State.TEXT_ACTIVE:
		entry_scroll_position = float(quest_entries_scroll.scroll_vertical)

# --- INPUT ---
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if is_rolling:
		return

	match current_state:
		State.LIST_ACTIVE:
			_input_list(event)
		State.TEXT_ACTIVE:
			_input_text(event)

# Q isn't handled here, so it carries on to GameMenuManager and closes the menu.
func _input_list(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
	if event.is_action_pressed("ui_down"):
		_move_selection(1)
	if event.is_action_pressed("interact"):
		_confirm_in_list()

# The second argument of is_action_pressed allows echoes, so holding up or down keeps scrolling.
func _input_text(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_set_state(State.LIST_ACTIVE)
		get_viewport().set_input_as_handled()

func _move_selection(step: int) -> void:
	if nav_list.is_empty():
		return
	# clampi keeps a whole number between a minimum and maximum, same as the old max/min pair.
	var new_index: int = clampi(selected_index + step, 0, nav_list.size() - 1)
	if new_index == selected_index:
		return
	selected_index = new_index
	_fade_highlight()
	_scroll_to_selected()
	_fade_details()

# E on a header expands or collapses it. E on a quest opens its description.
func _confirm_in_list() -> void:
	if nav_list.is_empty():
		return
	var entry: Dictionary = nav_list[selected_index]
	if entry["type"] == "header":
		_toggle_section()
	else:
		_set_state(State.TEXT_ACTIVE)

# --- LIST BUILDING ---
# Every entry stores its section, so headers and quests can be coloured from it.
func _build_nav_list() -> void:
	nav_list.clear()
	for section_name: String in sections.keys():
		nav_list.append({
			"type": "header",
			"section": section_name,
			"collapsed": sections[section_name]
		})
		if not sections[section_name]:
			var quests: Array = _get_quests_for_section(section_name)
			for quest: Dictionary in quests:
				nav_list.append({
					"type": "quest",
					"quest": quest,
					"section": section_name
				})

func _get_quests_for_section(section_name: String) -> Array:
	var status: String = ""
	match section_name:
		"Active Quests":
			status = "active"
		"Completed Quests":
			status = "completed"
		"Failed Quests":
			status = "failed"

	var result: Array = []
	for quest: Dictionary in PlayerData.journal.values():
		if quest.get("status", "") == status:
			result.append(quest)
	return result

# Each entry is a label inside its own row. The row's height is what animates.
func _populate_quest_list() -> void:
	for child: Node in quest_list_container.get_children():
		child.free()
	entry_rows.clear()
	entry_labels.clear()
	row_heights.clear()
	label_tweens.clear()

	for i: int in range(nav_list.size()):
		var entry: Dictionary = nav_list[i]

		var label: Label = Label.new()
		if entry["type"] == "header":
			var arrow: String = "- " if not entry["collapsed"] else "+ "
			label.text = arrow + entry["section"]
		else:
			label.text = "  " + entry["quest"].get("title", "Unknown Quest")

		var row: Control = Control.new()
		# clip_contents hides anything outside the row's rectangle, so a half-open row shows
		# only the top part of its text.
		row.clip_contents = true
		row.add_child(label)
		quest_list_container.add_child(row)

		# Measured after the row is in the tree, so the label has picked up the menu's font.
		var full_height: int = ceili(label.get_combined_minimum_size().y) + ROW_GAP
		row.custom_minimum_size.y = full_height

		entry_rows.append(row)
		entry_labels.append(label)
		row_heights.append(full_height)
		label_tweens.append(null)

# Rebuilds the list and keeps the cursor on the header that was toggled.
func _rebuild_list(section_name: String) -> void:
	_build_nav_list()
	_populate_quest_list()
	for i: int in range(nav_list.size()):
		if nav_list[i]["type"] == "header" and nav_list[i]["section"] == section_name:
			selected_index = i
			break
	_apply_list_colours_instantly()
	_scroll_to_selected()

# --- LIST COLOURS ---
func _get_list_colour(entry: Dictionary) -> Color:
	var colours: Dictionary = HEADER_COLOURS if entry["type"] == "header" else QUEST_COLOURS
	return colours.get(entry["section"], Color.WHITE)

# Used after a rebuild, where there's nothing to fade from.
func _apply_list_colours_instantly() -> void:
	for i: int in range(entry_labels.size()):
		var colour: Color = _get_list_colour(nav_list[i])
		if i == selected_index:
			colour = SELECTED_COLOUR
		entry_labels[i].add_theme_color_override("font_color", colour)
	highlighted_index = selected_index

# The old entry fades back to its section colour while the new one fades to yellow.
func _fade_highlight() -> void:
	if highlighted_index >= 0 and highlighted_index < entry_labels.size():
		_fade_label_colour(highlighted_index, _get_list_colour(nav_list[highlighted_index]))
	_fade_label_colour(selected_index, SELECTED_COLOUR)
	highlighted_index = selected_index

func _fade_label_colour(index: int, colour: Color) -> void:
	var old_tween: Tween = label_tweens[index]
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	var tween: Tween = create_tween()
	tween.tween_property(entry_labels[index], "theme_override_colors/font_color", colour, HIGHLIGHT_FADE_TIME)
	label_tweens[index] = tween

func _scroll_to_selected() -> void:
	if selected_index < entry_rows.size():
		quest_list_scroll.ensure_control_visible.call_deferred(entry_rows[selected_index])

# --- EXPAND / COLLAPSE ---
func _toggle_section() -> void:
	var entry: Dictionary = nav_list[selected_index]
	if entry["type"] != "header":
		return
	var section_name: String = entry["section"]

	if sections[section_name]:
		sections[section_name] = false
		_rebuild_list(section_name)
		_unroll(section_name)
	else:
		_roll_up(section_name)

# The positions in nav_list of one section's quests, top to bottom.
func _get_quest_indices(section_name: String) -> Array[int]:
	var indices: Array[int] = []
	for i: int in range(nav_list.size()):
		var entry: Dictionary = nav_list[i]
		if entry["type"] == "quest" and entry["section"] == section_name:
			indices.append(i)
	return indices

# The section's rows start closed and open one after another, top to bottom.
func _unroll(section_name: String) -> void:
	var indices: Array[int] = _get_quest_indices(section_name)
	if indices.is_empty():
		return

	for index: int in indices:
		entry_rows[index].custom_minimum_size.y = 0

	is_rolling = true
	# Steps in a tween run one after another unless set_parallel is used, which is what makes the
	# rows open in turn. bind() adds the row as an extra argument after the tweened height.
	var tween: Tween = create_tween()
	for index: int in indices:
		tween.tween_method(_set_row_height.bind(entry_rows[index]), 0.0, float(row_heights[index]), ROW_UNROLL_TIME)
	tween.tween_callback(_finish_unroll)

func _finish_unroll() -> void:
	is_rolling = false

# The section's rows close one after another, bottom to top, then the list is rebuilt without them.
func _roll_up(section_name: String) -> void:
	var indices: Array[int] = _get_quest_indices(section_name)
	if indices.is_empty():
		_finish_collapse(section_name)
		return

	is_rolling = true
	var tween: Tween = create_tween()
	for j: int in range(indices.size() - 1, -1, -1):
		var index: int = indices[j]
		tween.tween_method(_set_row_height.bind(entry_rows[index]), float(row_heights[index]), 0.0, ROW_UNROLL_TIME)
	tween.tween_callback(_finish_collapse.bind(section_name))

func _finish_collapse(section_name: String) -> void:
	sections[section_name] = true
	_rebuild_list(section_name)
	is_rolling = false

# Rounded so rows, and everything sliding below them, stay on whole art pixels.
func _set_row_height(height: float, row: Control) -> void:
	row.custom_minimum_size.y = roundf(height)

# --- RIGHT SIDE ---
# Fades the details out, then swaps the text. The fade back in happens in _on_details_faded_out.
func _fade_details() -> void:
	# A new selection takes over any reveal still waiting on the previous quest's scroll.
	if reveal_tab_after_scroll:
		reveal_tab_after_scroll = false
		_fade_in_list()
	reveal_details_after_scroll = false

	if details_tween != null and details_tween.is_valid():
		details_tween.kill()
	details_tween = create_tween()
	details_tween.set_parallel(true)
	details_tween.tween_property(quest_desc_panel, "modulate:a", 0.0, TEXT_FADE_OUT_TIME)
	details_tween.tween_property(header_summary_centre, "modulate:a", 0.0, TEXT_FADE_OUT_TIME)
	details_tween.chain().tween_callback(_on_details_faded_out)

# A quest whose text still needs scrolling waits for it. Headers and anything else fade straight in.
func _on_details_faded_out() -> void:
	_show_details()
	if entries_scroll_pending and is_visible_in_tree():
		reveal_details_after_scroll = true
	else:
		_fade_in_details()

func _show_details() -> void:
	if nav_list.is_empty():
		quest_title.text = ""
		_clear_entries()
		header_summary_centre.visible = false
		return

	var entry: Dictionary = nav_list[selected_index]
	var section_name: String = entry["section"]
	var title_colour: Color = HEADER_COLOURS.get(section_name, Color.WHITE)
	var text_colour: Color = QUEST_COLOURS.get(section_name, Color.WHITE)
	_set_details_colour(title_colour, text_colour)

	if entry["type"] == "header":
		quest_title.text = section_name
		_clear_entries()
		header_summary.text = _build_header_summary(section_name)
		header_summary_centre.visible = true
	else:
		var quest: Dictionary = entry["quest"]
		quest_title.text = quest.get("title", "Unknown")
		# A single space keeps the label one line tall, so it works as the blank line under the title.
		_populate_entries(quest, text_colour)
		header_summary_centre.visible = false

# The title takes the dark shade. The status line takes the light one. Entries are coloured as
# they're built.
func _set_details_colour(title_colour: Color, _text_colour: Color) -> void:
	quest_title.add_theme_color_override("font_color", title_colour)

# --- QUEST ENTRIES ---
func _clear_entries() -> void:
	entries_version += 1
	entries_scroll_target = null
	entries_scroll_pending = false
	for child: Node in quest_entries.get_children():
		child.free()

func _make_entry_label(text: String, colour: Color, is_divider: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", colour)
	if is_divider:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label
	
# Builds one label per entry, oldest first, with a divider between each. Quests saved with a
# single "description" instead of "entries" still show, as one entry.
func _populate_entries(quest: Dictionary, text_colour: Color) -> void:
	_clear_entries()
	var entries: Array = quest.get("entries", [])
	if entries.is_empty() and quest.has("description"):
		entries = [quest["description"]]

	# What to scroll to: the divider before the latest entry, or the entry itself if it's the only one.
	var scroll_target: Control = null
	for i: int in range(entries.size()):
		var entry_label: Label = _make_entry_label(str(entries[i]), text_colour, false)
		if i > 0:
			var divider: Label = _make_entry_label(ENTRY_DIVIDER, text_colour, true)
			quest_entries.add_child(divider)
			scroll_target = divider
		else:
			scroll_target = entry_label
		quest_entries.add_child(entry_label)

	entries_spacer = Control.new()
	quest_entries.add_child(entries_spacer)

	quest_entries_scroll.scroll_vertical = 0
	entries_scroll_target = scroll_target
	entries_scroll_pending = scroll_target != null
	# Hidden until scrolled into place, so the jump from the top is never seen.
	quest_entries.modulate.a = 0.0 if entries_scroll_pending else 1.0
	if entries_scroll_pending:
		_scroll_to_entry(scroll_target)

# Waits for the layout to settle, sizes the spacer so the target can reach the top, then scrolls.
# "await" pauses this function until the signal fires, while the rest of the game carries on.
func _scroll_to_entry(target: Control) -> void:
	# Hidden nodes aren't laid out, so their positions are meaningless. Leave the scroll pending
	# and let on_tab_shown() do it once the journal appears.
	if not is_visible_in_tree():
		return
	var version: int = entries_version

	# Vector3i is three whole numbers in one value, so all three measurements can be compared at once.
	var last_measure: Vector3i = Vector3i(-1, -1, -1)
	for i: int in range(LAYOUT_SETTLE_MAX_FRAMES):
		await get_tree().process_frame
		# A newer quest has replaced this one, and its own scroll will handle the reveal.
		if version != entries_version or not is_instance_valid(target):
			return
		# Switching tab mid-wait stops the layout. on_tab_shown() will start this again on return.
		if not is_visible_in_tree():
			return
		var measure: Vector3i = Vector3i(
			int(target.position.y),
			int(quest_entries.size.y),
			int(quest_entries_scroll.size.y)
		)
		if measure == last_measure:
			break
		last_measure = measure

	var target_y: int = last_measure.x
	var content_height: int = last_measure.y
	var view_height: int = last_measure.z
	entries_spacer.custom_minimum_size.y = maxi(0, target_y + view_height - content_height)

	await get_tree().process_frame
	if version != entries_version or not is_instance_valid(target):
		return
	quest_entries_scroll.scroll_vertical = target_y
	entries_scroll_pending = false

	# Whatever was waiting on this scroll now fades in, with the entries already fully visible
	# inside it, so title and text arrive together.
	if reveal_tab_after_scroll:
		reveal_tab_after_scroll = false
		quest_entries.modulate.a = 1.0
		_fade_in_tab()
	elif reveal_details_after_scroll:
		reveal_details_after_scroll = false
		quest_entries.modulate.a = 1.0
		_fade_in_details()
	else:
		_reveal_entries()

# Called by game_menu whenever the journal tab is shown. If the quest text still needs its first
# scroll, everything stays hidden until that's done, so it all fades in together.
func on_tab_shown() -> void:
	left_side.modulate.a = 0.0
	quest_desc_panel.modulate.a = 0.0
	header_summary_centre.modulate.a = 0.0
	if entries_scroll_pending and is_instance_valid(entries_scroll_target):
		reveal_tab_after_scroll = true
		_scroll_to_entry(entries_scroll_target)
	else:
		_fade_in_tab()

func _fade_in_tab() -> void:
	_fade_in_details()
	_fade_in_list()

# Starts the right side from invisible and fades it in. Uses details_tween so it cancels, or is
# cancelled by, the fade from moving the selection.
func _fade_in_details() -> void:
	if details_tween != null and details_tween.is_valid():
		details_tween.kill()
	quest_desc_panel.modulate.a = 0.0
	header_summary_centre.modulate.a = 0.0
	details_tween = create_tween()
	details_tween.set_parallel(true)
	details_tween.tween_property(quest_desc_panel, "modulate:a", 1.0, TEXT_FADE_IN_TIME)
	details_tween.tween_property(header_summary_centre, "modulate:a", 1.0, TEXT_FADE_IN_TIME)
	
func _fade_in_list() -> void:
	if list_fade_tween != null and list_fade_tween.is_valid():
		list_fade_tween.kill()
	left_side.modulate.a = 0.0
	list_fade_tween = create_tween()
	list_fade_tween.tween_property(left_side, "modulate:a", 1.0, TEXT_FADE_IN_TIME)

func _reveal_entries() -> void:
	if entries_reveal_tween != null and entries_reveal_tween.is_valid():
		entries_reveal_tween.kill()
	entries_reveal_tween = create_tween()
	entries_reveal_tween.tween_property(quest_entries, "modulate:a", 1.0, TEXT_FADE_IN_TIME)

# BBCode is a set of tags RichTextLabel reads: [center] centres the line, and [color] colours only
# the text inside it. to_html(false) turns a Color into a hex string, leaving out the alpha.
func _build_header_summary(section_name: String) -> String:
	var count: int = _get_quests_for_section(section_name).size()
	var noun: String = "quest" if count == 1 else "quests"
	var count_colour: Color = COUNT_COLOURS.get(section_name, Color.WHITE)
	var number: String = "[color=#" + count_colour.to_html(false) + "]" + str(count) + "[/color]"

	var sentence: String = ""
	match section_name:
		"Active Quests":
			sentence = "You currently have " + number + " active " + noun + "."
		"Completed Quests":
			sentence = "You have completed " + number + " " + noun + "."
		"Failed Quests":
			sentence = "You have failed " + number + " " + noun + "."
	# The whole sentence takes the light shade. The number's own [color] tag inside it overrides that.
	var text_colour: Color = QUEST_COLOURS.get(section_name, Color.WHITE)
	return "[center][color=#" + text_colour.to_html(false) + "]" + sentence + "[/color][/center]"
