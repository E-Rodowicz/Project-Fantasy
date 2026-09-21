extends RefCounted
class_name TurnOrder

# Each combatant has an accumulator that builds up each round.
# When it hits 100 or more, they get a turn and it resets.
var combatants: Array = []
var accumulators: Dictionary = {}

const TURN_THRESHOLD: float = 100.0
const TICK_MULTIPLIER: float = 10.0
const TICK_SAFETY_LIMIT: int = 10000

func setup(combatant_list: Array) -> void:
	combatants = combatant_list
	accumulators.clear()
	for combatant in combatants:
		accumulators[combatant] = 0.0

# The single source of truth for "who goes next". It mutates whichever accumulator
# dictionary it is handed. get_next_turn() hands it the real one, so the battle actually
# advances. peek_upcoming() hands it a throwaway copy, so nothing real changes.
func _resolve_next(acc: Dictionary) -> Node:
	if combatants.is_empty():
		return null

	var ready: Array = []
	for combatant in combatants:
		if acc.get(combatant, 0.0) >= TURN_THRESHOLD:
			ready.append(combatant)

	var safety: int = 0
	while ready.is_empty():
		safety += 1
		if safety > TICK_SAFETY_LIMIT:
			push_error("TurnOrder: no combatant ever reached the turn threshold. Check for zero speed values.")
			return combatants[0]
		for combatant in combatants:
			acc[combatant] = acc.get(combatant, 0.0) + _get_speed(combatant) * TICK_MULTIPLIER
		for combatant in combatants:
			if acc[combatant] >= TURN_THRESHOLD:
				ready.append(combatant)

	ready.sort_custom(func(a, b):
		if abs(acc[a] - acc[b]) < 0.001:
			if a.is_in_group("player"):
				return true
			if b.is_in_group("player"):
				return false
			return a.get_instance_id() < b.get_instance_id()
		return acc[a] > acc[b]
	)

	var winner: Node = ready[0]
	acc[winner] -= TURN_THRESHOLD
	return winner

func get_next_turn() -> Node:
	return _resolve_next(accumulators)

# Predicts the next `count` turns without advancing the real battle.
# The same combatant appearing several times in a row is correct and expected - overshoot
# is preserved, so a fast combatant banks surplus and can act repeatedly before a slow
# one surfaces. The display collapses those runs into a single card.
func peek_upcoming(count: int) -> Array:
	var preview: Array = []
	if combatants.is_empty() or count <= 0:
		return preview

	var sim: Dictionary = accumulators.duplicate()
	for i in range(count):
		var next_up: Node = _resolve_next(sim)
		if next_up == null:
			break
		preview.append(next_up)
	return preview

func remove_combatant(combatant: Node) -> void:
	combatants.erase(combatant)
	accumulators.erase(combatant)

func _get_speed(combatant: Node) -> float:
	if combatant.is_in_group("player"):
		return float(PlayerData.speed)
	return float(combatant.stats.speed)

func add_combatant(combatant: Node) -> void:
	if combatant in combatants:
		return
	combatants.append(combatant)
	accumulators[combatant] = 0.0

# Predicts turns until the order starts repeating. Does not include
# the combatant acting.
func peek_cycle(max_turns: int) -> Array:
	var preview: Array = []
	if combatants.is_empty() or max_turns <= 0:
		return preview
		
	var start: Dictionary = accumulators.duplicate()
	var sim: Dictionary = accumulators.duplicate()
	
	for i in range(max_turns):
		var next_up: Node = _resolve_next(sim)
		if next_up == null:
			break
		# State matches where we started, so this turn is the current
		# combatant's slot coming around again. Everything past here
		# is on repeat.
		if _same_state(sim, start):
			break
		preview.append(next_up)
	return preview
	
func _same_state(a: Dictionary, b: Dictionary) -> bool:
	for combatant in combatants:
		if abs(a.get(combatant, 0.0) - b.get(combatant, 0.0)) > 0.001:
			return false
	return true
