extends PointLight2D

@export var flicker_speed: float = 10.0
@export var scale_variance: float = 0.006
@export var energy_variance: float = 0.1

var base_scale: float
var base_energy: float

func _ready() -> void:
	base_scale = texture_scale
	base_energy = energy

func _process(_delta: float) -> void:
	var t = Time.get_ticks_msec() * 0.001
	var noise_val = sin(t * flicker_speed) * 0.6 + sin(t * flicker_speed * 2.7) * 0.4
	texture_scale = base_scale + noise_val * scale_variance
	energy = base_energy + noise_val * energy_variance
