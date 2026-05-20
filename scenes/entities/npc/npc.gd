extends StaticBody2D

# Btw, @export makes the var visible/editable in the godot edior! The one on the right there >>>
@export var interactable_name: String = "Gary"
var interact_action: String = "Talk"

# A dictionary of all the dialogue and player choices when talking to Gary.
var dialogue: Dictionary = {
	"pages": [
		{
			"speaker": "Gary",
			"text": "Oi! You there! There's a bloody imp living in my attic and he won't budge. I'll pay good coin to whoever gets rid of him."
		},
		{
			"choices": [
				{
					"text": "I'll sort it out for you.",
					"callback": "accept_imp_quest"
				},
				{
					"text": "Not my problem, mate.",
					"callback": "decline_imp_quest"
				},
				{
					"text": "Feck off!",
					"callback": "decline_imp_quest"
				}
			]
		}
	]
}

# This is just a trigger. When triggered, its sends off the above dictionary info to the
# DialogueManager, which handles the rest.
func interact() -> void:
	DialogueManager.open_dialogue(dialogue)
