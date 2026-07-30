extends CanvasLayer

# Gets all vars for the labels and the grid ready when its needed (@onready). $ finds tree paths.
# Reminder that without onready, the script tries to find these nodes the moment the script loads
# up. Sometimes the scene takes time to load up, so if these items (which are the children in that
# scene) tried to be set as vars, the game will crash as they would not have loaded in yet, as the
# scene containing them would not have loaded up yet.
@onready var grid_container = $fullscreen_background/item_grid/GridContainer
@onready var item_name = $fullscreen_background/item_info/item_name
@onready var item_type = $fullscreen_background/item_info/item_type
@onready var item_weight = $fullscreen_background/item_info/item_weight
@onready var carry_weight = $fullscreen_background/item_info/carry_weight_remaining
@onready var item_desc = $fullscreen_background/item_info/item_desc

# The items inventory.
var current_inventory: Array = []
# Which slot is currently selected. Starts at 0, so the first item.
var selected_index: int = 0
# Sets the amount of slots to move in order to simulate a column up/down movement.
const COLUMNS: int = 6

# Makes it always on.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# Clears and opulates inventory of the loot by getting an array input. This happens after any
# change, basically.
func populate(inventory: Array) -> void:
	current_inventory = inventory
	
	# Clears the slots so that slots dont stack on top of each other when updating
	# inventory.
	for child in grid_container.get_children():
		child.queue_free()
		
	# Loop through each inventory item.
	for i in range(inventory.size()):
		# Get the items ID.
		var item_id = inventory[i]
		# Grab a duplicate of the item from the ItemDB.
		var item = ItemDB.get_item(item_id)
		# Creates a new button node in the code - puts the item in the loot window.
		var slot = Button.new()
		# Sets the text to the item name, if no name uses item ID.
		slot.text = item.get("name", item_id)
		# Passes the index of the current item on button press so that it's declared. Note: A
		# signal is a pulse that's sent on a button press, in this case "pressed", which
		# is a button signal built into Godot. "Connect" links that signal to a functions so when
		# button is "pressed", _on_slot_pressed runs. bind(i) sends the index across that the the
		# function knows what button was pressed.
		slot.pressed.connect(_on_slot_pressed.bind(i))
		# Adds item to grid, which automatically positions it.
		grid_container.add_child(slot)

	# If loot screen is empty after taking item, closes loot screen.
	if inventory.is_empty():
		LootManager.close_loot(true)
		return
	
	# Clamps the new index (after the loot screen change) so that game doesnt explode.
	selected_index = clamp(selected_index, 0, inventory.size() - 1)
	_update_selection()

# Fetches the data to fill the info box upon item selection.
func _update_selection() -> void:
	if current_inventory.is_empty():
		return
	
	# Get's item id from the loot screen then sends that info to ItemDB to get
	# the item info.
	var item_id = current_inventory[selected_index]
	var item = ItemDB.get_item(item_id)
	
	# Updates the info panel. The second string is the default if info isnt there. Note: str() 
	# converts the data into a string so that it can be connected with other vars.
	item_name.text = item.get("name", "Unknown")
	item_type.text = item.get("type", "")
	item_weight.text = "Weight: " + str(item.get("weight", "0"))
	item_desc.text = item.get("desc", "")
	
	# Gets players carry weight from playerData and shows it alongside max carry weight.
	var current_weight = PlayerData.get_total_weight()
	carry_weight.text = str(current_weight) + " / " + str(PlayerData.max_carry_weight)
	
# Sets the new index when a button is clicked and refreshes right panel.
func _on_slot_pressed(index: int) -> void:
	selected_index = index
	_update_selection()
	
# Inputs and unhandled inputs to avoid errors.
func _unhandled_input(event: InputEvent) -> void:
	# Makes sure other inputs don't crash the game.
	if not event is InputEventKey:
		return
	
	# Loot screen navigation.
	if event.is_action_pressed("ui_up") and not event.is_echo():
		_navigate(-COLUMNS)
	if event.is_action_pressed("ui_down") and not event.is_echo():
		_navigate(COLUMNS)
	if event.is_action_pressed("ui_left") and not event.is_echo():
		_navigate(-1)
	if event.is_action_pressed("ui_right") and not event.is_echo():
		_navigate(1)
	if event.is_action_pressed("interact") and not event.is_echo():
		LootManager.take_item(current_inventory[selected_index])
	if event.is_action_pressed("precise_move") and not event.is_echo():
		LootManager.take_all()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		LootManager.close_loot(false)
	
func _navigate(direction: int) -> void:
	# Note1: this was the code used before I used modulo to block left/right movement by using W/S.
	# Note2 : Clamp gives bounds to the range of the var. It can never go above its actual number or
	# below 0, which avoids crashes. Adds direction to the current index and clamps it to be within
	# bounds. After, it refreshes the info panel. Bascially handles loot movement. When it comes to
	# the clamp below, think of it like this: clamp(current index, min, max). If there are 4 items
	# in inventory, calling inventory size would give us 4, hence the -1 at the end, as we are
	# counting from 0, so now it had the correct info of 4 items, the first having the index of 0
	# and the fourth item the index of 3. The first data, the value, is current index plus the
	# chosen int direction (Which is -1, 1, -COLUMNS(-6) or COLUMNS(6). So say you are on index 2,
	# which would be row 1 columns 2, and you press right. As the direction of right is +1, the
	# program does 2 + 1 = 3, which gives us the new index. Clamp is essential here as pressing
	# up on the top row or left on the first item would give us a negative, which would crash
	# the program, while pressing down on the bottom row would exceed the array size. Keep in mind
	# that arrays cannot be clamped, just plain ints or floats. We are giving a limit to what we can
	# get from that int, hence clamp(value, min, max).
	
	#The Old Code (how dramatic):
	#selected_index = clamp(selected_index + direction, 0, current_inventory.size() - 1)
	#_update_selection()
	
	# Declares the move, which is the current index plus direction.
	var new_index = selected_index + direction
	
	# Blocks left and right movement if it would mean a row change. Modulo is used as every start
	# of a row gives us an even number, so any division reminder will be 0. index & COLUMNS == 0
	# asks the program "is this index at the left edge of a row?"
	# This is right movement. This checks new_index, the place where we would go to, to see if going
	# right would get us to a new row (So the left edge of a row). If yes, it blocks it.
	if direction == 1 and (new_index % COLUMNS == 0):
		return
	# This is the left movement check. If we move left while on index 6 (So first column of row 2),
	# the move is blocked. Same for other left-most indexs. Index 6 was just an example. jeez.
	if direction == -1 and (selected_index % COLUMNS == 0):
		return
	
	# Blocks the move if the index goes below 0 or if the index gets bigger or equal to than the
	# size of the loot window's inventory (Remember, we can't equal inventory size as we count from
	# 0). This block up/down movement if they are not possible.
	if new_index < 0 or new_index >= current_inventory.size():
		return
	
	# Updates the current index if it passes the above if statements.
	selected_index = new_index
	_update_selection()
