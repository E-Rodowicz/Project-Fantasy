extends CanvasLayer

@onready var background: TextureRect = $Background

@export var basic_attack_icon: Texture2D
@export var highlight_frames: SpriteFrames

var highlight_sprite: AnimatedSprite2D = null
var reject_sprite: AnimatedSprite2D = null
var reject_plays_remaining: int = 0
var first_slot_offset: Vector2 = Vector2(8, 8)
var slot_spacing: float = 32.0
var icon_size: Vector2 = Vector2(24, 24)
var slot_charge_labels: Array = []
var slot_labels: Array = []
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
		charge_label.add_theme_color_override("font_color", Color.WHITE)
		charge_label.add_theme_color_override("font_outline_color", Color.BLACK)
		charge_label.add_theme_constant_override("outline_size", 1)
		charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		charge_label.size = Vector2(icon_size.x, 12)
		charge_label.position = Vector2(pos_x, pos_y + icon_size.y - 8)
		charge_label.z_index = 2
		background.add_child(charge_label)
		slot_charge_labels.append(charge_label)

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
			
		if ability_id != "" and ability_id != "basic_attack":
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			var cost: Dictionary = data.get("cost", {})
			if cost.has("sc"):
				var charges: int = PlayerData.get_spell_charges(ability_id)
				slot_charge_labels[i].text = str(charges)
			else:
				slot_charge_labels[i].text = ""
		else:
			slot_charge_labels[i].text = ""

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
		tween_down.tween_property(
			slot_charge_labels[old_slot], "position:y",
			slot_rest_y[old_slot] + icon_size.y - 8, tween_speed
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
		tween_up.tween_property(
			slot_charge_labels[new_slot], "position:y",
			slot_rest_y[new_slot] + icon_size.y - 8 - select_offset,
		tween_speed
		)
		slot_icons[new_slot].modulate = Color(1.241, 1.225, 1.055, 1.0)	
		highlight_sprite.position = slot_icons[new_slot].position
		highlight_sprite.visible = true
		highlight_sprite.play("select_intro")
	else:
		highlight_sprite.visible = false



func _play_reject(slot: int) -> void:
	var icon: TextureRect = slot_icons[slot]
	var rest_x: float = first_slot_offset.x + (slot_spacing * slot)
	var label_x: float = rest_x - 1.0

	var shake_tween: Tween = create_tween()
	shake_tween.set_parallel(true)

	# Step 1: everything moves left.
	shake_tween.tween_property(icon, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x - 1.0, 0.05)
	shake_tween.tween_property(slot_charge_labels[slot], "position:x", rest_x - 1.0, 0.05)

	# Step 2: everything moves right.
	shake_tween.chain()
	shake_tween.tween_property(icon, "position:x", rest_x + 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x + 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x + 1.0, 0.05)
	shake_tween.tween_property(slot_charge_labels[slot], "position:x", rest_x + 1.0, 0.05)

	# Step 3: everything moves left again.
	shake_tween.chain()
	shake_tween.tween_property(icon, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x - 1.0, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x - 1.0, 0.05)
	shake_tween.tween_property(slot_charge_labels[slot], "position:x", rest_x - 1.0, 0.05)

	# Step 4: everything returns to rest.
	shake_tween.chain()
	shake_tween.tween_property(icon, "position:x", rest_x, 0.05)
	shake_tween.tween_property(reject_sprite, "position:x", rest_x, 0.05)
	shake_tween.tween_property(slot_labels[slot], "position:x", label_x, 0.05)
	shake_tween.tween_property(slot_charge_labels[slot], "position:x", rest_x, 0.05)

	reject_plays_remaining = 2
	reject_sprite.position = icon.position
	reject_sprite.visible = true
	reject_sprite.play("reject")
