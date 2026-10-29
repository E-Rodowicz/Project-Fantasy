extends Control

# The character screen's abilities side. Three big tree buttons fill the panel. Entering one fades
# the other two away and slides it up to sit half off the top as the tree's title, then that
# tree's abilities fade in below it. character_screen passes it the keys while the side is entered.
class_name AbilityPanel

enum PanelState {
	CHOOSING,
	OPENING,
	TREE_OPEN,
	CLOSING,
	PLACING
}

const SELECTED_COLOUR: Color = Color.YELLOW
# The open tree's title is a structural marker, not the cursor, so it uses gold.
const TITLE_COLOUR: Color = Color("ffc439")
const FADE_TIME: float = 0.12
# How long the open tree's contents (icons, locks, cursor) take to fade in or out.
const TREE_FADE_TIME: float = 0.07
const SLIDE_TIME: float = 0.25
# How many pixels above true centre the title sits once its button has slid up.
const TITLE_RAISE: int = 4
# The tree each button opens, matching the "tree" field in AbilityDB, in button order.
const TREE_IDS: Array[String] = ["red", "green", "blue"]
const GREYSCALE_SHADER: Shader = preload("res://shaders/greyscale.gdshader")

# --- TREE LAYOUT (panel pixels) ---
const ICON_SIZE: int = 18
# Each grid cell is this wide and tall. The icon sits centred in its cell.
const CELL_SIZE: Vector2i = Vector2i(24, 24)
# Even, so two abilities in the middle two columns are centred in the panel.
const GRID_COLUMNS: int = 6
# Where the grid's first row starts, below the slid-up title.
const TREE_TOP: int = 34
# Empty pixels between an icon and the cursor box around it.
const CURSOR_GAP: int = 1
# How far the selected tree button rises while choosing, in pixels.
const POP_HEIGHT: int = 1
# Fully transparent, for fading things out.
const HIDDEN: Color = Color(1, 1, 1, 0)
# Nudges the hotbar key number from the icon's bottom-right corner, in pixels.
const BADGE_NUDGE: Vector2 = Vector2(-15, -7)

# --- BUYING ---
# The purchase flash: far brighter than the hotbar's, then a slower settle.
const BUY_FLASH_COLOUR: Color = Color(4.0, 4.0, 4.0, 1.0)
const BUY_FLASH_POP_TIME: float = 0.04
const BUY_FLASH_SETTLE_TIME: float = 0.4
# The purchase pop: up fast, then a bouncy settle back to normal size.
const BUY_POP_SCALE: float = 1.3
const BUY_POP_UP_TIME: float = 0.06
const BUY_POP_SETTLE_TIME: float = 0.3
# The ring that bursts out of the cursor box when you buy something.
const BURST_COLOUR: Color = Color("ffc439")
const BURST_TIME: float = 0.35
# How many pixels the ring travels outward on each side before it's gone.
const BURST_GROWTH: int = 8
# --- REJECTING ---
const REJECT_COLOUR: Color = Color(0.95, 0.048, 0.0, 1.0)
# The shake, in pixels from rest: left, right, left, home. One step every SHAKE_STEP_TIME.
const SHAKE_STEPS: Array[int] = [-1, 1, -1, 0]
const SHAKE_STEP_TIME: float = 0.05
# How many times the red reject animation plays, like on the hotbar.
const REJECT_PLAYS: int = 2
# The floating message: how far it rises, how long that takes, and how long it stays solid first.
const FLOAT_DISTANCE: int = 10
const FLOAT_TIME: float = 1.2
const FLOAT_HOLD_TIME: float = 0.4
# Pixels between the top of the icon and the bottom of the message when it appears.
const FLOAT_GAP: int = 2
# The cost number's offset from the icon's top-left: the hotbar badge's nudge, mirrored.
const COST_NUDGE: Vector2 = Vector2(8, 1)
# After a purchase, the cost waits for the flash to peak, then fades.
const COST_FADE_DELAY: float = 0.1
const COST_FADE_TIME: float = 0.3
# The cursor box's glow, the same as the skill points text.
const CURSOR_PULSE_SPEED: float = 0.5
const CURSOR_PULSE_MIN: float = 0.55
const FLOAT_OUTLINE_SIZE: int = 4
# --- POINTS INVESTED ---
# Pixels between a tree button's bottom edge and its points text.
const BUTTON_POINTS_INSET: int = 4
# Pixels in from the open tree's bottom-right corner.
const CORNER_POINTS_INSET: int = 3
const POINTS_OUTLINE_SIZE: int = 5
const POINTS_SCALE: float = 0.75
# --- HOTBAR PLACING ---
# Above the hotbar and the menu, both on layer 1, and below the info window on 18.
const PLACE_LAYER: int = 5
# Flying between the panel and the hotbar, moving along the hotbar, and settling into a slot.
const PLACE_FLY_TIME: float = 0.25
const PLACE_MOVE_TIME: float = 0.12
const PLACE_SETTLE_TIME: float = 0.15
# The floating ability pulses between normal and this bright.
const PLACE_PULSE_SPEED: float = 1
const PLACE_PULSE_MAX: float = 1.4
# Over its own slot it pulses red instead: green and blue drop to this, leaving red.
const PLACE_REMOVE_TINT: float = 0.3

# Shown instead of an ability's icon while it's locked, one per tree. Same size as an ability icon.
@export var red_lock_texture: Texture2D = null
@export var green_lock_texture: Texture2D = null
@export var blue_lock_texture: Texture2D = null
# The cost number on abilities you haven't bought: a bright version of the tree's colour, with a
# dark version as its outline.
@export var red_cost_colour: Color = Color("ff7a6b")
@export var red_cost_outline: Color = Color("4a0d0d")
@export var green_cost_colour: Color = Color("8cff7a")
@export var green_cost_outline: Color = Color("0d3d12")
@export var blue_cost_colour: Color = Color("7ac4ff")
@export var blue_cost_outline: Color = Color("0d2147")

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
# Where the chosen button was when its slide began, popped or not.
var slide_start_y: float = 0.0

# --- OPEN TREE ---
# Everything inside an open tree is built in code. tree_view fades in and out as one, so its
# children (icons, cursor, charge animation) fade with it.
var tree_view: Control = null
var icon_holder: Control = null
var charge_sprite: AnimatedSprite2D = null
var greyscale_material: ShaderMaterial = null
# The open tree's abilities, their icons and their grid positions, all in the same order.
var node_ids: Array[String] = []
var node_icons: Array[TextureRect] = []
var node_slots: Array[Vector2i] = []
# Each ability's cursor box, hotbar key number, and the key that number currently shows.
var node_boxes: Array[ReferenceRect] = []
var node_badges: Array[Label] = []
var node_badge_keys: Array[String] = []
# Each ability's lock texture, or null if it isn't locked. The info window copies it.
var node_locks: Array[Texture2D] = []
# Each ability's lock image. Always there, just hidden when the ability isn't locked.
var node_lock_rects: Array[TextureRect] = []
# Each ability's cost number, hidden once it's bought.
var node_costs: Array[Label] = []
var selected_node: int = 0
# How long E has been held on an ability, or -1 when it isn't being held.
var info_hold_timer: float = -1.0
var charge_started: bool = false
var cursor_pulse_time: float = 0.0
# The floating message on screen, if any. A new rejection replaces it.
var reject_text: Label = null
# Each tree button's "Points invested" text, in button order.
var button_points: Array[Label] = []
# The same count in the open tree's top-right corner.
var corner_points: Label = null
# The floating copy lives on its own layer, in screen pixels.
var place_layer: CanvasLayer = null
var place_ghost: TextureRect = null
# A copy of an ability knocked off the hotbar, while it fades.
var place_displaced: TextureRect = null
# Hotbar slots whose real ability is hidden until the change is made.
var place_hidden: Array[int] = []
# The slot whose real ability is sliding across to make room, or -1, and the tween sliding it.
var place_slid: int = -1
var place_slide_tween: Tween = null
# Slots the hotbar should change at once rather than fade, because something was carried there.
var place_snap: Array[int] = []
var place_tween: Tween = null
var place_slot: int = 1
# True while flying or settling, so keys wait until it arrives.
var place_busy: bool = false
# True between pressing E and the change being made.
var place_settling: bool = false
# True while it settles onto its own slot on the way to being taken off.
var place_removing: bool = false
var place_pulse_time: float = 0.0

func _ready() -> void:
	for i: int in range(tree_buttons.size()):
		button_home_y.append(tree_buttons[i].position.y)
		label_home_y.append(tree_labels[i].position.y)
	_build_tree_view()
	_build_points_labels()
	_build_place_overlay()
	_update_highlight()

# The parts of the open tree that never change: the holder the icons go in, the cursor box and
# the charge animation. Added in that order, so the cursor and charge draw on top of the icons.
func _build_tree_view() -> void:
	tree_view = Control.new()
	tree_view.modulate.a = 0.0
	add_child(tree_view)

	icon_holder = Control.new()
	tree_view.add_child(icon_holder)

	# The hotbar's own charge animation, so holding E here looks exactly like holding a hotbar key.
	charge_sprite = AnimatedSprite2D.new()
	charge_sprite.sprite_frames = HotbarDisplay.hold_charge_frames
	charge_sprite.centered = false
	charge_sprite.visible = false
	charge_sprite.animation_finished.connect(_hide_charge)
	tree_view.add_child(charge_sprite)

	# A material is what tells a node to draw with a shader. One is shared by every locked icon.
	greyscale_material = ShaderMaterial.new()
	greyscale_material.shader = GREYSCALE_SHADER

# A points label for each tree button, along its bottom, plus one for the open tree's corner.
func _build_points_labels() -> void:
	for i: int in range(tree_buttons.size()):
		var button: NinePatchRect = tree_buttons[i]
		var label: Label = _make_points_label(TREE_IDS[i])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_child(label)
		# The height is only known once it's in the tree, since the font comes from the theme.
		var height: float = label.get_combined_minimum_size().y
		# Size is before scale, so the width is divided back up to still span the whole button.
		label.size = Vector2(button.size.x / POINTS_SCALE, height)
		label.position = Vector2(0, roundf(button.size.y - height * POINTS_SCALE - BUTTON_POINTS_INSET))
		button_points.append(label)

	# Right-aligned, so the number can grow leftwards without anything moving.
	corner_points = _make_points_label(TREE_IDS[0])
	corner_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tree_view.add_child(corner_points)
	_refresh_points()

func _make_points_label(tree_id: String) -> Label:
	var label: Label = Label.new()
	label.text = _points_text(tree_id)
	label.add_theme_color_override("font_color", _cost_colour_for(tree_id))
	label.add_theme_color_override("font_outline_color", _cost_outline_for(tree_id))
	label.add_theme_constant_override("outline_size", POINTS_OUTLINE_SIZE)
	label.scale = Vector2.ONE * POINTS_SCALE
	return label

func _points_text(tree_id: String) -> String:
	return "Points Invested: " + str(PlayerData.get_tree_points(tree_id))

# The corner shows whichever tree is selected, so it's right before and while that tree is open.
func _refresh_points() -> void:
	for i: int in range(button_points.size()):
		button_points[i].text = _points_text(TREE_IDS[i])
	corner_points.text = _points_text(TREE_IDS[selected_tree])
	
# --- INPUT ---
# Returns true if it used the key. Q while choosing returns false, so character_screen
# knows to back out of the side.
func handle_input(event: InputEvent) -> bool:
	match state:
		PanelState.CHOOSING:
			return _input_choosing(event)
		PanelState.TREE_OPEN:
			return _input_tree(event)
		PanelState.PLACING:
			return _input_placing(event)
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
	if event.is_action_pressed("ui_up"):
		_move_cursor(0, -1)
		return true
	if event.is_action_pressed("ui_down"):
		_move_cursor(0, 1)
		return true
	if event.is_action_pressed("ui_left"):
		_move_cursor(-1, 0)
		return true
	if event.is_action_pressed("ui_right"):
		_move_cursor(1, 0)
		return true
	# Starts counting the hold. _process decides whether it was a tap or a hold.
	if event.is_action_pressed("interact") and not node_ids.is_empty():
		info_hold_timer = 0.0
		return true
	var slot: int = PlayerData.get_hotbar_slot_from_event(event)
	if slot != -1:
		_assign_to_hotbar(slot)
		# Keys 1-4 also switch menu tabs, so every hotbar key stops here while a tree is open.
		return true
	return false

# --- OPEN / CLOSE ---
# Each step runs after the one before it: buttons fade, title slides, abilities fade in.
func _open_tree() -> void:
	state = PanelState.OPENING
	_update_highlight()
	slide_start_y = tree_buttons[selected_tree].position.y
	# Only needed while a button can be half off the top.
	clip_contents = true
	_build_tree(TREE_IDS[selected_tree])
	_kill_tween()
	slide_tween = create_tween()
	slide_tween.tween_method(_apply_fade, 1.0, 0.0, FADE_TIME)
	slide_tween.tween_method(_apply_slide, 0.0, 1.0, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_tween.tween_property(tree_view, "modulate:a", 1.0, TREE_FADE_TIME)
	slide_tween.tween_callback(_on_opened)

func _on_opened() -> void:
	state = PanelState.TREE_OPEN
	_update_highlight()

# The same steps in reverse: abilities fade out, title slides down, buttons fade in.
func _close_tree() -> void:
	state = PanelState.CLOSING
	_cancel_charge()
	_update_highlight()
	_kill_tween()
	slide_tween = create_tween()
	slide_tween.tween_property(tree_view, "modulate:a", 0.0, TREE_FADE_TIME)
	slide_tween.tween_method(_apply_slide, 1.0, 0.0, SLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide_tween.tween_method(_apply_fade, 0.0, 1.0, FADE_TIME)
	slide_tween.tween_callback(_on_closed)

func _on_closed() -> void:
	clip_contents = false
	state = PanelState.CHOOSING
	_clear_tree()
	_update_highlight()

# Snaps straight back to the three buttons with no animation, cursor on the first one. Called
# when the player leaves the tab, so it always opens fresh.
func reset() -> void:
	_end_placing_instantly()
	_kill_tween()
	_cancel_charge()
	state = PanelState.CHOOSING
	# Slide and fade both act on whichever button is selected, so they must run before the
	# selection changes, or the old button would be left slid up or faded out.
	tree_labels[selected_tree].position.y = label_home_y[selected_tree]
	clip_contents = false
	_apply_fade(1.0)
	tree_view.modulate.a = 0.0
	_clear_tree()
	for label: Label in button_points:
		UiFade.stop(label)
		label.modulate = Color.WHITE
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
	# The chosen button stays, but its points text fades with the others, at exactly the same time.
	button_points[selected_tree].modulate.a = alpha

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
	button.position.y = roundf(lerpf(slide_start_y, button_open_y, t))
	label.position.y = roundf(lerpf(label_home_y[selected_tree], label_open_y, t))

# --- TREE BUILDING ---
# One icon per ability in this tree, placed by its tree_slot in AbilityDB. _refresh_icons then
# decides which are colour, grey, or grey and locked.
func _build_tree(tree_id: String) -> void:
	_clear_tree()
	# The corner takes the opening tree's colours. The panel's width is certain by now, unlike in _ready.
	corner_points.add_theme_color_override("font_color", _cost_colour_for(tree_id))
	corner_points.add_theme_color_override("font_outline_color", _cost_outline_for(tree_id))
	var corner_height: float = corner_points.get_combined_minimum_size().y
	corner_points.size = Vector2((size.x - CORNER_POINTS_INSET * 2) / POINTS_SCALE, corner_height)
	corner_points.position = Vector2(CORNER_POINTS_INSET, roundf(size.y - corner_height * POINTS_SCALE - CORNER_POINTS_INSET))
	_refresh_points()
	for ability_id: String in AbilityDB.abilities.keys():
		var data: Dictionary = AbilityDB.abilities[ability_id]
		if data.get("tree", "") != tree_id:
			continue
		var slot: Vector2i = data.get("tree_slot", Vector2i.ZERO)

		var icon: TextureRect = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.position = _slot_position(slot)
		icon.texture = data.get("icon", null)
		# Children don't use their parent's material, so the lock keeps its own colours.
		var lock_rect: TextureRect = _make_lock(_lock_texture_for(tree_id))
		icon.add_child(lock_rect)
		# Children don't use their parent's material, so the box and number never go grey.
		var box: ReferenceRect = _make_cursor_box()
		icon.add_child(box)
		var badge: Label = _make_badge()
		icon.add_child(badge)
		var cost: Label = _make_cost_label(tree_id, data.get("sp_cost", 0))
		# Already owned when the tree opens: nothing to show.
		if PlayerData.has_ability(ability_id):
			cost.modulate = HIDDEN
		icon.add_child(cost)
		icon_holder.add_child(icon)

		node_ids.append(ability_id)
		node_icons.append(icon)
		node_slots.append(slot)
		node_boxes.append(box)
		node_badges.append(badge)
		node_badge_keys.append("")
		node_locks.append(null)
		node_lock_rects.append(lock_rect)
		node_costs.append(cost)

	_refresh_icons()

	# Start on the top-left ability: the lowest row, then the lowest column in it.
	selected_node = 0
	for i: int in range(node_slots.size()):
		var slot: Vector2i = node_slots[i]
		var best: Vector2i = node_slots[selected_node]
		if slot.y < best.y or (slot.y == best.y and slot.x < best.x):
			selected_node = i
	_update_cursor()
	_refresh_badges(false)

func _lock_texture_for(tree_id: String) -> Texture2D:
	match tree_id:
		"red":
			return red_lock_texture
		"green":
			return green_lock_texture
		"blue":
			return blue_lock_texture
	return null

func _cost_colour_for(tree_id: String) -> Color:
	match tree_id:
		"red":
			return red_cost_colour
		"green":
			return green_cost_colour
		"blue":
			return blue_cost_colour
	return Color.WHITE

func _cost_outline_for(tree_id: String) -> Color:
	match tree_id:
		"red":
			return red_cost_outline
		"green":
			return green_cost_outline
		"blue":
			return blue_cost_outline
	return Color.BLACK

# Owned: full colour. Not owned: grey. Not enough points in the tree yet: grey with the lock.
# Runs after building and after every purchase, since buying one can unlock others.
func _refresh_icons() -> void:
	var tree_id: String = TREE_IDS[selected_tree]
	for i: int in range(node_ids.size()):
		var data: Dictionary = AbilityDB.get_ability(node_ids[i])
		var owned: bool = PlayerData.has_ability(node_ids[i])
		var locked: bool = not owned and PlayerData.get_tree_points(tree_id) < data.get("tree_points_req", 0)
		node_icons[i].material = null if owned else greyscale_material
		node_lock_rects[i].visible = locked
		node_locks[i] = _lock_texture_for(tree_id) if locked else null

# The tree's lock, laid exactly over the icon. Draw it with a transparent background so the
# grey icon shows through around it.
func _make_lock(texture: Texture2D) -> TextureRect:
	var lock: TextureRect = TextureRect.new()
	lock.texture = texture
	lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.size = Vector2(ICON_SIZE, ICON_SIZE)
	return lock

# A 1px yellow outline with a gap around the icon. Starts hidden. _update_cursor fades it.
func _make_cursor_box() -> ReferenceRect:
	var box: ReferenceRect = ReferenceRect.new()
	# On by default, which would hide the box in the running game.
	box.editor_only = false
	box.border_color = SELECTED_COLOUR
	box.border_width = 1.0
	var offset: int = CURSOR_GAP + 1
	box.position = Vector2(-offset, -offset)
	box.size = Vector2(ICON_SIZE + offset * 2, ICON_SIZE + offset * 2)
	box.modulate = HIDDEN
	return box

# The hotbar key the ability is on, in the icon's bottom-right corner. Starts hidden.
func _make_badge() -> Label:
	var badge: Label = Label.new()
	badge.size = Vector2(ICON_SIZE, ICON_SIZE)
	badge.position = BADGE_NUDGE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	badge.add_theme_color_override("font_outline_color", Color.BLACK)
	badge.add_theme_constant_override("outline_size", 1)
	badge.modulate = HIDDEN
	return badge

# How many skill points the ability costs, in its bottom-right corner, coloured for its tree.
# The mirror image of the hotbar badge.
func _make_cost_label(tree_id: String, cost: int) -> Label:
	var label: Label = Label.new()
	label.text = str(cost)
	label.size = Vector2(ICON_SIZE, ICON_SIZE)
	label.position = COST_NUDGE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_color_override("font_color", _cost_colour_for(tree_id))
	label.add_theme_color_override("font_outline_color", _cost_outline_for(tree_id))
	label.add_theme_constant_override("outline_size", 5)
	# Remembered so the shake can put it back exactly here, wherever it's been placed.
	label.set_meta("rest_x", label.position.x)
	return label

func _clear_tree() -> void:
	for child: Node in icon_holder.get_children():
		child.free()
	node_ids.clear()
	node_icons.clear()
	node_slots.clear()
	selected_node = 0
	node_boxes.clear()
	node_badges.clear()
	node_badge_keys.clear()
	node_locks.clear()
	node_lock_rects.clear()
	# Already freed with icon_holder's children above. This just forgets it.
	reject_text = null
	node_costs.clear()

# Where an icon goes for a grid position. The grid is centred across the panel, and the icon
# is centred inside its cell.
func _slot_position(slot: Vector2i) -> Vector2:
	var grid_left: int = floori((size.x - GRID_COLUMNS * CELL_SIZE.x) / 2.0)
	var inset_x: int = floori((CELL_SIZE.x - ICON_SIZE) / 2.0)
	var inset_y: int = floori((CELL_SIZE.y - ICON_SIZE) / 2.0)
	return Vector2(grid_left + slot.x * CELL_SIZE.x + inset_x, TREE_TOP + slot.y * CELL_SIZE.y + inset_y)

# --- TREE CURSOR ---
# Moves to the nearest ability in the pressed direction. "ahead" is how far it is that way and
# "sideways" how far off the line it is. Sideways counts double, so straight moves win.
func _move_cursor(dx: int, dy: int) -> void:
	if node_slots.is_empty():
		return
	var from: Vector2i = node_slots[selected_node]
	var best: int = -1
	var best_score: int = 0
	for i: int in range(node_slots.size()):
		var offset: Vector2i = node_slots[i] - from
		var ahead: int = offset.x * dx + offset.y * dy
		if ahead <= 0:
			continue
		var sideways: int = absi(offset.x * dy) + absi(offset.y * dx)
		var score: int = ahead + sideways * 2
		if best == -1 or score < best_score:
			best = i
			best_score = score
	if best == -1:
		return
	selected_node = best
	# Each new selection starts its glow at full brightness.
	cursor_pulse_time = 0.0
	_cancel_charge()
	_update_cursor()

# Every ability has its own box. The selected one fades in while the others fade out.
func _update_cursor() -> void:
	for i: int in range(node_boxes.size()):
		UiFade.modulate(node_boxes[i], Color.WHITE if i == selected_node else HIDDEN)

# --- HOTBAR ---
# Only abilities you have can go on the hotbar, and never on slot 0, the attack. Pressing the
# slot an ability is already on takes it off.
func _assign_to_hotbar(slot: int) -> void:
	if node_ids.is_empty() or slot == 0:
		return
	var ability_id: String = node_ids[selected_node]
	if not PlayerData.has_ability(ability_id):
		return
	PlayerData.assign_hotbar(slot, ability_id)
	_refresh_badges(true)

# Checks every ability, since one change can move or knock off another. A new key fades in,
# and the icon flashes if flash is true. Coming off the hotbar fades the number out.
func _refresh_badges(flash: bool) -> void:
	for i: int in range(node_ids.size()):
		var key: String = _hotbar_key_for(node_ids[i])
		if key == node_badge_keys[i]:
			continue
		node_badge_keys[i] = key
		var badge: Label = node_badges[i]
		if key == "":
			UiFade.modulate(badge, HIDDEN)
		else:
			# The new key fades in, from nothing even if it's replacing an old one.
			badge.text = key
			UiFade.stop(badge)
			badge.modulate = HIDDEN
			UiFade.modulate(badge, Color.WHITE)
			if flash:
				UiFade.flash(node_icons[i])

# Slot 0 is key 1, up to slot 9 as key 0. % gives the remainder after dividing, so (9 + 1) % 10
# is 0. Empty if the ability isn't on the hotbar.
func _hotbar_key_for(ability_id: String) -> String:
	if not PlayerData.has_ability(ability_id):
		return ""
	for i: int in range(PlayerData.hotbar.size()):
		if PlayerData.hotbar[i] == ability_id:
			return str((i + 1) % 10)
	return ""

# --- BUYING ---
# Tapping E on an ability buys it if you can: a hard flash, a pop, and a gold ring bursting out.
func _try_buy() -> void:
	var ability_id: String = node_ids[selected_node]
	# Already owned: a tap takes it to the hotbar instead.
	if PlayerData.has_ability(ability_id):
		_start_placing()
		return
	if not PlayerData.buy_ability(ability_id):
		# Owned or locked: nothing to say. Otherwise the only thing stopping it is the price.
		if not PlayerData.has_ability(ability_id) and node_locks[selected_node] == null:
			_reject(selected_node, "Not enough Skill Points")
		return
	_refresh_icons()
	# Shows the key it was auto-assigned to. No flash, since the purchase already flashes it.
	_refresh_badges(false)
	var icon: TextureRect = node_icons[selected_node]
	UiFade.flash(icon, BUY_FLASH_COLOUR, BUY_FLASH_POP_TIME, BUY_FLASH_SETTLE_TIME)
	# The icon's flash brightens the cost too, since it's a child. Once that's peaked, it fades.
	var cost: Label = node_costs[selected_node]
	var cost_tween: Tween = cost.create_tween()
	cost_tween.tween_property(cost, "modulate", HIDDEN, COST_FADE_TIME).set_delay(COST_FADE_DELAY)
	_play_buy_burst(icon)
	_play_buy_pop(icon)
	_refresh_points()
	UiFade.flash(corner_points)

# A one-off gold ring that grows out from the cursor box and fades, then deletes itself.
# It goes in tree_view, so it fades with the tree if you close it mid-burst.
func _play_buy_burst(icon: TextureRect) -> void:
	var ring: ReferenceRect = ReferenceRect.new()
	ring.editor_only = false
	ring.border_color = BURST_COLOUR
	ring.border_width = 1.0
	tree_view.add_child(ring)
	_set_burst_size(0.0, ring, icon.position)
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_burst_size.bind(ring, icon.position), 0.0, 1.0, BURST_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, BURST_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(ring.queue_free)

# t = 0 is the size of the cursor box, t = 1 is BURST_GROWTH pixels further out on every side.
# roundi keeps it on whole pixels.
func _set_burst_size(t: float, ring: ReferenceRect, icon_pos: Vector2) -> void:
	var offset: int = CURSOR_GAP + 1 + roundi(BURST_GROWTH * t)
	ring.position = icon_pos - Vector2(offset, offset)
	ring.size = Vector2(ICON_SIZE + offset * 2, ICON_SIZE + offset * 2)

# The flash tweens modulate and this tweens scale, so the two run side by side without fighting.
func _play_buy_pop(icon: TextureRect) -> void:
	# Scale grows from pivot_offset, so putting it in the middle makes the icon grow evenly
	# in every direction. The icon is at scale 1 here, so moving the pivot doesn't shift it.
	icon.pivot_offset = icon.size / 2.0
	var tween: Tween = icon.create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE * BUY_POP_SCALE, BUY_POP_UP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2.ONE, BUY_POP_SETTLE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# --- REJECTING ---
# The hotbar's rejection: the icon shakes, the red animation plays over it, and a message
# floats up from it.
func _reject(index: int, message: String) -> void:
	var icon: TextureRect = node_icons[index]
	var rest: Vector2 = _slot_position(node_slots[index])
	_shake(index, rest.x)
	_play_reject_sprite(icon)
	_float_text(rest, message)

# Each step slides from the last offset to the next. Restarts cleanly if it's still shaking.
func _shake(index: int, rest_x: float) -> void:
	var icon: TextureRect = node_icons[index]
	var box: ReferenceRect = node_boxes[index]
	var cost: Label = node_costs[index]
	if icon.has_meta("shake_tween"):
		var old_tween: Tween = icon.get_meta("shake_tween")
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
	_set_shake_offset(0.0, icon, box, cost, rest_x)
	var tween: Tween = icon.create_tween()
	var from: int = 0
	for step: int in SHAKE_STEPS:
		tween.tween_method(_set_shake_offset.bind(icon, box, cost, rest_x), float(from), float(step), SHAKE_STEP_TIME)
		from = step
	icon.set_meta("shake_tween", tween)

# The cursor box and cost are children of the icon, so they're moved the opposite way to stay
# still on screen.
func _set_shake_offset(offset: float, icon: TextureRect, box: ReferenceRect, cost: Label, rest_x: float) -> void:
	var pixels: float = roundf(offset)
	icon.position.x = rest_x + pixels
	box.position.x = -(CURSOR_GAP + 1) - pixels
	# Twice the offset: once to cancel the icon's shake, once more to shake the other way on screen.
	cost.position.x = cost.get_meta("rest_x") - pixels * 2
	
# A child of the icon, so it shakes with it. Children don't use their parent's material, so it
# stays red on a grey icon. Any old one still playing on this icon is replaced.
func _play_reject_sprite(icon: TextureRect) -> void:
	# The meta can still hold a sprite that has since freed itself. A freed object can't go into a
	# typed variable, so it's checked straight from the meta first.
	if icon.has_meta("reject_sprite") and is_instance_valid(icon.get_meta("reject_sprite")):
		var old_sprite: AnimatedSprite2D = icon.get_meta("reject_sprite")
		old_sprite.queue_free()
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = HotbarDisplay.highlight_frames
	sprite.offset = Vector2(ICON_SIZE, ICON_SIZE) / 2.0
	sprite.set_meta("plays_left", REJECT_PLAYS)
	sprite.animation_finished.connect(_on_reject_finished.bind(sprite))
	icon.add_child(sprite)
	icon.set_meta("reject_sprite", sprite)
	sprite.play("reject")

func _on_reject_finished(sprite: AnimatedSprite2D) -> void:
	var plays_left: int = sprite.get_meta("plays_left") - 1
	if plays_left > 0:
		sprite.set_meta("plays_left", plays_left)
		sprite.play("reject")
	else:
		sprite.queue_free()

# Red text that holds still for a moment, then drifts up while fading. It goes in icon_holder,
# so closing the tree clears it with the icons.
func _float_text(icon_pos: Vector2, message: String) -> void:
	if is_instance_valid(reject_text):
		reject_text.queue_free()
	var label: Label = Label.new()
	label.text = message
	label.add_theme_color_override("font_color", REJECT_COLOUR)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", FLOAT_OUTLINE_SIZE)
	icon_holder.add_child(label)
	reject_text = label

	# The text's size is only known once it's in the tree, since the font comes from the theme.
	var text_size: Vector2 = label.get_combined_minimum_size()
	label.size = text_size
	# Draws above the selection frame, which comes after this panel in the scene tree.
	label.z_index = 1
	# Centred over the icon, but clamped so it can't run off either side of the panel.
	var x: float = clampf(roundf(icon_pos.x + ICON_SIZE / 2.0 - text_size.x / 2.0), 0.0, size.x - text_size.x)
	var start_y: float = icon_pos.y - text_size.y - FLOAT_GAP
	label.position = Vector2(x, start_y)

	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_float_offset.bind(label, start_y), 0.0, float(FLOAT_DISTANCE), FLOAT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, FLOAT_TIME - FLOAT_HOLD_TIME).set_delay(FLOAT_HOLD_TIME)
	tween.chain().tween_callback(label.queue_free)

func _set_float_offset(offset: float, label: Label, start_y: float) -> void:
	label.position.y = start_y - roundf(offset)

# The selected box glows dark and bright. Only its line colour pulses, since its modulate is
# already used to fade it in and out.
func _pulse_cursor(delta: float) -> void:
	if node_boxes.is_empty():
		return
	cursor_pulse_time += delta
	var wave: float = 0.5 + 0.5 * cos(cursor_pulse_time * TAU * CURSOR_PULSE_SPEED)
	var brightness: float = lerpf(CURSOR_PULSE_MIN, 1.0, wave)
	node_boxes[selected_node].border_color = SELECTED_COLOUR.darkened(1.0 - brightness)
	# The floating ability on the hotbar pulses bright and normal.
	# Left alone while busy, so a fade on the copy isn't overwritten.
	if state == PanelState.PLACING and place_ghost.visible and not place_busy:
		place_pulse_time += delta
		var place_wave: float = 0.5 + 0.5 * cos(place_pulse_time * TAU * PLACE_PULSE_SPEED)
		# Over its own slot, E would take it off, so it warns in red instead of glowing.
		if PlayerData.hotbar[place_slot] == node_ids[selected_node]:
			var tint: float = lerpf(1.0, PLACE_REMOVE_TINT, place_wave)
			place_ghost.modulate = Color(1.0, tint, tint, 1.0)
		else:
			var bright: float = lerpf(1.0, PLACE_PULSE_MAX, place_wave)
			place_ghost.modulate = Color(bright, bright, bright, 1.0)

# --- HOTBAR PLACING ---
# Tapping E on an owned ability floats a copy of it over the hotbar. A/D move it, E places it,
# Q sends it back. The hotbar itself only changes when it's placed.
func _build_place_overlay() -> void:
	place_layer = CanvasLayer.new()
	place_layer.layer = PLACE_LAYER
	add_child(place_layer)
	place_ghost = _make_ghost(null, Rect2())
	place_ghost.visible = false

func _make_ghost(texture: Texture2D, rect: Rect2) -> TextureRect:
	var ghost: TextureRect = TextureRect.new()
	ghost.texture = texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	ghost.position = rect.position
	ghost.size = rect.size
	place_layer.add_child(ghost)
	return ghost

# Where the floating ability hovers: over the slot, lifted by half its height.
func _hover_rect(slot: int) -> Rect2:
	var rect: Rect2 = HotbarDisplay.get_slot_screen_rect(slot)
	rect.position.y -= roundf(rect.size.y / 2.0)
	return rect

# Moves the copy from wherever it is now, so a new move can start mid-way through the last.
# on_done can be an empty Callable() for nothing.
func _move_ghost(to: Rect2, time: float, on_done: Callable) -> void:
	_kill_place_tween()
	var from: Rect2 = Rect2(place_ghost.position, place_ghost.size)
	place_tween = create_tween()
	place_tween.tween_method(_set_rect.bind(place_ghost, from, to), 0.0, 1.0, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if on_done.is_valid():
		place_tween.tween_callback(on_done)

# Rounded to whole screen pixels, so nothing is drawn between them.
func _set_rect(t: float, node: Control, from: Rect2, to: Rect2) -> void:
	node.position = from.position.lerp(to.position, t).round()
	node.size = from.size.lerp(to.size, t).round()

func _kill_place_tween() -> void:
	if place_tween != null and place_tween.is_valid():
		place_tween.kill()

# Always starts on slot 1, the first ability slot. The panel's box fades while the copy flies.
func _start_placing() -> void:
	state = PanelState.PLACING
	place_busy = true
	place_slot = 1
	place_pulse_time = 0.0
	UiFade.modulate(node_boxes[selected_node], HIDDEN)
	var icon: TextureRect = node_icons[selected_node]
	var icon_rect: Rect2 = _screen_rect(icon)
	place_ghost.texture = icon.texture
	place_ghost.modulate = Color.WHITE
	place_ghost.position = icon_rect.position
	place_ghost.size = icon_rect.size
	place_ghost.visible = true
	_move_ghost(_hover_rect(place_slot), PLACE_FLY_TIME, _on_place_ready)

func _on_place_ready() -> void:
	place_busy = false

func _input_placing(event: InputEvent) -> bool:
	# Tab closes the menu as normal, so this clears up at once and lets the key through.
	if event.is_action_pressed("open_menu"):
		_end_placing_instantly()
		return false
	if place_busy:
		return true
	if event.is_action_pressed("ui_left"):
		_move_place(-1)
	elif event.is_action_pressed("ui_right"):
		_move_place(1)
	elif event.is_action_pressed("interact"):
		_confirm_place()
	elif event.is_action_pressed("ui_cancel"):
		_cancel_place()
	# Everything else is swallowed, so number keys and tab shortcuts can't act mid-placement.
	return true

func _move_place(direction: int) -> void:
	var new_slot: int = clampi(place_slot + direction, 1, PlayerData.hotbar.size() - 1)
	if new_slot == place_slot:
		return
	place_slot = new_slot
	_move_ghost(_hover_rect(place_slot), PLACE_MOVE_TIME, Callable())

# The copy settles into the slot. An ability already there slides to where it'll end up, the
# real one with its badge and numbers, or fades if it's coming off. The real change waits for
# both to finish.
func _confirm_place() -> void:
	place_busy = true
	var ability_id: String = node_ids[selected_node]
	# Over its own slot: it comes off the hotbar. The copy settles exactly onto the real icon first,
	# its red easing off as it goes, then hands over to it, so only one ability is seen fading.
	if PlayerData.hotbar[place_slot] == ability_id:
		place_removing = true
		var tint_tween: Tween = place_ghost.create_tween()
		tint_tween.tween_property(place_ghost, "modulate", Color.WHITE, PLACE_SETTLE_TIME)
		_move_ghost(HotbarDisplay.get_slot_screen_rect(place_slot), PLACE_SETTLE_TIME, _remove_from_hotbar)
		return
	place_settling = true
	place_snap.clear()
	var displaced: String = PlayerData.hotbar[place_slot]
	if displaced != "" and displaced != ability_id:
		var to_slot: int = PlayerData.get_displaced_slot(place_slot, ability_id)
		if to_slot != -1:
			_slide_displaced(place_slot, to_slot)
		else:
			_fade_displaced(displaced)
	_move_ghost(HotbarDisplay.get_slot_screen_rect(place_slot), PLACE_SETTLE_TIME, _commit_place)

# The real slot slides across, so it reads as one ability moving. Both ends then change at once
# when the change is made, and the slide snaps home in that same frame, so nothing jumps.
func _slide_displaced(from_slot: int, to_slot: int) -> void:
	# Heading for the slot the placed ability is leaving: that one gets out of its way.
	if PlayerData.hotbar[to_slot] != "":
		_hide_slot(to_slot)
	place_slid = from_slot
	place_snap = [from_slot, to_slot]
	var distance: float = (to_slot - from_slot) * HotbarDisplay.slot_spacing
	place_slide_tween = create_tween()
	place_slide_tween.tween_method(_set_slid_offset, 0.0, distance, PLACE_SETTLE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _set_slid_offset(offset: float) -> void:
	HotbarDisplay.set_slot_offset(place_slid, roundf(offset))

# Nowhere for it to go: a copy fades out under the settling ability while the real one hides.
func _fade_displaced(ability_id: String) -> void:
	var slot_rect: Rect2 = HotbarDisplay.get_slot_screen_rect(place_slot)
	_hide_slot(place_slot)
	place_displaced = _make_ghost(AbilityDB.get_ability(ability_id).get("icon", null), slot_rect)
	var tween: Tween = place_displaced.create_tween()
	tween.tween_property(place_displaced, "modulate:a", 0.0, PLACE_SETTLE_TIME)

func _hide_slot(slot: int) -> void:
	HotbarDisplay.set_slot_hidden(slot, true)
	place_hidden.append(slot)

# Makes the change for real. The slide snaps home and the hotbar updates in this same frame,
# flashing its arrivals, just as the copies disappear. Then the panel's box fades back in.
func _commit_place() -> void:
	_apply_place()
	_clear_place_copies()
	_refresh_badges(true)
	_finish_placing()

# The copy vanishes as the hotbar starts fading the real one out, badge and number with it.
func _remove_from_hotbar() -> void:
	_apply_remove()
	_clear_place_copies()
	_refresh_badges(true)
	_finish_placing()

func _apply_remove() -> void:
	place_removing = false
	place_ghost.visible = false
	PlayerData.assign_hotbar(place_slot, node_ids[selected_node])
	HotbarDisplay.refresh()

func _apply_place() -> void:
	place_settling = false
	_reset_slide()
	PlayerData.place_on_hotbar(place_slot, node_ids[selected_node])
	HotbarDisplay.refresh(place_snap)
	place_snap.clear()

func _reset_slide() -> void:
	if place_slide_tween != null and place_slide_tween.is_valid():
		place_slide_tween.kill()
	if place_slid != -1:
		HotbarDisplay.set_slot_offset(place_slid, 0.0)
		place_slid = -1

# Q: the copy flies back into its icon in the panel. Nothing on the hotbar changes.
func _cancel_place() -> void:
	place_busy = true
	var icon_rect: Rect2 = _screen_rect(node_icons[selected_node])
	_move_ghost(icon_rect, PLACE_FLY_TIME, _on_cancel_returned)

func _on_cancel_returned() -> void:
	_clear_place_copies()
	_finish_placing()

func _finish_placing() -> void:
	UiFade.modulate(node_boxes[selected_node], Color.WHITE)
	place_busy = false
	state = PanelState.TREE_OPEN

func _clear_place_copies() -> void:
	place_ghost.visible = false
	place_ghost.modulate = Color.WHITE
	if is_instance_valid(place_displaced):
		place_displaced.queue_free()
	place_displaced = null
	_reset_slide()
	for slot: int in place_hidden:
		HotbarDisplay.set_slot_hidden(slot, false)
	place_hidden.clear()

# For Tab and leaving the tab. If E was already pressed, that choice is kept. Otherwise the
# hotbar is exactly as it was.
func _end_placing_instantly() -> void:
	if state != PanelState.PLACING:
		return
	_kill_place_tween()
	if place_settling:
		_apply_place()
	elif place_removing:
		_apply_remove()
	_clear_place_copies()
	if not node_boxes.is_empty():
		UiFade.stop(node_boxes[selected_node])
		node_boxes[selected_node].modulate = Color.WHITE
	place_busy = false
	state = PanelState.TREE_OPEN

# --- INFO WINDOW ---
# Same timings as holding a hotbar key. Let go before the delay and it was a tap, which buys the
# ability. Hold on and the charge plays, then the info window opens.
func _process(delta: float) -> void:
	_pulse_cursor(delta)
	_refresh_points()
	if info_hold_timer < 0.0:
		return
	if not Input.is_action_pressed("interact") or state != PanelState.TREE_OPEN:
		# Worked out before _cancel_charge, which resets info_hold_timer.
		var was_tap: bool = state == PanelState.TREE_OPEN and info_hold_timer < SkillInfoScreen.CHARGE_DELAY
		_cancel_charge()
		if was_tap:
			_try_buy()
		return
	info_hold_timer += delta
	var charge_time: float = SkillInfoScreen.CHARGE_TIME
	var charge_elapsed: float = info_hold_timer - SkillInfoScreen.CHARGE_DELAY
	if charge_elapsed < 0.0:
		return
	if not charge_started:
		_start_charge(charge_time)
	if charge_elapsed >= charge_time * SkillInfoScreen.OPEN_AT:
		# The animation is left to play out and hides itself when it ends, like on the hotbar.
		info_hold_timer = -1.0
		charge_started = false
		var icon: TextureRect = node_icons[selected_node]
		SkillInfoScreen.open_ability_info(_screen_rect(icon), node_ids[selected_node], icon.material, node_locks[selected_node])

# speed_scale stretches the animation so it lasts exactly charge_time, whatever its frame rate.
func _start_charge(charge_time: float) -> void:
	charge_started = true
	var frames: SpriteFrames = charge_sprite.sprite_frames
	if frames == null or not frames.has_animation("charge"):
		return
	var frame_count: int = frames.get_frame_count("charge")
	var fps: float = frames.get_animation_speed("charge")
	charge_sprite.speed_scale = (frame_count / fps) / charge_time
	charge_sprite.position = node_icons[selected_node].position
	charge_sprite.visible = true
	charge_sprite.play("charge")

func _cancel_charge() -> void:
	info_hold_timer = -1.0
	charge_started = false
	_hide_charge()

func _hide_charge() -> void:
	charge_sprite.stop()
	charge_sprite.visible = false

# Where a node sits on the screen in real pixels, with every scale above it included, which is
# what the info window expects to grow out of.
func _screen_rect(node: Control) -> Rect2:
	var xform: Transform2D = node.get_global_transform_with_canvas()
	return Rect2(xform.origin, node.size * xform.get_scale())

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

	for i: int in range(tree_buttons.size()):
		# While a tree is opening, open or closing, the slide owns the chosen button's position.
		if i == selected_tree and state != PanelState.CHOOSING:
			continue
		var popped: bool = i == selected_tree and cursor_visible
		tree_buttons[i].position.y = button_home_y[i] - (POP_HEIGHT if popped else 0)
