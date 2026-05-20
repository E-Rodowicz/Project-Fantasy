extends Node

# Loads the scene of the loot screen so its always ready.
var loot_screen_scene = preload("res://scenes/gui/loot_screen.tscn")
# Declares loot_screen and the information souce as null so that they can be populated with info.
var loot_screen = null
var current_source = null
# Self explanatory.
var is_open: bool = false
var just_closed: bool = false

# This makes sure that the loot manager is always on even if the other nodes are paused.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
func open_loot(source) -> void:
	if is_open:
		return
	# Sets the info into the current_source var so other functions can use it.
	current_source = source
	# Kindly informs the code that the barrel is open. How nice.
	is_open = true
	# Makes an instance of the loot screen scene. The next ones add it to the scene as a child
	# and then pause the game.
	loot_screen = loot_screen_scene.instantiate()
	get_tree().root.add_child(loot_screen)
	get_tree().paused = true
	# Gets the item info and populates the loot screen with the inventory.
	loot_screen.populate(source.inventory)

# Individual item taking.
func take_item(item_id: String) -> void:
	# Gets the item info.
	var item = ItemDB.get_item(item_id)
	# If there is nothing there, returns.
	if item.is_empty():
		return
	if PlayerData.add_item(item):
		# Removes the specific item from the source (current loot window) if its there.
		current_source.remove_item(item_id)
		# Passes the barrels inventory array to the loot screen so it knows what to dispaly.
		loot_screen.populate(current_source.inventory)
	
	# Takes all the items in inventory by looping through each one.
func take_all() -> void:
	for item_id in current_source.inventory.duplicate():
		take_item(item_id)
		
# The bool it takes only becomes true when the items loot in emptied by taking its items, not when
# the player manually quits with Q.
func close_loot(was_auto_closed: bool = false) -> void:
	# Resets all vars to defaults once the loot window is closed.
	is_open = false
	current_source = null
	just_closed = was_auto_closed
	get_tree().paused = false
	if loot_screen:
		# Queue_free deletes a node from the scene after it finishes processing, the resets
		# loot_screen to 0.
		loot_screen.queue_free()
		loot_screen = null
