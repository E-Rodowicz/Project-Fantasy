class_name StatusIcon
extends Node2D

const FADE: float = 0.15
const PULSE_SPEED: float = 4.0
const PULSE_MIN: float = 0.75
const PULSE_MAX: float = 1.15

@onready var count_label: Label = $Count
@onready var icon: CanvasItem = $Icon

var _alpha: float = 0.0
var _dismissing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate = Color(1.0, 1.0, 1.0, 0.0)

func set_stacks(stacks: int) -> void:
	count_label.visible = stacks > 1
	count_label.text = str(stacks)

func dismiss() -> void:
	_dismissing = true

func _process(delta: float) -> void:
	if _dismissing:
		_alpha = maxf(0.0, _alpha - delta / FADE)
		if _alpha <= 0.0:
			queue_free()
			return
	else:
		_alpha = minf(1.0, _alpha + delta / FADE)

	# Root handles the fade for the whole icon, label included.
	modulate.a = _alpha

	# Shared clock, so every icon on screen pulses in unison.
	var wave: float = (sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED) + 1.0) * 0.5
	var pulse: float = lerpf(PULSE_MIN, PULSE_MAX, wave)
	icon.self_modulate = Color(pulse, pulse, pulse, 1.0)
