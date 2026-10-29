extends CanvasLayer

@onready var background: TextureRect = $Background

@export var basic_attack_icon: Texture2D
@export var ranged_attack_icon: Texture2D
@export var highlight_frames: SpriteFrames
@export var reject_cross_texture: Texture2D
@export var sc_orb_frames: SpriteFrames
@export var ranged_required_icon: SpriteFrames
@export var empty_orb_texture: Texture2D
# Animation named "charge" with not loop. Frames the same size as the icon.
@export var hold_charge_frames: SpriteFrames

var highlight_sprite: AnimatedSprite2D = null
var reject_sprite: AnimatedSprite2D = null
var reject_plays_remaining: int = 0
var first_slot_offset: Vector2 = Vector2(6, 6)
var slot_spacing: float = 24.0
var icon_size: Vector2 = Vector2(18, 18)
var reason_label: Label = null
var reason_tween: Tween = null
var name_label: Label = null
var name_tween: Tween = null
var slot_overlays: Array = []
var slot_blocked: Array = []
var overlay_tween_speed: float = 0.25
var slot_charge_labels: Array = []
var slot_charge_fade_labels: Array = []
var slot_charge_values: Array = []
# The same as the badge's own fade, so the number and the badge under it go together.
var charge_fade_speed: float = SLOT_VANISH_TIME
var slot_labels: Array = []
var slot_orbs: Array = []
var slot_empty_orbs: Array = []
var slot_orb_empty: Array = []
# Whether the slot's orb is showing at all. An emptied slot hides it, so a new SC ability always fades it back in.
var slot_orb_shown: Array = []
var slot_ranged_icons: Array = []
var slot_ranged_shown: Array = []
var label_rest_y: Array = []
var key_names: Array = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
var hold_charge_sprite: AnimatedSprite2D = null

# Which slot the charge animation is playing on, or -1 when it isn't.
var hold_charge_slot: int = -1
# Animation settings for when an ability is selected.
var select_offset: float = 1.0
var tween_speed: float = 0.12

# Stores the TextureRect nodes that display ability icons.
var slot_icons: Array = []
# Stores each icon's resting Y position so we know where to tween back to.
var slot_rest_y: Array = []
# Tracks which slot was active last frame so we only animate on change.
var previous_active_slot: int = -1

var hud_enabled: bool = true

# How long a slot takes to fade out when its ability is taken off the hotbar.
const SLOT_VANISH_TIME: float = 0.2
# The SC count's size and where it sits, relative to the slot's top-left corner. Both count
# labels use these, so the fading copy always lines up with the real one.
const CHARGE_SCALE: float = 0.87
const CHARGE_OFFSET: Vector2 = Vector2(14, -3)

# The ability each slot is showing, so a change can be spotted and animated.
var slot_shown_ids: Array[String] = []
var slot_change_tweens: Array[Tween] = []
# Slots that change at once instead of fading during the current refresh(). See refresh().
var snap_slots: Array[int] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_slots()
	# Starts matching the hotbar, so nothing animates on the first frame.
	for i: int in range(10):
		var ability_id: String = PlayerData.get_hotbar_ability(i)
		slot_shown_ids.append(ability_id)
		slot_change_tweens.append(null)
		slot_labels[i].modulate.a = 1.0 if ability_id != "" else 0.0
	_update_display()
	
func _process(_delta: float) -> void:
	# Follows the icon, which rises a pixel when its ability is selected.
	if hold_charge_slot != -1:
		hold_charge_sprite.position = slot_icons[hold_charge_slot].position
	if not hud_enabled:
		visible = false
		return
	visible = true
	_update_display()
	
func _build_slots() -> void:
	for i in range(10):
		var icon: TextureRect = TextureRect.new()
		# Makes sure icon does not force the frame to fit it.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# stretch_mode KEEP_ASPECT_CENTERED scales the texture to fit within the node's size without
		# distortion and centered.
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = icon_size
		
		# Calculates this icon's position on the background. Each slot is spaced evenly along the
		# horizontal axis. The x position starts at first_slot_offset.x and adds (slot_spacing * i)
		# for each subsequent slot.The y position is the same for all slots.
		var pos_x: float = first_slot_offset.x + (slot_spacing * i)
		var pos_y: float = first_slot_offset.y
		icon.position = Vector2(pos_x, pos_y)

		background.add_child(icon)
		slot_icons.append(icon)
		slot_rest_y.append(pos_y)
		
		var key_label: Label = Label.new()
		key_label.text = key_names[i]
		var font: Font = preload("res://assets/fonts/m3x6.ttf")
		key_label.add_theme_font_override("font", font)
		key_label.add_theme_font_size_override("font_size", 16)
		key_label.scale = Vector2(0.75, 0.75)
		key_label.add_theme_color_override("font_color", Color.WHITE)
		key_label.add_theme_color_override("font_outline_color", Color.BLACK)
		key_label.add_theme_constant_override("outline_size", 1)
		key_label.position = Vector2(pos_x - 1, pos_y - 5)
		label_rest_y.append(key_label.position.y)
		key_label.z_index = 2
		background.add_child(key_label)
		slot_labels.append(key_label)
		
		var charge_label: Label = Label.new()
		charge_label.text = ""
		var charge_font: Font = preload("res://assets/fonts/pixel-font-height-5.ttf")
		charge_label.add_theme_font_override("font", charge_font)
		charge_label.add_theme_font_size_override("font_size", 6)
		charge_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		charge_label.add_theme_color_override("font_outline_color", Color.BLACK)
		charge_label.add_theme_constant_override("outline_size", 1)
		charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		charge_label.size = Vector2(9, 9)
		charge_label.position = Vector2(pos_x, pos_y) + CHARGE_OFFSET
		charge_label.z_index = 3
		charge_label.scale = Vector2(CHARGE_SCALE, CHARGE_SCALE)
		background.add_child(charge_label)
		slot_charge_labels.append(charge_label)
		
		var charge_fade_label: Label = Label.new()
		charge_fade_label.add_theme_font_size_override("font_size", 6)
		charge_fade_label.add_theme_font_override("font", charge_font)
		charge_fade_label.add_theme_color_override("font_color", Color.WHITE)
		charge_fade_label.add_theme_color_override("font_outline_color", Color.BLACK)
		charge_fade_label.add_theme_constant_override("outline_size", 1)
		charge_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		charge_fade_label.size = Vector2(9, 9)
		charge_fade_label.position = Vector2(pos_x, pos_y) + CHARGE_OFFSET
		charge_fade_label.z_index = 3
		charge_fade_label.scale = Vector2(CHARGE_SCALE, CHARGE_SCALE)
		charge_fade_label.modulate = Color(1, 1, 1, 0)
		background.add_child(charge_fade_label)
		slot_charge_fade_labels.append(charge_fade_label)
		slot_charge_values.append("")
		
		var orb: AnimatedSprite2D = AnimatedSprite2D.new()
		orb.sprite_frames = sc_orb_frames
		orb.visible = true
		orb.stop()
		orb.frame = 0
		orb.centered = false
		orb.modulate = Color(1, 1, 1, 0)
		orb.offset = Vector2(0, 0)
		orb.position = Vector2(pos_x + 13, pos_y + icon_size.y - 22)
		orb.scale = Vector2(1, 1)
		orb.z_index = 2
		orb.stop()
		orb.frame = 0
		background.add_child(orb)
		slot_orbs.append(orb)
		
		var empty_orb: Sprite2D = Sprite2D.new()
		empty_orb.texture = empty_orb_texture
		empty_orb.centered = false
		empty_orb.position = Vector2(pos_x + 13, pos_y + icon_size.y - 22)
		empty_orb.scale = Vector2(1, 1)
		empty_orb.modulate = Color(1, 1, 1, 0)
		empty_orb.z_index = 2
		background.add_child(empty_orb)
		slot_empty_orbs.append(empty_orb)
		slot_orb_empty.append(true)
		slot_orb_shown.append(false)
		
		var overlay_rect: TextureRect = TextureRect.new()
		overlay_rect.texture = reject_cross_texture
		overlay_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		overlay_rect.size = icon_size
		overlay_rect.position = Vector2(pos_x, pos_y)
		overlay_rect.modulate = Color(1, 1, 1, 0)
		overlay_rect.z_index = 1
		background.add_child(overlay_rect)
		slot_overlays.append(overlay_rect)
		slot_blocked.append(false)
		
		var ranged_icon: AnimatedSprite2D = AnimatedSprite2D.new()
		ranged_icon.sprite_frames = ranged_required_icon
		ranged_icon.centered = false
		ranged_icon.stop()
		ranged_icon.frame = 0
		ranged_icon.offset = Vector2(0, 0)
		ranged_icon.position = Vector2(pos_x +- 12 + icon_size.x, pos_y - 2)
		ranged_icon.scale = Vector2(icon_size.x / 24.0, icon_size.y / 24.0)
		ranged_icon.modulate = Color(1, 1, 1, 0)
		ranged_icon.z_index = 3
		background.add_child(ranged_icon)
		slot_ranged_icons.append(ranged_icon)
		slot_ranged_shown.append(false)
		
		reason_label = Label.new()
		var reason_font: Font = preload("res://assets/fonts/m3x6.ttf")
		reason_label.add_theme_font_override("font", reason_font)
		reason_label.add_theme_font_size_override("font_size", 32)
		reason_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		reason_label.add_theme_color_override("font_outline_color", Color.BLACK)
		reason_label.add_theme_constant_override("outline_size", 3)
		reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reason_label.visible = false
		add_child(reason_label)

	name_label = Label.new()
	var name_font: Font = preload("res://assets/fonts/m3x6.ttf")
	name_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	name_label.add_theme_font_override("font", name_font)
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.visible = false
	add_child(name_label)

	highlight_sprite = AnimatedSprite2D.new()
	highlight_sprite.scale = Vector2(icon_size.x / 18.0, icon_size.y / 18.0)
	highlight_sprite.sprite_frames = highlight_frames
	highlight_sprite.visible = false
	highlight_sprite.offset = Vector2(9, 8)
	highlight_sprite.z_index = 1
	highlight_sprite.animation_finished.connect(_on_highlight_animation_finished)
	background.add_child(highlight_sprite)
	
	reject_sprite = AnimatedSprite2D.new()
	reject_sprite.sprite_frames = highlight_frames
	reject_sprite.visible = false
	reject_sprite.offset = Vector2(9, 9)
	reject_sprite.scale = Vector2(icon_size.x / 18.0, icon_size.y / 18.0)
	reject_sprite.z_index = 1
	reject_sprite.animation_finished.connect(_on_reject_animation_finished)
	background.add_child(reject_sprite)
	
	hold_charge_sprite = AnimatedSprite2D.new()
	hold_charge_sprite.sprite_frames = hold_charge_frames
	hold_charge_sprite.centered = false
	hold_charge_sprite.visible = false
	hold_charge_sprite.z_index = 1
	# Hides itself when the charge finishes, so it can play out after the key is let go.
	hold_charge_sprite.animation_finished.connect(stop_hold_charge)
	background.add_child(hold_charge_sprite)
	
func _on_highlight_animation_finished() -> void:
	if highlight_sprite.animation == "select_intro":
		highlight_sprite.play("select_loop")

func _on_reject_animation_finished() -> void:
	reject_plays_remaining -= 1
	if reject_plays_remaining > 0:
		reject_sprite.play("reject")
	else:
		reject_sprite.visible = false

func _update_display() -> void:
	var current_active_slot: int = -1
	if BattleManager.active and BattleManager.player_turn != null:
		current_active_slot = BattleManager.player_turn.active_hotbar_slot
		
	# Refreshes each slot's icon texture.
	for i in range(10):
		var ability_id: String = PlayerData.get_hotbar_ability(i)

		var changed: bool = ability_id != slot_shown_ids[i]
		# Icons, key numbers, charge badges and numbers all fade in and out when a slot changes,
		# unless refresh() was told this slot should change at once.
		var snap: bool = i in snap_slots
		if changed:
			_animate_slot_change(i, ability_id)
			slot_shown_ids[i] = ability_id

		# An emptied slot keeps its old icon while it fades out. _clear_slot_icon removes it after.
		if ability_id == "basic_attack":
			if PlayerData.is_ranged_weapon_equipped():
				slot_icons[i].texture = ranged_attack_icon
			else:
				slot_icons[i].texture = basic_attack_icon
		elif ability_id != "":
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			slot_icons[i].texture = data.get("icon", null)
			
		var wanted_charge: String = ""
		if ability_id != "" and ability_id != "basic_attack":
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			var cost: Dictionary = data.get("cost", {})
			if cost.has("sc"):
				wanted_charge = str(PlayerData.get_spell_charges(ability_id))

		if wanted_charge != slot_charge_values[i]:
			if snap:
				slot_charge_labels[i].text = wanted_charge
				slot_charge_labels[i].modulate.a = 1.0
				slot_charge_fade_labels[i].modulate.a = 0.0
			else:
				_fade_charge_value(i, slot_charge_values[i], wanted_charge)
			slot_charge_values[i] = wanted_charge
		
		var wants_ranged_icon: bool = false
		if ability_id != "" and ability_id != "basic_attack":
			var rdata: Dictionary = AbilityDB.get_ability(ability_id)
			if rdata.get("requires_ranged_weapon", false) and not PlayerData.is_ranged_weapon_equipped():
				wants_ranged_icon = true
		if wants_ranged_icon != slot_ranged_shown[i]:
			slot_ranged_shown[i] = wants_ranged_icon
			var target_a: float = 1.0 if wants_ranged_icon else 0.0
			_set_alpha(slot_ranged_icons[i], target_a, snap, overlay_tween_speed)
			
		if ability_id != "" and ability_id != "basic_attack":
			var data2: Dictionary = AbilityDB.get_ability(ability_id)
			var cost2: Dictionary = data2.get("cost", {})
			if cost2.has("sc"):
				var charges: int = PlayerData.get_spell_charges(ability_id)
				var is_empty: bool = charges <= 0

				if is_empty != slot_orb_empty[i] or not slot_orb_shown[i]:
					slot_orb_empty[i] = is_empty
					slot_orb_shown[i] = true
					var orb_alpha: float = 0.0 if is_empty else 1.0
					var empty_alpha: float = 1.0 if is_empty else 0.0
					_set_alpha(slot_orbs[i], orb_alpha, snap, overlay_tween_speed)
					_set_alpha(slot_empty_orbs[i], empty_alpha, snap, overlay_tween_speed)

				if not is_empty:
					if slot_orbs[i].modulate.a < 1.0:
						pass
					elif current_active_slot == i:
						slot_charge_labels[i].add_theme_color_override("font_color", Color(1, 1, 1))
						slot_charge_fade_labels[i].add_theme_color_override("font_color", Color(1, 1, 1))
						if not slot_orbs[i].is_playing():
							slot_orbs[i].play("default")
					else:
						slot_charge_labels[i].add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
						slot_charge_fade_labels[i].add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
						slot_orbs[i].stop()
						slot_orbs[i].frame = 0
			else:
				_hide_orbs(i, snap)
		else:
			_hide_orbs(i, snap)
			
		if BattleManager.active and BattleManager.player_turn != null and ability_id != "":
			var reasons: Array = BattleManager.player_turn.get_slot_block_reasons(i)
			var is_blocked: bool = not reasons.is_empty()
			if is_blocked != slot_blocked[i]:
				slot_blocked[i] = is_blocked
				var target_alpha: float = 1.0 if is_blocked else 0.0
				_set_alpha(slot_overlays[i], target_alpha, snap, overlay_tween_speed)
		else:
			var out_blocked: bool = false
			if ability_id == "basic_attack":
				if PlayerData.bp_max <= 0:
					out_blocked = true
			elif ability_id != "":
				var data3: Dictionary = AbilityDB.get_ability(ability_id)
				if data3.get("requires_ranged_weapon", false) and not PlayerData.is_ranged_weapon_equipped():
					out_blocked = true
				if not out_blocked:
					var cost3: Dictionary = data3.get("cost", {})
					for resource3 in cost3.keys():
						var amount3: int = cost3[resource3]
						match resource3:
							"ap":
								if PlayerData.ap_max < amount3:
									out_blocked = true
							"bp":
								if PlayerData.bp_max < amount3:
									out_blocked = true
							"mp":
								if PlayerData.get_max_mp() < amount3:
									out_blocked = true
							"sc":
								if PlayerData.get_spell_charges(data3.get("id", "")) < amount3:
									out_blocked = true
			if out_blocked != slot_blocked[i]:
				slot_blocked[i] = out_blocked
				var target_alpha: float = 1.0 if out_blocked else 0.0
				_set_alpha(slot_overlays[i], target_alpha, snap, overlay_tween_speed)

	# Only animates when the active slot changes, not every frame.
	if current_active_slot != previous_active_slot:
		_animate_selection(previous_active_slot, current_active_slot)
		if current_active_slot >= 0:
			_show_ability_name(current_active_slot)
		else:
			_hide_ability_name()
		previous_active_slot = current_active_slot
	
	# Switche's highlight animation based on confirm state.
	if highlight_sprite.visible and current_active_slot >= 0:
		var awaiting_confirm: bool = false
		var pt: CombatantTurn = BattleManager.player_turn
		if pt != null:
			if pt.mode == CombatantTurn.Mode.ATTACK and pt.has_target:
				awaiting_confirm = true
			elif pt.mode == CombatantTurn.Mode.ABILITY and pt.has_ability_target:
				awaiting_confirm = true

		if awaiting_confirm:
			if highlight_sprite.animation != "confirm":
				highlight_sprite.play("confirm")
		else:
			if highlight_sprite.animation == "confirm":
				highlight_sprite.play("select_loop")
				
	# Check for rejected ability.
	if BattleManager.rejected_hotbar_slot >= 0:
		var rejected_slot: int = BattleManager.rejected_hotbar_slot
		BattleManager.rejected_hotbar_slot = -1
		if rejected_slot < slot_icons.size():
			_play_reject(rejected_slot)

# Hides the slot's orbs with the icon. Runs once, not every frame, thanks to slot_orb_shown.
func _hide_orbs(slot: int, snap: bool) -> void:
	if not slot_orb_shown[slot]:
		return
	slot_orb_shown[slot] = false
	_set_alpha(slot_orbs[slot], 0.0, snap, SLOT_VANISH_TIME)
	_set_alpha(slot_empty_orbs[slot], 0.0, snap, SLOT_VANISH_TIME)

# Arriving: the icon shows at once and flashes, like in the tree, and its key number fades in.
# Leaving, whether it came off or moved to another slot: the icon and number fade out, and the
# icon is cleared once they're gone.
func _animate_slot_change(slot: int, ability_id: String) -> void:
	var icon: TextureRect = slot_icons[slot]
	var label: Label = slot_labels[slot]
	var old_tween: Tween = slot_change_tweens[slot]
	if old_tween != null and old_tween.is_valid():
		old_tween.kill()
	UiFade.stop(icon)
	var tween: Tween = create_tween()
	slot_change_tweens[slot] = tween
	if ability_id != "":
		icon.modulate = Color.WHITE
		UiFade.flash(icon)
		tween.tween_property(label, "modulate:a", 1.0, SLOT_VANISH_TIME)
	else:
		tween.tween_property(icon, "modulate:a", 0.0, SLOT_VANISH_TIME)
		# parallel() runs a step alongside the one before it, so the number fades with the icon.
		tween.parallel().tween_property(label, "modulate:a", 0.0, SLOT_VANISH_TIME)
		tween.tween_callback(_clear_slot_icon.bind(slot))

# Fades a node's alpha, or sets it straight away when snap is true. Any fade still running on it
# is stopped first, so a quick swap can't be undone by an older fade finishing late.
func _set_alpha(item: CanvasItem, alpha: float, snap: bool, duration: float) -> void:
	if item.has_meta("alpha_tween"):
		var old_tween: Tween = item.get_meta("alpha_tween")
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
	if snap:
		item.modulate.a = alpha
		return
	var tween: Tween = create_tween()
	tween.tween_property(item, "modulate:a", alpha, duration)
	item.set_meta("alpha_tween", tween)

# Only clears if the slot is still empty, in case something was put back on it mid-fade.
func _clear_slot_icon(slot: int) -> void:
	if PlayerData.get_hotbar_ability(slot) == "":
		slot_icons[slot].texture = null
		slot_icons[slot].modulate = Color.WHITE

func _animate_selection(old_slot: int, new_slot: int) -> void:
	if old_slot >= 0 and old_slot < slot_icons.size():
		var tween_down: Tween = create_tween()
		tween_down.set_parallel(true)
		tween_down.tween_property(
			slot_icons[old_slot], "position:y",
			slot_rest_y[old_slot], tween_speed
		)
		tween_down.tween_property(
			slot_labels[old_slot], "position:y",
			label_rest_y[old_slot], tween_speed
		)
		slot_icons[old_slot].modulate = Color.WHITE

	if new_slot >= 0 and new_slot < slot_icons.size():
		var tween_up: Tween = create_tween()
		tween_up.set_parallel(true)
		tween_up.tween_property(
			slot_icons[new_slot], "position:y",
			slot_rest_y[new_slot] - select_offset, tween_speed
		)
		tween_up.tween_property(
			slot_labels[new_slot], "position:y",
			label_rest_y[new_slot] - select_offset, tween_speed
		)
		slot_icons[new_slot].modulate = Color(1.241, 1.225, 1.055, 1.0)	
		highlight_sprite.position = slot_icons[new_slot].position
		highlight_sprite.visible = true
		highlight_sprite.play("select_intro")
	else:
		highlight_sprite.visible = false

func _fade_charge_value(slot: int, old_value: String, new_value: String) -> void:
	var main_label: Label = slot_charge_labels[slot]
	var fade_label: Label = slot_charge_fade_labels[slot]

	# Old value appears on the twin label and fades out.
	fade_label.text = old_value
	# Takes the main label's current colour, so the old number doesn't brighten as it starts fading.
	fade_label.add_theme_color_override("font_color", main_label.get_theme_color("font_color"))
	fade_label.modulate = Color(1, 1, 1, 1)
	var out_tween: Tween = create_tween()
	out_tween.tween_property(fade_label, "modulate:a", 0.0, charge_fade_speed)

	# New value goes on the main label and fades in.
	main_label.text = new_value
	main_label.modulate = Color(1, 1, 1, 0)
	var in_tween: Tween = create_tween()
	in_tween.tween_property(main_label, "modulate:a", 1.0, charge_fade_speed)

func _play_reject(slot: int) -> void:
	_show_reject_reason(slot)
	var icon: TextureRect = slot_icons[slot]
	var rest_x: float = first_slot_offset.x + (slot_spacing * slot)
	var label_x: float = rest_x - 1.0
	var ranged_x: float = rest_x + icon_size.x - 12

	var shake_tween: Tween = create_tween()
	shake_tween.set_parallel(true)

	# Step 1: Everything moves left.
	shake_tween.tween_property(icon, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x - 1.0, 0.05)
	shake_tween.tween_property(slot_overlays[slot], "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_ranged_icons[slot], "position:x", ranged_x + 1.0, 0.05)

	# Step 2: Everything moves right.
	shake_tween.chain()
	shake_tween.tween_property(slot_ranged_icons[slot], "position:x", ranged_x - 1.0, 0.05)
	shake_tween.tween_property(icon, "position:x", rest_x + 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x + 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x + 1.0, 0.05)
	shake_tween.tween_property(slot_overlays[slot], "position:x", rest_x + 1.0, 0.05)
	
	# Step 3: Everything moves left again.
	shake_tween.chain()
	shake_tween.tween_property(icon, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x - 1.0, 0.05)
	shake_tween.tween_property(slot_overlays[slot], "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_ranged_icons[slot], "position:x", ranged_x + 1.0, 0.05)
	
	# Step 4: Everything returns to rest.
	shake_tween.chain()
	shake_tween.tween_property(icon, "position:x", rest_x, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x, 0.05)
	shake_tween.tween_property(slot_overlays[slot], "position:x", rest_x, 0.05)
	shake_tween.tween_property(slot_ranged_icons[slot], "position:x", ranged_x, 0.05)

	reject_plays_remaining = 2
	reject_sprite.position = icon.position
	reject_sprite.visible = true
	reject_sprite.play("reject")
	
	if slot_ranged_shown[slot]:
		slot_ranged_icons[slot].frame = 0
		slot_ranged_icons[slot].play("default")
		
	# Two red flashes, one after the other, on the empty orb and its count.
	if slot_orb_empty[slot] and slot_empty_orbs[slot].modulate.a > 0:
		var orb_flash: Tween = create_tween()
		var label_flash: Tween = create_tween()
		for i: int in range(2):
			orb_flash.tween_property(slot_empty_orbs[slot], "modulate", Color(1, 0.3, 0.3, 1), 0.1)
			orb_flash.tween_property(slot_empty_orbs[slot], "modulate", Color(1, 1, 1, 1), 0.1)
			label_flash.tween_property(slot_charge_labels[slot], "modulate", Color(1, 0.3, 0.3, 1), 0.1)
			label_flash.tween_property(slot_charge_labels[slot], "modulate", Color(1, 1, 1, 1), 0.1)
	
func _show_ability_name(slot: int) -> void:
	var ability_id: String = PlayerData.get_hotbar_ability(slot)
	if reason_tween != null and reason_tween.is_valid():
		reason_tween.kill()
	reason_label.visible = false
	if ability_id == "":
		return

	var display_name: String = ""
	if ability_id == "basic_attack":
		display_name = "Attack"
	else:
		var data: Dictionary = AbilityDB.get_ability(ability_id)
		display_name = data.get("name", "")

	if display_name == "":
		return

	name_label.text = display_name
	_position_label_above_slot(name_label, slot, -35)

	if name_tween != null and name_tween.is_valid():
		name_tween.kill()

	name_label.modulate = Color(1, 1, 1, 0)
	name_label.visible = true

	name_tween = create_tween()
	name_tween.tween_property(name_label, "modulate:a", 1.0, 0.15)

func _hide_ability_name() -> void:
	if name_label == null or not name_label.visible:
		return

	if name_tween != null and name_tween.is_valid():
		name_tween.kill()

	name_tween = create_tween()
	name_tween.tween_property(name_label, "modulate:a", 0.0, 0.3)
	name_tween.tween_callback(func(): name_label.visible = false)
	
func _show_reject_reason(slot: int) -> void:
	var pt: CombatantTurn = BattleManager.player_turn
	if name_tween != null and name_tween.is_valid():
		name_tween.kill()
	name_label.visible = false
	if pt == null:
		return

	var reasons: Array = pt.get_slot_block_reasons(slot)
	if reasons.is_empty():
		return
		
	var ability_id: String = PlayerData.get_hotbar_ability(slot)
	var display_name: String = ""
	if ability_id == "basic_attack":
		display_name = "Attack"
	else:
		var data: Dictionary = AbilityDB.get_ability(ability_id)
		display_name = data.get("name", "")

	reason_label.text = display_name + ": " + ", ".join(reasons)
	_position_label_above_slot(reason_label, slot, -35)

	if reason_tween != null and reason_tween.is_valid():
		reason_tween.kill()

	reason_label.modulate = Color(1, 1, 1, 0)
	reason_label.visible = true

	reason_tween = create_tween()
	reason_tween.tween_property(reason_label, "modulate:a", 1.0, 0.15)
	reason_tween.tween_interval(0.8)
	reason_tween.tween_property(reason_label, "modulate:a", 0.0, 0.5)
	reason_tween.tween_callback(func(): reason_label.visible = false)

func _position_label_above_slot(label: Label, slot: int, y_offset: float) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var label_width: float = text_width + 16.0
	label.size = Vector2(label_width, 40)

	var slot_local_x: float = first_slot_offset.x + (slot_spacing * slot) + (icon_size.x / 2)
	var slot_screen_x: float = background.global_position.x + (slot_local_x * background.scale.x)

	var margin: float = 4.0
	var viewport_width: float = get_viewport().get_visible_rect().size.x
	var label_x: float = clampf(slot_screen_x - (label_width / 2.0), margin, viewport_width - label_width - margin)
	label.position = Vector2(label_x, background.global_position.y + y_offset)

# --- HOLD FOR INFO ---
# Plays the charge animation on that slot, sped up or slowed down to match the frame rate.
func start_hold_charge(slot: int, duration: float) -> void:
	if hold_charge_frames == null or not hold_charge_frames.has_animation("charge"):
		return
	var frame_count: int = hold_charge_frames.get_frame_count("charge")
	var fps: float = hold_charge_frames.get_animation_speed("charge")
	hold_charge_sprite.speed_scale = (frame_count / fps) / duration
	hold_charge_slot = slot
	hold_charge_sprite.position = slot_icons[slot].position
	hold_charge_sprite.visible = true
	hold_charge_sprite.play("charge")

func stop_hold_charge() -> void:
	hold_charge_slot = -1
	hold_charge_sprite.stop()
	hold_charge_sprite.visible = false
	
# Find out where the slots icon is on the screen in real pixels.
func get_slot_screen_rect(slot: int) -> Rect2:
	var local_pos: Vector2 = Vector2(first_slot_offset.x + (slot_spacing * slot), first_slot_offset.y)
	var screen_pos: Vector2 = background.global_position + local_pos * background.scale
	return Rect2(screen_pos, icon_size * background.scale)

# --- PLACING (used by the ability panel) ---
# The parts of a slot that belong to its ability rather than the slot: the icon, the charge badge
# and numbers, the ranged icon and the reject cross. The key number stays, since it's the slot's.
# Controls and Node2Ds are listed apart because they don't share a type with visible on it.
func _slot_controls(slot: int) -> Array[Control]:
	return [slot_icons[slot], slot_charge_labels[slot], slot_charge_fade_labels[slot], slot_overlays[slot]]

func _slot_sprites(slot: int) -> Array[Node2D]:
	return [slot_orbs[slot], slot_empty_orbs[slot], slot_ranged_icons[slot]]

# Slides an ability's parts sideways by offset pixels without moving the slot, badge and numbers
# included. Each part remembers where it was built, so an offset of 0 always puts it back exactly.
func set_slot_offset(slot: int, slot_offset: float) -> void:
	for part: Control in _slot_controls(slot):
		if not part.has_meta("rest_x"):
			part.set_meta("rest_x", part.position.x)
		part.position.x = part.get_meta("rest_x") + slot_offset
	for part: Node2D in _slot_sprites(slot):
		if not part.has_meta("rest_x"):
			part.set_meta("rest_x", part.position.x)
		part.position.x = part.get_meta("rest_x") + slot_offset

# Hides a slot's ability while a copy of it moves. Uses visible rather than modulate, since the
# hotbar fades these with modulate itself.
func set_slot_hidden(slot: int, hidden: bool) -> void:
	for part: Control in _slot_controls(slot):
		part.visible = not hidden
	for part: Node2D in _slot_sprites(slot):
		part.visible = not hidden

# Updates the slots now instead of next frame, so a change lands on the same frame the copies go.
# Slots listed in snap change at once rather than fading. That's for an ability that has visibly
# been carried there, so its badge doesn't fade out in one place and back in at another.
func refresh(snap: Array[int] = []) -> void:
	snap_slots = snap
	_update_display()
	snap_slots = []
