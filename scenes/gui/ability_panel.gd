extends Control

# The character screen's abilities side. Three big tree buttons fill the panel. Entering one fades
# the other two away and slides it up to sit half off the top, where it becomes the tree's title.
# character_screen passes it the keys while the abilities side is entered.
class_name AbilityPanel

enum PanelState {
	CHOOSING,
	OPENING,
	TREE_OPEN,
	CLOSING
}

const SELECTED_COLOUR: Color = Color.YELLOW
# The open tree's title is a structural marker, not the cursor, so it uses gold.
const TITLE_COLOUR: Color = Color("ffc439")
const FADE_TIME: float = 0.12
const SLIDE_TIME: float = 0.25
# How many pixels above true centre the title sits once its button has slid up.
const TITLE_RAISE: int = 4

@onready var tree_buttons: Array[NinePatchRect] = [
	$red_button,
	$green_button,
	$blue_button,
]
@onready var tree_labels: Array[Label] = [
	$red_button/label,
	$green_button/label,
	$blue_button/label,
]

var state: PanelState = PanelState.CHOOSING
var selected_tree: int = 0
var cursor_visible: bool = false
# Where each button and its label sit while choosing, taken from the scene.
var button_home_y: Array[float] = []
var label_home_y: Array[float] = []
var slide_tween: Tween = null

func _ready() -> void:
	# Hides anything outside the panel's rect, which is what cuts off the top half of the
	# chosen button once it slides up.
	clip_contents = true
	for i: int in range(tree_buttons.size()):
		button_home_y.append(tree_buttons[i].position.y)
		label_home_y.append(tree_labels[i].position.y)
	_update_highlight()

# --- INPUT ---
# Returns true if it used the key. Q while choosing returns false, so character_screen
# knows to back out of the side.
func handle_input(event: InputEvent) -> bool:
	match state:
		PanelState.CHOOSING:
			return _input_choosing(event)
		PanelState.TREE_OPEN:
			return _input_tree(event)
	# Mid-animation: Q is swallowed so it can't exit the side halfway through a slide.
	return event.is_action_pressed("ui_cancel")

func _input_choosing(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_up"):
		selected_tree = maxi(0, selected_tree - 1)
		_update_highlight()
		return true
	if event.is_action_pressed("ui_down"):
		selected_tree = mini(tree_buttons.size() - 1, selected_tree + 1)
		_update_highlight()
		return true
	if event.is_action_pressed("interact"):
		_open_tree()
		return true
	return false

func _input_tree(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		_close_tree()
		return true
	return false

# --- OPEN / CLOSE ---
# Each tween_method runs after the one before it, so this plays as: fade, slide, done.
func _open_tree() -> void:
	state = PanelState.OPENING
	_update_highlight()
	_kill_tween()
	slide_tween = create_tween()
	slide_tween.tween_method(_apply_fade, 1.0, 0.0, FADE_TIME)
	slide_tween.tween_method(_apply_slide, 0.0, 1.0, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_tween.tween_callback(_on_opened)

func _on_opened() -> void:
	state = PanelState.TREE_OPEN
	_update_highlight()

func _close_tree() -> void:
	state = PanelState.CLOSING
	_update_highlight()
	_kill_tween()
	slide_tween = create_tween()
	slide_tween.tween_method(_apply_slide, 1.0, 0.0, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_tween.tween_method(_apply_fade, 0.0, 1.0, FADE_TIME)
	slide_tween.tween_callback(_on_closed)

func _on_closed() -> void:
	state = PanelState.CHOOSING
	_update_highlight()

# Snaps straight back to the three buttons with no animation, cursor on the first one. Called
# when the player leaves the tab, so it always opens fresh.
func reset() -> void:
	_kill_tween()
	state = PanelState.CHOOSING
	# Slide and fade both act on whichever button is selected, so they must run before the
	# selection changes, or the old button would be left slid up or faded out.
	_apply_slide(0.0)
	_apply_fade(1.0)
	selected_tree = 0
	_update_highlight()

func _kill_tween() -> void:
	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()

# --- ANIMATION STEPS ---
# Fades every button except the chosen one. Modulate passes down to children, so each
# button's label fades with it.
func _apply_fade(alpha: float) -> void:
	for i: int in range(tree_buttons.size()):
		if i != selected_tree:
			tree_buttons[i].modulate.a = alpha

# t = 0 is the button at home, t = 1 is half off the top of the panel. Only the chosen button
# ever moves, so the others are always still at home.
func _apply_slide(t: float) -> void:
	var button: NinePatchRect = tree_buttons[selected_tree]
	var label: Label = tree_labels[selected_tree]
	var hidden_height: int = floori(button.size.y / 2.0)
	var button_open_y: float = -hidden_height
	# Shifting the label down by half the hidden part puts its centre in the middle of the
	# part still showing.
	var label_open_y: float = label_home_y[selected_tree] + floori(hidden_height / 2.0) - TITLE_RAISE
	button.position.y = roundf(lerpf(button_home_y[selected_tree], button_open_y, t))
	label.position.y = roundf(lerpf(label_home_y[selected_tree], label_open_y, t))

# --- HIGHLIGHT ---
func set_cursor_visible(show_cursor: bool) -> void:
	cursor_visible = show_cursor
	_update_highlight()

# Choosing: the selected button's text is yellow, but only while the side is entered.
# Opening or open: the chosen button's text turns gold as the title.
func _update_highlight() -> void:
	var choosing: bool = state == PanelState.CHOOSING or state == PanelState.CLOSING
	for i: int in range(tree_labels.size()):
		var colour: Color = Color.WHITE
		if i == selected_tree:
			if choosing and cursor_visible:
				colour = SELECTED_COLOUR
			elif not choosing:
				colour = TITLE_COLOUR
		UiFade.label_colour(tree_labels[i], colour)
