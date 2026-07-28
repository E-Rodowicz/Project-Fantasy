class_name LitEffect
extends AnimatedSprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	
	var light: PointLight2D = get_node_or_null("Light")
	if light != null:
		var frames: int = sprite_frames.get_frame_count("default")
		var fps: float = sprite_frames.get_animation_speed("default")
		var anim_length: float = float(frames) / fps
		var tween: Tween = create_tween()
		tween.tween_property(light, "energy", 0.0, anim_length).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		
	animation_finished.connect(queue_free)
	play("default")
