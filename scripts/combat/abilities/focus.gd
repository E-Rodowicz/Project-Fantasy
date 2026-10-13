class_name FocusAbility
extends BaseAbility

const FOCUS_RETICLE: PackedScene = preload("res://scenes/effects/focus_reticle.tscn")

func get_target_tiles(_player_tile: Vector2i, _direction: Vector2i, _world_layer: TileMapLayer) -> Array:
	return []
	
func execute(p_caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	caster = p_caster
	# Find first enemy on path. Target is stored as a node so that it is tracked if it moves.
	var target: Node = null
	for tile in tiles:
		var t: Node = combatant_on_tile(tile, all_combatants, world_layer)
		if t != null and t != caster:
			target = t
			break
			
	if target != null:
		CombatLog.add(caster.name + " focuses on " + target.name + "!")
	else:
		CombatLog.add(caster.name + " steadies aim...")

	# Stores focus shot for resolution at the start of players next turn.
	if caster.is_in_group("player"):
		var base_damage: int = roll_weapon_damage(caster)
		
		# Reticle parents to the target so that it follows automatically and dies with the parent.
		var reticle: Node2D = null
		if target != null:
			reticle = FOCUS_RETICLE.instantiate()
			reticle.process_mode = Node.PROCESS_MODE_ALWAYS
			target.add_child(reticle)
			reticle.position = Vector2.ZERO
			
		PlayerData.pending_focus = {
			"target": target,
			"reticle": reticle,
			"base_damage": base_damage,
			"damage_percent": data.get("damage_percent", 2.0),
			"crit_chance": data.get("crit_chance", 0.10),
			"crit_percent": data.get("crit_percent", 5.0),
			"hit_modifier": data.get("hit_modifier", 0.0)
		}

		# Holds the turn until the lock-on animation plays out.
		if reticle != null:
			var reticle_sprite: AnimatedSprite2D = reticle.get_node("Sprite")
			reticle_sprite.play("default")
			await reticle_sprite.animation_finished
