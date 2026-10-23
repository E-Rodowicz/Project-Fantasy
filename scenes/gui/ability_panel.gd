extends Control

# The character screen's abilities side. Three big tree buttons fill the panel. Entering one fades
# the other two away and slides it up to sit half off the top as the tree's title, then that
# tree's abilities fade in below it. character_screen passes it the keys while the side is entered.
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

# Shown instead of an ability's icon while it's locked, one per tree. Same size as an ability icon.
@export var red_lock_texture: Texture2D = null
@export var green_lock_texture: Texture2D = null
@export var blue_lock_texture: Texture2D = null

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
var selected_node: int = 0
# How long E has been held on an ability, or -1 when it isn't being held.
var info_hold_timer: float = -1.0
var charge_started: bool = false

func _ready() -> void:
	for i: int in range(tree_buttons.size()):
		button_home_y.append(tree_buttons[i].position.y)
		label_home_y.append(tree_labels[i].position.y)
	_build_tree_view()
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
	button.position.y = roundf(lerpf(slide_start_y, button_open_y, t))
	label.position.y = roundf(lerpf(label_home_y[selected_tree], label_open_y, t))

# --- TREE BUILDING ---
# One icon per ability in this tree, placed by its tree_slot in AbilityDB. Abilities you don't
# have are drawn grey with the lock on top.
func _build_tree(tree_id: String) -> void:
	_clear_tree()
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
		var lock: Texture2D = null
		if PlayerData.has_ability(ability_id):
			icon.texture = data.get("icon", null)
		elif PlayerData.get_tree_points(tree_id) >= data.get("level_req", 0):
			icon.texture = data.get("icon", null)
			icon.material = greyscale_material
		else:
			icon.texture = data.get("icon", null)
			icon.material = greyscale_material
			lock = _lock_texture_for(tree_id)
			# Children don't use their parent's material, so the lock keeps its own colours.
			icon.add_child(_make_lock(lock))
		# Children don't use their parent's material, so the box and number never go grey.
		var box: ReferenceRect = _make_cursor_box()
		icon.add_child(box)
		var badge: Label = _make_badge()
		icon.add_child(badge)
		icon_holder.add_child(icon)

		node_ids.append(ability_id)
		node_icons.append(icon)
		node_slots.append(slot)
		node_boxes.append(box)
		node_badges.append(badge)
		node_badge_keys.append("")
		node_locks.append(lock)

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

# Checks every ability, since one change can move or knock off another. A new key shows at once,
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
			badge.text = key
			UiFade.stop(badge)
			badge.modulate = Color.WHITE
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

# --- INFO WINDOW ---
# Same timings as holding a hotbar key. Let go before the delay and it was a tap, which will
# spend skill points later. Hold on and the charge plays, then the info window opens.
func _process(delta: float) -> void:
	if info_hold_timer < 0.0:
		return
	if not Input.is_action_pressed("interact") or state != PanelState.TREE_OPEN:
		_cancel_charge()
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
