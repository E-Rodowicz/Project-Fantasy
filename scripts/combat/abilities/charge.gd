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
	
	# Animates the player charging.
	var charge_path: Array = [start_tile] + tiles
	var tween: Tween = caster.create_tween()
	for i in range (1, charge_path.size()):
		var world_pos: Vector2 = world_layer.map_to_local(charge_path[i])
		tween.tween_property(caster, "global_position", world_pos, 0.07)
	await tween.finished
	
	# Handles the hits on targets to the endpoint, excluding endpoint.
	for i in range(tiles.size() - 1):
		var target: Node = combatant_on_tile(tiles[i], all_combatants, world_layer)
		if target == null or target == caster:
			continue
		var hit_chance: float = get_hit_chance(target)
		if randf() >= hit_chance:
			CombatLog.add(target.name + " dodges " + caster.name + "'s charge.")
			continue
		var base: int = roll_weapon_damage(caster)
		var dmg: int = maxi(1, roundi(base * path_dmg_pct))
		CombatLog.add(caster.name + " charges through " + target.name + " for " + str(dmg) + ".")
		_deal_damage(target, dmg)
		
	# Handles endpoint target.
	var ep_target: Node = combatant_on_tile(endpoint_tile, all_combatants, world_layer)
	if ep_target == null or ep_target == caster:
		return
	var hit_landed: bool = randf() < get_hit_chance(ep_target)
	if hit_landed:
		var base: int = roll_weapon_damage(caster)
		var dmg: int = maxi(1, roundi(base * endpoint_dmg_pct))
		CombatLog.add(caster.name + " slams into " + ep_target.name + " for " + str(dmg) + ".")
		_deal_damage(ep_target, dmg)
	else:
		CombatLog.add(ep_target.name + " dodges " + caster.name + "'s charge!")
