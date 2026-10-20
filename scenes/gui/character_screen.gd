extends Control

# Tells game_menu the player has backed out of a side, so it can take back left/right control.
signal side_exited

enum State {
	IDLE,
	STATS_ACTIVE,
	ABILITIES_ACTIVE
}

# --- LEFT: ABILITIES ---
@onready var ability_panel: AbilityPanel = $left_side/ability_panel
@onready var skills_frame: SelectionFrame = $left_side/skills_frame

# --- RIGHT: STATS ---
@onready var stats_panel: StatsPanel = $right_side/stats_panel
@onready var stats_frame: SelectionFrame = $right_side/stats_frame

var current_state: State = State.IDLE

func _ready() -> void:
	_refresh_cursors()

# --- SIDE SELECTION ---
# Called by game_menu when the player confirms a side.
func enter_side(side: int) -> void:
	if side == GameMenuManager.Side.LEFT:
		_set_state(State.ABILITIES_ACTIVE)
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
	ability_panel.reset()

# Marking the input handled stops Q travelling on to GameMenuManager and closing the menu.
func _exit_side() -> void:
	_set_state(State.IDLE)
	get_viewport().set_input_as_handled()
	side_exited.emit()

func _set_state(new_state: State) -> void:
	current_state = new_state
	_refresh_cursors()

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
		State.ABILITIES_ACTIVE:
			_input_abilities(event)

func _input_stats(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_exit_side()
		return
	stats_panel.handle_input(event)

# The panel gets first go. Q only exits the side if the panel didn't need it, i.e. no tree is open.
func _input_abilities(event: InputEvent) -> void:
	if ability_panel.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		_exit_side()

# --- CURSORS ---
# Yellow marks where the player's cursor is, so only the side they're in shows it.
func _refresh_cursors() -> void:
	stats_panel.set_cursor_visible(current_state == State.STATS_ACTIVE)
	ability_panel.set_cursor_visible(current_state == State.ABILITIES_ACTIVE)
