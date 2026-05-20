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

# All nodes pause when the dialogue is open. This makes sure that the DialogueManager is always
# running.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Opens dialogue.
func open_dialogue(dialogue: Dictionary) -> void:
	# If its open already, it doesnt open again.
	if is_open:
		return
	
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
	_show_current_page()

# This is the wrongly named handler of the actions.
func _unhandled_input(event: InputEvent) -> void:
	# Failsafe for is the dialogue box is not open.
	if not is_open:
		return
	
	# When pressing input, it either confirms choice or advances page. Echo is used instead of
	# just_pressed as Input Event objects cannot use just_pressed.
	if event.is_action_pressed("interact") and not event.is_echo():
		if in_choices:
			_confirm_choice()
		else:
			_advance()
	
	# Navigates choices, up or down.
	if in_choices:
		if event.is_action_pressed("ui_up") and not event.is_echo():
			_navigate_choice(-1)
		if event.is_action_pressed("ui_down") and not event.is_echo():
			_navigate_choice(1)

# Advances a page forward. If there is no next page, closes dialogue.
func _advance() -> void:
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
	# This is big, but bascially its nested. It gets the current_dialogue dictionary, then finds
	# the pages, then gets one specific page from the pages, then gets the choices from that page,
	# and finally gets one specific choice from those choices.
	var choice = current_dialogue["pages"][current_page]["choices"][current_choice]
	
	# If choice leads to more pages, it shows them.
	if choice.has("next_pages"):
		current_dialogue["pages"] = choice["next_pages"]
		current_page = 0
		in_choices = false
		_show_current_page()
	else:
		# When a player picks a dialogue choice, something needs to happen in the game world as a
		# result. A quest starts, an item is given etc. Rather than the dialogue system knowing
		# about every possible quest and item in the game, it just stores a string like
		# "accept_imp_quest" and fires it to _fire_callback, which then handles what that string
		# actually means. It keeps the dialogue system ignorant of game logic. In this case, its
		# for accepting or declining quests.
		if choice.has("callback"):
			_fire_callback(choice["callback"])
		close_dialogue()

# Reads the current page and decides what to display. If the page has choices, switches to choice
# mode and shows the player's name as speaker. Otherwise, it shows normal NPC text.
func _show_current_page() -> void:
	var page = current_dialogue["pages"][current_page]
	
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
			print("Imp quest accepted")
		"decline_imp_quest":
			print("Imp quest declined")
		# This is a default case, meaning that it catches andything that doesnt fit the above and
		# warns me.
		_:
			print("Unknown callback: ", callback_name)

# Resets the state of the dialogue box, unpauses game, destroys dialogue box. The null at the end
# is important. Without it the car would hold a deleted object and the game would crash if we 
# tried to use the dialogue_box var again.
func close_dialogue() -> void:
	is_open = false
	just_closed = true
	get_tree().paused = false
	if dialogue_box:
		dialogue_box.queue_free()
		dialogue_box = null
