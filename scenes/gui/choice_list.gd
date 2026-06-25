extends VBoxContainer
class_name ChoiceList

var choice_labels: Array = []
var choice_tweens: Array = []
var current_index: int = 0
var is_confirming: bool = false

func set_choices(choices: Array, start_index: int = 0) -> void:
	for child in get_children():
		child.queue_free()
	choice_labels.clear()
	choice_tweens.clear()
	current_index = start_index
	is_confirming = false

	for i in range(choices.size()):
		var label: Label = Label.new()
		label.text = choices[i]
		label.add_theme_constant_override("outline_size", 11)
		label.add_theme_color_override("font_outline_color", Color("#414141"))
		add_child(label)
		choice_labels.append(label)

	update_selection()

func navigate(direction: int) -> void:
	if is_confirming:
		return
	current_index = (current_index + direction) % choice_labels.size()
	if current_index < 0:
		current_index = choice_labels.size() - 1
	update_selection()

func update_selection() -> void:
	for t in choice_tweens:
		if t:
			t.kill()
	choice_tweens.clear()

	for i in range(choice_labels.size()):
		var label: Label = choice_labels[i]
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var text_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		label.pivot_offset = Vector2(text_width / 2.0, label.size.y / 2.0)

		var tween: Tween = create_tween().set_parallel()
		if i == current_index:
			tween.tween_property(label, "modulate", Color.YELLOW, 0.15)
			tween.tween_property(label, "scale", Vector2(1.02, 1.02), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		else:
			tween.tween_property(label, "modulate", Color.WHITE, 0.15)
			tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		choice_tweens.append(tween)

func glow_confirm(callback: Callable) -> void:
	if is_confirming:
		return
	is_confirming = true
	var label: Label = choice_labels[current_index]

	for t in choice_tweens:
		if t:
			t.kill()
	choice_tweens.clear()

	for i in range(choice_labels.size()):
		if i != current_index:
			choice_labels[i].modulate = Color.WHITE
			choice_labels[i].scale = Vector2(1.0, 1.0)

	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	label.pivot_offset = Vector2(text_width / 2.0, label.size.y / 2.0)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", Color(2.0, 1.977, 0.0, 1.0), 0.1)
	tween.tween_property(label, "scale", Vector2(1.05, 1.05), 0.08).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain()
	tween.tween_interval(0.15)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate", Color.WHITE, 0.12)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.chain()
	tween.tween_callback(callback)
