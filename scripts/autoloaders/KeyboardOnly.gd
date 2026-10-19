extends Node

# The game is keyboard-only. This swallows every mouse event before the GUI sees it, so the
# wheel can't scroll lists and clicks can't press anything, on every screen.
func _ready() -> void:
	# Keeps blocking while the game is paused, e.g. in the menu.
	process_mode = Node.PROCESS_MODE_ALWAYS

# _input runs before the GUI handles anything. InputEventMouse covers clicks, the wheel and
# movement, and set_input_as_handled() stops them going any further.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()
