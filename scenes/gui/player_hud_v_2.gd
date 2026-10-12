extends CanvasLayer

enum ApState { FULL, SELECT, USED, DEPLETED, REFILL }

# Onready's.
@onready var hp_bar: TextureProgressBar = $StatusBar_bg/hp_bar
@onready var mp_bar: TextureProgressBar = $StatusBar_bg/mp_bar
@onready var mp_bar_preview: TextureProgressBar = $StatusBar_bg/mp_bar_preview
@onready var hp_bar_trail: TextureProgressBar = $StatusBar_bg/hp_bar_trail
@onready var bp_icon: Sprite2D = $StatusBar_bg/bp_icon
@onready var bp_label: Label = $StatusBar_bg/bp_label
@onready var hp_current_label: Label = $StatusBar_bg/hp_current_label
@onready var hp_slash_label: Label = $StatusBar_bg/hp_slash_label
@onready var hp_max_label: Label = $StatusBar_bg/hp_max_label
@onready var mp_current_label: Label = $StatusBar_bg/mp_current_label
@onready var mp_slash_label: Label = $StatusBar_bg/mp_slash_label
@onready var mp_max_label: Label = $StatusBar_bg/mp_max_label

# Preloads.
var hp_damage_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_hp_hit.png")
var hp_heal_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_hp_heal.png")

var mp_flash_sheet: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_mp_animated-sheet.png")

var bp_active_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_bp_full.png")
var bp_inactive_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_bp_empty.png")
var bp_shine_sheet: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_bp_full-sheet.png")

var ap_full_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_ap_full.png")
var ap_depleted_texture: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_ap_empty.png")
var ap_select_sheet: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_ap_selected-sheet.png")
var ap_used_sheet: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_ap_used-sheet.png")
var ap_refill_sheet: Texture2D = preload("res://assets/sprites/gui/status_bar/status_bar_ap_animated-sheet.png")

# Basic vars.
var hp_trail_current: int = 100
var hp_drain_timer: float = 0.0
var hp_drain_delay: float = 0.0
var hp_display_current: int = 100
var hp_is_healing: bool = false
var hp_preview_active: bool = false
var hp_preview_current: int = 100
var hp_preview_timer: float = 0.0
var hp_preview_pulse: float = 0.0

var mp_flash_frames: Array = []
var mp_flash_frame: int = 0
var mp_flash_timer: float = 0.0
var mp_preview_current: int = 100
var mp_drain_timer: float = 0.0
var mp_display_current: int = 100
var mp_display_timer: float = 0.0

var bp_shine_frames: Array = []
var bp_shine_frame: int = 0
var bp_shine_timer: float = 0.0
var bp_label_fade: Label = null
var bp_previous_display: int = -1
var bp_was_active: bool = true
var bp_fading: bool = false
var bp_icon_back: Sprite2D = null
var bp_was_selected: bool = false
var bp_shine_holding: bool = false
var bp_shine_hold_timer: float = 0.0
var bp_counting: bool = false
var bp_count_display: int = 0
var bp_count_target: int = 0
var bp_count_timer: float = 0.0

var ap_pips: Array = []
var ap_pip_states: Array = []
var ap_pip_frames: Array = []
var ap_pip_timers: Array = []
var ap_pip_delays: Array = []
var ap_previous_count: int = -1
var ap_previous_remaining: int = -1
var ap_select_frames: Array = []
var ap_used_frames: Array = []
var ap_refill_frames: Array = []

# Consts.
const HP_DRAIN_RATE: float = 0.04
const HP_DRAIN_DELAY: float = 0.4
const HP_PREVIEW_RATE: float = 0.008

const MP_DRAIN_RATE: float = 0.008
const MP_FLASH_FRAME_COUNT: int = 8
const MP_FLASH_FPS: float = 10.0

const BP_SHINE_FRAME_COUNT: int = 8
const BP_SHINE_FPS: float = 10.0
const BP_FADE_SPEED: float = 0.25
const BP_ICON_FADE_SPEED: float = 0.15
const BP_SHINE_HOLD: float = 0.35
const BP_COUNT_SPEED: float = 0.15

const AP_SELECT_FRAME_COUNT: int = 9
const AP_USED_FRAME_COUNT: int = 7
const AP_REFILL_FRAME_COUNT: int = 3
const AP_SELECT_FPS: float = 10.0
const AP_USED_FPS: float = 10.0
const AP_REFILL_FPS: float = 10.0
const AP_REFILL_STAGGER: float = 0.25
const AP_PIP_SPACING: int = 6
const AP_PIP_START: Vector2 = Vector2(13, 5)

const HP_LABEL_CENTER_X: float = 60.0
const MP_LABEL_CENTER_X: float = 60.0
const LABEL_COLOR_NORMAL: Color = Color.WHITE
const LABEL_COLOR_COST: Color = Color(0.85, 0.35, 0.1)
const LABEL_COLOR_HEAL: Color = Color(0.3, 1.0, 0.3)

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
		
	var ap_sel_w: float = ap_select_sheet.get_width() / AP_SELECT_FRAME_COUNT
	var ap_sel_h: float = ap_select_sheet.get_height()
	for i in range(AP_SELECT_FRAME_COUNT):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = ap_select_sheet
		atlas.region = Rect2(i * ap_sel_w, 0, ap_sel_w, ap_sel_h)
		ap_select_frames.append(atlas)
		
	var ap_used_w: float = ap_used_sheet.get_width() / AP_USED_FRAME_COUNT
	var ap_used_h: float = ap_used_sheet.get_height()
	for i in range(AP_USED_FRAME_COUNT):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = ap_used_sheet
		atlas.region = Rect2(i * ap_used_w, 0, ap_used_w, ap_used_h)
		ap_used_frames.append(atlas)

	var ap_ref_w: float = ap_refill_sheet.get_width() / AP_REFILL_FRAME_COUNT
	var ap_ref_h: float = ap_refill_sheet.get_height()
	for i in range(AP_REFILL_FRAME_COUNT):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = ap_refill_sheet
		atlas.region = Rect2(i * ap_ref_w, 0, ap_ref_w, ap_ref_h)
		ap_refill_frames.append(atlas)
		
	bp_label_fade = bp_label.duplicate()
	bp_label.get_parent().add_child(bp_label_fade)
	bp_label_fade.modulate = Color(1, 1, 1, 0)
	bp_icon_back = bp_icon.duplicate()
	bp_icon.get_parent().add_child(bp_icon_back)
	bp_icon.get_parent().move_child(bp_icon_back, bp_icon.get_index())
	
func _process(delta: float) -> void:
	if not hud_enabled:
		visible = false
		return

	visible = true
	_update_display(delta)
	
func _update_display(delta: float) -> void:
	# Detect selected ability costs (used by HP preview, MP section, and labels)
	var selected_ability_mp_cost: int = 0
	var selected_ability_hp_cost: int = 0
	var selected_ability_hp_heal: int = 0
	if BattleManager.active and BattleManager.player_turn != null:
		var hud_active_slot: int = BattleManager.player_turn.active_hotbar_slot
		if hud_active_slot >= 0:
			var hud_ability_id: String = PlayerData.get_hotbar_ability(hud_active_slot)
			if hud_ability_id != "" and hud_ability_id != "basic_attack":
				var hud_ability: Dictionary = AbilityDB.get_ability(hud_ability_id)
				var hud_cost: Dictionary = hud_ability.get("cost", {})
				selected_ability_mp_cost = hud_cost.get("mp", 0)
				selected_ability_hp_cost = hud_cost.get("hp", 0)
				selected_ability_hp_heal = hud_ability.get("heal_hp", 0)
	
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

	# HP Preview
	var hp_is_previewing: bool = selected_ability_hp_cost > 0 or selected_ability_hp_heal > 0
	if hp_is_previewing:
		if not hp_preview_active:
			hp_preview_active = true
			hp_preview_current = hp_display_current
			hp_preview_timer = 0.0

		var preview_hp: int = clampi(PlayerData.current_hp - selected_ability_hp_cost + selected_ability_hp_heal, 0, PlayerData.max_hp)
		var hp_preview_target: int = round(float(preview_hp) / PlayerData.max_hp * 100.0)
		if preview_hp > 0:
			hp_preview_target = max(hp_preview_target, 2)

		if hp_preview_current > hp_preview_target:
			hp_preview_timer += delta
			while hp_preview_timer >= HP_PREVIEW_RATE and hp_preview_current > hp_preview_target:
				hp_preview_timer -= HP_PREVIEW_RATE
				hp_preview_current -= 1
		elif hp_preview_current < hp_preview_target:
			hp_preview_timer += delta
			while hp_preview_timer >= HP_PREVIEW_RATE and hp_preview_current < hp_preview_target:
				hp_preview_timer -= HP_PREVIEW_RATE
				hp_preview_current += 1

		hp_bar.value = hp_preview_current
		if selected_ability_hp_cost > 0:
			hp_bar_trail.texture_progress = hp_damage_texture
			hp_bar_trail.value = hp_display_current
		elif selected_ability_hp_heal > 0:
			hp_bar_trail.texture_progress = hp_heal_texture
			hp_bar_trail.value = hp_preview_target

		hp_preview_pulse += delta
		var pulse: float = 0.85 + sin(hp_preview_pulse * 5.0) * 0.15
		if selected_ability_hp_cost > 0:
			hp_bar_trail.modulate = Color(1.0, pulse * 0.7, pulse * 0.3, 1.0)
		else:
			hp_bar_trail.modulate = Color(pulse * 0.5, 1.0, pulse * 0.5, 1.0)
	else:
		if hp_preview_active:
			hp_preview_active = false
			hp_preview_pulse = 0.0
			hp_bar_trail.modulate = Color.WHITE
		hp_bar.value = hp_display_current
		hp_bar_trail.value = hp_trail_current
		
	# BP
	var bp_current: int = PlayerData.bp_max
	if BattleManager.active and BattleManager.player_turn != null:
		bp_current = BattleManager.player_turn.bp_remaining

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

	if not bp_ability_selected and bp_was_selected:
		bp_shine_frame = 0
		bp_shine_timer = 0.0
		bp_shine_holding = false
		bp_shine_hold_timer = 0.0
	bp_was_selected = bp_ability_selected

	# Fade purple to grey (or grey to purple) when BP state changes.
	var bp_is_active: bool = bp_current > 0
	if bp_is_active != bp_was_active:
		bp_was_active = bp_is_active
		bp_fading = true
		var new_texture: Texture2D = bp_active_texture if bp_is_active else bp_inactive_texture
		bp_icon_back.texture = bp_icon.texture
		bp_icon_back.modulate.a = 1.0
		bp_icon.texture = new_texture
		bp_icon.modulate.a = 0.0
		var crossfade_tween: Tween = create_tween()
		crossfade_tween.set_parallel(true)
		crossfade_tween.tween_property(bp_icon, "modulate:a", 1.0, BP_ICON_FADE_SPEED)
		crossfade_tween.tween_property(bp_icon_back, "modulate:a", 0.0, BP_ICON_FADE_SPEED)
		crossfade_tween.chain()
		crossfade_tween.tween_callback(func(): bp_fading = false)

	# Icon texture (shine, purple, or grey).
	if not bp_fading:
		if bp_ability_selected and bp_current > 0:
			if bp_shine_holding:
				bp_shine_hold_timer += delta
				if bp_shine_hold_timer >= BP_SHINE_HOLD:
					bp_shine_holding = false
					bp_shine_hold_timer = 0.0
					bp_shine_frame = 0
			else:
				bp_shine_timer += delta
				if bp_shine_timer >= 1.0 / BP_SHINE_FPS:
					bp_shine_timer -= 1.0 / BP_SHINE_FPS
					bp_shine_frame += 1
					if bp_shine_frame >= BP_SHINE_FRAME_COUNT:
						bp_shine_frame = BP_SHINE_FRAME_COUNT - 1
						bp_shine_holding = true
						bp_shine_hold_timer = 0.0
			bp_icon.texture = bp_shine_frames[bp_shine_frame]
		else:
			if bp_current > 0:
				bp_icon.texture = bp_active_texture
			else:
				bp_icon.texture = bp_inactive_texture

	# Label fades between values like SC charges on hotbar.
	var bp_label_target: int = bp_current if bp_current > 1 else 0

	# Start counting up when BP increases
	if bp_label_target > bp_previous_display and bp_previous_display >= 0:
		if not bp_counting:
			bp_counting = true
			bp_count_display = max(bp_previous_display, 0)
			bp_count_target = bp_label_target
			bp_count_timer = 0.0
		else:
			bp_count_target = bp_label_target

	# Count-up animation
	if bp_counting:
		bp_count_timer += delta
		if bp_count_timer >= BP_COUNT_SPEED:
			bp_count_timer -= BP_COUNT_SPEED
			bp_count_display += 1
			bp_label.text = str(bp_count_display)
			bp_label.visible = true
			if bp_count_display >= bp_count_target:
				bp_counting = false
		bp_previous_display = bp_count_display
	elif bp_label_target != bp_previous_display:
		# Non-counting changes (BP spent — use existing crossfade logic)
		if bp_previous_display > 1 and bp_label_target > 1:
			bp_label_fade.text = str(bp_previous_display)
			bp_label_fade.modulate = Color(1, 1, 1, 1)
			var out_tween: Tween = create_tween()
			out_tween.tween_property(bp_label_fade, "modulate:a", 0.0, BP_FADE_SPEED)
			bp_label.text = str(bp_label_target)
			bp_label.modulate = Color(1, 1, 1, 0)
			bp_label.visible = true
			var in_tween: Tween = create_tween()
			in_tween.tween_property(bp_label, "modulate:a", 1.0, BP_FADE_SPEED)
		elif bp_label_target > 1:
			bp_label.text = str(bp_label_target)
			bp_label.modulate = Color(1, 1, 1, 0)
			bp_label.visible = true
			var in_tween: Tween = create_tween()
			in_tween.tween_property(bp_label, "modulate:a", 1.0, BP_FADE_SPEED)
		else:
			var out_tween: Tween = create_tween()
			out_tween.tween_property(bp_label, "modulate:a", 0.0, BP_FADE_SPEED)
			out_tween.tween_callback(func(): bp_label.visible = false)
		bp_previous_display = bp_label_target

	# Label colour: bright when BP ability selected, dim otherwise.
	if bp_ability_selected:
		bp_label.self_modulate = Color.WHITE
		bp_label_fade.self_modulate = Color.WHITE
	else:
		bp_label.self_modulate = Color(0.9, 0.9, 0.9)
		bp_label_fade.self_modulate = Color(0.9, 0.9, 0.9)
	# Shake + red pulse on BP rejection
	if BattleManager.bp_rejected:
		BattleManager.bp_rejected = false
		_bp_shake()
		
	# AP
	var ap_max: int = PlayerData.ap_max
	var ap_remaining: int = PlayerData.ap_max
	if BattleManager.active and BattleManager.player_turn != null:
		ap_remaining = BattleManager.player_turn.ap_remaining
	elif BattleManager.active:
		ap_remaining = ap_previous_remaining if ap_previous_remaining >= 0 else PlayerData.ap_max
		
	# Rebuilds pips if max AP changed.
	if ap_max != ap_previous_count:
		_build_ap_pips(ap_max)
		ap_previous_count = ap_max
		ap_previous_remaining = ap_remaining
		
	if ap_max == 0:
		ap_previous_remaining = 0
	else:
		# Detects AP cost of selected ability.
		var ap_cost_selected: int = 0
		if BattleManager.active and BattleManager.player_turn != null:
			var ap_active_slot: int = BattleManager.player_turn.active_hotbar_slot
			if ap_active_slot >= 0:
				var ap_slot_id: String = PlayerData.get_hotbar_ability(ap_active_slot)
				if ap_slot_id != "" and ap_slot_id != "basic_attack":
					var ap_slot_ability: Dictionary = AbilityDB.get_ability(ap_slot_id)
					var ap_slot_cost: Dictionary = ap_slot_ability.get("cost", {})
					ap_cost_selected = ap_slot_cost.get("ap", 0)
					
		# Detects spent AP.
		if BattleManager.active and BattleManager.player_turn != null:
			if ap_remaining < ap_previous_remaining:
				var spent: int = ap_previous_remaining - ap_remaining
				for i in range(spent):
					var pip_index: int = ap_previous_remaining - 1 - i
					if pip_index >= 0 and pip_index < ap_pips.size():
						ap_pip_states[pip_index] = ApState.USED
						ap_pip_frames[pip_index] = 0
						ap_pip_timers[pip_index] = 0.0
						
			# Detects if AP was refilled.
			elif ap_remaining > ap_previous_remaining:
				var refill_index: int = 0
				for i in range(ap_remaining):
					if i < ap_pips.size() and ap_pip_states[i] != ApState.FULL:
						ap_pip_states[i] = ApState.REFILL
						ap_pip_frames[i] = 0
						ap_pip_timers[i] = 0.0
						ap_pip_delays[i] = refill_index * AP_REFILL_STAGGER
						refill_index += 1
						
			ap_previous_remaining = ap_remaining
		elif not BattleManager.active:
			ap_previous_remaining = ap_remaining
			
		# Handles AP rejection.
		if BattleManager.ap_rejected_cost > 0:
			var rejected_cost: int = BattleManager.ap_rejected_cost
			BattleManager.ap_rejected_cost = 0
			if rejected_cost > ap_max:
				for i in range(ap_pips.size()):
					_ap_flash_red(i)
					
			else: 
				var missing: int = rejected_cost - ap_remaining
				for i in range(missing):
					var pip_index: int = ap_remaining + i
					if pip_index < ap_pips.size():
						_ap_flash_red(pip_index)
						
		# Updates each pips state and texture.
		for i in range(ap_pips.size()):
			match ap_pip_states[i]:
				ApState.FULL:
					if ap_cost_selected > 0 and i >= ap_remaining - ap_cost_selected and i < ap_remaining:
						ap_pip_states[i] = ApState.SELECT
						ap_pip_frames[i] = 0
						ap_pip_timers[i] = 0.0
					else:
						ap_pips[i].texture = ap_full_texture

				ApState.SELECT:
					if ap_cost_selected == 0 or i < ap_remaining - ap_cost_selected or i >= ap_remaining:
						ap_pip_states[i] = ApState.FULL
						ap_pips[i].texture = ap_full_texture
					else:
						ap_pip_timers[i] += delta
						if ap_pip_timers[i] >= 1.0 / AP_SELECT_FPS:
							ap_pip_timers[i] -= 1.0 / AP_SELECT_FPS
							ap_pip_frames[i] = (ap_pip_frames[i] + 1) % AP_SELECT_FRAME_COUNT
						ap_pips[i].texture = ap_select_frames[ap_pip_frames[i]]

				ApState.USED:
					ap_pip_timers[i] += delta
					if ap_pip_timers[i] >= 1.0 / AP_USED_FPS:
						ap_pip_timers[i] -= 1.0 / AP_USED_FPS
						ap_pip_frames[i] += 1
						if ap_pip_frames[i] >= AP_USED_FRAME_COUNT:
							ap_pip_states[i] = ApState.DEPLETED
							ap_pips[i].texture = ap_depleted_texture
							continue
					ap_pips[i].texture = ap_used_frames[ap_pip_frames[i]]

				ApState.DEPLETED:
					ap_pips[i].texture = ap_depleted_texture

				ApState.REFILL:
					if ap_pip_delays[i] > 0:
						ap_pip_delays[i] -= delta
						ap_pips[i].texture = ap_depleted_texture
					else:
						ap_pip_timers[i] += delta
						if ap_pip_timers[i] >= 1.0 / AP_REFILL_FPS:
							ap_pip_timers[i] -= 1.0 / AP_REFILL_FPS
							ap_pip_frames[i] += 1
							if ap_pip_frames[i] >= AP_REFILL_FRAME_COUNT:
								ap_pip_states[i] = ApState.FULL
								ap_pips[i].texture = ap_full_texture
								continue
						ap_pips[i].texture = ap_refill_frames[ap_pip_frames[i]]
		
	# MP
	var max_mp: int = PlayerData.get_max_mp()
	mp_bar.max_value = 100
	mp_bar_preview.max_value = 100

	var current_mp: int = max_mp
	var planned_cost: int = 0

	if BattleManager.active and BattleManager.player_turn != null:
		current_mp = BattleManager.player_turn.mp_budget
		planned_cost = BattleManager.player_turn.path_cost

	var total_mp_cost: int = planned_cost + selected_ability_mp_cost
	var mp_preview_target: int = 0
	var mp_display_target: int = 0

	if max_mp > 0:
		mp_preview_target = round(float(current_mp) / max_mp * 100.0)
		mp_display_target = round(float(current_mp - total_mp_cost) / max_mp * 100.0)

	if (current_mp - total_mp_cost) > 0:
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

	# Preview bar snaps during planning, drains toward green, tracks green when matched.
	if total_mp_cost > 0:
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
	if total_mp_cost > 0:
		mp_flash_timer += delta
		if mp_flash_timer >= 1.0 / MP_FLASH_FPS:
			mp_flash_timer -= 1.0 / MP_FLASH_FPS
			mp_flash_frame = (mp_flash_frame + 1) % MP_FLASH_FRAME_COUNT
		mp_bar_preview.texture_progress = mp_flash_frames[mp_flash_frame]
	else:
		mp_flash_timer = 0.0
		mp_flash_frame = 0
		
	if BattleManager.mp_rejected:
		BattleManager.mp_rejected = false
		_mp_label_flash_red()

	# HP / MP Labels
	hp_max_label.text = str(PlayerData.max_hp)
	mp_max_label.text = str(max_mp)

	if selected_ability_hp_cost > 0:
		var hp_label_preview: int = max(PlayerData.current_hp - selected_ability_hp_cost, 0)
		hp_current_label.text = str(hp_label_preview)
		hp_current_label.self_modulate = LABEL_COLOR_COST
	elif selected_ability_hp_heal > 0:
		var hp_label_preview: int = min(PlayerData.current_hp + selected_ability_hp_heal, PlayerData.max_hp)
		hp_current_label.text = str(hp_label_preview)
		hp_current_label.self_modulate = LABEL_COLOR_HEAL
	else:
		hp_current_label.text = str(PlayerData.current_hp)
		hp_current_label.self_modulate = LABEL_COLOR_NORMAL

	var total_mp_preview: int = planned_cost + selected_ability_mp_cost
	if total_mp_preview > 0:
		var mp_label_preview: int = max(current_mp - total_mp_preview, 0)
		mp_current_label.text = str(mp_label_preview)
		mp_current_label.self_modulate = LABEL_COLOR_COST
	else:
		mp_current_label.text = str(current_mp)
		mp_current_label.self_modulate = LABEL_COLOR_NORMAL
		
func _bp_shake() -> void:
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(bp_icon, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.08)
	flash_tween.tween_property(bp_icon, "modulate", Color.WHITE, 0.08)
	flash_tween.tween_property(bp_icon, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.08)
	flash_tween.tween_property(bp_icon, "modulate", Color.WHITE, 0.08)
	
func _build_ap_pips(count: int) -> void:
	for pip in ap_pips:
		pip.queue_free()
	ap_pips.clear()
	ap_pip_states.clear()
	ap_pip_frames.clear()
	ap_pip_timers.clear()
	ap_pip_delays.clear()
	
	for i in range(count):
		var pip: Sprite2D = Sprite2D.new()
		pip.texture = ap_full_texture
		pip.centered = false
		pip.position = Vector2(AP_PIP_START.x + (i * AP_PIP_SPACING), AP_PIP_START.y)
		$StatusBar_bg.add_child(pip)
		ap_pips.append(pip)
		ap_pip_states.append(ApState.FULL)
		ap_pip_frames.append(0)
		ap_pip_timers.append(0.0)
		ap_pip_delays.append(0.0)
		
func _ap_flash_red(pip_index: int) -> void:
	var pip: Sprite2D = ap_pips[pip_index]
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(pip, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.08)
	flash_tween.tween_property(pip, "modulate", Color.WHITE, 0.08)
	flash_tween.tween_property(pip, "modulate", Color(1.0, 0.0, 0.0, 1.0), 0.08)
	flash_tween.tween_property(pip, "modulate", Color.WHITE, 0.08)

func _mp_label_flash_red() -> void:
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(mp_current_label, "self_modulate", Color(1.0, 0.0, 0.0, 1.0), 0.08)
	flash_tween.tween_property(mp_current_label, "self_modulate", Color.WHITE, 0.08)
	flash_tween.tween_property(mp_current_label, "self_modulate", Color(1.0, 0.0, 0.0, 1.0), 0.08)
	flash_tween.tween_property(mp_current_label, "self_modulate", Color.WHITE, 0.08)
