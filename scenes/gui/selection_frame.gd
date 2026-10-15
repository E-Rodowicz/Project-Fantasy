extends Control

# A 1px border drawn in code. Selected: pulsing corner brackets. Activated: the lines grow from
# each corner along the edges until they meet in the middle. Place it over a window with
# Layout → Full Rect.
class_name SelectionFrame

enum FrameState {
	HIDDEN,
	SELECTED,
	ACTIVE
}

# The top-left corner art. The other three corners are this, flipped.
@export var corner_texture: Texture2D = null
# The line's colour. The corner art keeps its own colours.
@export var colour: Color = Color("f2c14e")
# How many pixels in from the outer edge the line runs, to line up with the corner art.
@export var line_inset: int = 0
# How far each bracket reaches along an edge while selected, measured from the frame's corner,
# as a fraction of that edge. If this is shorter than the corner art, only the corners show.
@export_range(0.0, 0.5) var bracket_fraction: float = 0.16
@export var grow_time: float = 0.2
@export var shrink_time: float = 0.12
@export var fade_time: float = 0.12
# Pulses per second while selected, and how dim the pulse gets at its lowest.
@export var pulse_speed: float = 1.5
@export_range(0.0, 1.0) var pulse_min: float = 0.55
# Off: the arms snap straight to brackets or a full border instead of growing and shrinking.
# The frame still fades in and out either way.
@export var animate_arms: bool = true

var state: FrameState = FrameState.HIDDEN
# 0 = brackets, 1 = full border. Tweened smoothly, then rounded to whole pixels when drawn.
var arm_progress: float = 0.0
var frame_alpha: float = 0.0
var pulse_amount: float = 1.0
var pulse_time: float = 0.0
var frame_tween: Tween = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

# queue_redraw() asks Godot to run _draw() again this frame, so the border always shows its
# current lengths, fade and pulse.
func _process(delta: float) -> void:
	if state == FrameState.SELECTED:
		pulse_time += delta
		# cos swings smoothly between -1 and 1. This turns it into 0..1, starting at full brightness.
		var wave: float = 0.5 + 0.5 * cos(pulse_time * TAU * pulse_speed)
		pulse_amount = lerpf(pulse_min, 1.0, wave)
	else:
		pulse_amount = move_toward(pulse_amount, 1.0, delta * 4.0)
	queue_redraw()

# --- STATES ---
func select() -> void:
	if state == FrameState.SELECTED:
		return
	state = FrameState.SELECTED
	pulse_time = 0.0
	_animate_to(0.0, shrink_time)

func activate() -> void:
	if state == FrameState.ACTIVE:
		return
	state = FrameState.ACTIVE
	_animate_to(1.0, grow_time)

func deselect() -> void:
	if state == FrameState.HIDDEN:
		return
	state = FrameState.HIDDEN
	_kill_tween()
	frame_tween = create_tween()
	frame_tween.tween_property(self, "frame_alpha", 0.0, fade_time)
	# Once invisible, the arms reset, so the next select or activate starts from brackets.
	frame_tween.tween_callback(func() -> void: arm_progress = 0.0)

# tween_property works on script variables too, not just built-in properties.
func _animate_to(target_progress: float, duration: float) -> void:
	_kill_tween()
	frame_tween = create_tween()
	frame_tween.set_parallel(true)
	if animate_arms:
		frame_tween.tween_property(self, "arm_progress", target_progress, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		arm_progress = target_progress
	frame_tween.tween_property(self, "frame_alpha", 1.0, fade_time)

# For when a window appears and the frame should start from nothing, with no fade out first.
func hide_instantly() -> void:
	_kill_tween()
	state = FrameState.HIDDEN
	frame_alpha = 0.0
	arm_progress = 0.0

func _kill_tween() -> void:
	if frame_tween != null and frame_tween.is_valid():
		frame_tween.kill()

# --- DRAWING ---
# _draw() is where a Control draws itself in code, in this node's own native pixels.
func _draw() -> void:
	var w: int = int(size.x)
	var h: int = int(size.y)
	if frame_alpha <= 0.0:
		return

	var alpha: float = frame_alpha * pulse_amount
	var corner_w: int = 0
	var corner_h: int = 0
	if corner_texture != null:
		corner_w = corner_texture.get_width()
		corner_h = corner_texture.get_height()
		_draw_corners(w, h, Color(1.0, 1.0, 1.0, alpha))

	var c: Color = colour
	c.a *= alpha

	# Top and bottom lines start where the corner art ends and grow towards the middle. The left
	# half takes the odd middle pixel on an odd width, so the two meet with no gap and no overlap.
	var left: int = _arm(w * bracket_fraction - corner_w, ceili(w / 2.0) - corner_w)
	var right: int = _arm(w * bracket_fraction - corner_w, floori(w / 2.0) - corner_w)
	var top_y: int = line_inset
	var bottom_y: int = h - 1 - line_inset
	draw_rect(Rect2(corner_w, top_y, left, 1), c)
	draw_rect(Rect2(w - corner_w - right, top_y, right, 1), c)
	draw_rect(Rect2(corner_w, bottom_y, left, 1), c)
	draw_rect(Rect2(w - corner_w - right, bottom_y, right, 1), c)

	# Side lines, the same way.
	var top: int = _arm(h * bracket_fraction - corner_h, ceili(h / 2.0) - corner_h)
	var bottom: int = _arm(h * bracket_fraction - corner_h, floori(h / 2.0) - corner_h)
	var left_x: int = line_inset
	var right_x: int = w - 1 - line_inset
	draw_rect(Rect2(left_x, corner_h, 1, top), c)
	draw_rect(Rect2(left_x, h - corner_h - bottom, 1, bottom), c)
	draw_rect(Rect2(right_x, corner_h, 1, top), c)
	draw_rect(Rect2(right_x, h - corner_h - bottom, 1, bottom), c)

# draw_set_transform moves and scales everything drawn after it. A scale of -1 mirrors, so the
# same top-left art becomes the other three corners. It's reset at the end so the lines aren't
# affected.
func _draw_corners(w: int, h: int, tint: Color) -> void:
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1, 1))
	draw_texture(corner_texture, Vector2.ZERO, tint)
	draw_set_transform(Vector2(w, 0), 0.0, Vector2(-1, 1))
	draw_texture(corner_texture, Vector2.ZERO, tint)
	draw_set_transform(Vector2(0, h), 0.0, Vector2(1, -1))
	draw_texture(corner_texture, Vector2.ZERO, tint)
	draw_set_transform(Vector2(w, h), 0.0, Vector2(-1, -1))
	draw_texture(corner_texture, Vector2.ZERO, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# Blends from bracket length to meeting-in-the-middle length, then rounds to a whole pixel.
# maxi stops it going negative if the frame is smaller than two corners.
func _arm(bracket_length: float, full_length: int) -> int:
	var full: int = maxi(0, full_length)
	return clampi(roundi(lerpf(bracket_length, float(full), arm_progress)), 0, full)
