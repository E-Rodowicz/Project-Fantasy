class_name EnemyHealthBar
extends Node2D

# The counters below are in whole pixels, so one tick is one pixel of movement.
const DRAIN_RATE: float = 0.05    # seconds per pixel of trail movement.
const DRAIN_DELAY: float = 0.25   # pause before the trail starts chasing.
const FADE: float = 0.15          # fade in / out of the whole bar.
const UNDER_FADE: float = 0.05    # fades of the grey empty bar. lower is quicker.

@export var damage_trail_texture: Texture2D = null
@export var heal_trail_texture: Texture2D = null
@export var damage_trail_tint: Color = Color(0.75, 0.12, 0.12, 1.0)
@export var heal_trail_tint: Color = Color(0.35, 0.90, 0.35, 1.0)

@onready var bar: TextureProgressBar = $Bar
@onready var trail: TextureProgressBar = $Trail
@onready var label: Label = $Text

var _current_hp: int = 0
var _max_hp: int = 1
var _fill_pixels: int = 1
var _fill_texture: Texture2D = null
var _damage_texture: Texture2D = null

var _display_current: int = 0
var _trail_current: int = 0
var _drain_timer: float = 0.0
var _drain_delay: float = 0.0
var _is_healing: bool = false

var _alpha: float = 0.0
var _under_alpha: float = 0.0
var _initialised: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# The bar is UI, so world lighting shouldn't darken it in a dim room.
	var unshaded: CanvasItemMaterial = CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	bar.material = unshaded
	trail.material = unshaded
	label.material = unshaded

	_fill_texture = bar.texture_progress
	if _fill_texture != null:
		_fill_pixels = maxi(1, _fill_texture.get_width())

	# Whatever is assigned to Trail in the editor is the damage look. Cache it
	# before anything overwrites it.
	_damage_texture = trail.texture_progress
	if damage_trail_texture != null:
		_damage_texture = damage_trail_texture
	if _damage_texture == null:
		_damage_texture = _fill_texture

	# Each layer now fades on its own, so they start transparent individually
	# rather than the root fading everything together.
	bar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	trail.modulate = Color(1.0, 1.0, 1.0, 0.0)
	trail.tint_under = Color.WHITE
	label.modulate.a = 0.0

	# Both bars share one width so their left edges line up exactly, even if
	# the empty and full textures aren't the same size.
	var art_width: float = maxf(bar.get_combined_minimum_size().x, trail.get_combined_minimum_size().x)

	for progress_bar in [bar, trail]:
		progress_bar.min_value = 0.0
		progress_bar.max_value = float(_fill_pixels)
		progress_bar.step = 1.0
		progress_bar.size = Vector2(art_width, progress_bar.get_combined_minimum_size().y)
		progress_bar.position.x = -roundf(art_width * 0.5)

	label.position.x = -roundf(label.size.x * label.scale.x * 0.5)

	var host: Node = get_parent()
	if host != null and host.has_signal("health_changed"):
		host.health_changed.connect(_on_health_changed)
	else:
		push_warning("EnemyHealthBar: parent has no health_changed signal.")

func _on_health_changed(current: int, maximum: int) -> void:
	_current_hp = current
	_max_hp = maxi(1, maximum)
	label.text = str(_current_hp) + " / " + str(_max_hp)

	# The first report is the enemy's starting HP, so snap both counters to it
	# rather than animating a drain down from full.
	if not _initialised:
		_initialised = true
		_display_current = _hp_pixels()
		_trail_current = _display_current

func _process(delta: float) -> void:
	if not _initialised:
		return

	var target: int = _hp_pixels()

	if target < _display_current:
		# Damage. The front bar snaps down and the trail is left behind.
		_display_current = target
		_set_trail_look(false)
		_drain_delay = 0.0
		_drain_timer = 0.0
		_is_healing = false
	elif target > _display_current:
		# Heal. The trail jumps ahead and the front bar grows into it.
		_trail_current = target
		_set_trail_look(true)
		if not _is_healing:
			_drain_delay = 0.0
			_drain_timer = 0.0
			_is_healing = true

	if _trail_current > _display_current:
		_drain_delay += delta
		if _drain_delay >= DRAIN_DELAY:
			_drain_timer += delta
			# A while loop, not an if, so a long frame still ticks the right
			# number of steps instead of falling behind.
			if _is_healing:
				while _drain_timer >= DRAIN_RATE and _display_current < _trail_current:
					_drain_timer -= DRAIN_RATE
					_display_current += 1
			else:
				while _drain_timer >= DRAIN_RATE and _trail_current > _display_current:
					_drain_timer -= DRAIN_RATE
					_trail_current -= 1
	else:
		_trail_current = _display_current
		_drain_timer = 0.0
		_drain_delay = 0.0

	bar.value = float(_display_current)
	trail.value = float(_trail_current)

	# Hidden at full health, but stays up until any trail animation has finished.
	var settled: bool = _display_current >= _fill_pixels and _trail_current <= _display_current
	var target_alpha: float = 0.0
	if _current_hp < _max_hp or not settled:
		target_alpha = 1.0

	if not is_equal_approx(_alpha, target_alpha):
		_alpha = move_toward(_alpha, target_alpha, delta / FADE)
		bar.modulate.a = _alpha
		label.modulate.a = _alpha

	if not is_equal_approx(_under_alpha, target_alpha):
		_under_alpha = move_toward(_under_alpha, target_alpha, delta / UNDER_FADE)
		trail.modulate.a = _under_alpha

func _hp_pixels() -> int:
	var px: int = roundi(float(_current_hp) / float(_max_hp) * float(_fill_pixels))
	# A living enemy should never read as completely empty.
	if _current_hp > 0:
		px = maxi(px, 1)
	return px

func _set_trail_look(healing: bool) -> void:
	if healing and heal_trail_texture != null:
		trail.texture_progress = heal_trail_texture
		trail.tint_progress = Color.WHITE
	elif healing:
		trail.texture_progress = _damage_texture
		trail.tint_progress = heal_trail_tint
	else:
		trail.texture_progress = _damage_texture
		trail.tint_progress = Color.WHITE


# TEMPORARY - delete after testing the heal trail.
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			get_parent().heal(5)
