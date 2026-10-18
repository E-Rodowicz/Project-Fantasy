extends RefCounted

# Shared colour fades for the GUI. Every function is static, so any script can call it directly,
# e.g. UiFade.label_colour(label, Color.YELLOW), without needing a node or an instance.
class_name UiFade

const DEFAULT_TIME: float = 0.1

# Fades a Label's text colour.
static func label_colour(label: Label, colour: Color, duration: float = DEFAULT_TIME) -> void:
	# Meta is a small store of extra values you can attach to any node. Here it remembers each
	# label's running fade and where it's heading.
	if label.has_meta("fade_target") and label.get_meta("fade_target") == colour:
		return
	_kill_old_fade(label)
	# A theme colour tween needs a starting value, so give the label its current colour first.
	if not label.has_theme_color_override("font_color"):
		label.add_theme_color_override("font_color", label.get_theme_color("font_color"))
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "theme_override_colors/font_color", colour, duration)
	label.set_meta("fade_tween", tween)
	label.set_meta("fade_target", colour)

# Fades a node's modulate, for things coloured that way (like Buttons).
static func modulate(item: CanvasItem, colour: Color, duration: float = DEFAULT_TIME) -> void:
	if item.has_meta("fade_target") and item.get_meta("fade_target") == colour:
		return
	_kill_old_fade(item)
	var tween: Tween = item.create_tween()
	tween.tween_property(item, "modulate", colour, duration)
	item.set_meta("fade_tween", tween)
	item.set_meta("fade_target", colour)

static func _kill_old_fade(item: CanvasItem) -> void:
	if item.has_meta("fade_tween"):
		var old_tween: Tween = item.get_meta("fade_tween")
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
