class_name BlinkAbility
extends BaseAbility

func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var blink_range: int = data.get("blink_range", 6)
	var all_combatants: Array = BattleManager.combatants
	var valid: Array = []
	
	for dx in range(-blink_range, blink_range + 1):
		for dy in range(-blink_range, blink_range + 1):
			if dx == 0 and dy == 0:
				continue
			if maxi(abs(dx), abs(dy)) > blink_range:
				continue
			var tile: Vector2i = player_tile + Vector2i(dx, dy)
			# Not a wall.
			if world_layer.get_cell_source_id(tile) != -1:
				continue
			# Not occupied by any combatant.
			var occupied: bool = false
			for c in all_combatants:
				if is_instance_valid(c) and world_layer.local_to_map(c.global_position) == tile:
					occupied = true
					break
			if occupied:
				continue
			# Must be adjacent to at least one enemy.
			var near_enemy: bool = false
			for c in all_combatants:
				if not is_instance_valid(c) or c.is_in_group("player"):
					continue
				var c_tile: Vector2i = world_layer.local_to_map(c.global_position)
				if abs(c_tile.x - tile.x) <= 1 and abs(c_tile.y - tile.y) <= 1:
					near_enemy = true
					break
			if near_enemy:
				valid.append(tile)
	
	return valid
	
func execute(caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	if tiles.size() < 2:
		return
	var landing_tile: Vector2i = tiles[0]
	var target_tile: Vector2i = tiles[1]
	
	# Teleport.
	caster.global_position = world_layer.map_to_local(landing_tile)
	CombatLog.add(caster.name + " blinks.")
	
	# Find the selected target.
	var target: Node = combatant_on_tile(target_tile, all_combatants, world_layer)
	if target == null:
		return
	
	# Strike for 150% weapon damage.
	var damage_percent: float = data.get("damage_percent", 1.5)
	var hit_chance: float = get_hit_chance(target)
	if randf() >= hit_chance:
		CombatLog.add(target.name + " dodges " + caster.name + "'s blink strike.")
	else:
		var base_damage: int = roll_weapon_damage(caster)
		var final_damage: int = maxi(1, roundi(base_damage * damage_percent))
		CombatLog.add(caster.name + " strikes " + target.name + " for " + str(final_damage) + ".")
		_deal_damage(target, final_damage)
	
	# Apply blink dodge buff.
	if caster.is_in_group("player"):
		PlayerData.add_status_effect("blink_dodge", 1)
		CombatLog.add(caster.name + " is ready to dodge! (33%)")
