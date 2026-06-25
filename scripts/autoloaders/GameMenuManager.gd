extends Node

var game_menu_scene = preload("res://scenes/gui/game_menu.tscn")
var game_menu = null
var is_open: bool = false
var current_tab: int = 0
# Remembers what panel we were on in char and inv.
var saved_inventory_panel: int = 0
var saved_character_panel: int = 0

# These constants are only here for readability.
const TAB_CHARACTER = 0
const TAB_INVENTORY = 1
const TAB_JOURNAL = 2
const TAB_MAP = 3

var menus_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
# Inputs for menu.
func _unhandled_input(event: InputEvent) -> void:
	if not menus_enabled:
		return
	if not event is InputEventKey:
		return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if is_open:
			close_menu()
		return
	if event.is_action_pressed("open_menu") and not event.is_echo():
		if is_open:
			close_menu()
		else:
			open_menu()
	# Tab switchers which only work if menu is already open.
	if event.is_action_pressed("ui_1") and not event.is_echo():
		if is_open:
			GameMenuManager.switch_tab(GameMenuManager.TAB_CHARACTER)
	if event.is_action_pressed("ui_2") and not event.is_echo():
		if is_open:
			GameMenuManager.switch_tab(GameMenuManager.TAB_INVENTORY)
	if event.is_action_pressed("ui_3") and not event.is_echo():
		if is_open:
			GameMenuManager.switch_tab(GameMenuManager.TAB_JOURNAL)
	if event.is_action_pressed("ui_4") and not event.is_echo():
		if is_open:
			GameMenuManager.switch_tab(GameMenuManager.TAB_MAP)
	# These are the C,I,J,M shortcuts for menus.
	if event.is_action_pressed("open_character") and not event.is_echo():
		_handle_shortcut_key(TAB_CHARACTER)
	if event.is_action_pressed("open_inventory") and not event.is_echo():
		_handle_shortcut_key(TAB_INVENTORY)
	if event.is_action_pressed("open_journal") and not event.is_echo():
		_handle_shortcut_key(TAB_JOURNAL)
	if event.is_action_pressed("open_map") and not event.is_echo():
		_handle_shortcut_key(TAB_MAP)

# Handles the shortcut key logic for C,I,J,M.
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

# Opens menu on the last accessed tab.
func open_menu() -> void:
	if is_open:
		return
	if get_tree().paused:
		return
	is_open = true
	game_menu = game_menu_scene.instantiate()
	get_tree().root.add_child(game_menu)
	get_tree().paused = true
	game_menu.switch_tab(current_tab)

# Closes menu
func close_menu() -> void:
	is_open = false
	get_tree().paused = false
	if game_menu:
		game_menu.queue_free()
		game_menu = null

# Tracks state of tab.
func switch_tab(tab_index: int) -> void:
	current_tab = tab_index
	if game_menu:
		game_menu.switch_tab(tab_index)
