extends Node
class_name CombatantTurn

# # Who is being controlled this turn. Replaces the old "player" var.
var combatant: Node = null
var world_layer: TileMapLayer = null
var overlay: BattleOverlay = null
var combatants: Array = []
# When true, AI makes decisions. When false, human uses the cursor.
var ai_controlled: bool = false
var animating: bool = false
var attacks_remaining: int = 1

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

# Attack state. mode switches the turn between planning movement and aiming an attack.
enum Mode { MOVE, ATTACK }
var mode: int = Mode.MOVE

# The tiles the current attack can reach (the 8 around the player for a basic attack).
var attack_range_tiles: Array = []
# The tile the player has chosen to hit (only meaningful while has_target is true).
var attack_target: Vector2i = Vector2i.ZERO
# True once the first E has locked a target, waiting for the second E to confirm.
var has_target: bool = false

# PLACEHOLDER damage until the weapon/affinity damage from the combat doc exists.
const BASIC_ATTACK_RANGE: int = 1
const BASIC_ATTACK_DAMAGE: int = 5

const CURSOR_MOVE_RATE: float = 0.12
var cursor_move_timer: float = 0.0

# Emitted when the player ends their turn so BattleManager can advance.
signal turn_finished

func start(p_combatant: Node, p_world: TileMapLayer, p_overlay: BattleOverlay, p_combatants: Array, p_mp: int, p_ai: bool = false) -> void:
	combatant = p_combatant
	world_layer = p_world
	overlay = p_overlay
	combatants = p_combatants
	mp_budget = p_mp
	ai_controlled = p_ai
	
	player_tile = world_layer.local_to_map(combatant.global_position)
	cursor_tile = player_tile
	
	_recalculate_reachable()
	
	if ai_controlled:
		# When a function uses await, it pauses at that line and lets the rest of the game keep
		# running. When the thing its waiting for finishes, so in this case the tween, it continues
		# where it left of.
		await _run_ai()
	else:
		_redraw()

func _physics_process(delta: float) -> void:
	if ai_controlled:
		return
	if animating:
		return
	# Cursor movement is the same in both modes.
	cursor_move_timer -= delta
	if cursor_move_timer <= 0.0:
		var dir := Vector2i.ZERO
		if Input.is_action_pressed("ui_up"): dir.y -= 1
		if Input.is_action_pressed("ui_down"): dir.y += 1
		if Input.is_action_pressed("ui_left"): dir.x -= 1
		if Input.is_action_pressed("ui_right"): dir.x += 1
		if dir != Vector2i.ZERO:
			if mode == Mode.ATTACK:
				# In attack mode the cursor snaps to whichever attack tile
				# is in the pressed direction relative to the player. If there
				# is no valid tile that way (e.g. a wall), it stays put.
				var wanted := player_tile + dir
				# Checks the attack range and if the cursor is on screen.
				if wanted in attack_range_tiles and _is_tile_on_screen(wanted):
					cursor_tile = wanted
					has_target = false
				cursor_move_timer = CURSOR_MOVE_RATE
			else:
				var new_tile := cursor_tile + dir
				if _is_tile_on_screen(new_tile):
					cursor_tile = new_tile
				cursor_move_timer = CURSOR_MOVE_RATE
			_redraw()
	
	# End turn works from either mode.
	if Input.is_action_just_pressed("end_turn"):
		end_turn()
		return
	
	if mode == Mode.MOVE:
		if Input.is_action_just_pressed("ability_1"):
			_enter_attack_mode()
		elif Input.is_action_just_pressed("interact"):
			_on_confirm()
		elif Input.is_action_just_pressed("cancel"):
			_on_cancel()
	else: # Mode.ATTACK
		if Input.is_action_just_pressed("interact"):
			_on_attack_confirm()
		elif Input.is_action_just_pressed("cancel"):
			_on_attack_cancel()
		elif Input.is_action_just_pressed("ability_1"):
			# Pressing 1 again backs out of attack mode.
			_exit_attack_mode()

func _is_tile_on_screen(tile: Vector2i) -> bool:
	# Converts the tile to its world position.
	var world_pos := world_layer.map_to_local(tile)
	
	# Get the viewport and camera.
	var viewport := combatant.get_viewport()
	
	# Converts world position to screen position. The canvas transform does this. This is a matrix
	# (another word for transforms) that is interal to Godot, which changes world coords to screen
	# pixel coords. It accounts for the camera's position, zoom, rotation, everything. So you
	# multiply it by a world position and get back where that point appears on screen. Don't ask me
	# about the maths, but basically this is saying: "take this world position, apply the camera's
	# scroll and zoom to it, and give me back where it appears on screen in pixels." The * is not a
	# regular multiplication, it is a transfor multiplication. It is a forumla with multiple steps,
	# (for example, converting fahrenheit to celsius is temp * 9/5 + 32). Its first a conversion
	# scale, then it applies the offset. This does the same for the 2D coordiantes. As in, that's
	# what the * does in this case.
	var screen_pos := viewport.get_canvas_transform() * world_pos
	
	# Get the viewport size (Adapts to aspect ratio changes!). This gives the actual screen
	# dimension in pixels, so it would be Vector2(1920, 1080) for example.
	var screen_size := viewport.get_visible_rect().size
	
	# Add margin so the cursor doesnt go to the pixel edge. The margin is -8 to account for the fact
	# that the viewport counts from the centre of the tile, which is 8 pixels off. Making the margin
	# -8 ensures that the max you are able to go out of bounds of the screen is -8 pixels, meaning 
	# the cursor can go to the very edges of the screen but not past the edges. 
	var margin := -8.0

	# Screen coords starts at 0,0 in the top left corner. In the most popular resolution, the
	# bottom right corner of the screen would be 1920,1080. Read on under the returns checks for
	# more info...
	return (
		# "is the tile far enough from the left edge?" If margin is 32, the tile must be at least
		# 32 pixels from the left.
		screen_pos.x >= margin
		#"is the tile far enough from the right edge?" On a 1920-wide screen with margin 32, the
		# tile must be at pixel 1888 or less.
		and screen_pos.x <= screen_size.x - margin
		# Same thing but for the top edge.
		and screen_pos.y >= margin
		# And bottom edge.
		and screen_pos.y <= screen_size.y - margin
		# Clarifying example if the screen was 1920x1080 and margin 32 (names changed to values):
		# return (
		#     screen_pos.x >= 32
		#     and screen_pos.x <= 1888
		#     and screen_pos.y >= 32
		#     and screen_pos.y <= 1048
		# )
		# So the current screen (cursor) position for x must be between 32 and 1888, and for y
		# between 32 and 1048
	)

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
		await _execute_move()
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
		# Above is a left over from when I used map_to_local as I was bascially teleporting the
		# combatants.
		animating = true
		await _animate_movement(full_path)
		animating = false
		player_tile = dest
	
	# Take away the MP used.
	mp_budget -= path_cost
	
	# Clear the path and waypoints, move is done.
	waypoints.clear()
	full_path.clear()
	path_cost = 0
	
	# Reset the cursor to the new position.
	cursor_tile = player_tile
	
	# Recalculate the reachables with the remaining MP amount.
	_recalculate_reachable()
	_redraw()

func _recalculate_reachable() -> void:
	var blocked := _combatant_tiles()
	reachable = overlay.calculate_reachable(_path_origin(), _remaining_mp(), world_layer, blocked)
	
func _redraw() -> void:
	if not BattleManager.active:
		return
	overlay.clear_all()
	if mode == Mode.ATTACK:
		_redraw_attack()
		return
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
	if cursor_tile == player_tile:
		overlay.paint_grey(cursor_tile)
	# Is Combatant on this tile? PURPLE.
	elif _tile_has_combatant(cursor_tile):
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
		if c == combatant:
			continue
		if world_layer.local_to_map(c.global_position) == tile:
			return true
	return false

func _combatant_tiles() -> Array:
	var tiles: Array = []
	for c in combatants:
		if c == combatant:
			continue
		# Appends the position of the combatant.
		tiles.append(world_layer.local_to_map(c.global_position))
	return tiles
	
# ============================================================
# ATTACK
# ============================================================

# Switch from movement planning into attack aiming.
func _enter_attack_mode() -> void:
	if attacks_remaining <= 0:
		return
	# Abandon any half-planned movement; choosing to attack is a different action.
	waypoints.clear()
	full_path.clear()
	path_cost = 0
	
	mode = Mode.ATTACK
	has_target = false
	_build_attack_range()
	
	# Snap the cursor onto the first adjacent enemy if there is one, so the common
	# "one enemy right next to me" case is just: press 1, E, E.
	cursor_tile = player_tile
	for t in attack_range_tiles:
		if _tile_has_combatant(t):
			cursor_tile = t
			break
	_redraw()

# Back out of attack mode, returning to movement planning.
func _exit_attack_mode() -> void:
	mode = Mode.MOVE
	has_target = false
	attack_range_tiles.clear()
	cursor_tile = player_tile
	_recalculate_reachable()
	_redraw()

# Build the tiles a basic attack can reach: the 8 around the player. Walls are skipped
# so the highlight stays clean (you can't melee into a wall).
func _build_attack_range() -> void:
	attack_range_tiles.clear()
	for dx in range(-BASIC_ATTACK_RANGE, BASIC_ATTACK_RANGE + 1):
		for dy in range(-BASIC_ATTACK_RANGE, BASIC_ATTACK_RANGE + 1):
			if dx == 0 and dy == 0:
				continue
			var t := player_tile + Vector2i(dx, dy)
			if world_layer.get_cell_source_id(t) != -1:
				continue
			attack_range_tiles.append(t)

# First E chooses a target, second E (without moving) confirms and resolves it.
func _on_attack_confirm() -> void:
	if not has_target:
		# First press: only valid if the cursor is on an in-range tile that has an enemy.
		if cursor_tile in attack_range_tiles and _tile_has_combatant(cursor_tile):
			attack_target = cursor_tile
			has_target = true
			_redraw()
		return
	# Second press: the cursor is guaranteed to still be on the target (moving clears
	# has_target), so resolve the attack.
	_execute_attack()

# Cancel (Q): first unlocks the target; if there's nothing to unlock, leaves attack mode.
func _on_attack_cancel() -> void:
	if has_target:
		has_target = false
		_redraw()
	else:
		_exit_attack_mode()

# Apply the damage and end the turn.
func _execute_attack() -> void:
	var target := _combatant_on_tile(attack_target)
	if target == null:
		# Safety net; we only ever lock onto occupied tiles, so this shouldn't fire.
		_exit_attack_mode()
		return
	_apply_damage(target, BASIC_ATTACK_DAMAGE)
	attacks_remaining -= 1
	# Goes to move mode.
	_exit_attack_mode()

# Deals damage to whoever is on the tile. Player HP lives on the PlayerData autoload,
# enemies track their own HP on their node, so we branch on the group.
func _apply_damage(target: Node, amount: int) -> void:
	if target.is_in_group("player"):
		PlayerData.take_damage(amount)
		print("Player took ", amount, " damage. HP now ", PlayerData.current_hp, "/", PlayerData.max_hp)
		if PlayerData.current_hp <= 0:
			BattleManager.remove_combatant(target)
	else:
		# The enemy node handles its own HP and death (removing itself from the
		# battle and freeing itself when it hits 0).
		target.take_damage(amount)

# Returns the combatant node standing on a tile, or null. Skips the player so you
# can never target yourself.
func _combatant_on_tile(tile: Vector2i) -> Node:
	for c in combatants:
		if c == combatant:
			continue
		if world_layer.local_to_map(c.global_position) == tile:
			return c
	return null

# Draws the attack overlay: the whole range in red, the hover/target state on top.
func _redraw_attack() -> void:
	if has_target:
		overlay.paint_bright_green(attack_target)
		return
	# Only the cursor tile is highlighted: purple if an enemy is there, red if empty.
	if _tile_has_combatant(cursor_tile):
		overlay.paint_purple(cursor_tile)
	else:
		overlay.paint_red(cursor_tile)

func end_turn() -> void:
	overlay.clear_all()
	turn_finished.emit()
	
## AI LOGIC ##
func _run_ai() -> void:
	var target := _find_nearest_target()
	if target == null:
		turn_finished.emit()
		return
		
	var target_tile := world_layer.local_to_map(target.global_position)
	
	# If someone is adjescent, attack and end turn.
	if _is_adjacent(player_tile, target_tile):
		if attacks_remaining > 0:
			_apply_damage(target, BASIC_ATTACK_DAMAGE)
			attacks_remaining -= 1
		turn_finished.emit()
		return
		
	# Find the best tile to move to.
	var destination := _find_best_move(target_tile)
	
	if destination != player_tile:
		var blocked := _combatant_tiles()
		var path := overlay.find_path(player_tile, destination, world_layer, blocked, mp_budget)
		# For now it just teleports to the destination. Later we can use the path var above to add
		# animation.
		await _animate_movement(path)
		player_tile = destination
		# This takes away the cost of the move to that tile from the mp_budget. "reachable" checks
		# the cost ad "destination" is the tile it uses to calculate that cost.
		mp_budget -= reachable[destination]
		
	# After moving, it checks if target is adjacent and attacks.
	if _is_adjacent(player_tile, target_tile) and attacks_remaining > 0:
		_apply_damage(target, BASIC_ATTACK_DAMAGE)
		attacks_remaining -= 1
	
	turn_finished.emit()
	
func _find_nearest_target() -> Node:
	var best_target: Node = null
	var best_distance: float = 999999.0
	
	for c in combatants:
		if c == combatant:
			continue
		# Melee behaviour targets players and allies.
		if c.is_in_group("player") or c.is_in_group("ally"):
			var c_tile := world_layer.local_to_map(c.global_position)
			var dist := _tile_distance(player_tile, c_tile)
			if dist < best_distance:
				best_distance = dist
				best_target = c
				
	return best_target
	
func _find_best_move(target_tile: Vector2i) -> Vector2i:
	# First it tries to reach a tile adjacent to the target.
	var adjacent := _get_adjacent_tiles(target_tile)
	var best_tile: Vector2i = player_tile
	var best_cost: int = 999999
	
	for tile in adjacent:
		if reachable.has(tile) and reachable[tile] < best_cost:
			best_tile = tile
			best_cost = reachable[tile]
			
		if best_tile != player_tile:
			return best_tile
			
	# If ye can't reach the target, finds a real path using a huge amount of fake MP to get the
	# full route around the walls/obsticles.
	var blocked := _combatant_tiles()
	blocked.erase(target_tile)
	var search_budget: int = int(_tile_distance(player_tile, target_tile))
	var path := overlay.find_path(player_tile, target_tile, world_layer, blocked, search_budget)
				
	if path.is_empty():
		return player_tile
		
	# Walks along the path as far as real MP allows.
	var furthest: Vector2i = player_tile
	for tile in path:
		if reachable.has(tile):
			furthest = tile
			
	return furthest

func _get_adjacent_tiles(tile: Vector2i) -> Array:
	var tiles: Array = []
	for dx in range(-BASIC_ATTACK_RANGE, BASIC_ATTACK_RANGE + 1):
		for dy in range(-BASIC_ATTACK_RANGE, BASIC_ATTACK_RANGE + 1):
			if dx == 0 and dy == 0:
				continue
			var t := tile + Vector2i(dx, dy)
			if world_layer.get_cell_source_id(t) != -1:
				continue
			tiles.append(t)
	return tiles
	
func _is_adjacent(from: Vector2i, to: Vector2i) -> bool:
	return from != to and abs(from.x - to.x) <= BASIC_ATTACK_RANGE and abs(from.y - to.y) <= BASIC_ATTACK_RANGE
	
func _tile_distance(a: Vector2i, b: Vector2i) -> float:
	var dx: float = abs(a.x - b.x)
	var dy: float = abs(a.y - b.y)
	var mn: float = min(dx, dy)
	var mx: float = max(dx, dy)
	return mn * 3.0 + (mx - mn) * 2.0

func _animate_movement(path: Array) -> void:
	# Create a tween for the combatant.
	var tween := combatant.create_tween()
	
	# For each tile in the path (Skipping the first (0) as that's where we start).
	for i in range(1, path.size()):
		var world_pos := world_layer.map_to_local(path[i])
		# This bascially means move from your global position to world_pos (next part of path) in
		# 0.07 seconds.
		tween.tween_property(combatant, "global_position", world_pos, 0.1)
	
	# Wait for the tween to finish before continuing.
	await tween.finished
