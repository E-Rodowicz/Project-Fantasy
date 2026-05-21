extends Control

@onready var quest_list_container = $quest_list_panel/quest_list_container
@onready var quest_title = $quest_desc_panel/quest_title
@onready var quest_status = $quest_desc_panel/quest_status
@onready var quest_description = $quest_desc_panel/quest_description

# Selection and its collapsed state. False means not collapsed, true means collapsed.
var sections: Dictionary = {
	"Active Quests": false,
	"Completed Quests": true,
	"Failed Quests": true,
}

# The list of things to navigate (Quests and tabs) and current index (Did ya know, all navigation
# just moves this index up or down?). Bare in mind, nav_list is an array of dictionaries.
var nav_list: Array = []
var selected_index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_nav_list()
	_populate_quest_list()
	
	# Starts on the first active quest, not the header.
	selected_index = 0
	for i in range(nav_list.size()):
		# Loops once to find the first quest and changes current index to that quests' index.
		if nav_list[i]["type"] == "quest":
			selected_index = i
			break
	
	_update_selection()

# This rebuilds nav_list any time anything happens.
func _build_nav_list() -> void:
	# Reset.
	nav_list.clear()
	
	# Adds a header entry to the list using the dictionary, as well as their info.
	for section_name in sections.keys():
		# Add section header
		nav_list.append({
			"type": "header",
			"section": section_name,
			"collapsed": sections[section_name]
		})
		
		# Adds quests if section is expanded.
		if not sections[section_name]:
			var quests: Array = _get_quests_for_section(section_name)
			for quest in quests:
				nav_list.append({
					"type": "quest",
					"quest": quest
				})
				
func _get_quests_for_section(section_name: String) -> Array:
	# Morphs the section name into a string so that we have a status.
	var status: String = ""
	match section_name:
		"Active Quests":
			status = "active"
		"Completed Quests":
			status = "completed"
		"Failed Quests":
			status = "failed"
	
	# Loops all quests in the journal and keeps only the ones that match the status.
	var result: Array = []
	for quest in PlayerData.journal.values():
		if quest.get("status", "") == status:
			result.append(quest)
	return result

func _populate_quest_list() -> void:
	# Removes everything to start fresh.
	for child in quest_list_container.get_children():
		child.free()
	
	# Creates a label per entry in nav_list. If its a header, it gets an arrow which point
	# somewhere dependant on its collapsed status. Quests get an indent and every label gets added
	# to the quest list container.
	for i: int in range(nav_list.size()):
		var entry: Dictionary = nav_list[i]
		var label: Label = Label.new()
		
		if entry["type"] == "header":
			var arrow: String = "▼ " if not entry["collapsed"] else "► "
			label.text = arrow + entry["section"]
		else:
			label.text = "  " + entry["quest"].get("title", "Unknown Quest")
		# Adds the completed label.
		quest_list_container.add_child(label)

func _update_selection() -> void:
	
	# Updates highlights.
	for i: int in range(quest_list_container.get_child_count()):
		var label: Label = quest_list_container.get_child(i)
		label.modulate = Color.YELLOW if i == selected_index else Color.WHITE
	
	# In case nav list is empty, shows empty quest desc panel info.
	if nav_list.is_empty():
		quest_title.text = ""
		quest_status.text = ""
		quest_description.text = ""
		return
	
	# Populates info screen on the right. This reads the array and gets the current quest/header,
	# using the currently selected index to loop up the entry inforamtion. Meaning you can then use
	# entry["quest"] to set a quest variable, allowing you to get its titles, status, desc.
	var entry: Dictionary = nav_list[selected_index]
	if entry["type"] == "header":
		quest_title.text = entry["section"]
		quest_status.text = ""
		quest_description.text = "Press E to expand or collapse."
	else:
		var quest: Dictionary = entry["quest"]
		quest_title.text = quest.get("title", "Unknown")
		quest_status.text = "Status: " + quest.get("status", "")
		quest_description.text = quest.get("description", "")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	# Just the inputs, clamped with min/max to prevent it going out of bounds.
	if event.is_action_pressed("ui_up") and not event.is_echo():
		selected_index = max(0, selected_index - 1)
		_update_selection()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		selected_index = min(nav_list.size() - 1, selected_index + 1)
		_update_selection()
	if event.is_action_pressed("interact") and not event.is_echo():
		_toggle_section()

func _toggle_section() -> void:
	# Error net.
	if nav_list.is_empty():
		return
	
	# Returns on quests.
	var entry: Dictionary = nav_list[selected_index]
	if entry["type"] != "header":
		return
	
	# Toggles collapsed state.
	var section_name: String = entry["section"]
	sections[section_name] = not sections[section_name]
	
	# Rebuilds and repopulates.
	_build_nav_list()
	_populate_quest_list()
	
	# Finds and restores selection to the same header.
	for i: int in range(nav_list.size()):
		if nav_list[i]["type"] == "header" and nav_list[i]["section"] == section_name:
			selected_index = i
			break
	
	_update_selection()
