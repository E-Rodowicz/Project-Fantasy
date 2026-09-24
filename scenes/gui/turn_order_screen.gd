extends CanvasLayer

# --- INSPECTOR-ASSIGNED ---
@export var card_background: Texture2D = null
@export var card_font: Font = null
# Whole numbers only, so cards stay on the pixel grid.
@export var card_scale: int = 2
@export var badge_font_size: int = 12
@export var info_portrait_scale: int = 3

# --- LAYOUT ---
const COLUMNS: int = 5
const CARD_WIDTH: int = 18
const CARD_HEIGHT: int = 30
const PORTRAIT_POS: Vector2 = Vector2(9, 10)
const CARD_GAP_X: int = 12
const CARD_GAP_Y: int = 3
const BADGE_Y: int = -5
const BADGE_PREFIX: String = "x"
const SELECTED_TINT: Color = Color.YELLOW

# Only matters if speeds ever stop being whole numbers and the cycle gets very long.
const MAX_CYCLE_TURNS: int = 300

# --- SLIDE ---
const NATIVE_HEIGHT: int = 270
const PANEL_Y: int = 8
const SLIDE_IN_TIME: float = 0.25
const SLIDE_OUT_TIME: float = 0.18

# --- NODES ---
@onready var panel: TextureRect = $panel
@onready var order_scroll: ScrollContainer = $panel/margins/layout/order_scroll
@onready var order_grid: GridContainer = $panel/margins/layout/order_scroll/order_grid
@onready var info_portrait: TextureRect = $panel/margins/layout/info_panel/info_vbox/info_portrait
@onready var info_name: Label = $panel/margins/layout/info_panel/info_vbox/info_name
@onready var info_body: Label = $panel/margins/layout/info_panel/info_vbox/info_body

var panel_tween: Tween = null

# --- STATE ---
var is_open: bool = false
var raw_turns: Array = []   # every individual turn in the cycle, current combatant first
var entries: Array = []     # raw_turns collapsed into runs, one per card
var cards: Array = []       # the card Controls, same order as entries
var selected: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	order_grid.columns = COLUMNS
	order_grid.add_theme_constant_override("h_separation", CARD_GAP_X * card_scale)
	order_grid.add_theme_constant_override("v_separation", CARD_GAP_Y * card_scale)
	visible = false
	panel.position.y = NATIVE_HEIGHT

# --- INPUT ---
# _input runs before _unhandled_input anywhere in the game, and nodes in the level scene receive it
# before the autoloads' children (CombatantTurn is under BattleManager). While the turn order screen
# is open, every key is marked "handled" so nothing underneath reacts to the input.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
		
	if not is_open:
		if event.is_action_pressed("turn_order_screen") and not event.is_echo() and _can_open():
			_open()
			get_viewport().set_input_as_handled()
		return
		
	if not BattleManager.active:
		_close()
		return
		
	if not event.is_echo():
		if event.is_action_pressed("turn_order_screen") or event.is_action_pressed("ui_cancel"):
			_close()
		elif event.is_action_pressed("ui_left"):
			_select(selected - 1)
		elif event.is_action_pressed("ui_right"):
			_select(selected + 1)
		elif event.is_action_pressed("ui_up"):
			_select(selected - COLUMNS)
		elif event.is_action_pressed("ui_down"):
			_select(selected + COLUMNS)
	get_viewport().set_input_as_handled()
	
# Order cannot change while it is open, so no live refreshing. It can only open on player's turn.
func _can_open() -> bool:
	return BattleManager.active and BattleManager.turn_order != null and BattleManager.player_turn != null
	
func _open() -> void:
	BattleManager.input_locked = true
	is_open = true
	visible = true
	_build()
	order_scroll.scroll_vertical = 0
	_select(0)
	_slide_panel(float(PANEL_Y), SLIDE_IN_TIME, Tween.EASE_OUT)

func _close() -> void:
	is_open = false
	_slide_panel(float(NATIVE_HEIGHT), SLIDE_OUT_TIME, Tween.EASE_IN)
	panel_tween.tween_callback(func(): visible = false)

	# Hold the lock until the key that closed us has stopped counting as "just pressed".
	await get_tree().physics_frame
	await get_tree().physics_frame
	# If T was pressed again during those frames, we've reopened - keep the lock.
	if not is_open:
		BattleManager.input_locked = false

# Starts from wherever the panel is right now, so pressing T again halfway through
# a slide reverses it smoothly instead of snapping.
func _slide_panel(target_y: float, duration: float, ease_type: Tween.EaseType) -> void:
	# kill() stops the old tween dead, including its "hide when done" callback, so
	# reopening mid-close can't have the screen vanish on you a moment later.
	if panel_tween != null and panel_tween.is_valid():
		panel_tween.kill()
	panel_tween = create_tween()
	panel_tween.tween_method(
		func(v: float): panel.position.y = roundf(v),
		panel.position.y, target_y, duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)

# --- BUILDING ---
func _build() -> void:
	# remove_child first: queue_free alone leaves the old cards in the grid until the end of the 
	# frame, so the grid would lay out old and new together for one frame.
	for child in order_grid.get_children():
		order_grid.remove_child(child)
		child.queue_free()
	cards.clear()
	
	raw_turns.clear()
	if is_instance_valid(BattleManager.current_combatant):
		raw_turns.append(BattleManager.current_combatant)
	raw_turns.append_array(BattleManager.turn_order.peek_cycle(MAX_CYCLE_TURNS))

	entries = CombatantInfo.collapse_runs(raw_turns)
	for entry in entries:
		var card: Control = _make_card(entry)
		order_grid.add_child(card)
		cards.append(card)
		
func _make_card(entry: Dictionary) -> Control:
	var card_size: Vector2 = Vector2(CARD_WIDTH * card_scale, CARD_HEIGHT * card_scale)
	var card: Control = Control.new()
	card.custom_minimum_size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if card_background != null:
		var bg: TextureRect = TextureRect.new()
		bg.texture = card_background
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.size = card_size
		card.add_child(bg)

	var portrait_texture: Texture2D = CombatantInfo.get_portrait(entry["combatant"])
	if portrait_texture != null:
		var portrait: TextureRect = TextureRect.new()
		portrait.texture = portrait_texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.size = portrait_texture.get_size() * card_scale
		# PORTRAIT_POS is the portrait's centre, same as the mini cards.
		var top_left: Vector2 = PORTRAIT_POS * card_scale - portrait.size / 2.0
		portrait.position = Vector2(roundf(top_left.x), roundf(top_left.y))
		card.add_child(portrait)

	if entry["count"] > 1:
		var badge: Label = Label.new()
		badge.text = BADGE_PREFIX + str(entry["count"])
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.position = Vector2(0, BADGE_Y * card_scale)
		badge.size = Vector2(card_size.x, 0)
		if card_font != null:
			badge.add_theme_font_override("font", card_font)
			badge.add_theme_font_size_override("font_size", badge_font_size)
		badge.add_theme_color_override("font_color", Color.WHITE)
		badge.add_theme_color_override("font_outline_color", Color.BLACK)
		badge.add_theme_constant_override("outline_size", 8)
		card.add_child(badge)

	return card

# --- SELECTION ---
func _select(index: int) -> void:
	if cards.is_empty():
		return
	# Out of range means there is no card that way, so stay put rather than snapping
	# to the nearest one. Exception: opening the screen, which must land on 0.
	if index < 0 or index >= cards.size():
		return
	selected = index
	for i in range(cards.size()):
		cards[i].modulate = SELECTED_TINT if i == selected else Color.WHITE
	# Scrolls just far enough to have the cards in view.
	order_scroll.ensure_control_visible(cards[selected])
	_update_info_panel()
	
# --- INFO PANEL ---
func _update_info_panel() -> void:
	var entry: Dictionary = entries[selected]
	if not is_instance_valid(entry["combatant"]):
		info_name.text = ""
		info_body.text = ""
		info_portrait.texture = null
		return
	var combatant: Node = entry["combatant"]
	
	info_name.text = CombatantInfo.get_display_name(combatant)
	
	var tex: Texture2D = CombatantInfo.get_portrait(combatant)
	info_portrait.texture = tex
	if tex != null:
		info_portrait.custom_minimum_size = tex.get_size() * info_portrait_scale
		
	var text: String = ""
	
	# Timing specific to this card, not combatant in general.
	var start: int = entry["start"]
	if start == 0:
		text += "Acting now\n"
	elif start == 1:
		text += "Next up\n"
	else:
		text += "In " + str(start) + " turns\n"
	if entry["count"] > 1:
		text += str(entry["count"]) + " turns in a row\n"
	text += "Turns per cycle: " + str(raw_turns.count(combatant)) + " of " + str(raw_turns.size()) + "\n\n"
		
	# Stats.
	var dodge: float = CombatantStats.dodge_chance_for(combatant)
	if combatant.is_in_group("player"):
		text += "Level: " + str(PlayerData.combat_level) + "\n"
		text += "HP: " + str(PlayerData.current_hp) + " / " + str(PlayerData.max_hp) + "\n"
		text += "Speed: " + str(PlayerData.speed) + "\n"
	else:
		var stats: CombatantStats = combatant.stats
		text += "Level: " + str(stats.level) + "\n"
		if "current_hp" in combatant:
			text += "HP: " + str(combatant.current_hp) + " / " + str(stats.get_max_hp()) + "\n"
		else:
			text += "Max HP: " + str(stats.get_max_hp()) + "\n"
		text += "Speed: " + str(stats.speed) + "\n"
		text += "Movement: " + str(stats.get_movement_points()) + "\n"
		text += "Damage: " + str(stats.base_damage_min) + "-" + str(stats.base_damage_max) + "\n"
	text += "Dodge: " + str(int(roundf(dodge * 100.0))) + "%"

	info_body.text = text
		
		
		
		
		
		
		
