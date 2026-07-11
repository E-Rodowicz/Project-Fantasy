extends CanvasLayer

@onready var hp_bar: TextureProgressBar = $StatusBar_bg/hp_bar
@onready var mp_bar: TextureProgressBar = $StatusBar_bg/mp_bar
@onready var mp_bar_preview: TextureProgressBar = $StatusBar_bg/mp_bar_preview
@onready var hp_bar_trail: TextureProgressBar = $StatusBar_bg/hp_bar_trail

var mp_flash_sheet: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_mp_animated-sheet.png")
var mp_flash_frames: Array = []
var mp_flash_frame: int = 0
var mp_flash_timer: float = 0.0
var mp_preview_current: int = 100
var mp_drain_timer: float = 0.0
var mp_display_current: int = 100
var mp_display_timer: float = 0.0
var hp_trail_current: int = 100
var hp_drain_timer: float = 0.0
var hp_drain_delay: float = 0.0

const HP_DRAIN_RATE: float = 0.08
const HP_DRAIN_DELAY: float = 0.4
const MP_DRAIN_RATE: float = 0.008
const MP_FLASH_FRAME_COUNT: int = 4
const MP_FLASH_FPS: float = 10.0

var hud_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	var frame_width: float = mp_flash_sheet.get_width() / MP_FLASH_FRAME_COUNT
	var frame_height: float = mp_flash_sheet.get_height()
	for i in range(MP_FLASH_FRAME_COUNT):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = mp_flash_sheet
		atlas.region = Rect2(i * frame_width, 0, frame_width, frame_height)
		mp_flash_frames.append(atlas)
	
func _process(delta: float) -> void:
	if not hud_enabled:
		visible = false
		return

	visible = not GameMenuManager.is_open
	if visible:
		_update_display(delta)
	
func _update_display(delta: float) -> void:
	# HP
	hp_bar.max_value = 100
	hp_bar_trail.max_value = 100
	
	var hp_display_target: int = round(float(PlayerData.current_hp) / PlayerData.max_hp * 100)
	
	if PlayerData.current_hp > 0:
		hp_display_target = max(hp_display_target, 2)
		
	# Snaps front bar to current target HP.
	hp_bar.value = hp_display_target
	
	# Trail lingers at old value then aniamtes to meet the new one.
	if hp_display_target < hp_trail_current:
		hp_drain_delay += delta
		if hp_drain_delay >= HP_DRAIN_DELAY:
			# Delay is over, drain starts.
			hp_drain_timer += delta
			while hp_drain_timer >= HP_DRAIN_RATE and hp_trail_current > hp_display_target:
				hp_drain_timer -= HP_DRAIN_RATE
				hp_trail_current -= 1
	elif hp_display_target > hp_trail_current:
		# Healing.
		hp_trail_current = hp_display_target
		hp_drain_timer = 0.0
		hp_drain_delay = 0.0
	else:
		# Resets timers if they match.
		hp_drain_timer = 0.0
		hp_drain_delay = 0.0
		
	hp_bar_trail.value = hp_trail_current
			

	# MP
	var max_mp: int = PlayerData.get_max_mp()
	mp_bar.max_value = 100
	mp_bar_preview.max_value = 100

	var current_mp: int = max_mp
	var planned_cost: int = 0

	if BattleManager.active and BattleManager.player_turn != null:
		current_mp = BattleManager.player_turn.mp_budget
		planned_cost = BattleManager.player_turn.path_cost

	var mp_preview_target: int = 0
	var mp_display_target: int = 0

	if max_mp > 0:
		mp_preview_target = round(float(current_mp) / max_mp * 100.0)
		mp_display_target = round(float(current_mp - planned_cost) / max_mp * 100.0)

	if current_mp > 0:
		mp_preview_target = max(mp_preview_target, 2)
	if (current_mp - planned_cost) > 0:
		mp_display_target = max(mp_display_target, 2)

	# Green bar: snaps down, snaps up on cancel, animates up on refill
	if mp_display_target < mp_display_current:
		mp_display_current = mp_display_target
		mp_display_timer = 0.0
	elif mp_display_target > mp_display_current:
		if mp_display_target <= mp_preview_current:
			mp_display_current = mp_display_target
			mp_display_timer = 0.0
		else:
			mp_display_timer += delta
			while mp_display_timer >= MP_DRAIN_RATE and mp_display_current < mp_display_target:
				mp_display_timer -= MP_DRAIN_RATE
				mp_display_current += 1
	else:
		mp_display_timer = 0.0

	# Preview bar: snaps during planning, drains toward green, tracks green when matched
	if planned_cost > 0:
		mp_preview_current = mp_preview_target
		mp_drain_timer = 0.0
	elif mp_preview_current > mp_display_current:
		mp_drain_timer += delta
		while mp_drain_timer >= MP_DRAIN_RATE and mp_preview_current > mp_display_current:
			mp_drain_timer -= MP_DRAIN_RATE
			mp_preview_current -= 1
	else:
		mp_preview_current = mp_display_current
		mp_drain_timer = 0.0

	mp_bar_preview.value = mp_preview_current
	mp_bar.value = mp_display_current

	# Flash animation when there's a planned path cost
	if planned_cost > 0:
		mp_flash_timer += delta
		if mp_flash_timer >= 1.0 / MP_FLASH_FPS:
			mp_flash_timer -= 1.0 / MP_FLASH_FPS
			mp_flash_frame = (mp_flash_frame + 1) % MP_FLASH_FRAME_COUNT
		mp_bar_preview.texture_progress = mp_flash_frames[mp_flash_frame]
	else:
		mp_flash_timer = 0.0
		mp_flash_frame = 0
