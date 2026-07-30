class_name FloatingLabel
extends Node2D

const REST_HEIGHT: float = 4.0
const POP_TIME: float = 0.12
const SETTLE_TIME: float = 0.16
const FADE_IN: float = 0.06
const HOLD: float = 0.55
const FADE_OUT: float = 0.55
const RAINBOW_SPEED: float = 0.6
const CANCEL_TIME: float = 0.12

var _origin_y: float = 0.0
var _captured: bool = false
var _elapsed: float = 0.0
var _pop: float = 0.0
var _drift: float = 0.0
var _rainbow: bool = false
var _base_scale: Vector2 = Vector2.ONE
var _settings: LabelSettings = null
var _cancelled: bool = false
var _cancel_from: float = 1.0
var _cancel_t: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 0.0
	_base_scale = $Text.scale

# Pop - throws upward then settles back, for damage numbers.
# Drift - rises steadily the whole time, for miss / block / fire spread.
func setup(text: String, colour: Color = Color.WHITE, node_scale: float = 1.0, pop: float = 0.0, drift: float = 0.0, rainbow: bool = false) -> void:
	var label: Label = $Text
	label.text = text
	# LabelSettings saved in a scene is shared between instances.
	_settings = label.label_settings.duplicate()
	label.label_settings = _settings
	_settings.font_color = colour

	label.scale = _base_scale * node_scale
	_pop = pop
	_drift = drift
	_rainbow = rainbow

func _process(delta: float) -> void:
	if _cancelled:
		_cancel_t += delta
		modulate.a = _cancel_from * (1.0 - clampf(_cancel_t / CANCEL_TIME, 0.0, 1.0))
		if _cancel_t >= CANCEL_TIME:
			queue_free()
		return
	if not _captured:
		_origin_y = position.y
		_captured = true

	_elapsed += delta
	var total: float = POP_TIME + SETTLE_TIME + HOLD + FADE_OUT

	var offset: float = REST_HEIGHT
	if _drift > 0.0:
		# Steady rise across the whole life, decelerating as it goes.
		var t: float = clampf(_elapsed / total, 0.0, 1.0)
		offset = REST_HEIGHT + _drift * (1.0 - pow(1.0 - t, 3.0))
	elif _elapsed < POP_TIME:
		# Thrown upward, decelerating.
		var t: float = _elapsed / POP_TIME
		offset = REST_HEIGHT + _pop * (1.0 - pow(1.0 - t, 2.0))
	elif _elapsed < POP_TIME + SETTLE_TIME:
		# Falls back to rest, accelerating.
		var t: float = (_elapsed - POP_TIME) / SETTLE_TIME
		offset = lerpf(REST_HEIGHT + _pop, REST_HEIGHT, t * t)
	position.y = _origin_y - roundf(offset)

	if _elapsed < FADE_IN:
		modulate.a = _elapsed / FADE_IN
	elif _elapsed > total - FADE_OUT:
		modulate.a = clampf((total - _elapsed) / FADE_OUT, 0.0, 1.0)
	else:
		modulate.a = 1.0

	if _rainbow and _settings != null:
		var hue: float = fposmod(Time.get_ticks_msec() * 0.001 * RAINBOW_SPEED, 1.0)
		_settings.font_color = Color.from_hsv(hue, 0.85, 1.0)

	if _elapsed >= total:
		queue_free()

# Superseded by a newer number. Freezes in place and fades out quickly.
func cancel() -> void:
	if _cancelled:
		return
	_cancelled = true
	_cancel_from = modulate.a
	_cancel_t = 0.0
