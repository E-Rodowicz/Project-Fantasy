class_name StatusEffectProcessor
extends RefCounted

var combatant: Node = null
var combatants: Array = []
var world_layer: TileMapLayer = null

# Processes all active status effects for the combatant. Returns true if the combatant survived.
func process(p_combatant: Node, p_combatants: Array, p_world_layer: TileMapLayer) -> bool:
	combatant = p_combatant
	combatants = p_combatants
	world_layer = p_world_layer
	
	_process_fire()
	
	return _is_alive()
	
# ============================================================
# FIRE
# ============================================================
func _process_fire() -> void:
	var fire_stacks: int = _get_stacks("fire")
	if fire_stacks <= 0:
		return
		
	# Takes away 5% max HP per stack.
	var max_hp: int = _get_max_hp()
	var fire_damage: int = maxi(1, roundi(max_hp * 0.05 * fire_stacks))
	CombatLog.add(combatant.name + " burns for " + str(fire_damage) + ". (" + str(fire_stacks) + " fire stacks)")

	# Deals damage.
	if combatant.is_in_group("player"):
		PlayerData.take_damage(fire_damage)
		if PlayerData.current_hp <= 0:
			BattleManager.remove_combatant(combatant)
	else:
		combatant.take_damage(fire_damage)
		
	# Losees 1 stack.
	if _is_alive():
		_remove_stacks("fire", 1)
		
	# 15% chance to spread 1 stack to random adjacent combatant.
	if _is_alive():
		_try_spread_fire(fire_stacks)
		
func _try_spread_fire(fire_stacks: int) -> void:
	var source_tile: Vector2i = world_layer.local_to_map(combatant.global_position)
	var adjacent_targets: Array = []
	
	for c in combatants:
		if c == combatant or not is_instance_valid(c):
			continue
		var c_tile: Vector2i = world_layer.local_to_map(c.global_position)
		# This is checking whether a combatant is on one of the 8 adjacent tiles. If the X distance
		# is at most 1 AND the Y distance is at most 1, the combatant is within a 1-tile radius.
		# abs() makes it work regardless of direction as a combatant at X-1 and X+1 both have an
		# absolute distance of 1. We already skip c == combatant earlier in the loop, so the (0,0)
		# center case is excluded.
		if abs(c_tile.x - source_tile.x) <= 1 and abs(c_tile.y - source_tile.y) <= 1:
			adjacent_targets.append(c)
			
	if adjacent_targets.is_empty():
		return
		
	# Each stack does an independant check for adjacent targets.
	for target in adjacent_targets:
		var stacks_gained: int = 0
		for i in range(fire_stacks):
			if randf() < 0.1:
				stacks_gained += 1
		if stacks_gained > 0:
			_add_stacks_to(target, "fire", stacks_gained)
			var new_stacks: int = _get_stacks_from(target, "fire")
			CombatLog.add("Fire spreads to " + target.name + "! (Fire " + str(new_stacks) + ")")
	
# ============================================================
# HELPERS — current combatant
# ============================================================
func _get_stacks(effect_id: String) -> int:
	if combatant.is_in_group("player"):
		return PlayerData.get_status_stacks(effect_id)
	return combatant.get_status_stacks(effect_id)

func _remove_stacks(effect_id: String, amount: int) -> void:
	if combatant.is_in_group("player"):
		PlayerData.remove_status_stacks(effect_id, amount)
	else:
		combatant.remove_status_stacks(effect_id, amount)

func _get_max_hp() -> int:
	if combatant.is_in_group("player"):
		return PlayerData.max_hp
	return combatant.stats.get_max_hp()

func _is_alive() -> bool:
	if not is_instance_valid(combatant):
		return false
	if combatant.is_in_group("player"):
		return PlayerData.current_hp > 0
	return combatant.current_hp > 0

# ============================================================
# HELPERS — arbitrary target (for spread)
# ============================================================
func _add_stacks_to(target: Node, effect_id: String, stacks: int) -> void:
	if target.is_in_group("player"):
		PlayerData.add_status_effect(effect_id, stacks)
	else:
		target.add_status_effect(effect_id, stacks)

func _get_stacks_from(target: Node, effect_id: String) -> int:
	if target.is_in_group("player"):
		return PlayerData.get_status_stacks(effect_id)
	return target.get_status_stacks(effect_id)
