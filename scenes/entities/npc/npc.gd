extends StaticBody2D

# Btw, @export makes the var visible/editable in the godot edior! The one on the right there >>>
@export var interactable_name: String = "Gary"
var interact_action: String = "Talk"

@export var dialogue_file: String = "gary"

func interact() -> void:
	var dialogue: Dictionary = DialogueManager.load_dialogue(dialogue_file)
	if dialogue.is_empty():
		return
	DialogueManager.open_dialogue(dialogue)
