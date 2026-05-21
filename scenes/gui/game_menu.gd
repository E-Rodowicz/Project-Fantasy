extends CanvasLayer

@onready var tab_character = $menu_frame/HBoxContainer/tab_character
@onready var tab_inventory = $menu_frame/HBoxContainer/tab_inventory
@onready var tab_journal = $menu_frame/HBoxContainer/tab_journal
@onready var tab_map = $menu_frame/HBoxContainer/tab_map
@onready var content_area = $menu_frame/content_area

var tabs: Array = []
var current_tab: int = 0

# Preloads the menu tabs.
var character_scene = preload("res://scenes/gui/character_screen.tscn")
var inventory_scene = preload("res://scenes/gui/inventory_screen.tscn")
var journal_scene = preload("res://scenes/gui/journal_screen.tscn")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Sets up the tab array when the scene is ready. No real reason other than that to put the tabs
	# array in here.
	tabs = [tab_character, tab_inventory, tab_journal, tab_map]

func switch_tab(tab_index: int) -> void:
	current_tab = tab_index
	_update_tab_visuals()
	_load_tab_content()
	
# Makes unsused tabs grey, active tab white.
func _update_tab_visuals() -> void:
	for i in range(tabs.size()):
		if i == current_tab:
			tabs[i].modulate = Color.WHITE
		else:
			tabs[i].modulate = Color.DARK_GRAY
			
func _load_tab_content() -> void:
	# Clears current content
	for child in content_area.get_children():
		child.queue_free()
	
	match current_tab:
		GameMenuManager.TAB_CHARACTER:
			var screen = character_scene.instantiate()
			content_area.add_child(screen)
		GameMenuManager.TAB_INVENTORY:
			var screen = inventory_scene.instantiate()
			content_area.add_child(screen)
		GameMenuManager.TAB_JOURNAL:
			var screen = journal_scene.instantiate()
			content_area.add_child(screen)
		# Placeholder for the other tabs (This is how its done with "match". Fucking python).
		_:
			var label = Label.new()
			label.text = "Coming soon!"
			content_area.add_child(label)
