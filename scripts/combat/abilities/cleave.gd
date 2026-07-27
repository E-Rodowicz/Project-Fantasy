class_name CleaveAbility
extends BaseAbility

const CLEAVE_SLASH: PackedScene = preload("res://scenes/effects/cleave_slash_effect.tscn")

func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var tiles: Array = []
	var half: int = data.get("range", 3) / 2
	var front: Vector2i = player_tile + direction
	var perp: Vector2i = Vector2i(-direction.y, direction.x)

	if world_layer.get_cell_source_id(front) == -1:
		tiles.append(front)

	for i in range(1, half + 1):
		var tile: Vector2i = front + perp * i
		if world_layer.get_cell_source_id(tile) != -1:
			break
		tiles.append(tile)

	for i in range(1, half + 1):
		var tile: Vector2i = front + perp * -i
		if world_layer.get_cell_source_id(tile) != -1:
			break
		tiles.append(tile)

	return tiles

func execute(caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	var damage_percent: float = data.get("damage_percent", 0.5)
	var caster_tile: Vector2i = world_layer.local_to_map(caster.global_position)

	var front_tile: Vector2i = caster_tile + attack_direction
	var slash: AnimatedSprite2D = CLEAVE_SLASH.instantiate()
	slash.process_mode = Node.PROCESS_MODE_ALWAYS
	slash.rotation = Vector2(attack_direction).angle()
	world_layer.get_parent().add_child(slash)
	slash.global_position = world_layer.map_to_local(front_tile).lerp(caster.global_position, 0.5)

	# Wait for mid-animation before dealing damage.
	var frame_count: int = slash.sprite_frames.get_frame_count("default")
	var fps: float = slash.sprite_frames.get_animation_speed("default")
	var half_duration: float = (frame_count / fps) * 0.3
	await world_layer.get_tree().create_timer(half_duration).timeout

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
		if not attack_roll(caster, target):
			continue

		if randf() < dismember_chance:
			CombatLog.add(target.name + " is dismembered!")
			if target.is_in_group("player"):
				PlayerData.take_damage(PlayerData.max_hp)
			else:
				target.take_damage(target.stats.get_max_hp())
			continue

		var base_damage: int = roll_weapon_damage(caster)
		var final_damage: int = maxi(1, roundi(base_damage * damage_percent))
		CombatLog.add(caster.name + " cleaves " + target.name + " for " + str(final_damage) + ".")
		_deal_damage_parallel(target, final_damage)

	await _await_reactions(world_layer)
