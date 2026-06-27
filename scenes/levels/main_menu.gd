extends Control

@onready var choice_list: ChoiceList = $ChoiceList

func _ready() -> void:
	# GameMenuManager.menus_enabled = false
	modulate.a = 0.0
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, 1.0)

	choice_list.set_choices(["New Game", "Load Game", "Options", "Quit"])

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.is_echo():
		return
	if event.is_action_pressed("ui_up"):
		choice_list.navigate(-1)
	elif event.is_action_pressed("ui_down"):
		choice_list.navigate(1)
	elif event.is_action_pressed("interact"):
		choice_list.glow_confirm(_on_confirmed)

func _on_confirmed() -> void:
	match choice_list.current_index:
		0: get_tree().change_scene_to_file("res://scenes/levels/intro_cutscene.tscn")
		1: pass
		2: pass
		3: get_tree().quit()
