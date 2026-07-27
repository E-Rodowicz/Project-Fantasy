extends Node

const HIT_FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const BLOOD_EFFECT: PackedScene = preload("res://scenes/effects/blood_effect.tscn")

func get_sprite(target: Node) -> CanvasItem:
	for child in target.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
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
