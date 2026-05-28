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

# Terrain set and terrain indices for autotiled colours.
const TERRAIN_SET: int = 0
const SOFT_GREEN_TERRAIN: int = 0
const MID_GREEN_TERRAIN: int = 1

# Build an AStarGrid2D over the reachable region for pathfinding between waypoints
func find_path(from_tile: Vector2i, to_tile: Vector2i, world_layer: TileMapLayer, blocked_tiles: Array, mp_budget: int) -> Array:
	var astar := AStarGrid2D.new()
	
	# Determine the bounds of the region to search with a start grid by using the MP amount.
	var half_size: int = int(mp_budget / 2) + 10
	astar.region = Rect2i(
		from_tile.x - half_size, from_tile.y - half_size,
		half_size * 2, half_size * 2
	)
	
	# Sets astar cell size to match the game.
	astar.cell_size = Vector2(16, 16)
	# Stops the touching tips scenario from happening.
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	# This is a guess as to how far a tile is from the goal, this guides the search.
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	# This updates the settings above and builds the grid.
	astar.update()
	
	# Marks walls and blocked tiles as solid. Loops every tile in the region and checks the world
	# layer. If there's a wall there (!= -1 means a tile exists), it marks that grid point as solid
	# so paths route around it.
	for x in range(astar.region.position.x, astar.region.end.x):
		for y in range(astar.region.position.y, astar.region.end.y):
			var t := Vector2i(x, y)
			if world_layer.get_cell_source_id(t) != -1:
				astar.set_point_solid(t, true)
	
	# Makes sure combatants are also solid.
	for t in blocked_tiles:
		if astar.is_in_boundsv(t):
			astar.set_point_solid(t, true)
			
	# Diagonal and orthogonal cost.
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	
	if not astar.is_in_boundsv(from_tile) or not astar.is_in_boundsv(to_tile):
		return []
	# Stops pathing to solid tile.
	if astar.is_point_solid(to_tile):
		return []
	
	# This gets the results of calcualted path and returns them as "path".
	var path := astar.get_id_path(from_tile, to_tile)
	return path
	
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
	
# Calculates all tiles reachable from a starting tile within an MP budget. Returns a Dictionary
# mapping Vector2i tile -> int cost to reach.
func calculate_reachable(start_tile: Vector2i, mp_budget: int, world_layer: TileMapLayer) -> Dictionary:
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
				
				# Skips if already reached at lower cost
				if costs.has(neighbour) and costs[neighbour] <= new_cost:
					continue
				
				costs[neighbour] = new_cost
				frontier.append(neighbour)
	
	return costs
