extends Node
class_name BattleOverlay

# Reference to the combat_overlay TileMapLayer in the world scene.
var overlay_layer: TileMapLayer = null

# For AStarGrid.
const FINAL_WAYPOINT_COORDS := Vector2i(4, 7)

# Cost constants.
const COST_ORTHOGONAL: int = 2
const COST_DIAGONAL: int = 3

# The single-colour tiles' atlas coordinates in the tileset.
const SOURCE_ID: int = 0
const BRIGHT_GREEN_COORDS := Vector2i(0, 8)
const YELLOW_COORDS := Vector2i(1, 8)
const GREY_COORDS := Vector2i(2, 8)
const RED_COORDS := Vector2i(3, 8)
const PURPLE_COORDS := Vector2i(4, 8)
const LIGHT_BLUE_COORDS := Vector2i(3, 7)

# Terrain set and terrain indices for autotiled colours.
const TERRAIN_SET: int = 0
const SOFT_GREEN_TERRAIN: int = 0
const MID_GREEN_TERRAIN: int = 1

# Build an AStarGrid2D over the reachable region for pathfinding between waypoints
func find_path(from_tile: Vector2i, to_tile: Vector2i, world_layer: TileMapLayer, blocked_tiles: Array, mp_budget: int) -> Array:
	var astar := WeightedAStar.new()
	
	# Region origin is the top left corner of the region, region width is the size.
	var half_size: int = int(mp_budget / 2) + 10
	var region_origin := Vector2i(from_tile.x - half_size, from_tile.y - half_size)
	var region_width: int = half_size * 2
	
	# Adds all passable tiles as points by looping every tile in the above region.
	for x in range(region_origin.x, region_origin.x + region_width):
		for y in range(region_origin.y, region_origin.y + region_width):
			var t := Vector2i(x, y)
			if world_layer.get_cell_source_id(t) != -1:
				continue
			if t in blocked_tiles:
				continue
			var local := t - region_origin
			# Gives the tile a unique ID.
			var id: int = local.x * region_width + local.y
			astar.add_point(id, Vector2(t.x, t.y))
	
	# Connect adjacent passable tiles to the discovered tiles. We are doing the same loop again
	# so we can get the IDs of the tiles in the region.
	for x in range(region_origin.x, region_origin.x + region_width):
		for y in range(region_origin.y, region_origin.y + region_width):
			var t := Vector2i(x, y)
			if world_layer.get_cell_source_id(t) != -1:
				continue
			if t in blocked_tiles:
				continue
			var local := t - region_origin
			var id: int = local.x * region_width + local.y
			
			# Loops through all neighbours of the current tile, ignoring blockers and walls.
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var n := Vector2i(t.x + dx, t.y + dy)
					# Skip neighbours outside the search region, they were never added as points so
					# connecting to them would crash.
					if n.x < region_origin.x or n.x >= region_origin.x + region_width:
						continue
					if n.y < region_origin.y or n.y >= region_origin.y + region_width:
						continue
					if world_layer.get_cell_source_id(n) != -1:
						continue
					if n in blocked_tiles:
						continue
					# Touching-tips rule.
					if dx != 0 and dy != 0:
						var h := Vector2i(t.x + dx, t.y)
						var v := Vector2i(t.x, t.y + dy)
						var h_blocked: bool = world_layer.get_cell_source_id(h) != -1 or h in blocked_tiles
						var v_blocked: bool = world_layer.get_cell_source_id(v) != -1 or v in blocked_tiles
						if h_blocked and v_blocked:
							continue
					# Finds the ID of the neighbours and connects the two points (connect_points is
					# bidirectional, so works both ways).
					var n_local := n - region_origin
					var n_id: int = n_local.x * region_width + n_local.y
					astar.connect_points(id, n_id)
	
	# Calculates the IDs of the start and end tiles. If either wasn't added to the graph (because 
	# it's a wall or combatant), there is no possible path.
	var from_local := from_tile - region_origin
	var from_id: int = from_local.x * region_width + from_local.y
	var to_local := to_tile - region_origin
	var to_id: int = to_local.x * region_width + to_local.y
	

	if not astar.has_point(from_id) or not astar.has_point(to_id):
		return []
	
	# The actual pathfinding call.
	var path_vectors := astar.get_point_path(from_id, to_id)
	
	# Converts the coordinates back into Vector2i so that they can be used with the rest of the code
	# (as they rest uses ints, not floats).
	var result: Array = []
	for p in path_vectors:
		result.append(Vector2i(int(p.x), int(p.y)))
	return result

# Bresenham's line algorithm.
func get_line_tiles(from: Vector2i, to: Vector2i) -> Array:
	var tiles: Array = []
	var x: int = from.x
	var y: int = from.y
	var dx: int = abs(to.x - from.x)
	var dy: int = abs(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var err: int = dx - dy
	
	while true:
		tiles.append(Vector2i(x, y))
		if x == to.x and y == to.y:
			break
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
			
	return tiles

func path_mp_cost(path: Array) -> int:
	var total: int = 0
	for i in range(1, path.size()):
		var prev: Vector2i = path[i - 1]
		var curr: Vector2i = path[i]
		# How far the step moved on each axis. dx is horizontal change, dy is vertical change.
		# The abs() makes them positive since we only care about whether an axis changed, not which
		# direction. For a single tile step each will be either 0 or 1.
		var dx: int = abs(curr.x - prev.x)
		var dy: int = abs(curr.y - prev.y)
		if dx != 0 and dy != 0:
			total += COST_DIAGONAL
		else:
			total += COST_ORTHOGONAL
	return total

func paint_final_waypoint(tile: Vector2i) -> void:
	paint_single(tile, FINAL_WAYPOINT_COORDS)
	
func setup(layer: TileMapLayer) -> void:
	overlay_layer = layer

func clear_all() -> void:
	overlay_layer.clear()

func paint_soft_green(tiles: Array) -> void:
	overlay_layer.set_cells_terrain_connect(tiles, TERRAIN_SET, SOFT_GREEN_TERRAIN)

func paint_mid_green(tiles: Array) -> void:
	overlay_layer.set_cells_terrain_connect(tiles, TERRAIN_SET, MID_GREEN_TERRAIN)

func paint_single(tile: Vector2i, atlas_coords: Vector2i) -> void:
	overlay_layer.set_cell(tile, SOURCE_ID, atlas_coords)

func paint_bright_green(tile: Vector2i) -> void:
	paint_single(tile, BRIGHT_GREEN_COORDS)

func paint_yellow(tile: Vector2i) -> void:
	paint_single(tile, YELLOW_COORDS)

func paint_grey(tile: Vector2i) -> void:
	paint_single(tile, GREY_COORDS)

func paint_red(tile: Vector2i) -> void:
	paint_single(tile, RED_COORDS)

func paint_purple(tile: Vector2i) -> void:
	paint_single(tile, PURPLE_COORDS)
	
func paint_light_blue(tile: Vector2i) -> void:
	paint_single(tile, LIGHT_BLUE_COORDS)
	
# Calculates all tiles reachable from a starting tile within an MP budget. Returns a Dictionary
# mapping Vector2i tile -> int cost to reach.
func calculate_reachable(start_tile: Vector2i, mp_budget: int, world_layer: TileMapLayer, blocked_tiles: Array = []) -> Dictionary:
	var costs: Dictionary = {start_tile: 0}
	var frontier: Array = [start_tile]
	
	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = costs[current]
		
		# Checks all 8 neighbours.
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				
				var neighbour: Vector2i = Vector2i(current.x + dx, current.y + dy)
				var step_cost: int = COST_DIAGONAL if (dx != 0 and dy != 0) else COST_ORTHOGONAL
				var new_cost: int = current_cost + step_cost
				
				# Skips if over budget.
				if new_cost > mp_budget:
					continue
				
				# Skips if there's a wall.
				if world_layer.get_cell_source_id(neighbour) != -1:
					continue
					
				# Combatants block
				if neighbour in blocked_tiles:
					continue
				
				# Touching-tips rule
				if dx != 0 and dy != 0:
					var h_tile := Vector2i(current.x + dx, current.y)
					var v_tile := Vector2i(current.x, current.y + dy)
					var h_blocked: bool = world_layer.get_cell_source_id(h_tile) != -1 or h_tile in blocked_tiles
					var v_blocked: bool = world_layer.get_cell_source_id(v_tile) != -1 or v_tile in blocked_tiles
					if h_blocked and v_blocked:
						continue
				
				# Skips if already reached at lower cost
				if costs.has(neighbour) and costs[neighbour] <= new_cost:
					continue
				
				costs[neighbour] = new_cost
				frontier.append(neighbour)
	
	return costs
