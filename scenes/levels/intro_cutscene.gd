extends Control

@onready var cutscene_image: TextureRect = $CutsceneImage

func _ready() -> void:
	GameMenuManager.menus_enabled = false
	cutscene_image.modulate.a = 0.0
	
	var tween: Tween = create_tween()
	tween.tween_interval(0.1)
	tween.tween_property(cutscene_image, "modulate:a", 1.0, 0.1)
	tween.tween_callback(_start_dialogue)
	pass
	
func _start_dialogue() -> void:
	var dialogue: Dictionary = DialogueManager.load_dialogue("narrator")
	DialogueManager.open_dialogue(dialogue)
