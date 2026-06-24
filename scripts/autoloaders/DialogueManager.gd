extends Node

# Preload loads the dialogue box when the game starts rather than when its needed. Its faster this
# way. The box is null until assigned when dialogue is opened.
var dialogue_box_scene = preload("res://scenes/gui/dialogue_box.tscn")
var dialogue_box = null

# These track the states of dialogue. First one is self-explanatory.
var current_dialogue: Dictionary = {}
# This checks which page of dialogue you are on.
var current_page: int = 0
# What the current choice is.
var current_choice: int = 0
# This switches begaviour for "interact" between moving text along and picking a choice. 
var in_choices: bool = false
# Prevents two dialogues from opening at the same time.
var is_open: bool = false
# Just closed tell us if the dialogue window was just closed, so taht we do not reopen it from
# an additional input of "interact". This happened due to the game pausing, so unpausing after
# dialogue (Which uses E for interact) read that input continously as the game unpaused and opened
# the window again.
var just_closed: bool = false
# Tracks which fram the dialogue opened on and ignores input from the same frame - thanks to this,
# nothing is skipped when dialogue is initiated with E (which is the same key press used to skip
# dialogue.
var open_frame: int = -1
# Cache for current dialogue.
var dialogue_cache: Dictionary = {}

var current_file_data: Dictionary = {}

# All nodes pause when the dialogue is open. This makes sure that the DialogueManager is always
# running.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func load_dialogue(file_name: String) -> Dictionary:
	if not dialogue_cache.has(file_name):
		var path: String = "res://data/dialogues/" + file_name + ".json"
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		
		if file == null:
			push_error("Could not open dialogue file: " + path)
			return {}
		
		var text: String = file.get_as_text()
		file.close()
		
		var result = JSON.parse_string(text)
		
		if result == null:
			push_error("Failed to parse dialogue JSON: " + path)
			return {}
		
		dialogue_cache[file_name] = result
	
	var file_data: Dictionary = dialogue_cache[file_name]
	var dialogues: Array = file_data.get("dialogues", [])
	
	for entry in dialogues:
		var conditions: Array = entry.get("conditions", [])
		var all_met: bool = true
		
		for condition in conditions:
			if not PlayerData.has_flag(condition):
				all_met = false
				break
		
		if all_met:
			current_file_data = file_data
			return entry.duplicate(true)
	
	push_error("No matching dialogue found in: " + file_name)
	return {}
		
# Opens dialogue.
func open_dialogue(dialogue: Dictionary) -> void:
	# If its open already, it doesnt open again.
	if is_open:
		return
		
	# Saves current frame so that it can be compared in unhandled input. If it still is the current
	# frame, it skips input (this happens in unhandled input).
	open_frame = Engine.get_process_frames()
	
	# Resets the dialogue so its always the same once it starts.
	current_dialogue = dialogue
	current_page = 0
	current_choice = 0
	in_choices = false
	is_open = true
	
	# Makes an instance of the dialogue box and adds its to the scene, regardless of what scene it
	# may be. Means its always on top. Pauses the game and shows first page. Boom.
	dialogue_box = dialogue_box_scene.instantiate()
	# Note: get_tree gives acces to the scene tree on the left. This bascially pauses and unpauses
	# the game, as the scene tree has all of the nodes. Also adds new child, the newly made dialogue
	# box. Its a spawn in, bascially.
	get_tree().root.add_child(dialogue_box)
	get_tree().paused = true
	dialogue_box.slide_in()
	_show_current_page()
	# Sets all dialogue flags so the correct dialogue is read from the JSON file.
	var flags_to_set: Array = dialogue.get("set_flags", [])
	for flag in flags_to_set:
		PlayerData.set_flag(flag)

# This is the wrongly named handler of the actions.
func _unhandled_input(event: InputEvent) -> void:
	# Failsafe for is the dialogue box is not open.
	if not is_open:
		return
		
	# Checks current frame against saved frame so that input is ignored if they match. 
	if Engine.get_process_frames() == open_frame:
		return
	
	# When pressing input, it either confirms choice or advances page. Echo is used instead of
	# just_pressed as Input Event objects cannot use just_pressed.
	if event.is_action_pressed("interact") and not event.is_echo():
		if in_choices:
			if not dialogue_box.is_confirming:
				dialogue_box.glow_choice(current_choice, _confirm_choice)
		elif dialogue_box and dialogue_box.is_revealing:
			dialogue_box.skip_reveal()
		else:
			_advance()
	
	# Navigates choices, up or down.
	if in_choices and not dialogue_box.is_confirming:
		if event.is_action_pressed("ui_up") and not event.is_echo():
			_navigate_choice(-1)
		if event.is_action_pressed("ui_down") and not event.is_echo():
			_navigate_choice(1)

	# System for using 1, 2, 3, etc, for picking dialogue choices instead of navigating and pressing
	# interact.
	if in_choices and not dialogue_box.is_confirming:
		if event is InputEventKey and event.pressed and not event.is_echo():
			var choices: Array = current_dialogue["pages"][current_page]["choices"]
			# i start at 0, so when you add it to KEY 1, you get the appropraite key number with the
			# loop.
			for i in range(choices.size()):
				if event.keycode == KEY_1 + i:
					current_choice = i
					dialogue_box.update_selection(current_choice)
					dialogue_box.glow_choice(current_choice, _confirm_choice)
					break
				
# Advances a page forward. If there is no next page, closes dialogue.
func _advance() -> void:
	if dialogue_box and dialogue_box.has_overflow:
		dialogue_box.set_text(dialogue_box.overflow_text)
		return
	current_page += 1
	if current_page >= current_dialogue["pages"].size():
		close_dialogue()
	else:
		_show_current_page()

	# Wrap around for the choices, so you can go back to the last choice when you press up on the 
	# first one.
func _navigate_choice(direction: int) -> void:
	# The modulo lets you wrap around to the top when exceeding the choices.
	var choices = current_dialogue["pages"][current_page]["choices"]
	current_choice = (current_choice + direction) % choices.size()
	# This wraps you to the bottom when on top and pressing up. Modulo doesnt work for negatives.
	if current_choice < 0:
		current_choice = choices.size() - 1
	# Amends the current choice.
	dialogue_box.update_selection(current_choice)

# This is what happens when you confirm a choice.
func _confirm_choice() -> void:
	var choice = current_dialogue["pages"][current_page]["choices"][current_choice]
	
	var flags_to_set: Array = choice.get("set_flags", [])
	for flag in flags_to_set:
		PlayerData.set_flag(flag)
	
	if choice.has("next_pages"):
		var pages: Array = choice["next_pages"].duplicate(true)
		
		if choice.has("goto"):
			var section_id: String = choice["goto"]
			var sections: Dictionary = current_file_data.get("sections", {})
			if sections.has(section_id):
				pages.append_array(sections[section_id])
			else:
				push_error("Section not found: " + section_id)
		
		current_dialogue["pages"] = pages
		current_page = 0
		in_choices = false
		_show_current_page()
	elif choice.has("goto"):
		var section_id: String = choice["goto"]
		var sections: Dictionary = current_file_data.get("sections", {})
		if sections.has(section_id):
			current_dialogue["pages"] = sections[section_id].duplicate(true)
			current_page = 0
			in_choices = false
			_show_current_page()
		else:
			push_error("Section not found: " + section_id)
			close_dialogue()
	else:
		close_dialogue()

# Reads the current page and decides what to display. If the page has choices, switches to choice
# mode and shows the player's name as speaker. Otherwise, it shows normal NPC text.
func _show_current_page() -> void:
	var page = current_dialogue["pages"][current_page]
	
	var flags_to_set: Array = page.get("set_flags", [])
	for flag in flags_to_set:
		PlayerData.set_flag(flag)
	
	if page.has("choices"):
		in_choices = true
		current_choice = 0
		dialogue_box.set_speaker(PlayerData.player_name)
		dialogue_box.show_choices(page["choices"], current_choice)
	else:
		# Empty text after speaker and text is there so there is no crash if something doesnt 
		# have a definition. Otherwise uses dictionary data.
		in_choices = false
		dialogue_box.set_speaker(page.get("speaker", ""))
		dialogue_box.set_text(page.get("text", ""))
		dialogue_box.hide_choices()

# Quest accepts/declines. This will need to be replaced with quest logic later on. Note: Match is
# a switch, it picks whatever callback_name fits and prints things accordingly. Its a prettier
# "if" statement. Does the same thing.
func _fire_callback(callback_name: String) -> void:
	match callback_name:
		"accept_imp_quest":
			PlayerData.set_flag("imp_quest_accepted")
		"decline_imp_quest":
			PlayerData.set_flag("imp_quest_declined")
		# This is a default case, meaning that it catches andything that doesnt fit the above and
		# warns me.
		_:
			push_error("Unknown callback: " + callback_name)

# Resets the state of the dialogue box, unpauses game, destroys dialogue box. The null at the end
# is important. Without it the car would hold a deleted object and the game would crash if we 
# tried to use the dialogue_box var again.
func close_dialogue() -> void:
	is_open = false
	just_closed = true
	if dialogue_box:
		dialogue_box.slide_out(_cleanup_dialogue)
	else:
		get_tree().paused = false

func _cleanup_dialogue() -> void:
	get_tree().paused = false
	if dialogue_box:
		dialogue_box.queue_free()
		dialogue_box = null
