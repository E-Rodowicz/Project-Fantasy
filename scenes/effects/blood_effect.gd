extends AnimatedSprite2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var index: int = randi_range(1, 9)
	play("blood_" + str(index).pad_zeros(2))

	flip_h = randi() % 2 == 0
	flip_v = randi() % 2 == 0

	animation_finished.connect(queue_free)
