extends CanvasLayer

const TAB_TEXT_COLOUR: Color = Color.WHITE
const TAB_TEXT_SELECTED_COLOUR: Color = Color("ffc439")
const TAB_FADE_TIME: float = 0.15
const BACKGROUND_FADE_TIME: float = 0.15

# --- SLIDE ---
const PIXEL_SCALE: int = 4
const SLIDE_IN_TIME: float = 0.25
const SLIDE_OUT_TIME: float = 0.18
# How long a tab's screen takes to fade in when shown.
const SCREEN_FADE_TIME: float = 0.12

@onready var menu_frame: TextureRect = $menu_frame
@onready var tab_select: AnimatedSprite2D = $menu_frame/tabs/tab_select
@onready var tab_character: Control = $menu_frame/tabs/tab_character
@onready var tab_inventory: Control = $menu_frame/tabs/tab_inventory
@onready var tab_journal: Control = $menu_frame/tabs/tab_journal
@onready var tab_map: Control = $menu_frame/tabs/tab_map
@onready var screen_holder: Control = $menu_frame/content_area/screen_holder

# One background per tab, in tab order: Character, Inventory, Journal, Map.
# An empty slot falls back to the texture set on menu_frame in the editor.
@export var tab_backgrounds: Array[Texture2D] = []

var default_background: Texture2D = null
# Holds the old background on top of the new one and fades away.
var background_fade: TextureRect = null
var background_tween: Tween = null
var character_scene: PackedScene = preload("res://scenes/gui/character_screen.tscn")
var inventory_scene: PackedScene = preload("res://scenes/gui/inventory_screen.tscn")
var journal_scene: PackedScene = preload("res://scenes/gui/journal_screen.tscn")

var tabs: Array[Control] = []
var tab_labels: Array[Label] = []
var screens: Array[Control] = []
var tab_sides: Array[int] = []
var tab_in_screen: Array[bool] = []
var current_tab: int = -1

var select_offset: Vector2 = Vector2.ZERO
# One selector per tab, faded in and out. tab_select itself is just the template.
var tab_selects: Array[AnimatedSprite2D] = []
var tab_select_tweens: Array[Tween] = []

var slide_tween: Tween = null
# False while sliding out, so the menu ignores keys on its way off screen.
var screen_fade_tween: Tween = null
var accepting_input: bool = true
# Fully above the screen: the frame's own height, negative.
var hidden_native_y: int = 0
# Where the frame rests when open, read from its position in the editor.
var shown_native_y: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	default_background = menu_frame.texture
	background_fade = TextureRect.new()
	background_fade.size = menu_frame.size
	background_fade.modulate.a = 0.0
	menu_frame.add_child(background_fade)
	# Index 0 draws first among the children, so it sits under the tabs and screens.
	menu_frame.move_child(background_fade, 0)
	tabs = [tab_character, tab_inventory, tab_journal, tab_map]
	for tab: Control in tabs:
		var label: Label = tab.get_node("label") as Label
		label.add_theme_color_override("font_color", TAB_TEXT_COLOUR)
		tab_labels.append(label)

	select_offset = tab_select.position - tab_character.position
	
	for tab: Control in tabs:
		# duplicate() copies the node with all its settings, including its SpriteFrames.
		var selector: AnimatedSprite2D = tab_select.duplicate() as AnimatedSprite2D
		selector.position = tab.position + select_offset
		selector.modulate.a = 0.0
		tab_select.get_parent().add_child(selector)
		# Index 0 draws first, so the selector stays behind the tab text.
		selector.get_parent().move_child(selector, 0)
		selector.play("default")
		tab_selects.append(selector)
		tab_select_tweens.append(null)
	tab_select.visible = false	

	screens = [
		_add_screen(character_scene.instantiate() as Control),
		_add_screen(inventory_scene.instantiate() as Control),
		_add_screen(journal_scene.instantiate() as Control),
		_add_screen(_make_placeholder("Coming soon!")),
	]

	for i: int in range(screens.size()):
		tab_sides.append(GameMenuManager.Side.LEFT)
		tab_in_screen.append(false)

	shown_native_y = roundi(menu_frame.position.y / PIXEL_SCALE)
	hidden_native_y = -int(menu_frame.size.y)
	menu_frame.position.y = hidden_native_y * PIXEL_SCALE

# --- SLIDING ---
func slide_in() -> void:
	accepting_input = true
	screen_holder.process_mode = Node.PROCESS_MODE_INHERIT
	_slide_frame(shown_native_y, SLIDE_IN_TIME, Tween.EASE_OUT)

# on_finished runs once the frame is off screen. A Callable is a function passed around as a value,
# so GameMenuManager can say what happens next without game_menu needing to know.
func slide_out(on_finished: Callable) -> void:
	accepting_input = false
	# Switches off the screens' input while leaving them visible for the slide.
	screen_holder.process_mode = Node.PROCESS_MODE_DISABLED
	_slide_frame(hidden_native_y, SLIDE_OUT_TIME, Tween.EASE_IN)
	slide_tween.tween_callback(on_finished)

# Starts from wherever the frame is now, so reopening mid-slide reverses smoothly. kill() also
# cancels the old tween's callback, so a reopened menu can't be deleted a moment later.
func _slide_frame(target_native_y: int, duration: float, ease_type: Tween.EaseType) -> void:
	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()
	var start_native_y: float = menu_frame.position.y / PIXEL_SCALE
	slide_tween = create_tween()
	slide_tween.tween_method(
		_set_frame_native_y, start_native_y, float(target_native_y), duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)

# Rounds to a whole native pixel, then scales, so the art never lands between its own pixels.
func _set_frame_native_y(native_y: float) -> void:
	menu_frame.position.y = roundf(native_y) * PIXEL_SCALE

# --- SCREENS ---
func _add_screen(screen: Control) -> Control:
	screen_holder.add_child(screen)
	screen.visible = false
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	if screen.has_signal("side_exited"):
		screen.connect("side_exited", _on_side_exited)
	return screen

func _make_placeholder(text: String) -> Control:
	var label: Label = Label.new()
	label.text = text
	return label

func _uses_split(screen: Control) -> bool:
	return screen.has_method("enter_side")

func switch_tab(tab_index: int) -> void:
	var is_first_show: bool = current_tab == -1
	if tab_index == current_tab:
		return

	if current_tab != -1:
		screens[current_tab].visible = false
		screens[current_tab].process_mode = Node.PROCESS_MODE_DISABLED

	current_tab = tab_index
	var screen: Control = screens[current_tab]
	screen.visible = true
	screen.process_mode = Node.PROCESS_MODE_INHERIT
	_fade_in_screen(screen)
	if screen.has_method("on_tab_shown"):
		screen.call("on_tab_shown")

	_update_background(not is_first_show)
	_update_tab_visuals()
	_update_side_visuals()

# --- VISUALS ---
# The menu opening on its first tab just sets the background. Switching tabs crossfades.
func _update_background(animate: bool) -> void:
	var texture: Texture2D = default_background
	if current_tab < tab_backgrounds.size() and tab_backgrounds[current_tab] != null:
		texture = tab_backgrounds[current_tab]
	if texture == menu_frame.texture:
		return

	if background_tween != null and background_tween.is_valid():
		background_tween.kill()

	if not animate:
		menu_frame.texture = texture
		background_fade.modulate.a = 0.0
		return

	background_fade.texture = menu_frame.texture
	background_fade.modulate.a = 1.0
	menu_frame.texture = texture
	background_tween = create_tween()
	background_tween.tween_property(background_fade, "modulate:a", 0.0, BACKGROUND_FADE_TIME)

func _update_tab_visuals() -> void:
	for i: int in range(tabs.size()):
		_fade_tab(i, i == current_tab)

# Fades the tab's selector and text colour together. Killing the old tween first means a fade
# starts from wherever the previous one had reached.
func _fade_tab(index: int, is_current: bool) -> void:
	var old_tween: Tween = tab_select_tweens[index]
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()

	var target_alpha: float = 1.0 if is_current else 0.0
	var target_colour: Color = TAB_TEXT_SELECTED_COLOUR if is_current else TAB_TEXT_COLOUR

	var tween: Tween = create_tween()
	# By default a tween runs its steps one after another. set_parallel(true) runs them together.
	tween.set_parallel(true)
	tween.tween_property(tab_selects[index], "modulate:a", target_alpha, TAB_FADE_TIME)
	# A theme override can be tweened like any property, using the path the Inspector shows for it.
	tween.tween_property(tab_labels[index], "theme_override_colors/font_color", target_colour, TAB_FADE_TIME)
	tab_select_tweens[index] = tween

# Tells a gem screen which side is selected and whether the player is inside it, so the screen
# can show it with its frames. Screens without this function are left alone.
func _update_side_visuals() -> void:
	var screen: Control = screens[current_tab]
	if not _uses_split(screen):
		return
	if screen.has_method("show_side_selection"):
		screen.call("show_side_selection", tab_sides[current_tab], tab_in_screen[current_tab])

# --- INPUT ---
func _unhandled_input(event: InputEvent) -> void:
	if not accepting_input:
		return
	if not event is InputEventKey:
		return
	if event.is_echo():
		return
	if current_tab == -1:
		return
	if not _uses_split(screens[current_tab]):
		return
	if tab_in_screen[current_tab]:
		return

	if event.is_action_pressed("ui_left"):
		_select_side(GameMenuManager.Side.LEFT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_select_side(GameMenuManager.Side.RIGHT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		_confirm_side()
		get_viewport().set_input_as_handled()

func _select_side(side: int) -> void:
	if side == tab_sides[current_tab]:
		return
	tab_sides[current_tab] = side
	_update_side_visuals()

func _confirm_side() -> void:
	tab_in_screen[current_tab] = true
	screens[current_tab].call("enter_side", tab_sides[current_tab])
	_update_side_visuals()

func _on_side_exited() -> void:
	tab_in_screen[current_tab] = false
	_update_side_visuals()
# Every tab fades in when shown. A screen with its own fade-in sets fades_itself = true and is
# left alone. get() reads a variable by name and returns null if the screen doesn't have it, so
# screens without the flag need nothing.

func _fade_in_screen(screen: Control) -> void:
	if screen_fade_tween != null and screen_fade_tween.is_valid():
		screen_fade_tween.kill()
	if screen.get("fades_itself") == true:
		screen.modulate.a = 1.0
		return
	screen.modulate.a = 0.0
	screen_fade_tween = create_tween()
	screen_fade_tween.tween_property(screen, "modulate:a", 1.0, SCREEN_FADE_TIME)
