extends RefCounted

# Shared colour fades for the GUI. Every function is static, so any script can call it directly,
# e.g. UiFade.label_colour(label, Color.YELLOW), without needing a node or an instance.
class_name UiFade

const DEFAULT_TIME: float = 0.1
# The flash an ability plays when it lands on the hotbar: up to bright white fast, then settle back.
# Above 1 brightens.
const FLASH_COLOUR: Color = Color(2.0, 2.0, 2.0, 1.0)
const FLASH_POP_TIME: float = 0.06
const FLASH_SETTLE_TIME: float = 0.2
# How much bigger a selected item grows, and how long it takes.
const POP_SCALE: float = 1.1
const POP_TIME: float = 0

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
	
# Pops a node bright and settles it back to normal. Shares the fade's slot in meta, so a flash
# and a fade on the same node never fight: whichever starts last wins.
static func flash(item: CanvasItem) -> void:
	_kill_old_fade(item)
	var tween: Tween = item.create_tween()
	tween.tween_property(item, "modulate", FLASH_COLOUR, FLASH_POP_TIME)
	tween.tween_property(item, "modulate", Color.WHITE, FLASH_SETTLE_TIME)
	item.set_meta("fade_tween", tween)
	item.set_meta("fade_target", Color.WHITE)

# Stops any fade or flash on a node, leaving it as it is right now.
static func stop(item: CanvasItem) -> void:
	_kill_old_fade(item)
	if item.has_meta("fade_target"):
		item.remove_meta("fade_target")

# Grows an item when popped and shrinks it back when not. TRANS_BACK overshoots a touch, which reads
# as a pop. Only acts when the target changes, so it's safe to call every highlight update.
static func pop(item: Control, popped: bool, pop_scale: float = POP_SCALE, duration: float = POP_TIME) -> void:
	var target: float = pop_scale if popped else 1.0
	if item.has_meta("pop_target") and item.get_meta("pop_target") == target:
		return
	if item.has_meta("pop_tween"):
		var old_tween: Tween = item.get_meta("pop_tween")
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
	# Moving the pivot of an item that's already scaled shifts where it's drawn, so the position is
	# moved back by the same amount. At scale 1 that amount is zero, so most items aren't touched.
	var new_pivot: Vector2 = _pop_pivot(item).round()
	item.position += (item.pivot_offset - new_pivot) * (Vector2.ONE - item.scale)
	item.pivot_offset = new_pivot
	# Draws the popped item over its neighbours, since it now slightly overlaps them.
	item.z_index = 1 if popped else 0
	var tween: Tween = item.create_tween()
	# Grows relative to the item's own scale, so something already scaled in the scene (like the
	# 0.75 XP text) keeps it. Taken the first time it's popped, before any pop has changed it.
	if not item.has_meta("pop_base_scale"):
		item.set_meta("pop_base_scale", item.scale)
	var base_scale: Vector2 = item.get_meta("pop_base_scale")
	tween.tween_property(item, "scale", base_scale * target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	item.set_meta("pop_tween", tween)
	item.set_meta("pop_target", target)

# pivot_offset is the point scale grows from. For a container or a left-aligned label, the content
# can be narrower than the node, so the pivot goes at the content's middle. Anything else grows
# from its own centre.
static func _pop_pivot(item: Control) -> Vector2:
	var content: Vector2 = item.get_combined_minimum_size()
	var centred_label: bool = item is Label and (item as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER
	if item is Container or (item is Label and not centred_label):
		return Vector2(content.x / 2.0, item.size.y / 2.0)
	return item.size / 2.0

static func _kill_old_fade(item: CanvasItem) -> void:
	if item.has_meta("fade_tween"):
		var old_tween: Tween = item.get_meta("fade_tween")
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()
