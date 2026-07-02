extends CanvasLayer

@onready var background: TextureRect = $Background

@export var basic_attack_icon: Texture2D
@export var highlight_frames: SpriteFrames
@export var reject_cross_texture: Texture2D
@export var sc_orb_frames: SpriteFrames
@export var ranged_required_icon: SpriteFrames
@export var empty_orb_texture: Texture2D

var highlight_sprite: AnimatedSprite2D = null
var reject_sprite: AnimatedSprite2D = null
var reject_plays_remaining: int = 0
var first_slot_offset: Vector2 = Vector2(8, 8)
var slot_spacing: float = 32.0
var icon_size: Vector2 = Vector2(24, 24)
var reason_label: Label = null
var reason_tween: Tween = null
var slot_overlays: Array = []
var slot_blocked: Array = []
var overlay_tween_speed: float = 0.25
var slot_charge_labels: Array = []
var slot_charge_fade_labels: Array = []
var slot_charge_values: Array = []
var charge_fade_speed: float = 0.3
var slot_labels: Array = []
var slot_orbs: Array = []
var slot_empty_orbs: Array = []
var slot_orb_empty: Array = []
var slot_ranged_icons: Array = []
var slot_ranged_shown: Array = []
var label_rest_y: Array = []
var key_names: Array = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_slots()
	_update_display()
	
func _process(_delta: float) -> void:
	if not hud_enabled:
		visible = false
		return
	visible = not GameMenuManager.is_open
	if visible:
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
		key_label.add_theme_color_override("font_color", Color.WHITE)
		key_label.add_theme_color_override("font_outline_color", Color.BLACK)
		key_label.add_theme_constant_override("outline_size", 1)
		key_label.position = Vector2(pos_x - 1, pos_y - 7)
		label_rest_y.append(key_label.position.y)
		key_label.z_index = 2
		key_label.visible = false
		background.add_child(key_label)
		slot_labels.append(key_label)
		
		var charge_label: Label = Label.new()
		charge_label.text = ""
		var charge_font: Font = preload("res://assets/fonts/m3x6.ttf")
		charge_label.add_theme_font_override("font", charge_font)
		charge_label.add_theme_font_size_override("font_size", 16)
		charge_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		charge_label.add_theme_color_override("font_outline_color", Color.BLACK)
		charge_label.add_theme_constant_override("outline_size", 1)
		charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		charge_label.size = Vector2(icon_size.x + 1, 12)
		charge_label.position = Vector2(pos_x + 0.25, pos_y + icon_size.y - 6)
		charge_label.z_index = 3
		background.add_child(charge_label)
		slot_charge_labels.append(charge_label)
		
		var charge_fade_label: Label = Label.new()
		charge_fade_label.add_theme_font_override("font", charge_font)
		charge_fade_label.add_theme_font_size_override("font_size", 16)
		charge_fade_label.add_theme_color_override("font_color", Color.WHITE)
		charge_fade_label.add_theme_color_override("font_outline_color", Color.BLACK)
		charge_fade_label.add_theme_constant_override("outline_size", 1)
		charge_fade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		charge_fade_label.size = Vector2(icon_size.x + 1, 12)
		charge_fade_label.position = Vector2(pos_x, pos_y + icon_size.y - 6)
		charge_fade_label.z_index = 3
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
		orb.position = Vector2(pos_x + 5.5, pos_y + icon_size.y - 4)
		orb.scale = Vector2(1.5, 1.5)
		orb.z_index = 2
		orb.stop()
		orb.frame = 0
		background.add_child(orb)
		slot_orbs.append(orb)
		
		var empty_orb: TextureRect = TextureRect.new()
		empty_orb.texture = empty_orb_texture
		empty_orb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		empty_orb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		empty_orb.size = Vector2(12, 12)
		empty_orb.position = Vector2(pos_x + 5.5, pos_y + icon_size.y - 4)
		empty_orb.modulate = Color(1, 1, 1, 0)
		empty_orb.z_index = 2
		background.add_child(empty_orb)
		slot_empty_orbs.append(empty_orb)
		slot_orb_empty.append(true)
		
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
		ranged_icon.position = Vector2(pos_x +- 16 + icon_size.x, pos_y - 3.2)
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

	highlight_sprite = AnimatedSprite2D.new()
	highlight_sprite.scale = Vector2(icon_size.x / 18.0, icon_size.y / 18.0)
	highlight_sprite.sprite_frames = highlight_frames
	highlight_sprite.visible = false
	highlight_sprite.offset = Vector2(9, 8.2)
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
		
		if ability_id == "basic_attack":
			slot_icons[i].texture = basic_attack_icon
			slot_labels[i].visible = ability_id != ""
		elif ability_id != "":
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			slot_icons[i].texture = data.get("icon", null)
			slot_labels[i].visible = ability_id != ""
		else:
			slot_icons[i].texture = null
			slot_labels[i].visible = ability_id != ""
			
		var wanted_charge: String = ""
		if ability_id != "" and ability_id != "basic_attack":
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			var cost: Dictionary = data.get("cost", {})
			if cost.has("sc"):
				wanted_charge = str(PlayerData.get_spell_charges(ability_id))

		if wanted_charge != slot_charge_values[i]:
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
			var t: Tween = create_tween()
			t.tween_property(slot_ranged_icons[i], "modulate:a", target_a, overlay_tween_speed)
			
		if ability_id != "" and ability_id != "basic_attack":
			var data2: Dictionary = AbilityDB.get_ability(ability_id)
			var cost2: Dictionary = data2.get("cost", {})
			if cost2.has("sc"):
				var charges: int = PlayerData.get_spell_charges(ability_id)
				var is_empty: bool = charges <= 0

				if is_empty != slot_orb_empty[i]:
					slot_orb_empty[i] = is_empty
					var orb_alpha: float = 0.0 if is_empty else 1.0
					var empty_alpha: float = 1.0 if is_empty else 0.0
					var crossfade: Tween = create_tween()
					crossfade.set_parallel(true)
					crossfade.tween_property(slot_orbs[i], "modulate:a", orb_alpha, overlay_tween_speed)
					crossfade.tween_property(slot_empty_orbs[i], "modulate:a", empty_alpha, overlay_tween_speed)

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
				slot_orbs[i].modulate = Color(1, 1, 1, 0)
				slot_empty_orbs[i].modulate = Color(1, 1, 1, 0)
		else:
			slot_orbs[i].modulate = Color(1, 1, 1, 0)
			slot_empty_orbs[i].modulate = Color(1, 1, 1, 0)
			
		if BattleManager.active and BattleManager.player_turn != null and ability_id != "":
			var reasons: Array = BattleManager.player_turn.get_slot_block_reasons(i)
			var is_blocked: bool = not reasons.is_empty()
			if is_blocked != slot_blocked[i]:
				slot_blocked[i] = is_blocked
				var target_alpha: float = 1.0 if is_blocked else 0.0
				var tween: Tween = create_tween()
				tween.tween_property(slot_overlays[i], "modulate:a", target_alpha, overlay_tween_speed)
		else:
			# Out of combat: still cross out abilities blocked by non-combat requirements.
			var out_blocked: bool = false
			if ability_id != "" and ability_id != "basic_attack":
				var data3: Dictionary = AbilityDB.get_ability(ability_id)
				if data3.get("requires_ranged_weapon", false) and not PlayerData.is_ranged_weapon_equipped():
					out_blocked = true
			if out_blocked != slot_blocked[i]:
				slot_blocked[i] = out_blocked
				var target_alpha: float = 1.0 if out_blocked else 0.0
				var tween: Tween = create_tween()
				tween.tween_property(slot_overlays[i], "modulate:a", target_alpha, overlay_tween_speed)

	# Only animates when the active slot changes, not every frame.
	if current_active_slot != previous_active_slot:
		_animate_selection(previous_active_slot, current_active_slot)
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
	var ranged_x: float = rest_x + icon_size.x - 16

	var shake_tween: Tween = create_tween()
	shake_tween.set_parallel(true)

	# Step 1: everything moves left.
	shake_tween.tween_property(icon, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x - 1.0, 0.05)
	shake_tween.tween_property(slot_overlays[slot], "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_ranged_icons[slot], "position:x", ranged_x + 1.0, 0.05)

	# Step 2: everything moves right.
	shake_tween.chain()
	shake_tween.tween_property(slot_ranged_icons[slot], "position:x", ranged_x - 1.0, 0.05)
	shake_tween.tween_property(icon, "position:x", rest_x + 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x + 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x + 1.0, 0.05)
	shake_tween.tween_property(slot_overlays[slot], "position:x", rest_x + 1.0, 0.05)
	
	# Step 3: everything moves left again.
	shake_tween.chain()
	shake_tween.tween_property(icon, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x - 1.0, 0.05)
	shake_tween.tween_property(slot_overlays[slot], "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_ranged_icons[slot], "position:x", ranged_x + 1.0, 0.05)
	
	# Step 4: everything returns to rest.
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
		
	if slot_orb_empty[slot] and slot_empty_orbs[slot].modulate.a > 0:
		var orb_flash: Tween = create_tween()
		orb_flash.tween_property(slot_empty_orbs[slot], "modulate", Color(1, 0.3, 0.3, 1), 0.1)
		orb_flash.tween_property(slot_empty_orbs[slot], "modulate", Color(1, 1, 1, 1), 0.1)
		
	if slot_orb_empty[slot] and slot_empty_orbs[slot].modulate.a > 0:
		var orb_flash: Tween = create_tween()
		orb_flash.tween_property(slot_empty_orbs[slot], "modulate", Color(1, 0.3, 0.3, 1), 0.1)
		orb_flash.tween_property(slot_empty_orbs[slot], "modulate", Color(1, 1, 1, 1), 0.1)

		var label_flash: Tween = create_tween()
		label_flash.tween_property(slot_charge_labels[slot], "modulate", Color(1, 0.3, 0.3, 1), 0.1)
		label_flash.tween_property(slot_charge_labels[slot], "modulate", Color(1, 1, 1, 1), 0.1)
	
func _show_reject_reason(slot: int) -> void:
	var pt: CombatantTurn = BattleManager.player_turn
	if pt == null:
		return

	var reasons: Array = pt.get_slot_block_reasons(slot)
	if reasons.is_empty():
		return

	reason_label.text = ", ".join(reasons)
	reason_label.size = Vector2(400, 40)

	var slot_local_x: float = first_slot_offset.x + (slot_spacing * slot) + (icon_size.x / 2)
	var slot_screen_x: float = background.global_position.x + (slot_local_x * background.scale.x)
	reason_label.position = Vector2(slot_screen_x - 200, background.global_position.y - 50)

	if reason_tween != null and reason_tween.is_valid():
		reason_tween.kill()

	reason_label.modulate = Color(1, 1, 1, 0)
	reason_label.visible = true

	reason_tween = create_tween()
	reason_tween.tween_property(reason_label, "modulate:a", 1.0, 0.15)
	reason_tween.tween_interval(0.8)
	reason_tween.tween_property(reason_label, "modulate:a", 0.0, 0.5)
	reason_tween.tween_callback(func(): reason_label.visible = false)
