extends Node
class_name PlayerBattleTurn

# Things passed in from BattleManager.
var player: Node = null
var world_layer: TileMapLayer = null
var overlay: BattleOverlay = null
var combatants: Array = []

# State of everything.
var mp_budget: int = 0
var player_tile: Vector2i = Vector2i.ZERO
var cursor_tile: Vector2i = Vector2i.ZERO
var reachable: Dictionary = {}

# List of confirmed tiles The last one is the final waypoint.
var waypoints: Array = []
# The full path across all waypoint segments.
var full_path: Array = []
# MP spent by the path so far.
var path_cost: int = 0

const CURSOR_MOVE_RATE: float = 0.12
var cursor_move_timer: float = 0.0

# Emitted when the player ends their turn so BattleManager can advance.
signal turn_finished

func start(p_player: Node, p_world: TileMapLayer, p_overlay: BattleOverlay, p_combatants: Array, p_mp: int) -> void:
	player = p_player
	world_layer = p_world
	overlay = p_overlay
	combatants = p_combatants
	mp_budget = p_mp
	
	player_tile = world_layer.local_to_map(player.global_position)
	cursor_tile = player_tile
	
	_recalculate_reachable()
	_redraw()

func _physics_process(delta: float) -> void:
	cursor_move_timer -= delta
	if cursor_move_timer <= 0.0:
		var dir := Vector2i.ZERO
		if Input.is_action_pressed("ui_up"): dir.y -= 1
		if Input.is_action_pressed("ui_down"): dir.y += 1
		if Input.is_action_pressed("ui_left"): dir.x -= 1
		if Input.is_action_pressed("ui_right"): dir.x += 1
		if dir != Vector2i.ZERO:
			cursor_tile += dir
			cursor_move_timer = CURSOR_MOVE_RATE
			_redraw()
	
	if Input.is_action_just_pressed("interact"):
		_on_confirm()
	if Input.is_action_just_pressed("cancel"):
		_on_cancel()
	if Input.is_action_just_pressed("end_turn"):
		end_turn()
	# CONTINUE FROM ABOVE ^ This was the last thing you did!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	
func _recalculate_reachable() -> void:
	reachable = overlay.calculate_reachable(player_tile, mp_budget, world_layer)
	
func _redraw() -> void:
	overlay.clear_all()
	# Paint all reachable tiles soft green.
	overlay.paint_soft_green(reachable.keys())
	# Paint the cursor tile on top with the right colour.
	_paint_cursor()

func _paint_cursor() -> void:
	# Is Combatant on this tile? PURPLE.
	if _tile_has_combatant(cursor_tile):
		overlay.paint_purple(cursor_tile)
	# Reachable within budget? YELLOW.
	elif reachable.has(cursor_tile):
		overlay.paint_yellow(cursor_tile)
	# Not a wall but unreachable in budget? GREY.
	elif world_layer.get_cell_source_id(cursor_tile) == -1:
		overlay.paint_grey(cursor_tile)
	# Wall / blocked? RED.
	else:
		overlay.paint_red(cursor_tile)

func _tile_has_combatant(tile: Vector2i) -> bool:
	for c in combatants:
		if c == player:
			continue
		if world_layer.local_to_map(c.global_position) == tile:
			return true
	return false

func end_turn() -> void:
	overlay.clear_all()
	turn_finished.emit()
