extends Control

@onready var cutscene_image: TextureRect = $CutsceneImage

func _ready() -> void:
	cutscene_image.modulate.a = 0.0
	
	var tween: Tween = create_tween()
	tween.tween_interval(0.1)
	tween.tween_property(cutscene_image, "modulate:a", 1.0, 0.1)
	tween.tween_callback(_start_dialogue)
	pass
	
func _start_dialogue() -> void:
	var intro_dialogue: Dictionary = {
		"pages": [
			{
				"speaker": "Narrator",
				"text": "The ancient halls stretch endlessly into shadow..."
			},
			{
				"speaker": "Narrator",
				"text": "A presence stirs in the depths below."
			},
			{
				"speaker": "Narrator",
				"text": "Your story begins here."
			}
		]
	}
	DialogueManager.open_dialogue(intro_dialogue)
