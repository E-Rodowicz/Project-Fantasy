# This just means its UI.
extends CanvasLayer

# @onready delays the assignment of information until the scene is ready. Otherwise it would look
# into the nodes immideitely and crash as the info from the dictionaries is not there yet.
@onready var speaker_label = $NinePatchRect/speaker_label
@onready var text_label = $NinePatchRect/VBoxContainer/text_label
@onready var choices_container = $NinePatchRect/VBoxContainer/choices_container

var choice_labels: Array = []

# These two functions just push the text into the label and textbox.
func set_speaker(speaker_name: String) -> void:
	speaker_label.text = speaker_name

func set_text(text: String) -> void:
	text_label.text = text

# Shows choices
func show_choices(choices: Array, selected_index: int) -> void:
	# This clears old choices so they dont show on top of new ones.
	for child in choices_container.get_children():
		child.queue_free()
	choice_labels.clear()
	
	# Makes the choices vbox visible and loops through each choice. It loops as there can be any
	# amount of choices.
	choices_container.visible = true
	
	for i in range(choices.size()):
		var label = Label.new()
		label.text = str(i + 1) + ".  " + choices[i]["text"]
		choices_container.add_child(label)
		choice_labels.append(label)
	
	update_selection(selected_index)

# Loops through choices, making the picked option yellow, the other's white.
func update_selection(selected_index: int) -> void:
	for i in range(choice_labels.size()):
		if i == selected_index:
			choice_labels[i].modulate = Color.YELLOW
		else:
			choice_labels[i].modulate = Color.WHITE

# Hides choices when normal dialogue is showing.
func hide_choices() -> void:
	choices_container.visible = false
