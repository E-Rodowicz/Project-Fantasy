extends Control

@onready var label: Label = $Label

var tween: Tween
var skipped: bool = false

func _ready() -> void:
	GameMenuManager.menus_enabled = false
	# Label fully visible.
	label.modulate.a = 0.0
	
	# Builds a tween sequence of fade in and fade out.
	tween = create_tween()
	tween.tween_interval(1.0)
	# Fades in
	tween.tween_property(label, "modulate:a", 1.0, 2.5)
	# Holds.
	tween.tween_interval(1.5)
	# Fades out.
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	# Goes to main menu scene.
	tween.tween_callback(_go_to_menu)
	
func _unhandled_input(event: InputEvent) -> void:
	if skipped: return
	
	# Skin on any key press
	if event is InputEventKey and event.pressed:
		skipped = true
		if tween:
			tween.kill()
		_go_to_menu()
		
func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/main_menu.tscn")
