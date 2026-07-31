extends Node
class_name BattleOverlay

# Reference to the combat_overlay TileMapLayer in the world scene.
var overlay_layer: TileMapLayer = null

# Cost constants.
const COST_ORTHOGONAL: int = 2
const COST_DIAGONAL: int = 3

# The single-colour tiles' atlas coordinates in the tileset.
const SOURCE_ID: int = 0

# Every colour the overlay can draw. SOFT_GREEN and MID_GREEN are fills: they autotile against
# other tiles of the same colour. Everything else is a marker: a single fixed tile drawn on top of 
# the fill.
enum Colour {
	SOFT_GREEN,
	MID_GREEN,
	BRIGHT_GREEN,
	YELLOW,
	GREY,
	RED,
	PURPLE,
	LIGHT_BLUE,
}

# Mid green is laid out identically to soft green, four rows further down, so one table covers both.
const MID_GREEN_OFFSET: Vector2i = Vector2i(0, 4)

# Indexed by the 4-bit neighbour mask: north=1, east=2, south=4, west=8.
const FILL_LOOKUP: Array = [
	Vector2i(0, 0), # 0  - no neighbours
	Vector2i(3, 0), # 1  - N
	Vector2i(4, 0), # 2  - E
	Vector2i(4, 1), # 3  - N E
	Vector2i(1, 0), # 4  - S
	Vector2i(0, 1), # 5  - N S
	Vector2i(2, 1), # 6  - E S
	Vector2i(4, 2), # 7  - N E S
	Vector2i(2, 0), # 8  - W
	Vector2i(0, 2), # 9  - N W
	Vector2i(1, 1), # 10 - E W
	Vector2i(3, 2), # 11 - N E W
	Vector2i(3, 1), # 12 - S W
	Vector2i(2, 2), # 13 - N S W
	Vector2i(1, 2), # 14 - E S W
	Vector2i(0, 3), # 15 - all four
]

# What is currently on screen. Two parallel dictionaries: one holds each tile's colour, the other
# holds the atlas cell it resolved to. Keeping them apart lets the diff tell "this tile changed
# colour" from "this tile kept its colour but its border changed because a neighbour appeared" -
# which will need different animations later.
var _colour_state: Dictionary = {}
var _atlas_state: Dictionary = {}

# Fills and markers live in two sibling containers rather than being separated by z_index.
# Godot draws siblings in tree order, so the marker container going in second puts markers
# above fills - and because both sit at the tilemap layer's own depth, the overlay stays
# exactly where it was relative to characters and the floor.
const POOL_INITIAL_FILL: int = 512
const POOL_INITIAL_MARKER: int = 128

var _fill_root: Node2D = null
var _marker_root: Node2D = null
# Sprites that are built but not currently showing anything, kept per container so a
# sprite never has to be reparented.
var _fill_pool: Array = []
var _marker_pool: Array = []
# Vector2i tile -> the Sprite2D currently drawing it.
var _tile_sprites: Dictionary = {}
var _atlas_texture: Texture2D = null
var _tile_pixel_size: Vector2i = Vector2i(16, 16)

# --- ANIMATION VARS ---
# Animation timings. All short - this is interface feedback, not spectacle, and the cursor
# repeats every 0.12s so anything slower than that would smear.
const SPAWN_DURATION: float = 0.10
const DESPAWN_DURATION: float = 0.08
const TRANSITION_DURATION: float = 0.12
# Border changes on fills. Shorter than a full colour transition, since the two artworks
# differ only at the edges rather than entirely.
const RESTYLE_DURATION: float = 0.08
# Single tiles are snappier than the big fills so they never feel sluggish.
const MARKER_SPAWN_DURATION: float = 0.05
const MARKER_DESPAWN_DURATION: float = 0.05
const CURSOR_MOVE_DURATION: float = 0.07
const CURSOR_FADE_DURATION: float = 0.06

enum Anim { SPAWN, DESPAWN }

# A small inner class - a custom type that only exists inside this file. Using one instead
# of a Dictionary means the fields are typed and named at declaration, so a typo in a field
# name is a parse error rather than a silent null at runtime.
class TileAnim:
	var mode: int = Anim.SPAWN
	var elapsed: float = 0.0
	var delay: float = 0.0
	var duration: float = 0.0
	var is_marker: bool = false
	# Captured when the animation starts, so a despawn fades from wherever the sprite
	# actually was instead of jumping to full opacity on its first frame.
	var start_alpha: float = 1.0
	# False for the cursor, which is not pooled and must not be handed out to a tile.
	var release_to_pool: bool = true

# Sprite2D -> TileAnim. Keyed by sprite rather than by tile so that assigning a new
# animation for a sprite automatically cancels whatever it was doing before.
var _sprite_anims: Dictionary = {}

# The cursor is a single persistent sprite that slides, not a pooled tile that is destroyed
# and recreated, so it lives outside the diff entirely.
var _cursor_root: Node2D = null
var _cursor_sprite: Sprite2D = null
var _cursor_tile: Vector2i = Vector2i.ZERO
var _cursor_visible: bool = false
var _cursor_moving: bool = false
var _cursor_elapsed: float = 0.0
var _cursor_start_pos: Vector2 = Vector2.ZERO
var _cursor_target_pos: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
	_process_tile_anims(delta)
	_process_cursor(delta)

	# Go fully dormant once nothing is moving. Since there is no idle animation, this is
	# the state the overlay sits in almost all the time.
	if _sprite_anims.is_empty() and not _cursor_moving:
		set_process(false)

func _start_anim(sprite: Sprite2D, mode: int, duration: float, delay: float, is_marker: bool, release_to_pool: bool = true) -> void:
	var anim: TileAnim = TileAnim.new()
	anim.mode = mode
	anim.duration = duration
	anim.delay = delay
	anim.is_marker = is_marker
	anim.release_to_pool = release_to_pool
	anim.start_alpha = sprite.modulate.a
	# Assigning over any existing entry is what cancels the sprite's previous animation.
	_sprite_anims[sprite] = anim
	set_process(true)

func _region_for(atlas_coords: Vector2i) -> Rect2:
	return Rect2(Vector2(atlas_coords * _tile_pixel_size), Vector2(_tile_pixel_size))

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

# Shows the cursor at a tile, sliding it there if it is already on screen.
func set_cursor(tile: Vector2i, colour: int) -> void:
	var target: Vector2 = overlay_layer.map_to_local(tile)
	_cursor_sprite.region_rect = _region_for(_marker_atlas_coords(colour))

	if not _cursor_visible:
		# Appearing fresh, so snap into place and fade in rather than sliding from
		# wherever it happened to be left last time.
		_cursor_visible = true
		_cursor_moving = false
		_cursor_sprite.position = target
		_cursor_sprite.modulate.a = 0.0
		_cursor_sprite.visible = true
		_start_anim(_cursor_sprite, Anim.SPAWN, CURSOR_FADE_DURATION, 0.0, false, false)
	elif tile != _cursor_tile:
		# Start from where the sprite actually is, not from its last target, so
		# interrupting a slide continues smoothly instead of snapping backwards.
		_cursor_start_pos = _cursor_sprite.position
		_cursor_target_pos = target
		_cursor_elapsed = 0.0
		_cursor_moving = true
		set_process(true)

	_cursor_tile = tile

func get_cursor_position() -> Vector2:
	if not is_instance_valid(_cursor_sprite):
		return Vector2.ZERO
	return _cursor_sprite.position

func is_cursor_visible() -> bool:
	return _cursor_visible

func hide_cursor() -> void:
	if not _cursor_visible:
		return
	_cursor_visible = false
	_cursor_moving = false
	_start_anim(_cursor_sprite, Anim.DESPAWN, CURSOR_FADE_DURATION, 0.0, false, false)

# Distance from origin to every tile currently drawn. Shared by both delay builders. Must
# be called before commit, since it reads what is on screen right now.
func _build_distance_map(origin: Vector2i, costs: Dictionary) -> Dictionary:
	var distances: Dictionary = {}
	for tile in _colour_state:
		if costs.has(tile):
			distances[tile] = float(costs[tile])
		else:
			# Fallback for tiles the flood fill never reached - out of budget, or left over
			# from another mode. Chebyshev doubled to roughly match the 3/2 diagonal metric
			# the cost map uses, so the two do not run at visibly different speeds.
			distances[tile] = float(maxi(abs(tile.x - origin.x), abs(tile.y - origin.y))) * 2.0
	return distances

# Nearest tiles wait longest, so the field collapses inward toward origin.
func build_inward_delays(origin: Vector2i, step: float, costs: Dictionary = {}) -> Dictionary:
	var distances: Dictionary = _build_distance_map(origin, costs)
	var max_dist: float = 0.0
	for tile in distances:
		if distances[tile] > max_dist:
			max_dist = distances[tile]

	var delays: Dictionary = {}
	for tile in distances:
		# Inverted against the furthest tile, so the outer edge goes first.
		delays[tile] = (max_dist - distances[tile]) * step
	return delays

# Nearest tiles go first, so the field clears outward from origin - the same direction the
# replacement ripples in, so the two read as one wave rather than two events.
func build_outward_delays(origin: Vector2i, step: float, costs: Dictionary = {}) -> Dictionary:
	var distances: Dictionary = _build_distance_map(origin, costs)
	var delays: Dictionary = {}
	for tile in distances:
		delays[tile] = distances[tile] * step
	return delays

func _process_tile_anims(delta: float) -> void:
	# .keys() returns a fresh Array, a snapshot of the dictionary as it is right now. That
	# matters because finishing an animation erases from _sprite_anims, and mutating a
	# dictionary while iterating it directly is undefined behaviour.
	for sprite in _sprite_anims.keys():
		var anim: TileAnim = _sprite_anims[sprite]
		anim.elapsed += delta

		# Still waiting for its turn in the ripple.
		if anim.elapsed < anim.delay:
			continue

		# t is progress from 0 to 1. Everything below is expressed in terms of it, so
		# changing a duration constant never breaks the maths.
		var t: float = clampf((anim.elapsed - anim.delay) / anim.duration, 0.0, 1.0)

		match anim.mode:
			Anim.SPAWN:
				sprite.modulate.a = t
			Anim.DESPAWN:
				sprite.modulate.a = anim.start_alpha * (1.0 - t)

		if t >= 1.0:
			if anim.mode == Anim.DESPAWN:
				if anim.release_to_pool:
					# Only now is the sprite safe to reuse.
					_release_sprite(sprite, anim.is_marker)
				else:
					sprite.visible = false
					sprite.modulate.a = 1.0
					_sprite_anims.erase(sprite)
			else:
				sprite.modulate.a = 1.0
				_sprite_anims.erase(sprite)

func _process_cursor(delta: float) -> void:
	if not _cursor_moving:
		return
	_cursor_elapsed += delta
	var t: float = clampf(_cursor_elapsed / CURSOR_MOVE_DURATION, 0.0, 1.0)
	# Cubic ease-out: leaves fast, settles gently. Feels responsive rather than floaty.
	var eased: float = 1.0 - pow(1.0 - t, 3.0)
	var pos: Vector2 = _cursor_start_pos.lerp(_cursor_target_pos, eased)
	# Snap to whole pixels. A fractional position at 4x zoom reads as blur or jitter, so
	# the slide happens in discrete pixel steps instead.
	_cursor_sprite.position = Vector2(roundf(pos.x), roundf(pos.y))
	if t >= 1.0:
		_cursor_sprite.position = _cursor_target_pos
		_cursor_moving = false

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
	
func setup(layer: TileMapLayer) -> void:
	overlay_layer = layer

	# Pull the texture and tile size off the TileSet rather than hardcoding them, so the
	# atlas stays the single source of truth. The layer no longer draws anything itself.
	var source: TileSetAtlasSource = overlay_layer.tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	if source == null:
		push_error("BattleOverlay: source " + str(SOURCE_ID) + " is not a TileSetAtlasSource.")
		return
	_atlas_texture = source.texture
	_tile_pixel_size = overlay_layer.tile_set.tile_size

	# Wipe anything left on the layer, including cells placed in the editor. From here on
	# the layer is only a coordinate reference and a texture source.
	overlay_layer.clear()

	_fill_root = _create_root("OverlayFills")
	_marker_root = _create_root("OverlayMarkers")
	# Added last, so it draws above both.
	_cursor_root = _create_root("OverlayCursor")

	for i in range(POOL_INITIAL_FILL):
		_fill_pool.append(_create_sprite(false))
	for i in range(POOL_INITIAL_MARKER):
		_marker_pool.append(_create_sprite(true))

	_cursor_sprite = Sprite2D.new()
	_cursor_sprite.texture = _atlas_texture
	_cursor_sprite.region_enabled = true
	_cursor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor_sprite.use_parent_material = true
	_cursor_sprite.visible = false
	_cursor_root.add_child(_cursor_sprite)

	# Nothing is animating yet. _process is switched on only while animations are live.
	set_process(false)
func _create_root(root_name: String) -> Node2D:
	var root: Node2D = Node2D.new()
	root.name = root_name
	# The world scene is paused during battle, so without this the tile animations added
	# in Phase 4 would never tick. Set before add_child so no delta accumulates.
	root.process_mode = Node.PROCESS_MODE_ALWAYS

	# One material per container, shared by its sprites via use_parent_material. Unshaded
	# so CanvasModulate and Light2D leave the overlay alone - it is UI drawn in world
	# space, and it has to stay readable in an unlit room.
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	root.material = mat

	overlay_layer.add_child(root)
	return root

# The sprite containers are parented to the tilemap layer in the world scene, not to this
# node, so freeing this node would otherwise strand them there.
func _exit_tree() -> void:
	if is_instance_valid(_fill_root):
		_fill_root.queue_free()
	if is_instance_valid(_marker_root):
		_marker_root.queue_free()
	if is_instance_valid(_cursor_root):
		_cursor_root.queue_free()
	_fill_root = null
	_marker_root = null
	_cursor_root = null
	_cursor_sprite = null
	_fill_pool.clear()
	_marker_pool.clear()
	_tile_sprites.clear()
	_sprite_anims.clear()

func _create_sprite(is_marker: bool) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = _atlas_texture
	# region_enabled lets one sprite show a chosen rectangle of the atlas, so every tile
	# shares a single texture and swapping variant is just moving the rectangle.
	sprite.region_enabled = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.use_parent_material = true
	sprite.visible = false
	if is_marker:
		_marker_root.add_child(sprite)
	else:
		_fill_root.add_child(sprite)
	return sprite

func _acquire_sprite(is_marker: bool) -> Sprite2D:
	# Grow rather than fail if a pool runs dry. Costs one allocation, and only once, since
	# the sprite goes back into the pool afterwards.
	var pool: Array = _marker_pool if is_marker else _fill_pool
	if pool.is_empty():
		return _create_sprite(is_marker)
	return pool.pop_back()

func _apply_sprite(sprite: Sprite2D, tile: Vector2i, atlas_coords: Vector2i) -> void:
	# map_to_local gives the centre of the tile, and Sprite2D is centred by default, so
	# the two line up with no offset needed.
	sprite.position = overlay_layer.map_to_local(tile)
	sprite.region_rect = _region_for(atlas_coords)
	sprite.visible = true

func _release_sprite(sprite: Sprite2D, is_marker: bool) -> void:
	# Reset alpha on the way back into the pool so the next tile to borrow this sprite
	# does not inherit a half-faded state.
	_sprite_anims.erase(sprite)
	sprite.modulate.a = 1.0
	sprite.visible = false
	if is_marker:
		_marker_pool.append(sprite)
	else:
		_fill_pool.append(sprite)

func _is_marker(colour: int) -> bool:
	return colour != Colour.SOFT_GREEN and colour != Colour.MID_GREEN

func clear_all() -> void:
	hide_cursor()
	commit({}, {})
	
# The entry point for drawing tiles. Gets handed the desired state and works out the minimum amount
# of changes needed to get there.
func commit(fill_state: Dictionary, marker_state: Dictionary, spawn_delays: Dictionary = {}, despawn_delays: Dictionary = {}) -> void:
	var new_colour: Dictionary = {}
	var new_atlas: Dictionary = {}

	# Fills first without any markers on top.
	for tile in fill_state:
		var colour: int = fill_state[tile]
		new_colour[tile] = colour
		new_atlas[tile] = _fill_atlas_coords(tile, colour, fill_state)

	for tile in marker_state:
		var colour: int = marker_state[tile]
		new_colour[tile] = colour
		new_atlas[tile] = _marker_atlas_coords(colour)

	# Sort every tile into a bucket. These all do the same thing right now, but they will not once
	# animation goes in. They are seperate on purpose right now.
	var added: Array = []
	var recoloured: Array = []
	var restyled: Array = []
	var removed: Array = []

	for tile in new_colour:
		if not _colour_state.has(tile):
			added.append(tile)
		elif _colour_state[tile] != new_colour[tile]:
			recoloured.append(tile)
		elif _atlas_state[tile] != new_atlas[tile]:
			restyled.append(tile)
		# Otherwise identical - deliberately left alone.

	for tile in _colour_state:
		if not new_colour.has(tile):
			removed.append(tile)

	for tile in added:
		var is_marker: bool = _is_marker(new_colour[tile])
		var sprite: Sprite2D = _acquire_sprite(is_marker)
		_tile_sprites[tile] = sprite
		_apply_sprite(sprite, tile, new_atlas[tile])
		sprite.modulate.a = 0.0
		var dur: float = MARKER_SPAWN_DURATION if is_marker else SPAWN_DURATION
		# Absent from spawn_delays just means no ripple, not no fade.
		_start_anim(sprite, Anim.SPAWN, dur, spawn_delays.get(tile, 0.0), is_marker)

	for tile in recoloured:
		var sprite: Sprite2D = _tile_sprites[tile]
		var was_marker: bool = _is_marker(_colour_state[tile])
		var now_marker: bool = _is_marker(new_colour[tile])
		if was_marker != now_marker:
			# Crossing the fill/marker line means a different container, so one sprite
			# cannot do both halves. The outgoing sprite takes the incoming one's delay so
			# each tile hands over at its own moment in the ripple, rather than the whole
			# old layer vanishing before the new one starts arriving.
			var delay: float = spawn_delays.get(tile, 0.0)
			var out_dur: float = MARKER_DESPAWN_DURATION if was_marker else DESPAWN_DURATION
			_start_anim(sprite, Anim.DESPAWN, out_dur, delay, was_marker)
			sprite = _acquire_sprite(now_marker)
			_tile_sprites[tile] = sprite
			_apply_sprite(sprite, tile, new_atlas[tile])
			sprite.modulate.a = 0.0
			var in_dur: float = MARKER_SPAWN_DURATION if now_marker else SPAWN_DURATION
			_start_anim(sprite, Anim.SPAWN, in_dur, delay, now_marker)
		elif now_marker:
			# Markers snap. The ranged aim line recolours its whole length on every cursor
			# move, and dipping through transparent would strobe the blue underneath it.
			# Any in-flight fade is deliberately left running, so a tile recoloured while
			# still fading in carries on fading rather than popping to full.
			_apply_sprite(sprite, tile, new_atlas[tile])
		else:
			# Same container, so the same cross-fade the restyles use: old artwork fades
			# out while the new fades in over it, with no gap between.
			if _sprite_anims.has(sprite):
				_apply_sprite(sprite, tile, new_atlas[tile])
			else:
				_start_anim(sprite, Anim.DESPAWN, TRANSITION_DURATION, 0.0, now_marker)
				var new_sprite: Sprite2D = _acquire_sprite(now_marker)
				_tile_sprites[tile] = new_sprite
				_apply_sprite(new_sprite, tile, new_atlas[tile])
				new_sprite.modulate.a = 0.0
				_start_anim(new_sprite, Anim.SPAWN, TRANSITION_DURATION, 0.0, now_marker)

	for tile in restyled:
		var old_sprite: Sprite2D = _tile_sprites[tile]
		var is_marker: bool = _is_marker(new_colour[tile])
		# A sprite still mid-fade has no stable alpha to cross-fade from, and stacking a
		# second fade on top of an unfinished one compounds the transparency. Correct the
		# artwork and let the animation in progress finish against it instead.
		if _sprite_anims.has(old_sprite):
			_apply_sprite(old_sprite, tile, new_atlas[tile])
		else:
			# Old artwork fades out where it is, and releases itself to the pool when done.
			_start_anim(old_sprite, Anim.DESPAWN, RESTYLE_DURATION, 0.0, is_marker)
			# New artwork fades in over the top. The tile now points at this one.
			var new_sprite: Sprite2D = _acquire_sprite(is_marker)
			_tile_sprites[tile] = new_sprite
			_apply_sprite(new_sprite, tile, new_atlas[tile])
			new_sprite.modulate.a = 0.0
			_start_anim(new_sprite, Anim.SPAWN, RESTYLE_DURATION, 0.0, is_marker)

	for tile in removed:
		# Not released yet - the sprite stays checked out of the pool until its fade
		# finishes, or it would be handed to another tile mid-animation.
		var was_marker: bool = _is_marker(_colour_state[tile])
		var dur: float = MARKER_DESPAWN_DURATION if was_marker else DESPAWN_DURATION
		_start_anim(_tile_sprites[tile], Anim.DESPAWN, dur, despawn_delays.get(tile, 0.0), was_marker)
		_tile_sprites.erase(tile)

	_colour_state = new_colour
	_atlas_state = new_atlas
	 
# Builds the 4-bit neighbour mask for one fill tile and returns the atlas cell for it.
func _fill_atlas_coords(tile: Vector2i, colour: int, fill_state: Dictionary) -> Vector2i:
	# get() with a default of -1 covers both "no tile there" and "a tile of a different
	# colour" in one check, since -1 can never match a Colour value.
	var mask: int = 0
	if fill_state.get(tile + Vector2i(0, -1), -1) == colour:
		mask += 1
	if fill_state.get(tile + Vector2i(1, 0), -1) == colour:
		mask += 2
	if fill_state.get(tile + Vector2i(0, 1), -1) == colour:
		mask += 4
	if fill_state.get(tile + Vector2i(-1, 0), -1) == colour:
		mask += 8

	var coords: Vector2i = FILL_LOOKUP[mask]
	if colour == Colour.MID_GREEN:
		coords += MID_GREEN_OFFSET
	return coords

func _marker_atlas_coords(colour: int) -> Vector2i:
	match colour:
		Colour.BRIGHT_GREEN:
			return Vector2i(0, 8)
		Colour.YELLOW:
			return Vector2i(1, 8)
		Colour.GREY:
			return Vector2i(2, 8)
		Colour.RED:
			return Vector2i(3, 8)
		Colour.PURPLE:
			return Vector2i(4, 8)
		Colour.LIGHT_BLUE:
			return Vector2i(2, 7)
	return Vector2i(0, 8)
	
# Calculates all tiles reachable from a starting tile within an MP budget. Returns a Dictionary
# mapping Vector2i tile -> int cost to reach. If bounds is given, the search never expands outside
# it, so off-screen tiles are never explored or stored.
func calculate_reachable(start_tile: Vector2i, mp_budget: int, world_layer: TileMapLayer, blocked_tiles: Array = [], bounds: Rect2i = Rect2i()) -> Dictionary:
	# A default Rect2i has zero size, which is how we detect "no bounds given".
	var use_bounds: bool = bounds.size.x > 0 and bounds.size.y > 0

	var costs: Dictionary = {start_tile: 0}
	var frontier: Array = [start_tile]

	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = costs[current]

		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue

				var neighbour: Vector2i = Vector2i(current.x + dx, current.y + dy)

				# Cut off-screen tiles first, before any other work. Because this skips adding them 
				# to the frontier, the whole branch beyond them is pruned too, not just the single
				# tile.
				if use_bounds and not bounds.has_point(neighbour):
					continue

				var step_cost: int = COST_DIAGONAL if (dx != 0 and dy != 0) else COST_ORTHOGONAL
				var new_cost: int = current_cost + step_cost

				if new_cost > mp_budget:
					continue

				if world_layer.get_cell_source_id(neighbour) != -1:
					continue

				if neighbour in blocked_tiles:
					continue

				if dx != 0 and dy != 0:
					var h_tile: Vector2i = Vector2i(current.x + dx, current.y)
					var v_tile: Vector2i = Vector2i(current.x, current.y + dy)
					var h_blocked: bool = world_layer.get_cell_source_id(h_tile) != -1 or h_tile in blocked_tiles
					var v_blocked: bool = world_layer.get_cell_source_id(v_tile) != -1 or v_tile in blocked_tiles
					if h_blocked and v_blocked:
						continue

				if costs.has(neighbour) and costs[neighbour] <= new_cost:
					continue

				costs[neighbour] = new_cost
				frontier.append(neighbour)

	return costs
