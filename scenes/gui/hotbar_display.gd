extends CanvasLayer

@onready var background: TextureRect = $Background

@export var basic_attack_icon: Texture2D

var first_slot_offset: Vector2 = Vector2(4, 4)
var slot_spacing: float = 20.0
var icon_size: Vector2 = Vector2(18, 18)

# Animation settings for when an ability is selected.
var selected_offset: float = 1.0
var tween_speed: float = 0.12

# Stores the TextureRect nodes that display ability icons.
var slot_icons: Array = []
# Stores each icon's resting Y position so we know where to tween back to.
var slot_rest_y: Array = []
# Tracks which slot was active last frame so we only animate on change.
var previous_active_slot: int = -1

var hud_enabled: bool = true

func read() -> void:
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

func _update_display() -> void:
	var current_active_slot: int = -1
	if BattleManager.active and BattleManager.player_turn != null:
		current_active_slot = BattleManager.player_turn.active_hotbar_slot
		
	# Refreshes each slot's icon texture.
	for i in range(10):
		var ability_id: String = PlayerData.get_hotbar_ability(i)
		
		if ability_id == "basic_attack":
			slot_icons[i].texture = basic_attack_icon
		elif ability_id != "":
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			slot_icons[i].texture = data.get("icon", null)
		else:
			slot_icons[i].texture = null

	# Only animates when the active slot changes, not every frame.
	if current_active_slot != previous_active_slot:
		_animate_selection(previous_active_slot, current_active_slot)
		previous_active_slot = current_active_slot

func _animate_selection(old_slot: int, new_slot: int) -> void:
	######################################################
