extends CharacterBody2D

signal battle_started(enemy, player)

@export var vision_radius: float = 80.0

var player_in_range: bool = false
var player_ref: Node2D = null
var battle_triggered: bool = false

@onready var vision_area = $vision_area

func _ready() -> void:
	vision_area.body_entered.connect(_on_body_entered)
	vision_area.body_exited.connect(_on_body_exited)
	print("Enemy ready, vision area: ", vision_area)

func _physics_process(_delta: float) -> void:
	if player_in_range and player_ref and not battle_triggered:
		print("Checking line of sight...")
		if _has_line_of_sight():
			battle_triggered = true
			print("Battle started!")
			emit_signal("battle_started", self, player_ref)

func _on_body_entered(body: Node2D) -> void:
	print("Body entered vision: ", body.name, " groups: ", body.get_groups())
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null

func _has_line_of_sight() -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		player_ref.global_position
	)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	print("Ray hit: ", result.get("collider", "nothing"))
	return result.is_empty()
