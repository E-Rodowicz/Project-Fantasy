extends TileMapLayer

const SOURCE_ID: int = 0
const TERRAIN_SET: int = 0

func _ready() -> void:
	_dump_terrain_lookup(0, "SOFT_GREEN")
	_dump_terrain_lookup(1, "MID_GREEN")

func _dump_terrain_lookup(terrain_index: int, label: String) -> void:
	var source: TileSetAtlasSource = tile_set.get_source(SOURCE_ID) as TileSetAtlasSource
	if source == null:
		print("ERROR: source ", SOURCE_ID, " is not an atlas source.")
		return

	# One slot per possible neighbour combination. Filled with an obvious
	# sentinel so any gap is easy to spot in the output.
	var lookup: Array = []
	for i in range(16):
		lookup.append(Vector2i(-1, -1))

	for i in range(source.get_tiles_count()):
		var coords: Vector2i = source.get_tile_id(i)
		var data: TileData = source.get_tile_data(coords, 0)
		if data == null:
			continue
		if data.terrain_set != TERRAIN_SET:
			continue
		if data.terrain != terrain_index:
			continue

		var mask: int = 0
		if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == terrain_index:
			mask += 1
		if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == terrain_index:
			mask += 2
		if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == terrain_index:
			mask += 4
		if data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == terrain_index:
			mask += 8

		if lookup[mask] != Vector2i(-1, -1):
			print("WARNING: mask ", mask, " claimed twice - ", lookup[mask], " and ", coords)
		lookup[mask] = coords

	var output: String = "const " + label + "_LOOKUP: Array = [\n"
	var missing: int = 0
	for i in range(16):
		var entry: Vector2i = lookup[i]
		if entry == Vector2i(-1, -1):
			missing += 1
		output += "\tVector2i(" + str(entry.x) + ", " + str(entry.y) + "), # mask " + str(i) + "\n"
	output += "]"
	print(output)
	if missing > 0:
		print("WARNING: ", label, " has ", missing, " unfilled mask slots.")
