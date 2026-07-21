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

	var ep_target: Node = combatant_on_tile(endpoint_tile, all_combatants, world_layer)
	if ep_target == caster:
		ep_target = null

	var start_pos: Vector2 = caster.global_position
	var end_pos: Vector2 = world_layer.map_to_local(endpoint_tile)
	var charge_dir: Vector2 = (end_pos - start_pos).normalized()

	# Facing.
	var sprite: CanvasItem = _get_target_sprite(caster)
	if sprite and charge_dir.x != 0:
		if caster.get("sprite_faces_right") != null and not caster.sprite_faces_right:
			sprite.flip_h = charge_dir.x > 0
		else:
			sprite.flip_h = charge_dir.x < 0

	# Wind-up.
	var windup_tween: Tween = caster.create_tween()
	windup_tween.tween_property(caster, "global_position", start_pos - charge_dir * 3.0, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await windup_tween.finished

	# Snap from windup back to start.
	var snap_tween: Tween = caster.create_tween()
	snap_tween.tween_property(caster, "global_position", start_pos, 0.02)
	await snap_tween.finished

	# Charge through tile by tile.
	for i in range(tiles.size()):
		var tile: Vector2i = tiles[i]
		var world_pos: Vector2 = world_layer.map_to_local(tile)

		# Find target BEFORE the caster lands on the tile.
		var path_target: Node = null
		if i < tiles.size() - 1:
			path_target = combatant_on_tile(tile, all_combatants, world_layer)
			if path_target == caster:
				path_target = null

		# Move to tile.
		var step_tween: Tween = caster.create_tween()
		step_tween.tween_property(caster, "global_position", world_pos, 0.04)
		await step_tween.finished

		# Path hit.
		if path_target != null and is_instance_valid(path_target):
			var hit_chance: float = get_hit_chance(path_target)
			if randf() >= hit_chance:
				CombatLog.add(path_target.name + " dodges " + caster.name + "'s charge!")
			else:
				# Hitstop — brief freeze on impact.
				await world_layer.get_tree().create_timer(0.08).timeout

				var base: int = roll_weapon_damage(caster)
				var dmg: int = maxi(1, roundi(base * path_dmg_pct))
				CombatLog.add(caster.name + " charges through " + path_target.name + " for " + str(dmg) + ".")

				var hit_pos: Vector2 = path_target.global_position
				if path_target.is_in_group("player"):
					PlayerData.take_damage(dmg)
				else:
					path_target.take_damage(dmg)

				# Blood — fire and forget.
				if data.get("causes_blood", true):
					var blood: AnimatedSprite2D = BLOOD_EFFECT.instantiate()
					blood.process_mode = Node.PROCESS_MODE_ALWAYS
					world_layer.get_parent().add_child(blood)
					blood.global_position = hit_pos

				# Flash + nudge — fire and forget, NOT awaited.
				if is_instance_valid(path_target):
					_play_hit_reaction(path_target)
					
	# Overshoot and correct.
	var overshoot_tween: Tween = caster.create_tween()
	overshoot_tween.tween_property(caster, "global_position", end_pos + charge_dir * 4.0, 0.04)
	overshoot_tween.tween_property(caster, "global_position", end_pos, 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await overshoot_tween.finished

	# Endpoint target.
	if ep_target == null:
		return

	var hit_landed: bool = randf() < get_hit_chance(ep_target)
	if not hit_landed:
		CombatLog.add(ep_target.name + " dodges " + caster.name + "'s charge!")

	if not is_instance_valid(ep_target):
		return

	var candidates: Array = _get_push_candidates(endpoint_tile, all_combatants, world_layer)
	if not candidates.is_empty():
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
		if hit_landed:
			var crush_base: int = roll_weapon_damage(caster)
			var crush_dmg: int = maxi(1, roundi(crush_base * crush_dmg_pct))
			CombatLog.add(ep_target.name + " has nowhere to go! " + str(crush_dmg) + " crush damage!")
			await _deal_damage(ep_target, crush_dmg)
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
