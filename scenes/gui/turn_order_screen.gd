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
const CARD_GAP_X: int = 4
const CARD_GAP_Y: int = 4
const BADGE_Y: int = -5
const BADGE_PREFIX: String = "x"
const SELECTED_TINT: Color = Color.YELLOW

# Only matters if speeds ever stop being whole numbers and the cycle gets very long.
const MAX_CYCLE_TURNS: int = 300

# --- NODES ---
@onready var order_scroll: ScrollContainer = $root/layout/order_scroll
@onready var order_grid: GridContainer = $root/layout/order_scroll/order_grid
@onready var info_portrait: TextureRect = $root/layout/info_panel/info_vbox/info_portrait
@onready var info_name: Label = $root/layout/info_panel/info_vbox/info_name
@onready var info_body: Label = $root/layout/info_panel/info_vbox/info_body

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
	return BattleManager.active and BattleManager.turn_order != null and BattleManager != null
	
func _open() -> void:
	is_open = true
	visible = true
	_build()
	order_scroll.scroll_vertical = 0
	_select(0)
	
func _close() -> void:
	is_open = false
	visible = false

# --- BUILDING ---
func _build() -> void:
	# remove_child first: queue_free alone leaves the old cards in the grid until the end of the 
	# frame, so the grid would lay out old and new together for one frame.
