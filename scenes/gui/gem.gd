extends AnimatedSprite2D

class_name MenuGem

enum GemState {
	OFF,
	ACTIVATING,
	ON,
	GLITTERING,
	FADING
}

@export var glitter_interval: float = 1.2

var state: GemState = GemState.OFF
var fade_queued: bool = false
var time_to_glitter: float = 0.0

func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	set_off_instantly()

func _process(delta: float) -> void:
	if state != GemState.ON:
		return
	time_to_glitter -= delta
	if time_to_glitter <= 0.0:
		_start_glitter()

# Used on tab switch: snaps with no animation.
func set_on_instantly() -> void:
	fade_queued = false
	state = GemState.ON
	play("on")
	_reset_glitter_timer()

func set_off_instantly() -> void:
	fade_queued = false
	state = GemState.OFF
	play("off")

# Used when the player moves back onto the gem.
func turn_on() -> void:
	if state == GemState.OFF:
		_start_activate()
	elif state == GemState.FADING:
		# Reverses from the frame the fade has reached, instead of jumping to frame 1.
		var current_frame: int = frame
		_start_activate()
		frame = current_frame
	elif state == GemState.GLITTERING:
		fade_queued = false

# Used when the player moves off the gem. A glitter in progress finishes first.
func turn_off() -> void:
	if state == GemState.ON:
		_start_fade()
	elif state == GemState.GLITTERING:
		fade_queued = true
	elif state == GemState.ACTIVATING:
		var current_frame: int = frame
		_start_fade()
		frame = current_frame

func glitter_now() -> void:
	if state == GemState.ON:
		_start_glitter()

func _start_activate() -> void:
	state = GemState.ACTIVATING
	play("activate")

func _start_glitter() -> void:
	state = GemState.GLITTERING
	play("glitter")

func _start_fade() -> void:
	state = GemState.FADING
	play_backwards("activate")

func _on_animation_finished() -> void:
	if state == GemState.GLITTERING:
		if fade_queued:
			fade_queued = false
			_start_fade()
		else:
			state = GemState.ON
			play("on")
			_reset_glitter_timer()
	elif state == GemState.ACTIVATING:
		state = GemState.ON
		play("on")
		_reset_glitter_timer()
	elif state == GemState.FADING:
		state = GemState.OFF
		play("off")

func _reset_glitter_timer() -> void:
	time_to_glitter = glitter_interval
