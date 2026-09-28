extends CanvasLayer

# --- TIMING ---
# Nothing visible yet, so ordinary taps never show the charge.
const CHARGE_DELAY: float = 0.2
# The charge animation on the hotbar slot. When it finishes, the window opens.
# Letting go at any point before then is a tap, which selects the ability.
const CHARGE_TIME: float = 0.5
const GROW_TIME: float = 0.22
const SHRINK_TIME: float = 0.18
const CONTENT_FADE_TIME: float = 0.1
# How far through the charge the window opens (0.8 = 80%). The animation plays out
# the rest of the way on its own, whether or not the key is still held.
const OPEN_AT: float = 0.50

# --- LAYOUT (native pixels, i.e. the 480x270 space) ---
# Width is fixed so the body text always wraps at the same point. Height is measured
# from the content each time the window opens.
const WINDOW_WIDTH: int = 230
# Screen is 270 tall - this leaves an 8px gap top and bottom.
const MAX_HEIGHT: int = 254

const RESOURCE_NAMES: Dictionary = {"ap": "AP", "bp": "BP", "mp": "MP", "sc": "SC"}

enum State {IDLE, HOLDING, CHARGING, OPENING, OPEN, CLOSING}

# --- NODES ---
@onready var frame: NinePatchRect = $frame
@onready var content: MarginContainer = $frame/content
@onready var icon: TextureRect = $frame/content/vbox/header/icon
@onready var title: Label = $frame/content/vbox/header/title
@onready var body: Label = $frame/content/vbox/body

# --- STATE ---
var state: int = State.IDLE
var held_slot: int = -1
var hold_timer: float = 0.0
var open_slot: int = -1
# Hotbar slots whose press this screen took. Their releases must never reach combat,
# or letting go would select the ability.
var swallow_releases: Array = []
# Where the window grows out of and shrinks back into, in native pixels.
var slot_rect: Rect2 = Rect2()
var frame_tween: Tween = null
# Size the window grows to this time, worked out from its content in _open.
var window_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Must keep running while the game is paused, since opening pauses it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	content.visible = false


# --- HOLD DETECTION ---
func _process(delta: float) -> void:
	match state:
		State.IDLE:
			var slot: int = _just_pressed_slot()
			if slot != -1 and _can_start(slot):
				held_slot = slot
				hold_timer = 0.0
				state = State.HOLDING

		State.HOLDING, State.CHARGING:
			# Let go at any point before the window opens: that was a tap. The release
			# passes through to combat untouched, which selects the ability.
			if not Input.is_action_pressed(PlayerData.HOTBAR_ACTIONS[held_slot]) or not _can_start(held_slot):
				_cancel_hold()
				return
			hold_timer += delta
			if state == State.HOLDING and hold_timer >= CHARGE_DELAY:
				state = State.CHARGING
				hold_timer = 0.0
				HotbarDisplay.start_hold_charge(held_slot, CHARGE_TIME)
			elif state == State.CHARGING and hold_timer >= CHARGE_TIME * OPEN_AT:
				# No stop_hold_charge here. The hotbar hides the sprite once it finishes.
				# Only a completed charge is a hold, so only now is the release swallowed.
				_swallow_release_of(held_slot)
				_open(held_slot)

func _just_pressed_slot() -> int:
	for i in range(PlayerData.HOTBAR_ACTIONS.size()):
		if Input.is_action_just_pressed(PlayerData.HOTBAR_ACTIONS[i]):
			return i
	return -1


func _can_start(slot: int) -> bool:
	if PlayerData.get_hotbar_ability(slot) == "":
		return false
	if GameMenuManager.is_open or DialogueManager.is_open:
		return false
	# Combat keeps the tree paused for the whole fight, so a paused tree only means
	# "another screen has the game" (like loot) outside of combat.
	if get_tree().paused and not BattleManager.active:
		return false
	if not HotbarDisplay.visible:
		return false
	if TurnOrderScreen.is_open:
		return false
	return true


func _cancel_hold() -> void:
	HotbarDisplay.stop_hold_charge()
	state = State.IDLE
	held_slot = -1


func _swallow_release_of(slot: int) -> void:
	if slot not in swallow_releases:
		swallow_releases.append(slot)


# --- INPUT ---
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	# Checked in every state, since a release can arrive after the window has closed.
	var released: int = PlayerData.get_hotbar_slot_released(event)
	if released != -1 and released in swallow_releases:
		swallow_releases.erase(released)
		get_viewport().set_input_as_handled()
		return

	if state == State.IDLE or state == State.HOLDING or state == State.CHARGING:
		return

	# The window is on screen from here on, so every key stops here.
	var pressed: int = PlayerData.get_hotbar_slot_from_event(event)
	if pressed != -1:
		_swallow_release_of(pressed)
	if state == State.OPEN and not event.is_echo():
		if event.is_action_pressed("ui_cancel") or pressed == open_slot:
			_close()
	get_viewport().set_input_as_handled()


# --- OPEN / CLOSE ---
func _open(slot: int) -> void:
	state = State.OPENING
	open_slot = slot
	_fill_content(slot)

	# Does nothing in combat, where the tree is already paused.
	get_tree().paused = true
	BattleManager.input_locked = true

	# Lay the content out at full width but invisible, so Godot works out how tall the
	# wrapped text makes it. The window has to be visible for containers to lay out,
	# so it is faded to nothing instead of hidden.
	visible = true
	frame.modulate.a = 0.0
	content.visible = true
	content.modulate.a = 0.0
	frame.size = Vector2(WINDOW_WIDTH, 0)
	# One frame for the containers to lay out, one for the wrapped label to report
	# its new height back up. Too short to see.
	await get_tree().process_frame
	await get_tree().process_frame
	var needed_height: float = ceilf(content.get_combined_minimum_size().y)
	window_size = Vector2(WINDOW_WIDTH, minf(needed_height, MAX_HEIGHT))

	# Now grow out of the slot as normal.
	content.visible = false
	frame.modulate.a = 1.0
	slot_rect = _slot_rect_native(slot)
	_apply_grow(0.0)

	_tween_frame(0.0, 1.0, GROW_TIME, Tween.EASE_OUT)
	frame_tween.tween_callback(_on_opened)
	frame_tween.tween_property(content, "modulate:a", 1.0, CONTENT_FADE_TIME)


func _on_opened() -> void:
	state = State.OPEN
	content.visible = true


func _close() -> void:
	state = State.CLOSING
	content.visible = false
	_tween_frame(1.0, 0.0, SHRINK_TIME, Tween.EASE_IN)
	frame_tween.tween_callback(_on_closed)


func _on_closed() -> void:
	state = State.IDLE
	visible = false
	open_slot = -1
	held_slot = -1
	# Paused if and only if a battle is running - combat owns the pause during a fight.
	get_tree().paused = BattleManager.active
	BattleManager.input_locked = false


# --- GROW / SHRINK ---
func _tween_frame(from_t: float, to_t: float, duration: float, ease_type: Tween.EaseType) -> void:
	if frame_tween != null and frame_tween.is_valid():
		frame_tween.kill()
	frame_tween = create_tween()
	frame_tween.tween_method(_apply_grow, from_t, to_t, duration).set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)


# t = 0 is sitting on the slot, t = 1 is full size in the centre. Position and size are
# both rounded, so every frame of the animation lands on whole pixels.
func _apply_grow(t: float) -> void:
	var centre_rect: Rect2 = _centre_rect()
	var pos: Vector2 = slot_rect.position.lerp(centre_rect.position, t)
	var rect_size: Vector2 = slot_rect.size.lerp(centre_rect.size, t)
	frame.size = rect_size.round()
	frame.position = pos.round()


# The hotbar works in real screen pixels, this layer in native ones, so divide by our scale.
func _slot_rect_native(slot: int) -> Rect2:
	var screen_rect: Rect2 = HotbarDisplay.get_slot_screen_rect(slot)
	return Rect2(screen_rect.position / scale, screen_rect.size / scale)

func _centre_rect() -> Rect2:
	var native_screen: Vector2 = get_viewport().get_visible_rect().size / scale
	var pos: Vector2 = (native_screen - window_size) / 2.0
	return Rect2(pos.round(), window_size)

# --- CONTENT ---
func _fill_content(slot: int) -> void:
	# Reuse the hotbar's icon so attack/ranged attack picks the right one automatically.
	icon.texture = HotbarDisplay.slot_icons[slot].texture
	var ability_id: String = PlayerData.get_hotbar_ability(slot)
	if ability_id == "basic_attack":
		_fill_basic_attack()
	else:
		_fill_ability(ability_id)


func _fill_ability(ability_id: String) -> void:
	var data: Dictionary = AbilityDB.get_ability(ability_id)
	title.text = data.get("name", "")

	var lines: Array = []
	var tree_name: String = data.get("tree", "")
	if tree_name != "":
		lines.append(tree_name.capitalize() + " tree, level " + str(data.get("level_req", 1)))

	var cost: Dictionary = data.get("cost", {})
	if not cost.is_empty():
		lines.append("Cost: " + _cost_text(cost))
	if cost.has("sc"):
		lines.append("Charges: " + str(PlayerData.get_spell_charges(ability_id)) + " / " + str(data.get("max_sc", 0)))

	if data.get("requires_ranged_weapon", false):
		lines.append("Requires a ranged weapon")
	if data.get("requires_first_action", false):
		lines.append("Must be your first action")
	if data.get("ends_turn", false):
		lines.append("Ends your turn")

	lines.append("")
	lines.append(data.get("description", ""))
	body.text = "\n".join(lines)


func _fill_basic_attack() -> void:
	var ranged: bool = PlayerData.is_ranged_weapon_equipped()
	title.text = "Ranged Attack" if ranged else "Attack"

	var lines: Array = ["Cost: 1 BP"]
	var weapon: Dictionary = PlayerData.get_equipped_weapon()
	if weapon.is_empty():
		lines.append("Damage: 1 (unarmed)")
	else:
		lines.append("Weapon: " + str(weapon.get("name", "")))
		var dmg: Dictionary = ItemDB.calculate_damage(weapon, PlayerData.get_stats_dict())
		lines.append("Damage: " + str(dmg["min"]) + "-" + str(dmg["max"]))
		if ranged:
			lines.append("Range: " + str(weapon.get("weapon_range", 12)))
	if PlayerData.is_dual_wielding():
		lines.append("Off-hand strikes again for 50%")

	lines.append("")
	lines.append("Strike with your equipped weapon.")
	body.text = "\n".join(lines)


# {"ap": 1, "mp": 3} becomes "1 AP, 3 MP".
func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for resource in cost.keys():
		parts.append(str(cost[resource]) + " " + RESOURCE_NAMES.get(resource, resource.to_upper()))
	return ", ".join(parts)
