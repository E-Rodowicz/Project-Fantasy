extends Control

@onready var cutscene_image: TextureRect = $CutsceneImage

func _ready() -> void:
	cutscene_image.modulate.a = 0.0
	
	var tween: Tween = create_tween()
	tween.tween_interval(6.0)
	tween.tween_property(cutscene_image, "modulate:a", 1.0, 15.0)
	tween.tween_callback(_start_dialogue)
	
func _start_dialogue() -> void:
	pass # Placeholder.
