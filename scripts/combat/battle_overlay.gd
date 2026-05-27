extends Node
class_name BattleOverlay

# Reference to the combat_overlay TileMapLayer in the world scene.
var overlay_layer: TileMapLayer = null

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
