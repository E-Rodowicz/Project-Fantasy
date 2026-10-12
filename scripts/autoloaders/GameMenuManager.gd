extends Node

# The three places the cursor can sit on a split screen. An enum declared in an autoload can be
# reached from any script as GameMenuManager.Side.LEFT, etc.
enum Side {
	GEM,
	LEFT,
	RIGHT
}

const TAB_CHARACTER: int = 0
const TAB_INVENTORY: int = 1
const TAB_JOURNAL: int = 2
const TAB_MAP: int = 3

var game_menu_scene: PackedScene = preload("res://scenes/gui/game_menu.tscn")
var game_menu: CanvasLayer = null
var is_open: bool = false
var current_tab: int = TAB_CHARACTER
var menus_enabled: bool = true

# true: closing deletes the menu, so every tab starts back on the gem next time.
# false: closing only hides it, so it reopens exactly as it was left.
var reset_on_close: bool = true

# Still read by character_screen and inventory_screen. Delete once both are converted.
var saved_inventory_panel: int = 0
var saved_character_panel: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not menus_enabled:
		return
	if not event is InputEventKey:
		return
	if event.is_echo():
		return

	if event.is_action_pressed("ui_cancel"):
		if is_open:
			close_menu()
		return
	if event.is_action_pressed("open_menu"):
		if is_open:
			close_menu()
		else:
			open_menu()
		return

	if is_open:
		if event.is_action_pressed("ui_1"):
			switch_tab(TAB_CHARACTER)
		if event.is_action_pressed("ui_2"):
			switch_tab(TAB_INVENTORY)
		if event.is_action_pressed("ui_3"):
			switch_tab(TAB_JOURNAL)
		if event.is_action_pressed("ui_4"):
			switch_tab(TAB_MAP)

	if event.is_action_pressed("open_character"):
		_handle_shortcut_key(TAB_CHARACTER)
	if event.is_action_pressed("open_inventory"):
		_handle_shortcut_key(TAB_INVENTORY)
	if event.is_action_pressed("open_journal"):
		_handle_shortcut_key(TAB_JOURNAL)
	if event.is_action_pressed("open_map"):
		_handle_shortcut_key(TAB_MAP)

func _handle_shortcut_key(tab_index: int) -> void:
	if get_tree().paused and not is_open:
		return
	if is_open and current_tab == tab_index:
		close_menu()
	elif is_open:
		switch_tab(tab_index)
	else:
		current_tab = tab_index
		open_menu()

func open_menu() -> void:
	if is_open:
		return
	if get_tree().paused:
		return
	is_open = true
	if game_menu == null:
		game_menu = game_menu_scene.instantiate()
		get_tree().root.add_child(game_menu)
	else:
		# Reached when reopening mid slide-out, or when reset_on_close is false.
		game_menu.visible = true
		game_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	game_menu.switch_tab(current_tab)
	game_menu.slide_in()

func close_menu() -> void:
	is_open = false
	get_tree().paused = false
	if game_menu == null:
		return
	game_menu.slide_out(_on_menu_slid_out)

func _on_menu_slid_out() -> void:
	if game_menu == null:
		return
	if reset_on_close:
		game_menu.queue_free()
		game_menu = null
	else:
		game_menu.visible = false
		game_menu.process_mode = Node.PROCESS_MODE_DISABLED

func switch_tab(tab_index: int) -> void:
	current_tab = tab_index
	if game_menu:
		game_menu.switch_tab(tab_index)
