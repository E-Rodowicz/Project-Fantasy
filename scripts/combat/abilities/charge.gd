class_name ChargeAbility
extends BaseAbility

func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var tiles: Array = []
	var is_diagonal: bool = direction.x != 0 and direction.y != 0
	var max_range: int = data.get("diag_range", 2) if is_diagonal else data.get("ortho_range", 3)
	
	for i in range(1, max_range + 1):
		var tile: Vector2i = player_tile + direction * i
		if world_layer.get_cell_source_id(tile) != -1:
			break
		tiles.append(tile)
	
	return tiles
	
func execute(caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	if tiles.is_empty():
		return
	
	var start_tile: Vector2i = world_layer.local_to_map(caster.global_position)
	var endpoint_tile: Vector2i = tiles.back()
	var path_dmg_pct: float = data.get("path_damage_percent", 0.5)
	var endpoint_dmg_pct: float = data.get("endpoint_damage_percent", 1.0)
	var crush_dmg_pct: float = data.get("no_push_damage_percent", 3.0)
	
	# Find the endpoint target BEFORE moving. After the charge tween, the caster
	# will be on the endpoint tile too, so combatant_on_tile would find the caster
	# instead of the enemy.
	var ep_target: Node = combatant_on_tile(endpoint_tile, all_combatants, world_layer)
	if ep_target == caster:
		ep_target = null
	
	# Animate the player charging to the endpoint.
	var charge_path: Array = [start_tile] + tiles
	var tween: Tween = caster.create_tween()
	for i in range(1, charge_path.size()):
		var world_pos: Vector2 = world_layer.map_to_local(charge_path[i])
		tween.tween_property(caster, "global_position", world_pos, 0.07)
	await tween.finished
	
	# Hit targets along the path (everything except the last tile).
	for i in range(tiles.size() - 1):
		var target: Node = combatant_on_tile(tiles[i], all_combatants, world_layer)
		if target == null or target == caster:
			continue
		var hit_chance: float = get_hit_chance(target)
		if randf() >= hit_chance:
			CombatLog.add(target.name + " dodges " + caster.name + "'s charge!")
			continue
		var base: int = roll_weapon_damage(caster)
		var dmg: int = maxi(1, roundi(base * path_dmg_pct))
		CombatLog.add(caster.name + " charges through " + target.name + " for " + str(dmg) + ".")
		await _deal_damage(target, dmg)
	
	# Handle the endpoint target.
	if ep_target == null:
		return
	
	var hit_landed: bool = randf() < get_hit_chance(ep_target)
	if not hit_landed:
		CombatLog.add(ep_target.name + " dodges " + caster.name + "'s charge!")
	
	# Push regardless of hit — the player is on their tile now.
	if not is_instance_valid(ep_target):
		return
	
	var candidates: Array = _get_push_candidates(endpoint_tile, all_combatants, world_layer)
	if not candidates.is_empty():
		# Space to push — deal 100% if hit landed.
		if hit_landed:
			var base: int = roll_weapon_damage(caster)
			var dmg: int = maxi(1, roundi(base * endpoint_dmg_pct))
			CombatLog.add(caster.name + " slams into " + ep_target.name + " for " + str(dmg) + ".")
			await _deal_damage(ep_target, dmg)
		if is_instance_valid(ep_target):
			var push_tile: Vector2i = candidates[randi() % candidates.size()]
			CombatLog.add(ep_target.name + " is pushed back!")
			var push_tween: Tween = ep_target.create_tween()
			push_tween.tween_property(ep_target, "global_position", world_layer.map_to_local(push_tile), 0.1)
			await push_tween.finished
	else:
		# No space to push — 300% crush REPLACES the 100%.
		if hit_landed:
			var crush_base: int = roll_weapon_damage(caster)
			var crush_dmg: int = maxi(1, roundi(crush_base * crush_dmg_pct))
			CombatLog.add(ep_target.name + " has nowhere to go! " + str(crush_dmg) + " crush damage!")
			await _deal_damage(ep_target, crush_dmg)
		# Either way, move them to where the player started.
		if is_instance_valid(ep_target):
			var crush_tween: Tween = ep_target.create_tween()
			crush_tween.tween_property(ep_target, "global_position", world_layer.map_to_local(start_tile), 0.15)
			await crush_tween.finished
		
func _get_push_candidates(origin: Vector2i, all_combatants: Array, world_layer: TileMapLayer) -> Array:
	var candidates: Array = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var tile: Vector2i = origin + Vector2i(dx, dy)
			if world_layer.get_cell_source_id(tile) != -1:
				continue
			if combatant_on_tile(tile, all_combatants, world_layer) != null:
				continue
			candidates.append(tile)
	return candidates
