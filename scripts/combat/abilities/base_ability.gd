class_name BaseAbility
extends  RefCounted

const ARROW_EFFECT: PackedScene = preload("res://scenes/effects/arrow_projectile.tscn")
const ARROW_SPEED: float = 240.0
const ARROW_MISS_OVERSHOOT: float = 12.0

var data: Dictionary = {}
var caster: Node = null
var attacker_position: Vector2 = Vector2.ZERO
var attack_direction: Vector2i = Vector2i.ZERO
var _pending_reactions: int = 0

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
	
func _deal_damage(target: Node, amount: int, do_nudge: bool = true) -> void:
	var hit_pos: Vector2 = target.global_position
	var effect_parent: Node = target.get_parent()
	var is_player: bool = target.is_in_group("player")

	if not is_player and data.get("requires_ranged_weapon", false):
		await _fly_arrow(attacker_position, hit_pos, effect_parent)

	if not is_player:
		await effect_parent.get_tree().create_timer(0.04).timeout

		if data.get("causes_blood", true):
			CombatEffects.spawn_blood(effect_parent, hit_pos)

	if is_player:
		PlayerData.take_damage(amount)
	else:
		target.take_damage(amount)

	CombatEffects.float_damage(amount, float(amount) / average_weapon_damage(caster), effect_parent, hit_pos)

	if not is_player:
		await CombatEffects.play_hit_reaction(target, attacker_position, do_nudge)
	
# Rolls to hit. On a miss, logs it and plays the sidestep. Returns true if it connects. Pass 
# play_reaction = false when the caller moves the target itself, so the two don't fight over 
# global_position.
func attack_roll(caster: Node, target: Node, play_reaction: bool = true) -> bool:
	if randf() < get_hit_chance(target):
		return true
	CombatLog.add(target.name + " dodges " + caster.name + "'s " + data.get("name", "attack").to_lower() + "!")
	CombatEffects.float_label("Miss", target.get_parent(), target.global_position, Color(0.75, 0.75, 0.75))
	if play_reaction:
		CombatEffects.play_dodge_reaction(target, attacker_position)
	return false
		
func _apply_status_effect(target: Node, effect_id: String, stacks: int) -> void:
	if target.is_in_group("player"):
		PlayerData.add_status_effect(effect_id, stacks)
	else:
		target.add_status_effect(effect_id, stacks)
		
func _engage_if_needed(target: Node) -> void:
	if target.is_in_group("enemy") and target not in BattleManager.combatants:
		BattleManager.add_combatant(target)

func _fly_arrow(from: Vector2, to: Vector2, parent: Node, overshoot: float = 0.0) -> void:
	var arrow: AnimatedSprite2D = ARROW_EFFECT.instantiate()
	arrow.process_mode = Node.PROCESS_MODE_ALWAYS
	var direction: Vector2 = (to - from).normalized()
	arrow.rotation = direction.angle()
	parent.add_child(arrow)
	arrow.global_position = from

	var dist: float = from.distance_to(to)
	var duration: float = dist / ARROW_SPEED
	var tween: Tween = arrow.create_tween()
	tween.tween_property(arrow, "global_position", to, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	if overshoot > 0.0 and direction != Vector2.ZERO:
		var past_duration: float = overshoot / ARROW_SPEED
		tween.tween_property(arrow, "global_position", to + direction * overshoot, past_duration)
		tween.parallel().tween_property(arrow, "modulate:a", 0.0, past_duration)

	await tween.finished
	arrow.queue_free()

# Plays the "shot sails past" visual for a missed ranged ability. Does nothing for abilities that 
# aren't ranged, so callers don't need to know which is which.
func play_miss_projectile(to: Vector2, parent: Node) -> void:
	if not data.get("requires_ranged_weapon", false):
		return
	await _fly_arrow(attacker_position, to, parent, ARROW_MISS_OVERSHOOT)

func _get_current_hp(target: Node) -> int:
	if target.is_in_group("player"):
		return PlayerData.current_hp
	return target.current_hp

# Starts a damage resolution without blocking, so several can run on the same frame.
func _deal_damage_parallel(target: Node, amount: int) -> void:
	_pending_reactions += 1
	await _deal_damage(target, amount)
	_pending_reactions -= 1

# Blocks until every _deal_damage_parallel call has finished.
func _await_reactions(tree_node: Node) -> void:
	while _pending_reactions > 0:
		await tree_node.get_tree().process_frame

# Expected damage of a plain weapon swing, affinity included. The yardstick for how big a number
# should look, and it scales with gear and level on its own.
func average_weapon_damage(attacker: Node) -> float:
	if attacker == null or not is_instance_valid(attacker):
		return 1.0
	if attacker.is_in_group("player"):
		var weapon: Dictionary = PlayerData.get_equipped_weapon()
		if weapon.is_empty():
			return 1.0
		var result: Dictionary = ItemDB.calculate_damage(weapon, PlayerData.get_stats_dict())
		return maxf(1.0, (float(result["min"]) + float(result["max"])) * 0.5)
	return maxf(1.0, (float(attacker.stats.base_damage_min) + float(attacker.stats.base_damage_max)) * 0.5)
