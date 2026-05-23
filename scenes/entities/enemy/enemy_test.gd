extends CharacterBody2D

# Signal takes an array, knows who is involved in the battle.
# This just declares that this node can emit a signal called battle_started,
# and when it does it will carry an array with it, the enemy 
# and the player. Think of it like registering an event. Nothing happens
# when you declare it, it only does something when you call 
# emit_signal. Whatever node connects to it receives the value automatically
# as a function argument.
signal battle_started(combatants)

var player_in_range: bool = false
var player_ref: Node2D = null
var battle_triggered: bool = false

@onready var vision_area = $vision_area

func _ready() -> void:
	# vision_area.body_entered is a signal that Godot fires automatically
	# whenever a physics body enters the Area2D, it's built into the
	# Area2D class. .connect(_on_body_entered) tells it which function
	# to call when that happens. 
	vision_area.body_entered.connect(_on_body_entered)
	vision_area.body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	# The two if checks are seperate for style points. I don't think
	# this affects performance as the check runs every frame anyway and
	# player is not in range, it does not continue into the next if check.
	if player_in_range and player_ref and not battle_triggered:
		if _has_line_of_sight(player_ref):
			# Gathers all combatants before firing the signal.
			var combatants = _gather_combatants()
			battle_triggered = true
			emit_signal("battle_started", combatants)
			
func _on_body_entered(body: Node2D) -> void:
	# If the player body node2d data enters this function, player in range becomes
	# the body var, and the player_ref gets amended to that body.
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null

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
	return combatants
