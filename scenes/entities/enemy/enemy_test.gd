extends CharacterBody2D

signal health_changed(current: int, maximum: int)

var player_in_range: bool = false
var player_ref: Node2D = null
var battle_triggered: bool = false
var current_hp: int = 0
var status_effects: Dictionary = {}

var detection_range: float = 0.0

@onready var vision_area = $vision_area

@export var stats: CombatantStats

func _ready() -> void:
	# vision_area.body_entered is a signal that Godot fires automatically
	# whenever a physics body enters the Area2D, it's built into the
	# Area2D class. .connect(_on_body_entered) tells it which function
	# to call when that happens. 
	vision_area.body_entered.connect(_on_body_entered)
	vision_area.body_exited.connect(_on_body_exited)
	_set_hp(stats.get_max_hp())
	for child in vision_area.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			detection_range = child.shape.radius
			break
			
# The only place current_hp is allowed to change. Everything that alters HP
# goes through here, so the signal can never be silently skipped.
func _set_hp(value: int) -> void:
	var max_hp: int = stats.get_max_hp()
	current_hp = clampi(value, 0, max_hp)
	health_changed.emit(current_hp, max_hp)

func take_damage(amount: int) -> void:
	_set_hp(current_hp - amount)
	CombatLog.add(name + " takes " + str(amount) + " damage. (" + str(current_hp) + "/" + str(stats.get_max_hp()) + " HP)")
	if current_hp <= 0:
		_die()

func heal(amount: int) -> void:
	_set_hp(current_hp + amount)

func _die() -> void:
	CombatLog.add(name + " has been slain.")
	BattleManager.remove_combatant(self)
	queue_free()
			
func _on_body_entered(body: Node2D) -> void:
	# If the player body node2d data enters this function, player in range becomes
	# the body var, and the player_ref gets amended to that body.
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		body.player_moved.connect(_on_player_moved)
		# Also check immediately in case they stepped into LoS.
		_on_player_moved()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.player_moved.is_connected(_on_player_moved):
			body.player_moved.disconnect(_on_player_moved)
		player_in_range = false
		player_ref = null
		
func _on_player_moved() -> void:
	if player_in_range and player_ref and not battle_triggered:
		if _has_line_of_sight(player_ref):
			await get_tree().physics_frame
			if battle_triggered:
				return
			var combatants = _gather_combatants()
			battle_triggered = true
			BattleManager.start_battle(combatants)

# Casts a ray from the enemy position to player/ally position. If the player/ally is not
# covered by a wall, it sents out a return hit.
func _has_line_of_sight(target: Node2D) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		target.global_position
	)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

# Gathers combatants.
func _gather_combatants() -> Array:
	var combatants = []
	# This tracks already chcecked enemies so we dont loop through
	# them forever.
	var checked = []
	# List of enemies to still check, starting with the one that noticed
	# the player.
	var to_check = [self]
	
	# Player is always in battle, so gets auto added.
	combatants.append(player_ref)
	
	# Checks the first guy on the to check list. Puts him into checked and combatants.
	# Starts battle. 
	while to_check.size() > 0:
		var current = to_check.pop_front()
		checked.append(current)
		combatants.append(current)
		current.battle_triggered = true
		
		# get_overlapping_bodies is a godot function which checks for all character bodies
		# inside the vision area. This is used in a loop.
		for body in current.vision_area.get_overlapping_bodies():
			# This checks all the visible enemies bascially, the ones that havent been checked.
			if body.is_in_group("enemy") and body not in checked and body not in to_check:
				if current._has_line_of_sight(body):
					# Adds the found bodies into to_check.
					to_check.append(body)
	
	# Returns complete list to phyiscs process.
	print("ITS TRUE!")
	print(combatants)
	return combatants
	
func get_status_stacks(effect_id: String) -> int:
	return status_effects.get(effect_id, 0)

func add_status_effect(effect_id: String, stacks: int) -> void:
	status_effects[effect_id] = status_effects.get(effect_id, 0) + stacks

func remove_status_stacks(effect_id: String, amount: int) -> void:
	if status_effects.has(effect_id):
		status_effects[effect_id] -= amount
		if status_effects[effect_id] <= 0:
			status_effects.erase(effect_id)
