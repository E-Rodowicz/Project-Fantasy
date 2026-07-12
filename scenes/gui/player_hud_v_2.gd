extends CanvasLayer

@onready var hp_bar: TextureProgressBar = $StatusBar_bg/hp_bar
@onready var mp_bar: TextureProgressBar = $StatusBar_bg/mp_bar
@onready var mp_bar_preview: TextureProgressBar = $StatusBar_bg/mp_bar_preview
@onready var hp_bar_trail: TextureProgressBar = $StatusBar_bg/hp_bar_trail
@onready var bp_icon: Sprite2D = $StatusBar_bg/bp_icon
@onready var bp_label: Label = $StatusBar_bg/bp_label

var mp_flash_sheet: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_mp_animated-sheet.png")
var hp_damage_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_hp_hit.png")
var hp_heal_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_hp_heal.png")
var bp_active_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_bp_full.png")
var bp_inactive_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_bp_empty.png")
var bp_shine_sheet: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_bp_full-sheet.png")

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
var hp_display_current: int = 100
var hp_is_healing: bool = false
var bp_shine_frames: Array = []
var bp_shine_frame: int = 0
var bp_shine_timer: float = 0.0

const HP_DRAIN_RATE: float = 0.04
const HP_DRAIN_DELAY: float = 0.4
const MP_DRAIN_RATE: float = 0.008
const MP_FLASH_FRAME_COUNT: int = 8
const MP_FLASH_FPS: float = 10.0
const BP_SHINE_FRAME_COUNT: int = 7
const BP_SHINE_FPS: float = 10.0

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
		
	var bp_frame_width: float = bp_shine_sheet.get_width() / BP_SHINE_FRAME_COUNT
	var bp_frame_height: float = bp_shine_sheet.get_height()
	for i in range(BP_SHINE_FRAME_COUNT):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = bp_shine_sheet
		atlas.region = Rect2(i * bp_frame_width, 0, bp_frame_width, bp_frame_height)
		bp_shine_frames.append(atlas)
	
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
		
	if hp_display_target < hp_display_current:
		hp_display_current = hp_display_target
		hp_bar_trail.texture_progress = hp_damage_texture
		hp_drain_delay = 0.0
		hp_drain_timer = 0.0
		hp_is_healing = false
		
	elif hp_display_target > hp_display_current: 
		hp_trail_current = hp_display_target
		hp_bar_trail.texture_progress = hp_heal_texture
		if not hp_is_healing:
			hp_drain_delay = 0.0
			hp_drain_timer = 0.0
			hp_is_healing = true
		
	if hp_trail_current > hp_display_current:
		hp_drain_delay += delta
		if hp_drain_delay >= HP_DRAIN_DELAY:
			hp_drain_timer += delta
			if hp_is_healing:
				while hp_drain_timer >= HP_DRAIN_RATE and hp_display_current < hp_trail_current:
					hp_drain_timer -= HP_DRAIN_RATE
					hp_display_current += 1
			else:
				while hp_drain_timer >= HP_DRAIN_RATE and hp_trail_current > hp_display_current:
					hp_drain_timer -= HP_DRAIN_RATE
					hp_trail_current -= 1
	else:
		hp_trail_current = hp_display_current
		hp_drain_timer = 0.0
		hp_drain_delay = 0.0

	hp_bar.value = hp_display_current
	hp_bar_trail.value = hp_trail_current
		
	# BP
	var bp_current: int = PlayerData.bp_max
	if BattleManager.active and BattleManager.player_turn != null:
		bp_current = BattleManager.player_turn.bp_remaining
		
	# This checks if a BP-using ability is selected (BP abilities always use 1 BP, but it is
	# future-proofed in case that changes).
	var bp_ability_selected: bool = false
	if BattleManager.active and BattleManager.player_turn != null:
		var active_slot: int = BattleManager.player_turn.active_hotbar_slot
		if active_slot >= 0:
			var slot_ability_id: String = PlayerData.get_hotbar_ability(active_slot)
			if slot_ability_id == "basic_attack":
				bp_ability_selected = true
			elif slot_ability_id != "":
				var slot_ability: Dictionary = AbilityDB.get_ability(slot_ability_id)
				var slot_cost: Dictionary = slot_ability.get("cost", {})
				bp_ability_selected = slot_cost.has("bp")
				
	# Shine animation when BP ability is selected and BP is available.
	########################################################################
	
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
