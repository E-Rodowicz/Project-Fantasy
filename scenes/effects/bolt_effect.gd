class_name BoltEffect
extends AnimatedSprite2D

var _mat: ShaderMaterial = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Materials assigned in a .tscn are shared between every instance of that scene,
	# so give this one its own copy before touching any parameter.
	_mat = material.duplicate() as ShaderMaterial
	material = _mat

	var light: PointLight2D = $BoltLight
	var frames: int = sprite_frames.get_frame_count("default")
	var fps: float = sprite_frames.get_animation_speed("default")
	var anim_length: float = float(frames) / fps

	var tween: Tween = create_tween()
	tween.tween_property(light, "energy", 0.0, anim_length).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)

	animation_finished.connect(queue_free)
	play("default")

func set_length(world_length: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("cut_beyond", world_length / scale.x)

func duration() -> float:
	return float(sprite_frames.get_frame_count("default")) / sprite_frames.get_animation_speed("default")
