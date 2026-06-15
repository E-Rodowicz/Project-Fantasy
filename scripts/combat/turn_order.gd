extends RefCounted
class_name TurnOrder

# Each combatant has an accumulator that builds up each round.
# When it hits 100 or more, they get a turn and it resets.
var combatants: Array = []
var accumulators: Dictionary = {}

func setup(combatant_list: Array) -> void:
	combatants = combatant_list
	accumulators.clear()
	for combatant in combatants:
		accumulators[combatant] = 0.0

func get_next_turn() -> Node:
	var ready: Array = []
	# Checks if anyone is already ready from overshoot.
	for combatant in combatants:
		if accumulators[combatant] >= 100.0:
			ready.append(combatant)
	
	# If no one ready, tick until someone is.
	while ready.is_empty():
		for combatant in combatants:
			accumulators[combatant] += _get_speed(combatant) * 10.0
		for combatant in combatants:
			if accumulators[combatant] >= 100.0:
				ready.append(combatant)
	
	# Sorts the ready array so that the one who goes first is on index 0.
	ready.sort_custom(func(a, b):
		# If two guys get the same value, player wins tiebreak. abs just checks edge cases of
		# really low float points and treats them as the same number. Just error precaution. Coin
		# flip for non player characters.
		if abs(accumulators[a] - accumulators[b]) < 0.001:
			if a.is_in_group("player"):
				return true
			# Sort custom works by asking "should a come before ?" True means yes, false means no.
			# This is why it returns false is player is in b.
			if b.is_in_group("player"):
				return false
			# Uses instnace ID to break speed ties between NPCs.
			return a.get_instance_id() < b.get_instance_id()
		# If there is no tie, the guy with more accumulator value goes first. This means that if a 
		# guy get 100 speed this round and guy2 gets 110 speed this round, guy2 goes first.
		return accumulators[a] > accumulators[b]
	)
	
	var winner = ready[0]
	accumulators[winner] -= 100.0
	return winner

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
