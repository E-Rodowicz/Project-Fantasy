class_name CleaveAbility
extends BaseAbility

func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var tiles: Array = []
	var half: int = data.get("range", 3) / 2
	var front: Vector2i = player_tile + direction
	var perp: Vector2i = Vector2i(-direction.y, direction.x)
	
	# If the centre tile is a wall, nothing is valid.
	if world_layer.get_cell_source_id(front) != -1:
		return tiles
	tiles.append(front)
	
	# Expand outward in one direction, stop at walls.
	for i in range(1, half + 1):
		var tile: Vector2i = front + perp * i
		if world_layer.get_cell_source_id(tile) != -1:
			break
		tiles.append(tile)
	
	# Expand outward in the other direction, stop at walls.
	for i in range(1, half + 1):
		var tile: Vector2i = front + perp * -i
		if world_layer.get_cell_source_id(tile) != -1:
			break
		tiles.append(tile)
	
	return tiles

func execute(caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	var damage_percent: float = data.get("damage_percent", 0.5)
	
	var weapon: Dictionary = PlayerData.get_equipped_weapon()
	var dismember_chance: float = 0.0
	if not weapon.is_empty():
		if weapon.get("handed") == "two":
			dismember_chance = data.get("dismember_two_hand", 0.05)
		else:
			dismember_chance = data.get("dismember_one_hand", 0.025)
	
	for tile in tiles:
		var target: Node = combatant_on_tile(tile, all_combatants, world_layer)
		if target == null or target == caster:
			continue
		
		# Dismember check.
		if randf() < dismember_chance:
			CombatLog.add(target.name + " is dismembered!")
			if target.is_in_group("player"):
				PlayerData.take_damage(PlayerData.max_hp)
			else:
				target.take_damage(target.stats.get_max_hp())
			continue
		
		# Percentage-based damage.
		var base_damage: int = roll_weapon_damage(caster)
		var final_damage: int = maxi(1, roundi(base_damage * damage_percent))
		CombatLog.add(caster.name + " cleaves " + target.name + " for " + str(final_damage) + ".")
		if target.is_in_group("player"):
			PlayerData.take_damage(final_damage)
		else:
			target.take_damage(final_damage)
