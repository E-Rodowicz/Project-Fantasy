extends Node

var active: bool = false
var combatants: Array = []
var turn_order: TurnOrder = null
var current_combatant: Node = null

func start_battle(combatant_list: Array) -> void:
	if active:
		return
	active = true
	combatants = combatant_list
	
	# Pause everything except combat participants.
	get_tree().paused = true
	for combatant in combatants:
		combatant.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Set up turn order.
	turn_order = TurnOrder.new()
	turn_order.setup(combatants)
	
	print("Battle started with: ")
	for c in combatants:
		print("  - ", c.name)
	
	_next_turn()

func _next_turn() -> void:
	current_combatant = turn_order.get_next_turn()
	print("It is ", current_combatant.name, "'s turn")
	
	if current_combatant.is_in_group("player"):
		_start_player_turn()
	elif current_combatant.is_in_group("ally"):
		_start_ally_turn()
	else:
		_start_enemy_turn()

func _start_player_turn() -> void:
	# Player turn logic will go here
	print("Player turn - awaiting input")

func _start_ally_turn() -> void:
	# Ally AI will go here
	print("Ally turn - AI thinking")
	end_turn()

func _start_enemy_turn() -> void:
	# Enemy AI will go here
	print("Enemy turn - AI thinking")
	end_turn()

func end_turn() -> void:
	if not active:
		return
	await get_tree().process_frame
	_next_turn()

func remove_combatant(combatant: Node) -> void:
	combatants.erase(combatant)
	turn_order.remove_combatant(combatant)
	_check_battle_end()

func _check_battle_end() -> void:
	var enemies_alive = combatants.any(func(c): return c.is_in_group("enemy"))
	var player_alive = combatants.any(func(c): return c.is_in_group("player"))
	
	if not player_alive:
		_end_battle_player_dead()
	elif not enemies_alive:
		_end_battle_victory()

func _end_battle_victory() -> void:
	print("Victory!")
	_cleanup()

func _end_battle_player_dead() -> void:
	print("Game over")
	_cleanup()
	get_tree().quit()

func _cleanup() -> void:
	active = false
	get_tree().paused = false
	combatants.clear()
	turn_order = null
	current_combatant = null
