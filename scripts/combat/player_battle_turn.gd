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

# Gives the last waypoint, if nothing there, gives player position. This lets us move from that
# point.
func _path_origin() -> Vector2i:
	if waypoints.is_empty():
		return player_tile
	return waypoints.back()

# MP remaining after the chosen path.
func _remaining_mp() -> int:
	return mp_budget - path_cost
	
func _on_confirm() -> void:
	# If the cursor is on the final waypoint, execute move.
	if not waypoints.is_empty() and cursor_tile == waypoints.back():
		_execute_move()
		return
		
	# If that is not the case, tried to add a new waypoint where the cursor is.
	var blocked := _combatant_tiles()
	# This gets the amount that will be traversed. := means inferred value, so it gets that
	# something is an int if you give it a 5, and gets something is a float if you give it 5.0.
	# Here we declare a segment, and use our find_path function from the battle_overlay to get the
	# path we need (and the find_path function functions with the help of astargrid, but also does
	# other things, like look at the world_layer and checks for blocked tiles, remaining MP, etc).
	var segment := overlay.find_path(_path_origin(), cursor_tile, world_layer, blocked, _remaining_mp())
	
	# Invalid if there is no path or if the path doesnt go anywhere.
	if segment.size() < 2:
		return
		
	var segment_cost := overlay.path_mp_cost(segment)
	
	# Reject if it would exceed remaining MP.
	if segment_cost > _remaining_mp():
		return
		
	# Make the waypoint!
	waypoints.append(cursor_tile)
	# Append the segment minus its first tile. It duplicates the previous end point. This means
	# that the path is added on to what already exists instead of on top of it.
	if full_path.is_empty():
		full_path = segment.duplicate()
	else:
		# Every time a segment is added to the end of the current path (which is the latest
		# waypoint, the last waypoint), exactly one tile at its start overlaps with what's 
		# already in full_path, and it's always at index 0 of that new segment. So always  
		# skipping index 0 of the new segment is the right move, it just prevents overlap.
		for i in range(1, segment.size()):
			full_path.append(segment[i])
			
	path_cost += segment_cost	
	_recalculate_reachable()
	_redraw()
		
func _on_cancel() -> void:
	if waypoints.is_empty():
		return

	# Remove the last waypoint. Rebuild the path from the start. Note: pop_back() removes and
	# returns the last element of an array. pop_front removes and returns the first element.
	waypoints.pop_back()
	_rebuild_path()
	_recalculate_reachable()
	_redraw()

# Makes a new full_path and path_cost from the current waypoint array. It makes a whole new path
# from scratch as its just easier and less prone to errors. So it starts from the player tile,
# rebuilding a path to each waypoint. 
func _rebuild_path() -> void:
	full_path.clear()
	path_cost = 0
	var origin := player_tile
	var blocked := _combatant_tiles()
	for wp in waypoints:
		var segment := overlay.find_path(origin, wp, world_layer, blocked, mp_budget)
		if segment.size() < 2:
			continue
		if full_path.is_empty():
			full_path = segment.duplicate()
		else:
			# This is the same as on confirm, but since we clear the full path at the start of
			# this function, it builds the path from scratch.
			for i in range(1, segment.size()):
				full_path.append(segment[i])
		path_cost += overlay.path_mp_cost(segment)
		origin = wp
		
func _execute_move() -> void:
	# Just teleports the player for now.
	if not waypoints.is_empty():
		var dest: Vector2i = waypoints.back()
		# Note: Map to local means that you take a tiles cord and get the actual pixel position in
		# the world, of that tiles centre. Local to map does the opposite, and takes a world
		# position (Like Vector2 72,-56) and returns the tile which that falls in (Like Vector 2i
		# (4, -3)). Btw i in Vector2i stands for int, regular Vector2 holds floats. Vector2 is for
		# world position as pixels can be fractional, while Vector2i is an in because tiles are a
		# grid, they have no float in betweens. So, things the players sees, like animation, can
		# use floats, but since it is grid based the logic is entirly based on int.
		player.global_position = world_layer.map_to_local(dest)
	overlay.clear_all()
	turn_finished.emit()

func _recalculate_reachable() -> void:
	var blocked := _combatant_tiles()
	reachable = overlay.calculate_reachable(_path_origin(), _remaining_mp(), world_layer, blocked)
	
func _redraw() -> void:
	overlay.clear_all()
	# Paint all reachable tiles soft green.
	overlay.paint_soft_green(reachable.keys())
	# Mid green for commited path.
	if full_path.size() > 0:
		overlay.paint_mid_green(full_path)
	# Bright green for all waypoints except the final one.
	for i in range(waypoints.size()):
		if i < waypoints.size() - 1:
			overlay.paint_bright_green(waypoints[i])
	# The final waypoint.
	if not waypoints.is_empty():
		overlay.paint_final_waypoint(waypoints.back())
	# Paint the cursor tile on top with the right colour.
	_paint_cursor()

func _paint_cursor() -> void:
	# Prevents painting over final waypoint.
	if not waypoints.is_empty() and cursor_tile == waypoints.back():
		return
	# Is Combatant on this tile? PURPLE.
	if _tile_has_combatant(cursor_tile):
		overlay.paint_purple(cursor_tile)
	# Reachable within budget? YELLOW.
	elif reachable.has(cursor_tile):
		overlay.paint_yellow(cursor_tile)
	# Not a wall but unreachable in budget? GREY.
	elif world_layer.get_cell_source_id(cursor_tile) == -1:
		overlay.paint_grey(cursor_tile)
	# Wall/blocked? RED.
	else:
		overlay.paint_red(cursor_tile)

func _tile_has_combatant(tile: Vector2i) -> bool:
	for c in combatants:
		if c == player:
			continue
		if world_layer.local_to_map(c.global_position) == tile:
			return true
	return false

func _combatant_tiles() -> Array:
	var tiles: Array = []
	for c in combatants:
		if c == player:
			continue
		# Appends the position of the combatant.
		tiles.append(world_layer.local_to_map(c.global_position))
	return tiles

func end_turn() -> void:
	overlay.clear_all()
	turn_finished.emit()
