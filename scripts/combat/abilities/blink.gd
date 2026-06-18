class_name BlinkAbility
extends BaseAbility

func get_target_tiles(player_tile: Vector2i, _direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var blink_range: int = data.get("blink_range", 6)
	var all_combatants: Array = BattleManager.combatants
	var all_enemies: Array = world_layer.get_tree().get_nodes_in_group("enemy")
	var valid: Array = []
	
	# Pre-compute occupied tiles (can't land on anyone).
	var occupied_tiles: Array = []
	for c in all_combatants:
		if is_instance_valid(c):
			occupied_tiles.append(world_layer.local_to_map(c.global_position))
	for e in all_enemies:
		if is_instance_valid(e) and e not in all_combatants:
			occupied_tiles.append(world_layer.local_to_map(e.global_position))
	
	# Pre-compute enemy tiles (must land adjacent to one).
	var enemy_tiles: Array = []
	for c in all_combatants:
		if is_instance_valid(c) and not c.is_in_group("player"):
			enemy_tiles.append(world_layer.local_to_map(c.global_position))
	for e in all_enemies:
		if is_instance_valid(e) and e not in all_combatants:
			enemy_tiles.append(world_layer.local_to_map(e.global_position))
	
	for dx in range(-blink_range, blink_range + 1):
		for dy in range(-blink_range, blink_range + 1):
			if dx == 0 and dy == 0:
				continue
			if maxi(abs(dx), abs(dy)) > blink_range:
				continue
			var tile: Vector2i = player_tile + Vector2i(dx, dy)
			if world_layer.get_cell_source_id(tile) != -1:
				continue
			if tile in occupied_tiles:
				continue
			var near_enemy: bool = false
			for e_tile in enemy_tiles:
				if abs(e_tile.x - tile.x) <= 1 and abs(e_tile.y - tile.y) <= 1:
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
