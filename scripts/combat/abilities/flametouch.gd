class_name FlameTouchAbility
extends BaseAbility

func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var tile: Vector2i = player_tile + direction
	# Not valid if wall.
	if world_layer.get_cell_source_id(tile) != -1:
		return []
	return [tile]
	
func execute(caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	var damage_percent: float = data.get("damage_percent", 2.0)
	
	for tile in tiles:
		var target: Node = combatant_on_tile(tile, all_combatants, world_layer)
		if target == null or target == caster:
			continue
		var hit_chance: float = get_hit_chance(target)
		if randf() >= hit_chance:
			CombatLog.add(target.name + " dodges " + caster.name + "'s flametouch.")
			continue
			
		var base_damage: int = roll_weapon_damage(caster)
		var final_damage: int = maxi(1, roundi(base_damage * damage_percent))
		CombatLog.add(caster.name + " touches " + target.name + " with flame for " + str(final_damage) + ".")
		_deal_damage(target, final_damage)
		
		# Applies fire stack.
		if is_instance_valid(target):
			var still_alive: bool = true
			if target.is_in_group("player"):
				still_alive = PlayerData.current_hp > 0
			else:
				still_alive = target.current_hp > 0
			if still_alive:
				_apply_status_effect(target, "fire", 1)
				CombatLog.add(target.name + " is set ablaze! Fire +1")
