extends Node

# Preloads the interact scene when the game laods so that its ready as a var at all times. This is
# done as popups need to be as fast as possible.
var interact_popup_scene = preload("res://scenes/gui/interact_popup.tscn")
# Set as null so can be defined later.
var interact_popup = null
var is_open: bool = false
var interactables: Array = []
# Current index.
var selected_index: int = 0

# This makes it so that it can never be paused unlike other nodes.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Opens interacion choice popup.
func open_popup(found: Array) -> void:
	# If its already open, do nothing. Just an error net, really. However I should always have these
	# when there is a single instance of something, as you never want two of anything spawning in
	# when it should be one.
	if is_open:
		return
	is_open = true
	# Sets the array of found interactables to the var promptly named... interactables. Very nice.
	interactables = found
	selected_index = 0
	# Sets popup scene as interact_popup, which unnulls it (lol).
	interact_popup = interact_popup_scene.instantiate()
	# Adds the interact scene to the scene tree as a child.
	get_tree().root.add_child(interact_popup)
	# Pauses the scene tree.
	get_tree().paused = true
	# Populates the spawned interact scene with the array of interactables. AMAZING!!! WOW!!!
	interact_popup.populate(interactables)

func confirm_selection() -> void:
	# Establishes what the selected thing is by taking the interactables array and using the current
	# index to determine position.
	var selected = interactables[selected_index]
	# Calls the function that closes the interact choice window.
	close_popup()
	# Interacts with the selected item. We close_popup first before interacting so that the next
	# GUI element (Loot window, dialogue, etc.) can cleanly pause it again. This is probably a 1
	# frame unpause, but it makes sure there is a clear structure and no funny overlap madness.
	selected["collider"].interact()
	
func navigate(direction: int) -> void:
	# Clamps so it cant go beyond 0 or t he number of interactables.
	selected_index = clamp (selected_index + direction, 0, interactables.size() - 1)
	# Updates the selection of the current pop-up with the selected index.
	interact_popup.update_selection(selected_index)
	
func close_popup() -> void:
	is_open = false
	get_tree().paused = false
	if interact_popup:
		# Clears popup queue  to avoid errors if there are somehow multiple.
		interact_popup.queue_free()
		# Clears popup data.
		interact_popup = null
