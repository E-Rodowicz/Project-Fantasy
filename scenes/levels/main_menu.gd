extends Control

@onready var new_game_button: Button = $VBoxContainer/NewGame
@onready var load_game_button: Button = $VBoxContainer/LoadGame
@onready var options_button: Button = $VBoxContainer/Options
@onready var quit_button: Button = $VBoxContainer/Quit

func _ready() -> void:
	# Fades in the menu from black.
	modulate.a = 0.0
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 1.0)
	
	# Connect each button's "pressed" signal to its handler
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Gives the first button keyboard focus so arrow keys work immediately
	new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/intro_cutscene.tscn")


func _on_load_game_pressed() -> void:
	pass  # Placeholder


func _on_options_pressed() -> void:
	pass  # Placeholder


func _on_quit_pressed() -> void:
	get_tree().quit()
