extends Label

# Shows how many skill points the player has to spend, pulsing slowly between dim and bright.
# It watches PlayerData itself, so nothing else has to tell it when the amount changes.

# Which PlayerData variable this label watches, and what one point is called.
@export var points_variable: String = "unspent_skill_points"
@export var point_name: String = "skill point"
@export var pulse_speed: float = 0.5
@export_range(0.0, 1.0) var pulse_min: float = 0.55
@export var fade_time: float = 0.25
# The pop when the amount changes: up fast, then a quick drop back.
@export var pop_scale: float = 1.15
@export var pop_up_time: float = 0.05
@export var pop_settle_time: float = 0.20
# The flash with the pop. Above 1 brightens, like the hotbar flash.
@export var flash_brightness: float = 2.0
@export var flash_time: float = 0.3
# Shown instead of "1 ... to spend!" when there's exactly one point. Left empty, it uses the number.
@export var singular_text: String = ""

# The label's own scale from the scene, so the pop always returns to it.
var base_scale: Vector2 = Vector2.ONE
var pop_tween: Tween = null
# 1 = full flash, 0 = none. Blended over the pulse, so the two never fight.
var flash_amount: float = 0.0
var flash_tween: Tween = null

# The amount the text currently shows.
var shown_points: int = 0
var pulse_time: float = 0.0
# 0 = hidden, 1 = fully shown. Tweened separately from the pulse.
var show_alpha: float = 0.0
var fade_tween: Tween = null

func _ready() -> void:
	base_scale = scale
	# get() reads a variable by its name, so this script can watch any kind of point.
	shown_points = PlayerData.get(points_variable)
	if shown_points > 0:
		_set_text(shown_points)
		show_alpha = 1.0
	_apply_colour(1.0)

func _process(delta: float) -> void:
	var points: int = PlayerData.get(points_variable)
	if points != shown_points:
		_on_points_changed(points)
	pulse_time += delta
	var wave: float = 0.5 + 0.5 * cos(pulse_time * TAU * pulse_speed)
	var pulse: float = lerpf(pulse_min, 1.0, wave)
	_apply_colour(lerpf(pulse, flash_brightness, flash_amount))

func _on_points_changed(points: int) -> void:
	var was_showing: bool = shown_points > 0
	shown_points = points
	# Only if it was already on screen. Appearing from 0 just fades in.
	if was_showing:
		_pop()
	if points > 0:
		_set_text(points)
		if not was_showing:
			pulse_time = 0.0
			_fade_to(1.0)
	else:
		# The text is left as it was, so it doesn't read "0" while fading out.
		_fade_to(0.0)

func _set_text(points: int) -> void:
	if points == 1 and singular_text != "":
		text = singular_text
		return
	var plural: String = "" if points == 1 else "s"
	text = str(points) + " " + point_name + plural + " to spend!"

func _fade_to(target: float) -> void:
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(self, "show_alpha", target, fade_time)

func _apply_colour(brightness: float) -> void:
	modulate = Color(brightness, brightness, brightness, show_alpha)

# Pops the text up and flashes it bright. The flash has its own tween, since pop_tween runs its
# steps one after another and would make the shrink wait for the flash to finish.
func _pop() -> void:
	if pop_tween != null and pop_tween.is_valid():
		pop_tween.kill()
	# Back to normal size first, so moving the pivot can't shift the label mid-pop.
	scale = base_scale
	# Scale grows from pivot_offset. The text is centred, so the label's middle is the text's middle.
	pivot_offset = (size / 2.0).round()
	pop_tween = create_tween()
	pop_tween.tween_property(self, "scale", base_scale * pop_scale, pop_up_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "scale", base_scale, pop_settle_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# The pulse restarts at full brightness, so the flash settles into its bright end.
	pulse_time = 0.0
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_amount = 1.0
	flash_tween = create_tween()
	flash_tween.tween_property(self, "flash_amount", 0.0, flash_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
