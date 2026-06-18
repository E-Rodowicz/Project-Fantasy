class_name BaseAbility
extends  RefCounted

var data: Dictionary = {}

func setup(ability_data: Dictionary) -> void:
	data = ability_data
	
func get_targeting_type() -> String:
	return data.get("targeting", "")
	
# Override in each ability: return which tiles are affected.
func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	return []
	
# Override in each ability: do the thing.
func execute(caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	pass

# Find who is standing on a tile.
func combatant_on_tile(tile: Vector2i, all_combatants: Array, world_layer: TileMapLayer) -> Node:
	for c in all_combatants:
		if world_layer.local_to_map(c.global_position) == tile:
			return c
	for e in world_layer.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e in all_combatants:
			continue
		if world_layer.local_to_map(e.global_position) == tile:
			return e
	return null
	
# Roll weapon damage for the caster.
func roll_weapon_damage(caster: Node) -> int:
	if caster.is_in_group("player"):
		var weapon: Dictionary = PlayerData.get_equipped_weapon()
		if weapon.is_empty():
			return 1
		var result: Dictionary = ItemDB.calculate_damage(weapon, PlayerData.get_stats_dict())
		return randi_range(result["min"], result["max"])
	else:
		return randi_range(caster.stats.base_damage_min, caster.stats.base_damage_max)

func get_hit_modifier() -> float:
	return data.get("hit_modifier", 0.0)
	
func get_hit_chance(target: Node) -> float:
	return CombatantStats.hit_chance_for(target, get_hit_modifier())
	
func _deal_damage(target: Node, amount: int) -> void:
	if target.is_in_group("player"):
		PlayerData.take_damage(amount)
	else:
		target.take_damage(amount)
		
func _apply_status_effect(target: Node, effect_id: String, stacks: int) -> void:
	if target.is_in_group("player"):
		PlayerData.add_status_effect(effect_id, stacks)
	else:
		target.add_status_effect(effect_id, stacks)
		
func _engage_if_needed(target: Node) -> void:
	if target.is_in_group("enemy") and target not in BattleManager.combatants:
		BattleManager.add_combatant(target)
