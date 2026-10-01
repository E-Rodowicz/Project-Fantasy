extends CanvasLayer

# --- LAYOUT ---
const PANEL_WIDTH: int = 64
# Gap between the panel and the top and right edges of the screen.
const EDGE_MARGIN: int = 4
# Twice a 16x16 sprite. Whole-number scale, so it stays crisp.
const PORTRAIT_SIZE: Vector2 = Vector2(32, 32)

# --- TIMING ---
const SLIDE_IN_TIME: float = 0.16
const SLIDE_OUT_TIME: float = 0.10
# Pauses off screen between one combatant's panel leaving and the next arriving,
# so a swap reads as two separate windows rather than one bounce.
const SWAP_GAP: float = 0.02

# --- NODES ---
@onready var panel: PanelContainer = $panel
@onready var portrait: TextureRect = $panel/vbox/portrait
@onready var name_label: Label = $panel/vbox/name_label
@onready var body: Label = $panel/vbox/body

# --- STATE ---
var is_out: bool = false
var sliding_out: bool = false
# Who is on the panel.
var shown: Node = null
var slide_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.custom_minimum_size.x = PANEL_WIDTH
	portrait.custom_minimum_size = PORTRAIT_SIZE
	panel.position = Vector2(_off_x(), EDGE_MARGIN)
	panel.visible = false
	
func _process(_delta: float) -> void:
	# Keeps the numbers live, so HP drops while you watch.
	if is_out and not sliding_out and is_instance_valid(shown):
		_refresh_stats()

	# Waits for slide to finish.
	if sliding_out:
		return

	var wanted: Node = _hovered()
	if is_out:
		# If cursor moved off or combatant died.
		if not is_instance_valid(shown) or wanted != shown:
			_slide_out()
	elif wanted != null:
		_slide_in(wanted)
			
func _hovered() -> Node:
	if not BattleManager.active:
		return null
	var pt: CombatantTurn = BattleManager.player_turn
	if pt == null:
		return null
	return pt.get_hovered_combatant()
	
# --- SLIDING ---
func _slide_in(target: Node) -> void:
	shown = target
	is_out = true
	# Name and portrait only need setting once. Stats refresh every frame.
	name_label.text = CombatantInfo.get_display_name(target)
	portrait.texture = CombatantInfo.get_portrait(target)
	_refresh_stats()
	panel.visible = true
	_slide_to(_on_x(), SLIDE_IN_TIME, Tween.EASE_OUT)

func _slide_out() -> void:
	sliding_out = true
	_slide_to(_off_x(), SLIDE_OUT_TIME, Tween.EASE_IN)
	slide_tween.tween_interval(SWAP_GAP)
	slide_tween.tween_callback(_on_slid_out)

func _on_slid_out() -> void:
	sliding_out = false
	is_out = false
	shown = null
	panel.visible = false

# Starts from wherever the panel is now, so an interrupted slide-in reverses cleanly.
func _slide_to(target_x: float, duration: float, ease_type: Tween.EaseType) -> void:
	if slide_tween != null and slide_tween.is_valid():
		slide_tween.kill()
	slide_tween = create_tween()
	slide_tween.tween_method(
		func(v: float): panel.position.x = roundf(v),
		panel.position.x, target_x, duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)

# Resting place: tucked into the top-right corner.
func _on_x() -> float:
	return _native_width() - PANEL_WIDTH - EDGE_MARGIN

# Just past the right edge of the screen.
func _off_x() -> float:
	return _native_width()

func _native_width() -> float:
	return get_viewport().get_visible_rect().size.x / scale.x

# --- CONTENT ---
func _refresh_stats() -> void:
	var lines: Array = []
	if "stats" in shown and shown.stats != null:
		var stats: CombatantStats = shown.stats
		lines.append("Level " + str(stats.level))
		if "current_hp" in shown:
			lines.append("HP: " + str(shown.current_hp) + " / " + str(stats.get_max_hp()))
		lines.append("Damage: " + str(stats.base_damage_min) + "-" + str(stats.base_damage_max))
	lines.append("Dodge: " + str(roundi(CombatantStats.dodge_chance_for(shown) * 100.0)) + "%")

	if "status_effects" in shown:
		for effect_id in shown.status_effects.keys():
			lines.append(str(effect_id).capitalize() + " x" + str(shown.status_effects[effect_id]))

	body.text = "\n".join(lines)
	# Containers grow to fit on their own but never shrink back, so without this a
	# status wearing off would leave an empty line at the bottom.
	panel.reset_size()
