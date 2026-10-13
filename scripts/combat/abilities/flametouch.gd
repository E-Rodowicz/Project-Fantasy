class_name FlameTouchAbility
extends BaseAbility

const FLAME_EFFECT: PackedScene = preload("res://scenes/effects/flametouch_effect.tscn")

func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var tile: Vector2i = player_tile + direction
	# Not valid if wall.
	if world_layer.get_cell_source_id(tile) != -1:
		return []
	return [tile]
	
func execute(p_caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	caster = p_caster
	var damage_percent: float = data.get("damage_percent", 2.0)
	
	for tile in tiles:
		var target: Node = combatant_on_tile(tile, all_combatants, world_layer)
		if target == null or target == caster:
			continue

		# The flame lands whether or not it connects.
		var fx: AnimatedSprite2D = CombatEffects.spawn_effect(FLAME_EFFECT, world_layer.get_parent(), target.global_position)
		await world_layer.get_tree().create_timer(CombatEffects.effect_duration(fx) * 0.1).timeout

		if not attack_roll(caster, target):
			continue

		var base_damage: int = roll_weapon_damage(caster)
		var final_damage: int = maxi(1, roundi(base_damage * damage_percent))
		CombatLog.add(caster.name + " touches " + target.name + " with flame for " + str(final_damage) + ".")
		await _deal_damage(target, final_damage)

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
