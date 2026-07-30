extends Node

# Highest offset in world pixels at full strength.
const SHAKE_MAX_OFFSET: float = 20.0
# How much trauma drains per second.
const SHAKE_DECAY: float = 2.0
const LABEL_GAP: float = 0.22
const LABEL_KEY_SIZE: float = 16.0
const HIT_FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const BLOOD_EFFECT: PackedScene = preload("res://scenes/effects/blood_effect.tscn")
const LABEL_DRIFT: float = 8.0
const FLOATING_LABEL: PackedScene = preload("res://scenes/effects/floating_labels.tscn")
const DAMAGE_TIERS: Array = [
	Color(0.95, 0.95, 0.95),   # 0    <100%
	Color(0.95, 0.95, 0.95),   # 1    100-199%   white
	Color(1.00, 0.85, 0.20),   # 2    200-299%   yellow
	Color(1.00, 0.58, 0.10),   # 3    300-399%   orange
	Color(0.88, 0.33, 0.05),   # 4    400-499%   blood orange
	Color(0.88, 0.14, 0.14),   # 5    500-599%   red
	Color(1.00, 0.45, 0.75),   # 7    600-699%   pink
	Color(0.62, 0.24, 0.85),   # 6    700-799%   purple
	Color(0.24, 0.44, 0.95),   # 8    800-899%   blue
	Color(0.48, 0.82, 1.00),   # 9    900-999%   light blue
]

# These scale the size of the text.
const TIER_SCALES: Array = [1.0, 1.0, 1.3, 1.6, 1.9, 2.2, 2.5, 2.8, 3.1, 3.4, 4.0]

# Pop height in world pixels, added per tier above the white band.
const POP_PER_TIER: float = 3.0

# Spot -> earliest time the next queued label may appear there.
var _next_slot: Dictionary = {}
# Spot -> the damage number currently on screen there.
var _active_damage: Dictionary = {}
var _screen_flash: ColorRect = null
var _trauma: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	_screen_flash = ColorRect.new()
	_screen_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	_screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_screen_flash)
	_screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
		
	if _trauma <= 0.0:
		if cam.offset != Vector2.ZERO:
			cam.offset = Vector2.ZERO
		return
		
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	
	# Squared, so weak shakes die off quicker and stronger ones linger.
	var power: float = _trauma
	var off: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_MAX_OFFSET * power
	cam.offset = off.round()
	
func flash_screen(intensity: float = 0.10, duration: float = 0.12, colour: Color = Color.WHITE) -> void:
	_screen_flash.color = Color(colour.r, colour.g, colour.b, intensity)
	var tween: Tween = create_tween()
	tween.tween_property(_screen_flash, "color:a", 0.0, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

func get_sprite(target: Node) -> CanvasItem:
	for child in target.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null
	
func get_light(target: Node) -> Light2D:
	for child in target.get_children():
		if child is Light2D:
			return child
		var nested: Light2D = get_light(child)
		if nested != null:
			return nested
	return null

func spawn_blood(parent: Node, at_pos: Vector2) -> void:
	var blood: AnimatedSprite2D = BLOOD_EFFECT.instantiate()
	blood.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(blood)
	blood.global_position = at_pos

func play_hit_reaction(target: Node, from_pos: Vector2, do_nudge: bool = true) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return
	var sprite: CanvasItem = get_sprite(target)
	if sprite == null:
		return

	var original_pos: Vector2 = target.global_position
	var dir: Vector2 = (target.global_position - from_pos).normalized()

	var shader_mat: ShaderMaterial = ShaderMaterial.new()
	shader_mat.shader = HIT_FLASH_SHADER
	var old_material: Material = sprite.material
	sprite.material = shader_mat

	var flash_set: Callable = func(val: float) -> void:
		shader_mat.set_shader_parameter("flash_amount", val)
	flash_set.call(1.0)

	var flash_tween: Tween = target.create_tween()
	flash_tween.tween_method(flash_set, 1.0, 0.25, 0.05)
	flash_tween.tween_method(flash_set, 0.25, 1.0, 0.05)
	flash_tween.tween_method(flash_set, 1.0, 0.0, 0.05)

	if do_nudge:
		var nudge_tween: Tween = target.create_tween()
		nudge_tween.tween_property(target, "global_position", original_pos + dir * 2.0, 0.05)
		nudge_tween.tween_property(target, "global_position", original_pos, 0.1)

	await flash_tween.finished
	if is_instance_valid(sprite):
		sprite.material = old_material

func play_dodge_reaction(target: Node, from_pos: Vector2) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return

	var original_pos: Vector2 = target.global_position
	var dir: Vector2 = (target.global_position - from_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	# Perpendicular to the incoming attack, flipped to a random side.
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var dodge_offset: Vector2 = Vector2(-dir.y, dir.x) * 3.0 * side

	var dodge_tween: Tween = target.create_tween()
	dodge_tween.tween_property(target, "global_position", original_pos + dodge_offset, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	dodge_tween.tween_property(target, "global_position", original_pos, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await dodge_tween.finished
	
# Spawns a one-shot effect and returns it, so callers can time against its length.
func spawn_effect(scene: PackedScene, parent: Node, at_pos: Vector2, rot: float = 0.0) -> AnimatedSprite2D:
	var fx: AnimatedSprite2D = scene.instantiate()
	fx.process_mode = Node.PROCESS_MODE_ALWAYS
	fx.rotation = rot
	parent.add_child(fx)
	fx.global_position = at_pos
	return fx

# How long a one-shot effect's animation runs, in seconds.
func effect_duration(fx: AnimatedSprite2D, anim: String = "default") -> float:
	var frames: int = fx.sprite_frames.get_frame_count(anim)
	var fps: float = fx.sprite_frames.get_animation_speed(anim)
	if fps <= 0.0:
		return 0.0
	return float(frames) / fps
	
func float_label(text: String, parent: Node, at_pos: Vector2, colour: Color = Color.WHITE) -> void:
	var key: Vector2i = _label_key(at_pos)
	var delay: float = _book_slot(key)
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	# The enemy may have died while this was waiting its turn.
	if not is_instance_valid(parent):
		return

	var fl: FloatingLabel = FLOATING_LABEL.instantiate()
	fl.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(fl)
	fl.global_position = (at_pos + Vector2(0.0, -10.0)).round()
	fl.setup(text, colour, 1.0, 0.0, LABEL_DRIFT)

func float_damage(amount: int, ratio: float, parent: Node, at_pos: Vector2) -> void:
	var key: Vector2i = _label_key(at_pos)

	# Prune labels that have already expired on their own.
	for k in _active_damage.keys():
		if not is_instance_valid(_active_damage[k]):
			_active_damage.erase(k)

	# A newer number supersedes whatever is still on screen here.
	var previous: Node = _active_damage.get(key)
	if previous != null and is_instance_valid(previous):
		previous.cancel()
	_active_damage.erase(key)

	var tier: int = clampi(floori(ratio), 0, 10)
	var rainbow: bool = tier >= 10
	var colour: Color = Color.WHITE
	if not rainbow:
		colour = DAMAGE_TIERS[tier]
	var pop: float = maxf(0.0, float(tier - 1)) * POP_PER_TIER

	var fl: FloatingLabel = FLOATING_LABEL.instantiate()
	fl.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(fl)
	fl.global_position = (at_pos + Vector2(0.0, -10.0)).round()
	fl.setup(str(amount), colour, TIER_SCALES[tier], pop, 0.0, rainbow)
	_active_damage[key] = fl

	# Pushes the queue back so a following miss or fire label doesn't land on top.
	var now: float = Time.get_ticks_msec() * 0.001
	_next_slot[key] = maxf(_next_slot.get(key, 0.0), now + LABEL_GAP)

func _label_key(at_pos: Vector2) -> Vector2i:
	return Vector2i((at_pos / LABEL_KEY_SIZE).round())

# Books the next free slot for a spot and returns how long to wait for it.
func _book_slot(key: Vector2i) -> float:
	var now: float = Time.get_ticks_msec() * 0.001

	# Drop expired entries so the dictionary can't grow forever.
	for k in _next_slot.keys():
		if _next_slot[k] < now:
			_next_slot.erase(k)

	var slot: float = maxf(now, _next_slot.get(key, 0.0))
	_next_slot[key] = slot + LABEL_GAP
	return slot - now

# amount is 0.0 to 1.0. This is called when something worth feeling happens.
func shake(amount: float) -> void:
	if amount <= 0.0:
		return
	_trauma = minf(1.0, maxf(_trauma, amount))
