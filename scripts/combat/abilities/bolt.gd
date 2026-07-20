class_name BoltAbility
extends BaseAbility

func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var max_range: int = data.get("range_ortho", 3)
	if direction.x != 0 and direction.y != 0:
		max_range = data.get("range_diag", 2)
		
	var tiles: Array = []
	for i in range(1, max_range + 1):
		var tile: Vector2i = player_tile + direction * i
		if world_layer.get_cell_source_id(tile) != -1:
			break
		tiles.append(tile)
	return tiles
	
func execute(caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	# Finds the first target in bolt's path.
	var initial_target: Node = null
	for tile in tiles:
		var target: Node = combatant_on_tile(tile, all_combatants, world_layer)
		if target != null and target != caster:
			initial_target = target
			break
			
	if initial_target == null:
		CombatLog.add(caster.name + "'s bolt fizzles — no target in range.")
		return
		
	# Initial hit of full weapon damage.
	var hit_chance: float = get_hit_chance(initial_target)
	if randf() >= hit_chance:
		CombatLog.add(initial_target.name + " dodges " + caster.name + "'s bolt!")
		return

	var base_damage: int = roll_weapon_damage(caster)
	var final_damage: int = maxi(1, roundi(base_damage * data.get("damage_percent", 1)))
	CombatLog.add(caster.name + "'s bolt strikes " + initial_target.name + " for " + str(final_damage) + "!")
	await _deal_damage(initial_target, final_damage)
	
# Bounce chain — chance and damage decrease by 20% per bounce.
	var last_tile: Vector2i = world_layer.local_to_map(initial_target.global_position)
	var bounce_range: int = data.get("bounce_range", 5)
	var bounce_chance: float = 0.80
	var bounce_multiplier: float = 0.80
	
	while true:
		# Roll to see if the bolt arcs again.
		if randf() >= bounce_chance:
			CombatLog.add("Bolt dissipates.")
			break
		
		var bounce_target: Node = _find_bounce_target(last_tile, caster, all_combatants, world_layer, bounce_range)
		if bounce_target == null:
			CombatLog.add("Bolt has no target to bounce to.")
			break
		
		var bounce_hit_chance: float = get_hit_chance(bounce_target)
		if randf() >= bounce_hit_chance:
			CombatLog.add(bounce_target.name + " dodges the bouncing bolt!")
			break
		
		var bounce_base: int = roll_weapon_damage(caster)
		var bounce_damage: int = maxi(1, roundi(bounce_base * bounce_multiplier))
		CombatLog.add("Bolt bounces to " + bounce_target.name + " for " + str(bounce_damage) + "!")
		last_tile = world_layer.local_to_map(bounce_target.global_position)
		await _deal_damage(bounce_target, bounce_damage)
		
		# Decrease for next bounce, floored at minimums.
		bounce_chance = maxf(0.01, bounce_chance - 0.20)
		bounce_multiplier = maxf(0.20, bounce_multiplier - 0.20)
		
func _find_bounce_target(from_tile: Vector2i, caster: Node, all_combatants: Array, world_layer: TileMapLayer, bounce_range: int) -> Node:
	var candidates: Array = []
	
	for c in all_combatants:
		if c == caster or not is_instance_valid(c):
			continue
		var alive: bool = true
		if c.is_in_group("player"):
			alive = PlayerData.current_hp > 0
		else:
			alive = c.current_hp > 0
		if not alive:
			continue
		
		var c_tile: Vector2i = world_layer.local_to_map(c.global_position)
		if c_tile == from_tile:
			continue
		var dist: int = maxi(abs(c_tile.x - from_tile.x), abs(c_tile.y - from_tile.y))
		if dist <= bounce_range:
			candidates.append(c)
			
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
