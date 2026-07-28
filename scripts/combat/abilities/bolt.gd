class_name BoltAbility
extends BaseAbility

const BOLT_EFFECT: PackedScene = preload("res://scenes/effects/bolt_effect.tscn")

var _bolt_timer: SceneTreeTimer = null

func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	var max_range: int = data.get("range_ortho", 3)
	if direction.x != 0 and direction.y != 0:
		max_range = data.get("range_diag", 2)

	var all_combatants: Array = BattleManager.combatants
	var tiles: Array = []
	for i in range(1, max_range + 1):
		var tile: Vector2i = player_tile + direction * i
		if world_layer.get_cell_source_id(tile) != -1:
			break
		tiles.append(tile)
		# The bolt stops at the first thing it hits — don't highlight past it.
		if combatant_on_tile(tile, all_combatants, world_layer) != null:
			break
	return tiles

# One bolt: a beam from the source to the target, cropped so it stops where it lands.
# Returns at the animation's halfway point, so damage resolves mid-flash.
func _strike(from_pos: Vector2, target: Node, world_layer: TileMapLayer) -> void:
	var to_pos: Vector2 = target.global_position
	var fx: BoltEffect = CombatEffects.spawn_effect(
		BOLT_EFFECT,
		world_layer.get_parent(),
		from_pos,
		(to_pos - from_pos).angle()
	) as BoltEffect
	fx.set_length(from_pos.distance_to(to_pos))
	CombatEffects.flash_screen(0.10, 0.12, Color(0.75, 0.85, 1.0))

	var length: float = fx.duration()
	# Started now, awaited later — this is what holds the next bolt back.
	_bolt_timer = world_layer.get_tree().create_timer(length)
	await world_layer.get_tree().create_timer(length * 0.2).timeout

# Holds the chain until the current bolt's animation has actually finished.
func _await_bolt_finish() -> void:
	if _bolt_timer != null and _bolt_timer.time_left > 0.0:
		await _bolt_timer.timeout

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

	# The bolt lands whether or not it connects.
	await _strike(caster.global_position, initial_target, world_layer)

	if not attack_roll(caster, initial_target):
		return

	# Captured before the damage, in case this kills them.
	var last_pos: Vector2 = initial_target.global_position
	var last_tile: Vector2i = world_layer.local_to_map(last_pos)

	var base_damage: int = roll_weapon_damage(caster)
	var final_damage: int = maxi(1, roundi(base_damage * data.get("damage_percent", 1)))
	CombatLog.add(caster.name + "'s bolt strikes " + initial_target.name + " for " + str(final_damage) + "!")
	await _deal_damage(initial_target, final_damage)
	await _await_bolt_finish()

	# Bounce chain — chance and damage decrease by 20% per bounce.
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

		# The arc comes from the last thing it hit, not from the caster.
		attacker_position = last_pos

		await _strike(last_pos, bounce_target, world_layer)

		var bounce_hit_chance: float = get_hit_chance(bounce_target)
		if randf() >= bounce_hit_chance:
			CombatLog.add(bounce_target.name + " dodges the bouncing bolt!")
			CombatEffects.play_dodge_reaction(bounce_target, last_pos)
			break

		last_pos = bounce_target.global_position
		last_tile = world_layer.local_to_map(last_pos)

		var bounce_base: int = roll_weapon_damage(caster)
		var bounce_damage: int = maxi(1, roundi(bounce_base * bounce_multiplier))
		CombatLog.add("Bolt bounces to " + bounce_target.name + " for " + str(bounce_damage) + "!")
		await _deal_damage(bounce_target, bounce_damage)
		await _await_bolt_finish()

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
