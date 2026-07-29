extends Node

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

var _screen_flash: ColorRect = null

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
	var fl: FloatingLabel = FLOATING_LABEL.instantiate()
	fl.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(fl)
	fl.global_position = (at_pos + Vector2(0.0, -10.0)).round()
	fl.setup(text, colour, 1.0, 0.0, LABEL_DRIFT)

func float_damage(amount: int, ratio: float, parent: Node, at_pos: Vector2) -> void:
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
