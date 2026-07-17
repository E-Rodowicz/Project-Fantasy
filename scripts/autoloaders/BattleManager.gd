extends Node

var active: bool = false
var combatants: Array = []
var turn_order: TurnOrder = null
var current_combatant: Node = null
var player_turn: CombatantTurn = null
# For when battle just ends, so that any key presses arent immidietly used out of battle, like using
# E to kill something then the game checking for interactables as there is no delay between battle
# mode and regular mode.
var just_closed: bool = false
var rejected_hotbar_slot: int = -1
var bp_rejected: bool = false
var ap_rejected_cost: int = 0
var mp_rejected: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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
	
	CombatLog.clear()
	var names: String = ""
	for c in combatants:
		names += c.name + ", "
	# Trum suffic get rid of the ending, meaning the last name does not get the comma and space.
	CombatLog.add("Battle started: " + names.trim_suffix(", "))
	
	_next_turn()

func _next_turn() -> void:
	if not active:
		return
	check_for_reinforcements()
	current_combatant = turn_order.get_next_turn()
	CombatLog.add(current_combatant.name + "'s turn.")
	
	if current_combatant.is_in_group("player"):
		_start_player_turn()
	elif current_combatant.is_in_group("ally"):
		_start_ally_turn()
	else:
		_start_enemy_turn()

func _start_player_turn() -> void:
	var overlay_node = get_tree().current_scene.get_node("combat_overlay")
	var world_layer = get_tree().current_scene.get_node("TileMapLayer")
	var overlay = BattleOverlay.new()
	overlay.setup(overlay_node)
	
	player_turn = CombatantTurn.new()
	player_turn.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player_turn)
	player_turn.turn_finished.connect(_on_player_turn_finished)
	player_turn.start(current_combatant, world_layer, overlay, combatants, PlayerData.get_max_mp())

func _on_player_turn_finished() -> void:
	player_turn.queue_free()
	player_turn = null
	end_turn()
	
func _start_ally_turn() -> void:
	# Ally AI will go here
	print("Ally turn - AI thinking")
	end_turn()

func _start_enemy_turn() -> void:
	var overlay_node = get_tree().current_scene.get_node("combat_overlay")
	var world_layer = get_tree().current_scene.get_node("TileMapLayer")
	var overlay = BattleOverlay.new()
	overlay.setup(overlay_node)
	
	var enemy_turn := CombatantTurn.new()
	enemy_turn.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(enemy_turn)
	enemy_turn.turn_finished.connect(_on_enemy_turn_finished.bind(enemy_turn))
	enemy_turn.start(current_combatant, world_layer, overlay, combatants, current_combatant.stats.get_movement_points(), true)

func _on_enemy_turn_finished(enemy_turn: CombatantTurn) -> void:
	enemy_turn.queue_free()
	end_turn()

func end_turn() -> void:
	if not active:
		return
	CombatLog.add("----------------------------------")
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
	CombatLog.add("Victory!")
	_cleanup()

func _end_battle_player_dead() -> void:
	CombatLog.add("Defeated...")
	_cleanup()
	get_tree().quit()

func _cleanup() -> void:
	active = false
	just_closed = true
	
	# Clean up active turn node.
	if player_turn:
		player_turn.turn_finished.disconnect(_on_player_turn_finished)
		player_turn.queue_free()
		player_turn = null
		
	# Clears the overlay.
	var overlay_node = get_tree().current_scene.get_node_or_null("combat_overlay")
	if overlay_node:
		overlay_node.clear()
	
	# Resets process mode to normal.
	for c in combatants:
		if is_instance_valid(c):
			c.process_mode = Node.PROCESS_MODE_INHERIT
	
	get_tree().paused = false
	PlayerData.clear_status_effects()
	PlayerData.pending_focus = {}
	combatants.clear()
	turn_order = null
	current_combatant = null
	
func add_combatant(new_combatant: Node) -> void:
	if new_combatant in combatants:
		return
	new_combatant.battle_triggered = true
	new_combatant.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	turn_order.add_combatant(new_combatant)
	CombatLog.add(new_combatant.name + " has joined the battle.")
	
func check_for_reinforcements() -> void:
	var all_enemies: Array = get_tree().get_nodes_in_group("enemy")
	
	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in combatants:
			continue
		if enemy.battle_triggered:
			continue
			
		# Check if any current combatant is within this enemy's detection range.
		for combatant in combatants:
			if not is_instance_valid(combatant):
				continue
			var dist_sq: float = enemy.global_position.distance_squared_to(combatant.global_position)
			if dist_sq <= enemy.detection_range * enemy.detection_range:
				if enemy._has_line_of_sight(combatant):
					add_combatant(enemy)
					break
