extends CanvasLayer

@onready var choices_container = $NinePatchRect/choices_container

var choice_labels: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
func populate(interactables: Array) -> void:
	# Clears all child nodes in ninepatch so they return to defaults.
	for child in choices_container.get_children():
		child.queue_free()
	# Same for choice_labels array.
	choice_labels.clear()

	# Counts how many times each name appears.
	var name_counts: Dictionary = {}
	for entry in interactables:
		# Adds the entry's name to the n var.
		var n = entry["action"] + ": " + entry["name"]
		# This is what does the counting. Example: First barrel in loop gets found, nut as there is
		# no barrel in the name_count dictionary yet, it retuns 0 (Number next to n). After that, it
		# adds 1 to whatever was returned, so name_counts now holds 1 Barrel. Second barrel gets
		# founds, returns 1, and program still adds 1, so now we have two barrels. The name of the
		# item is the key in name_counts, with the value being how many times it loops to through
		# the same name. .get(n, 0) is a dictionary method which reads values by key. n is the key
		# that it looks up, which is a string like "Barrel". 0 is just default value to return if it
		# doesnt find anything. As earlier we decalred var n as the entry's name, that is its key.
		# It is saying "look up barrel (or n) in name_counts, if its not there, return 0". After
		# which, we add 1, as the whole point is that the barrel is already in interactables
		# if we got to this points (As this func was passed the interactables array).
		name_counts[n] = name_counts.get(n, 0) + 1

	# Builds labels. Uses size of interactables.
	for i in range(interactables.size()):
		# Declares which interactables it is as per the loop.
		var entry = interactables[i]
		# Makes new label.
		var label = Label.new()
		# Declares a name using the entry's name.
		var display_name = entry["action"] + ": " + entry["name"]
		
		# If the name appears more than once, adds direction. Shows direction label only if there
		# are more than 1 of the same item.
		if name_counts[display_name] > 1:
			display_name += " (" + _direction_name(entry["direction"]) + ")"
		
		# Sets the text of label with the display name.
		label.text = display_name
		choices_container.add_child(label)
		choice_labels.append(label)
		
	update_selection(0)

# Updates the selected with the colour yellow, makes the others white. Temporary as I will have GUI
# graphics.
func update_selection(index: int) -> void:
	for i in range(choice_labels.size()):
		if i == index:
			choice_labels[i].modulate = Color.YELLOW
		else:
			choice_labels[i].modulate = Color.WHITE
			
# Gives a certain string according to direction.
func _direction_name(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return "Here"
	elif dir == Vector2(0, -1):
		return "North"
	elif dir == Vector2(0, 1):
		return "South"
	elif dir == Vector2(-1, 0):
		return "West"
	elif dir == Vector2(1, 0):
		return "East"
	elif dir == Vector2(-1, -1):
		return "North-West"
	elif dir == Vector2(1, -1):
		return "North-East"
	elif dir == Vector2(-1, 1):
		return "South-West"
	elif dir == Vector2(1, 1):
		return "South-East"
	return ""
	
# Control for the popup window.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.is_action_pressed("ui_up") and not event.is_echo():
		InteractManager.navigate(-1)
	if event.is_action_pressed("ui_down") and not event.is_echo():
		InteractManager.navigate(1)
	if event.is_action_pressed("interact") and not event.is_echo():
		InteractManager.confirm_selection()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		InteractManager.close_popup()
