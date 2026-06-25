extends CanvasLayer

@onready var hp_bar: TextureProgressBar = $anchor/hp_bar
@onready var hp_label: Label = $anchor/hp_bar/hp_label

@onready var mp_bar: TextureProgressBar = $anchor/mp_bar
@onready var mp_bar_preview: TextureProgressBar = $anchor/mp_bar_preview
@onready var mp_label: Label = $anchor/mp_label

@onready var bp_icon: TextureRect = $anchor/bp_icon
@onready var bp_label: Label = $anchor/bp_icon/bp_label

@onready var ap_container: HBoxContainer = $anchor/ap_container

var orb_filled: Texture2D = preload("res://assets/sprites/ap_orb_filled.png")
var orb_empty: Texture2D = preload("res://assets/sprites/ap_orb_empty.png")
var orb_nodes: Array = []

var mp_flash_sheet: Texture2D = preload("res://assets/sprites/mp_bar_flash-Sheet.png")
var mp_flash_frames: Array = []
var mp_flash_frame: int = 0
var mp_flash_timer: float = 0.0

const MP_FLASH_FRAME_COUNT: int = 6
const MP_FLASH_FPS: float = 10.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	var frame_width: float = mp_flash_sheet.get_width() / MP_FLASH_FRAME_COUNT
	var frame_height: float = mp_flash_sheet.get_height()
	for i in range(MP_FLASH_FRAME_COUNT):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = mp_flash_sheet
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		mp_flash_frames.append(atlas)

func _process(delta: float) -> void:
	# HP
	hp_bar.max_value = PlayerData.max_hp
	hp_bar.value = PlayerData.current_hp
	hp_label.text = str(PlayerData.current_hp) + " / " + str(PlayerData.max_hp)

	# MP
	_update_mp_display(delta)
	
	# BP
	if BattleManager.active and BattleManager.player_turn != null:
		bp_label.text = str(BattleManager.player_turn.bp_remaining)
	else:
		bp_label.text = str(PlayerData.bp_max)
		
	# AP
	_update_ap_display()

func _update_ap_display() -> void:
	var max_ap: int = PlayerData.ap_max
	var current_ap: int = PlayerData.ap_max
	
	if BattleManager.active and BattleManager.player_turn != null:
		current_ap = BattleManager.player_turn.ap_remaining
		
	# Adds orbs if max ap increases.
	while orb_nodes.size() < max_ap:
		var orb: TextureRect = TextureRect.new()
		orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ap_container.add_child(orb)
		orb_nodes.append(orb)
		
	# Removes orbs if max AP decreases.
	while orb_nodes.size() > max_ap:
		var orb: TextureRect = orb_nodes.pop_back()
		orb.queue_free()
		
	# Sets orbs to be full or empty.
	for i in range(orb_nodes.size()):
		if i < current_ap:
			orb_nodes[i].texture = orb_filled
		else:
			orb_nodes[i].texture = orb_empty
			
func _update_mp_display(delta: float) -> void:
	var max_mp: int = PlayerData.get_max_mp()
	mp_bar.max_value = max_mp
	mp_bar_preview.max_value = max_mp

	if BattleManager.active and BattleManager.player_turn != null:
		var current_mp: int = BattleManager.player_turn.mp_budget
		var planned_cost: int = BattleManager.player_turn.path_cost

		mp_bar_preview.value = current_mp
		mp_bar.value = current_mp - planned_cost

		mp_label.text = str(current_mp - planned_cost) + " / " + str(max_mp)

		# Animate the flash when there's a planned path.
		if planned_cost > 0:
			mp_flash_timer += delta
			if mp_flash_timer >= 1.0 / MP_FLASH_FPS:
				mp_flash_timer -= 1.0 / MP_FLASH_FPS
				mp_flash_frame = (mp_flash_frame + 1) % MP_FLASH_FRAME_COUNT
			mp_bar_preview.texture_progress = mp_flash_frames[mp_flash_frame]
		else:
			# No planned path — reset animation to frame 0.
			mp_flash_timer = 0.0
			mp_flash_frame = 0
	else:
		mp_bar.value = max_mp
		mp_bar_preview.value = max_mp
		mp_label.text = str(max_mp) + " / " + str(max_mp)
