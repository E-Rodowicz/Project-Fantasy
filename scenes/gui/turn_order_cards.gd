extends CanvasLayer

# --- INSPECTOR-ASSIGNED ---
@export var card_background: Texture2D = null
@export var card_font: Font = null

# How many CARDS to show. Because consecutive turns by the same combatant collapse into
# one card, this is NOT the same as how many turns are shown. Read once in _ready.
@export var card_count: int = 5

# Distance between card origins. Set this LOWER than CARD_WIDTH to make cards overlap
# like a fanned deck, which is how you would fit 20-30 on a full screen view later.
@export var card_stride: int = 19

# --- LAYOUT ---
const CARD_WIDTH: int = 18
const CARD_HEIGHT: int = 30
const START_X: int = 137
const CARD_Y: int = 238
const OFF_SCREEN_MARGIN: int = 8

const PORTRAIT_POS: Vector2 = Vector2(9, 10)
const NAME_Y: int = 20
const NAME_HEIGHT: int = 0

const BADGE_FONT_SIZE: int = 12
const BADGE_Y: int = -5
const BADGE_HEIGHT: int = 0
const BADGE_MARGIN_RIGHT: int = -1
const BADGE_PREFIX: String = "x"

const BADGE_SCALE: float = 0.5

# --- TIMING ---
const RISE_TIME: float = 0.28
const FALL_TIME: float = 0.22
const SLIDE_TIME: float = 0.22

# Cards rising together are staggered so each starts partway through the last, but the
# whole batch is squeezed into STAGGER_BUDGET so a deep queue does not take seconds.
const RISE_STAGGER: float = 0.14
const STAGGER_BUDGET: float = 0.9

const BADGE_POP_HEIGHT: int = 3
const BADGE_POP_TIME: float = 0.22

# Predict this many times deeper than we display, because runs collapse. A single fast
# combatant can eat many consecutive turns that all become one card.
const PEEK_DEPTH_MULTIPLIER: int = 6

const PLAYER_DISPLAY_NAME: String = "Nihil"

# --- STATE ---
# cards[i]        - the Node2D sitting in slot i, or null if the slot is empty
# slot_ids[i]     - instance ID of the combatant that card represents, or 0 if empty
# slot_counts[i]  - how many consecutive turns that card currently represents
# IDs rather than Node references, so the diff never touches a freed object.
var cards: Array = []
var slot_ids: Array = []
var slot_counts: Array = []

var was_active: bool = false
var last_turn_counter: int = -1
var last_roster_size: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("turn order display ready, viewport: ", get_viewport().get_visible_rect().size)
	card_count = max(1, card_count)
	_reset_state()


func _reset_state() -> void:
	cards.clear()
	slot_ids.clear()
	slot_counts.clear()
	for i in range(card_count):
		cards.append(null)
		slot_ids.append(0)
		slot_counts.append(0)


func _process(_delta: float) -> void:
	if not BattleManager.active:
		if was_active:
			was_active = false
			_clear_all_cards()
		return

	if not was_active:
		was_active = true
		last_turn_counter = -1
		last_roster_size = -1

	if BattleManager.turn_order == null:
		return

	# turn_counter catches every turn INCLUDING repeat turns by the same combatant, which
	# is exactly what a badge tick-down is. Roster size catches deaths and reinforcements.
	var turn_counter: int = BattleManager.turn_counter
	var roster_size: int = BattleManager.turn_order.combatants.size()

	if turn_counter == last_turn_counter and roster_size == last_roster_size:
		return

	last_turn_counter = turn_counter
	last_roster_size = roster_size
	_reflow(_build_desired_list())

# --- BUILDING THE DESIRED LIST ---
# Returns an Array of Dictionaries shaped {"combatant": Node, "count": int}.
# Consecutive turns by the same combatant are collapsed into one entry, with count
# recording how many turns in a row they get.
func _build_desired_list() -> Array:
	var raw: Array = []

	# Slot 0 is whoever is acting RIGHT NOW. If you would rather slot 0 be the NEXT
	# combatant, delete this append and the peek will fill from index 0 instead.
	if is_instance_valid(BattleManager.current_combatant):
		raw.append(BattleManager.current_combatant)

	var depth: int = card_count * PEEK_DEPTH_MULTIPLIER
	var remaining: int = depth - raw.size()
	if remaining > 0:
		raw.append_array(BattleManager.turn_order.peek_upcoming(remaining))

	# Run length collapse: [A,A,A,B,C] becomes [{A,3},{B,1},{C,1}]
	var entries: Array = []
	for combatant in raw:
		if not is_instance_valid(combatant):
			continue
		if entries.size() > 0 and entries[entries.size() - 1]["combatant"] == combatant:
			entries[entries.size() - 1]["count"] += 1
		else:
			entries.append({"combatant": combatant, "count": 1})

	if entries.size() > card_count:
		entries.resize(card_count)
	return entries

# --- REFLOW ---
func _reflow(entries: Array) -> void:
	# Normalise to exactly card_count slots so every loop below is index safe.
	var new_ids: Array = []
	var new_counts: Array = []
	for i in range(card_count):
		if i < entries.size() and is_instance_valid(entries[i]["combatant"]):
			new_ids.append(entries[i]["combatant"].get_instance_id())
			new_counts.append(entries[i]["count"])
		else:
			new_ids.append(0)
			new_counts.append(0)

	var reuse_from: Array = []   # for each NEW slot: which OLD slot to recycle, or -1
	var consumed: Array = []     # for each OLD slot: was it claimed by anyone
	for i in range(card_count):
		reuse_from.append(-1)
		consumed.append(false)

	# Two pointer scan. old_ptr only ever moves FORWARD. That is what stops cards from
	# crossing over each other when the same combatant appears at more than one point in
	# the queue, for example [A x3, B x1, A x2].
	var old_ptr: int = 0
	for i in range(card_count):
		var wanted: int = new_ids[i]
		if wanted == 0:
			continue
		var found: int = -1
		for j in range(old_ptr, card_count):
			if slot_ids[j] != 0 and slot_ids[j] == wanted:
				found = j
				break
		if found != -1:
			reuse_from[i] = found
			consumed[found] = true
			old_ptr = found + 1

	# Anything unclaimed has left the queue.
	var dropped_any: bool = false
	for j in range(card_count):
		if not consumed[j] and is_instance_valid(cards[j]):
			_animate_fall(cards[j])
			dropped_any = true

	var next_cards: Array = []
	for i in range(card_count):
		next_cards.append(null)

	# Reused cards slide to their new slot, and pop their badge if the run changed.
	for i in range(card_count):
		var source: int = reuse_from[i]
		if source == -1:
			continue
		var card: Node2D = cards[source]
		next_cards[i] = card
		if not is_instance_valid(card):
			continue
		card.z_index = _slot_z(i)
		if source != i:
			_animate_slide(card, i)
		if slot_counts[source] != new_counts[i]:
			_set_badge(card, new_counts[i], true)

	# Count how many cards need building, so the stagger can be divided between them.
	var fresh_total: int = 0
	for i in range(card_count):
		if next_cards[i] == null and new_ids[i] != 0:
			fresh_total += 1

	var stagger: float = 0.0
	if fresh_total > 1:
		stagger = min(RISE_STAGGER, STAGGER_BUDGET / float(fresh_total))

	# New cards wait for outgoing ones to clear the way before rising.
	var base_delay: float = 0.0
	if dropped_any:
		base_delay = FALL_TIME * 0.45

	var fresh_index: int = 0
	for i in range(card_count):
		if next_cards[i] != null or new_ids[i] == 0:
			continue
		var card: Node2D = _make_card(entries[i]["combatant"], i, new_counts[i])
		next_cards[i] = card
		_animate_rise(card, base_delay + fresh_index * stagger)
		fresh_index += 1

	cards = next_cards
	slot_ids = new_ids.duplicate()
	slot_counts = new_counts.duplicate()


func _clear_all_cards() -> void:
	for i in range(card_count):
		if is_instance_valid(cards[i]):
			_animate_fall(cards[i])
	_reset_state()

# --- CARD CONSTRUCTION ---
func _make_card(combatant: Node, slot_index: int, run_count: int) -> Node2D:
	var card: Node2D = Node2D.new()
	# Set BEFORE add_child so the card never accumulates a frame of delta in a paused tree.
	card.process_mode = Node.PROCESS_MODE_ALWAYS
	card.position = Vector2(_slot_x(slot_index), _off_screen_y())
	card.z_index = _slot_z(slot_index)
	add_child(card)

	if card_background != null:
		var bg: Sprite2D = Sprite2D.new()
		bg.texture = card_background
		bg.centered = false
		card.add_child(bg)

	var portrait_texture: Texture2D = _grab_texture(combatant)
	if portrait_texture != null:
		var portrait: Sprite2D = Sprite2D.new()
		portrait.texture = portrait_texture
		portrait.centered = true
		portrait.position = PORTRAIT_POS
		card.add_child(portrait)

	# The badge lives inside its own Node2D wrapper so the pop can move the wrapper
	# without disturbing the Label's own alignment and layout. Both are named so
	# _set_badge can find them again later via get_node_or_null.
	var badge_root: Node2D = Node2D.new()
	badge_root.name = "BadgeRoot"
	card.add_child(badge_root)

	var badge_label: Label = Label.new()
	badge_label.name = "BadgeLabel"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.position = Vector2(0, BADGE_Y)
	badge_label.size = Vector2((CARD_WIDTH - BADGE_MARGIN_RIGHT) / BADGE_SCALE, BADGE_HEIGHT / BADGE_SCALE)
	badge_label.scale = Vector2(BADGE_SCALE, BADGE_SCALE)
	if card_font != null:
		badge_label.add_theme_font_override("font", card_font)
		badge_label.add_theme_font_size_override("font_size", BADGE_FONT_SIZE)
		badge_label.add_theme_color_override("font_color", Color.WHITE)
		badge_label.add_theme_color_override("font_outline_color", Color.BLACK)
		badge_label.add_theme_constant_override("outline_size", 8)
	badge_root.add_child(badge_label)

	_set_badge(card, run_count, false)
	return card

# --- BADGE ---
# Writes the run count into the badge. A run of 1 hides it entirely, since a lone card
# needs no "x1". When animate is true it snaps up, flashes bright, and eases back down.
# Deliberately a vertical bump rather than a scale: scaling a pixel font produces
# fractional glyph positions and blurred edges, which would fight the roundf snapping
# used everywhere else in this script.
func _set_badge(card: Node2D, run_count: int, animate: bool) -> void:
	if not is_instance_valid(card):
		return
	var badge_root: Node2D = card.get_node_or_null("BadgeRoot")
	if badge_root == null:
		return
	var badge_label: Label = badge_root.get_node_or_null("BadgeLabel")
	if badge_label == null:
		return

	if run_count <= 1:
		if animate and badge_root.visible:
			# Ticking down to the final turn - let it flash out rather than just vanish.
			_pop_badge(badge_root, badge_label, "")
		else:
			badge_root.visible = false
			badge_label.text = ""
		return

	badge_root.visible = true
	if animate:
		_pop_badge(badge_root, badge_label, BADGE_PREFIX + str(run_count))
	else:
		badge_label.text = BADGE_PREFIX + str(run_count)
		badge_root.position.y = 0.0
		badge_label.modulate = Color.WHITE


func _pop_badge(badge_root: Node2D, badge_label: Label, new_text: String) -> void:
	badge_label.text = new_text
	badge_root.position.y = float(-BADGE_POP_HEIGHT)
	badge_label.modulate = Color(2.0, 2.0, 2.0, 1.0)

	var tween: Tween = badge_root.create_tween()
	tween.set_parallel(true)
	tween.tween_method(
		func(v: float): badge_root.position.y = roundf(v),
		float(-BADGE_POP_HEIGHT), 0.0, BADGE_POP_TIME
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(badge_label, "modulate", Color.WHITE, BADGE_POP_TIME)

	if new_text == "":
		tween.chain().tween_callback(func():
			if is_instance_valid(badge_root):
				badge_root.visible = false
		)

# --- ANIMATION ---
# tween_method calls the given function each frame with the interpolated value instead
# of writing into a property directly, so we can roundf() and stay on whole pixels.
# Tweens are created ON THE CARD so they die automatically when it is freed.
func _animate_rise(card: Node2D, delay: float) -> void:
	if not is_instance_valid(card):
		return
	var start_y: float = _off_screen_y()
	var end_y: float = float(CARD_Y)
	card.position.y = start_y

	var tween: Tween = card.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(
		func(v: float): card.position.y = roundf(v),
		start_y, end_y, RISE_TIME * 1.5
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _animate_fall(card: Node2D) -> void:
	if not is_instance_valid(card) or card.is_queued_for_deletion():
		return
	var start_y: float = card.position.y
	var end_y: float = _off_screen_y()

	var tween: Tween = card.create_tween()
	tween.tween_method(
		func(v: float): card.position.y = roundf(v),
		start_y, end_y, FALL_TIME * 1.5
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(card.queue_free)


func _animate_slide(card: Node2D, target_slot: int) -> void:
	if not is_instance_valid(card) or card.is_queued_for_deletion():
		return
	var start_x: float = card.position.x
	var end_x: float = float(_slot_x(target_slot))

	var tween: Tween = card.create_tween()
	tween.tween_method(
		func(v: float): card.position.x = roundf(v),
		start_x, end_x, SLIDE_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _slot_x(slot_index: int) -> int:
	return START_X + slot_index * card_stride


# Earlier turns draw on top. Flip the sign to fan the queue the other way. Only matters
# once card_stride is small enough that cards overlap.
func _slot_z(slot_index: int) -> int:
	return card_count - slot_index


func _off_screen_y() -> float:
	return get_viewport().get_visible_rect().size.y + OFF_SCREEN_MARGIN

# --- COMBATANT DATA EXTRACTION ---
func _grab_name(combatant: Node) -> String:
	if not is_instance_valid(combatant):
		return "???"
	if combatant.is_in_group("player"):
		return PLAYER_DISPLAY_NAME
	if "stats" in combatant and combatant.stats != null:
		return combatant.stats.character_name
	return combatant.name


func _grab_texture(combatant: Node) -> Texture2D:
	if not is_instance_valid(combatant):
		return null
	var sprite_node: Node = _find_sprite_node(combatant)
	if sprite_node == null:
		return null

	if sprite_node is AnimatedSprite2D:
		var frames: SpriteFrames = sprite_node.sprite_frames
		if frames == null:
			return null
		if not frames.has_animation(sprite_node.animation):
			return null
		return frames.get_frame_texture(sprite_node.animation, sprite_node.frame)

	if sprite_node is Sprite2D:
		var base: Texture2D = sprite_node.texture
		if base == null:
			return null

		# Plain single image sprite - use it as is.
		if sprite_node.hframes <= 1 and sprite_node.vframes <= 1 and not sprite_node.region_enabled:
			return base

		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = base

		if sprite_node.region_enabled and sprite_node.hframes <= 1 and sprite_node.vframes <= 1:
			atlas.region = sprite_node.region_rect
			return atlas

		# Sprite sheet - carve out whichever frame the sprite is currently showing.
		var frame_w: float = float(base.get_width()) / float(sprite_node.hframes)
		var frame_h: float = float(base.get_height()) / float(sprite_node.vframes)
		var col: int = sprite_node.frame % sprite_node.hframes
		var row: int = int(sprite_node.frame / sprite_node.hframes)
		atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
		return atlas

	return null


# The function calls itself on each child, so it searches the entire subtree
# however deep it goes. This means the display never needs to know the internal node
# layout of the player or of any enemy scene.
func _find_sprite_node(root: Node) -> Node:
	for child in root.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
		var deeper: Node = _find_sprite_node(child)
		if deeper != null:
			return deeper
	return null
