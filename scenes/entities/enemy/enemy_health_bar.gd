class_name EnemyHealthBar
extends Node2D

# Trail timing, matched to the player HUD so both bars feel the same.
const DRAIN_RATE: float = 0.04    # seconds per 1% of trail movement
const DRAIN_DELAY: float = 0.4    # pause before the trail starts chasing
const FADE: float = 0.15          # fade in / out of the whole bar

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

# Both counters are percentages, 0-100, exactly like the player HUD.
var _display_current: int = 100
var _trail_current: int = 100
var _drain_timer: float = 0.0
var _drain_delay: float = 0.0
var _is_healing: bool = false

var _alpha: float = 0.0
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

	# Counting in whole pixels means the fill edge can never land on a fraction.
	for progress_bar in [bar, trail]:
		progress_bar.min_value = 0.0
		progress_bar.max_value = float(_fill_pixels)
		progress_bar.step = 1.0

	# Centre all three children on the node's own origin.
	bar.position.x = -roundf(bar.size.x * bar.scale.x * 0.5)
	trail.position.x = -roundf(trail.size.x * trail.scale.x * 0.5)
	label.position.x = -roundf(label.size.x * label.scale.x * 0.5)

	modulate.a = 0.0

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
		_display_current = _percent()
		_trail_current = _display_current

func _process(delta: float) -> void:
	if not _initialised:
		return

	var target: int = _percent()

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

	bar.value = _to_pixels(_display_current)
	trail.value = _to_pixels(_trail_current)

	# Hidden at full health, but stays up until any trail animation has finished.
	var settled: bool = _display_current >= 100 and _trail_current <= _display_current
	var target_alpha: float = 0.0
	if _current_hp < _max_hp or not settled:
		target_alpha = 1.0

	if not is_equal_approx(_alpha, target_alpha):
		_alpha = move_toward(_alpha, target_alpha, delta / FADE)
		modulate.a = _alpha

func _percent() -> int:
	return roundi(float(_current_hp) / float(_max_hp) * 100.0)

func _to_pixels(percent: int) -> float:
	var px: float = roundf(float(percent) / 100.0 * float(_fill_pixels))
	# A living enemy should never read as completely empty.
	if percent > 0:
		px = maxf(px, 1.0)
	return px

func _set_trail_look(healing: bool) -> void:
	var custom: Texture2D = heal_trail_texture if healing else damage_trail_texture
	if custom != null:
		trail.texture_progress = custom
		trail.modulate = Color.WHITE
	else:
		trail.texture_progress = _fill_texture
		trail.modulate = heal_trail_tint if healing else damage_trail_tint
