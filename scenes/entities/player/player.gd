extends CharacterBody2D

# Declares the constant of a tile in 2D, and declares its size (Vector2, 16x16)
const tile_size: Vector2 = Vector2(16, 16)
# Holds the animation.
var sprite_node_pos_tween: Tween
# Checks if precision mode is on.
var precision_mode: bool = false
# A var to store the direction of where the player is pointing while in precision mode.
var pointer_dir: Vector2 = Vector2.ZERO
# This is a countdown which starts at 0 and gets set to...
var pointer_update_timer: float = 0.0
# ...this. How many seconds must pass before the pointer (arrow) can update again.
const POINTER_UPDATE_RATE: float = 0.12  # seconds between pointer updates
# This will be used for checks against the player, enemy detection and other triggers.
signal player_moved

# This built-in function does a check every frame (there's 60fps by default, so theres 60 checks per
# second). Note: Delta is important. Frames might run quicker on some PCs, and delta checks how
# many seconds have passed since last frame. Without it, timers would run at different speeds
# depending on the machine. For example, Dark Souls 2 had weapon durability tied to fps, meaning
# items would break quicker if you had high fps. Delta would fix this by counting real-time instead
# of fps. How it works exactly is that the higher the fps, the lower the delta amount. So for 
# 30fps, delta is 0.033, meaning it counts down faster, but since it does it every frame and there
# are 30 frames to work with, it counts down in real-time. Same with 120fps, it counts down by
# 0.008 seconds, but since there are so many frames, it counts down just as quickly as it would
# with 30fps.
func _physics_process(delta: float) -> void:
	if BattleManager.active:
		return
	# Checks if shift is pressed or not.
	if Input.is_action_just_pressed("precision"):
		precision_mode = not precision_mode
	# If yes, it runs precision mode.
	if precision_mode:
		_handle_precision_mode(delta)
	# If not, it resets the pointer to 0 so that it disappears if it was on.
	else:
		pointer_dir = Vector2.ZERO
		_handle_movement()
		_handle_quick_interact()
	# Runs regardless of what happens. It handles its own visibility logic (When it comes to
	# updating where the arrow is).
	_update_arrow()

# Movement of WASD/Arrow keys. It reads inputs. Only runs when there is no tween playing. If
# Vector2 is not 0, it runs the _move function, which moves the character (This just reads inputs).
func _handle_movement():
	if !sprite_node_pos_tween or !sprite_node_pos_tween.is_valid():
		var dir = Vector2.ZERO
		if Input.is_action_pressed("ui_up"): dir.y -= 1
		if Input.is_action_pressed("ui_down"): dir.y += 1
		if Input.is_action_pressed("ui_left"): dir.x -= 1
		if Input.is_action_pressed("ui_right"): dir.x += 1
		if dir != Vector2.ZERO:
			_move(dir)

# Does the quick interact action when not in precision mode. Also, tells the DM that after the first
# frame of dialogue closing, just_closed gets the false bool so that the dialogue doesn't
# retrigger when leaving dialogue. This is set to false, as it is set to true when dialogue closes
# for a single frame, as on the next frame this sets it to false again. That single frame "true"
# makes sure dialogue doesnt fire again after exiting a dialogue window.
func _handle_quick_interact():
	if DialogueManager.just_closed:
		DialogueManager.just_closed = false
		return
	if LootManager.just_closed:
		LootManager.just_closed = false
		return
	if BattleManager.just_closed:
		BattleManager.just_closed = false
		return
	if not Input.is_action_just_pressed("interact"):
		return
	
	# The directions of all the places that should be checked for interactables around the player.
	# Ordered top-left to bottom-right, like reading a book.
	var directions = [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1),
		Vector2(-1, 0),  Vector2.ZERO,   Vector2(1, 0),
		Vector2(-1, 1),  Vector2(0, 1),  Vector2(1, 1)
	]
	
	# "Found" is an array of dictionaries, each containing the interactable object, its direction
	# relative to the player, its display name, and its action type (Loot, Talk, etc).
	var found = []
	# Loops through all declared directions above.
	for dir in directions:
		var check_pos = global_position + dir * tile_size
		# Checks if current position in loop has an interactable on layer 2.
		if _has_interactable(check_pos):
			# This gets the actual node (collider) at that position.
			var collider = _get_interactables(check_pos)
			# If there's something there, we add the object, its direction, name and action to found.
			if collider:
				# If the lootable item is empty, it does "continue", meaning it skips the rest of 
				# the loop. This means empty barrels never make it to found and therefore don't
				# show up in the interactable window.
				if collider.has_method("is_empty") and collider.is_empty():
					continue
				found.append({
					"collider": collider,
					"direction": dir,
					"name": collider.interactable_name if "interactable_name" in collider else "Unknown",
					"action": collider.interact_action if "interact_action" in collider else ""
				})
				
	if found.size() == 0:
		print("Nothing here!")
	# Sends info of the single interactable so it can be interacted with directly. 
	elif found.size() == 1:
		found[0]["collider"].interact()
	# Sends the found array to the interact manager so that it knows the names, items and
	# directions.
	else:
		InteractManager.open_popup(found)
	
	# Explanation of how the below and above functions work:
	# Player presses E near two barrels
	# _handle_quick_interact finds both, builds found array with colliders and directions
	# Calls InteractManager.open_popup(found)
	# InteractManager stores that array as interactables
	# Player navigates the popup and picks one
	# confirm_selection runs — interactables[selected_index] gets the chosen Dictionary
	# selected["collider"].interact() calls interact on the actual barrel node

# Asks what is sitting at the current position on layer 2. Returns the actual node.
func _get_interactables(pos: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 2
	query.exclude = [get_rid()]
	# This is what finds the COLLIDER. Godot looks at the position you gave it, checks what physics
	# bodies are there, and returns an array of Dictionaries, one per thing found. Each Dictionary
	# has several keys that Godot fills in automatically, and "collider" is one of them, pointing
	# directly to the node that was found.
	var results = space_state.intersect_point(query)
	# When we get the results and they are greater than 0, we grab the first object.
	# This if only checks if something is found in this position, if not, it returns null.
	if results.size() > 0:
		return results[0]["collider"]
	return null

# Counts the timer down by however many seconds have passed since last frame.
func _handle_precision_mode(delta: float):
	pointer_update_timer -= delta
	# Once that timer goes back to 0, it can read inputs again. It moves to the picked directions
	# and updates pointer_dir, then resets the timer. This basically means the pointer can change
	# max every x seconds, stopping jerky movement because you let go of one of the inputs too
	# quickly (Like holding up-right and letting go of W slightly before D - this will make it so
	# that the input doesn't jump to right but stays at up-right). 
	if pointer_update_timer <= 0.0:
		var new_dir = Vector2.ZERO
		if Input.is_action_pressed("ui_up"): new_dir.y -= 1
		if Input.is_action_pressed("ui_down"): new_dir.y += 1
		if Input.is_action_pressed("ui_left"): new_dir.x -= 1
		if Input.is_action_pressed("ui_right"): new_dir.x += 1
		if new_dir != Vector2.ZERO:
			pointer_dir = new_dir
			pointer_update_timer = POINTER_UPDATE_RATE

	# If E is tapped and the arrow is pointing somewhere, it finds the world position of that place
	# and passes that information to _try_interact.
	if Input.is_action_just_pressed("interact") and pointer_dir != Vector2.ZERO:
		var target = global_position + pointer_dir * tile_size
		_try_interact(target)

	# If Space is tapped and the arrow is pointing somewhere and no movement animation is playing,
	# moves the player in the pointed direction using the exact same logic (_move()) as normal movement.
	if Input.is_action_just_pressed("precise_move") and pointer_dir != Vector2.ZERO:
		if !sprite_node_pos_tween or !sprite_node_pos_tween.is_valid():
			_move(pointer_dir)
			
# Updates the arrow movement.
func _update_arrow():
	# Only does stuff if precision mode is active and the arrow is pointing somewhere.
	if precision_mode and pointer_dir != Vector2.ZERO:
		var target = global_position + pointer_dir * tile_size
		# Checks if a pointed tile is reachable. It is flipped so that if something IS blocked,
		# we get a "true" value.
		var blocked = not _is_move_valid(pointer_dir)
		# Calculation for where to put both sprites. It is normalised so that diagonals aren't too
		# far away from the player. The value at the end controls the distance from the player
		# (lower being closer, 1.0 being default). 
		var sprite_pos = global_position + pointer_dir.normalized() * tile_size * 0.66
		# Atan2 converts the direction vector into a specific angle, meaning the arrows rotate to
		# the correct direction, facing outward from the player. I had to do +PI/2 (Meaning a 90
		# degree turn right) as I drew the arrow pointing upwards - atan2 expects you draw things
		# facing rightward. Will know for future.
		var sprite_rot = atan2(pointer_dir.y, pointer_dir.x) + PI/2
		# Is the object interactable (for the golden arrow).
		var interactable = _has_interactable(target)
		
		# Only a cross or an arrow can be visible at a time, depending on the boolean value of
		# "blocked" and "interactable."
		$player_arrow_sprite.visible = not blocked and not interactable
		$player_cross_sprite.visible = blocked and not interactable
		$player_gold_arrow_sprite.visible = interactable
		
		# Applies positions to both sprites using sprite_pos (same calculation for both). The arrow
		# also has rotation applied; the cross doesn't, as it doesn't need to rotate.
		$player_arrow_sprite.global_position = sprite_pos
		$player_arrow_sprite.rotation = sprite_rot
		$player_cross_sprite.global_position = sprite_pos
		$player_gold_arrow_sprite.global_position = sprite_pos
		$player_gold_arrow_sprite.rotation = sprite_rot
		
		# Tells the game to play a specific animation. These don't need conditions as only one
		# sprite is visible (As per the "not blocked" and "blocked" above).
		$player_arrow_sprite.play("arrow")
		$player_cross_sprite.play("cross")
		$player_gold_arrow_sprite.play("gold_arrow")
		
	# If either precision mode is not active or arrow is not pointing, hides everything (including
	# animation).
	else:
		$player_arrow_sprite.visible = false
		$player_cross_sprite.visible = false
		$player_gold_arrow_sprite.visible = false
		$player_arrow_sprite.stop()
		$player_cross_sprite.stop()
		$player_gold_arrow_sprite.stop()
		
# The interaction function. It finds the node at the target position using a physics query on
# layer 2, gets the result, checks if it has an interact method, and calls it if it does.
# has_method() makes this generic and therefore any object with an interact function works
# automatically without the player needing to know what type of object it is.
func _try_interact(target_pos: Vector2):
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = target_pos
	query.collision_mask = 2
	query.exclude = [get_rid()]
	var results = space_state.intersect_point(query)
	if results.size() > 0:
		var collider = results[0]["collider"]
		# Note: has_method checks for functions!
		if collider.has_method("interact"):
			collider.interact()
	else:
		print("Nothing to interact with")
	
# Checks if destination tile is blocked, if yes it returns false.
func _is_move_valid(dir: Vector2) -> bool:
	var target = global_position + dir * tile_size
	if not _can_move_to(target):
		return false
	# This is specific to diagonal moves as it checks if two tiles alongside the diagonal path are
	# blocked at the same time (touching tips). If yes, it returns false.
	if dir.x != 0 and dir.y != 0:
		var h_tile = global_position + Vector2(dir.x, 0) * tile_size
		var v_tile = global_position + Vector2(0, dir.y) * tile_size
		if not _can_move_to(h_tile) and not _can_move_to(v_tile):
			return false
	# If everything is passed, it returns true as the move is valid.
	return true

# This checks if we can move to a certain space or if its blocked. Returns true or false.
func _can_move_to(target_pos: Vector2) -> bool:
	# Gets the current world and uses the physics engine of Godot to ask if there are collisions.
	# Such collision as walls, for example. If they are in the correct layer (which is further down)
	var space_state = get_world_2d().direct_space_state
	# A "point query" which checks a single point in the world to see if there is a collision.
	# It asks the question "is anything solid at this exact coordinate?". The .new() creates an
	# instance of the class PhysicsPointQueryParameters2D, which then requires you to fill out
	# its questions for position, collision and exclude.
	var query = PhysicsPointQueryParameters2D.new()
	# This sets the current target_pos (Vector2) position to the query, so it checks the current
	# Vector2 position and sees if its "passable".
	query.position = target_pos
	# Sets the layer that is being checked to layer 1. Collision masks in godot use bitwise layers.
	# This means that Layer 1 = 1, layer 2 = 2, layer 3 = 4, layer 4 = 8. To check multiple layers,
	# you must add them together. So if the value below is 1, it is layer 1. If it is 3, it is 
	# layers 1 and 2. If it is 5, it is layers 1 and 3, etc. Instead of adding, you can also use the
	# bitwise values separately: query.collision_mask = 1 | 2 | 4. These are layers 1, 2 and 3.
	# Btw, having hardcoded collision mask in this script overrides the inspector collision options.
	query.collision_mask = 1 | 8
	# This excludes the player from collision checking himself (Its what get_rid() does). More can
	# be added, as it is a list [], so if anything else needs to be excluded it can be passed onto
	# here.
	query.exclude = [get_rid()]
	# Runs the query and returns a list of everything that was found. If nothing is found and the
	# list is empty, it returns true. Otherwise, false.
	return space_state.intersect_point(query).is_empty()

# Movement function - what makes the player actually move. Above this all we had were inputs.
func _move(dir: Vector2):
	# Checks the destination position with is_move_valid. global_position is where the player is.
	# dir * tile_size multiplies the direction by 16, so (1,0) becomes (16,0), moving one tile.
	if not _is_move_valid(dir):
		return
	# This "if" checks if this movement is diagonal. Only cardinal moves have one axis active at a
	# time. (1,0) and (0,-1) are cardinal moves. All diagonals have both axes active at a time, as
	# they require two inputs, hence why this "if" then activates and does whatever is inside it.
	if dir.x != 0 and dir.y != 0:
		# Calculates the two tiles along the diagonal path, both the horizontal tiles next to the
		# player (left or right) and the vertical tiles above or below the player.
		var h_tile = global_position + Vector2(dir.x, 0) * tile_size
		var v_tile = global_position + Vector2(0, dir.y) * tile_size
		# Checks both tiles, horizontal and vertical. If both tiles are walls, it exits the _move
		# function. This stops player movement if two tiles are "touching tips", while letting all
		# other diagonal movement through.
		if not _can_move_to(h_tile) and not _can_move_to(v_tile):
			return
	# This teleports the player to the destination tile, instantly. Note: This does NOT move the
	# sprite.
	global_position += dir * tile_size
	# As the sprite is a child of the player body, and the player body moves in the line above,
	# usually all its children move with it. This moves the sprite back to the previous position,
	# cancelling the sprite's movement in the previous line. This gets it ready to be animated by
	# the tween.
	$player_sprite.global_position -= dir * tile_size

	# This checks if a tween for the sprite exists. If yes, it is killed so that two tweens dont
	# fight over the sprite position at the same time. Note: A tween is basically a timer that
	# smoothly changes a value from A to B over a set duration. Think of keyframes in animation.
	if sprite_node_pos_tween:
		sprite_node_pos_tween.kill()
	# Creates a new tween and attaches it to this node.
	sprite_node_pos_tween = create_tween()
	# This is important, as it updates the tween with the physics engine instead of the fps. Drops
	# in fps won't affect the movement or collision.
	sprite_node_pos_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	# .length returns the mathematical length of the direction vector. So, a cardinal move is 
	# exactly 1.0, meaning that the duration is 0.14 seconds. For diagonals, the length is √2 ≈ 1.414
	# meaning that the duration is extended to around 0.198 seconds. This slows down diagonal
	# movement so that the speed of tiles-per-second stays consistent with cardinal movement.
	var duration = 0.16 * dir.length()
	# tween_property animates the sprite from its current position (old tile) to global_position
	# (new tile, where the body already snapped to). TRANS_SINE applies a curve making movement
	# smooth - slow at start, fast in middle, slow at end.
	sprite_node_pos_tween.tween_property($player_sprite, "global_position", global_position, duration).set_trans(Tween.TRANS_SINE)
	emit_signal("player_moved")

# Checks if what is being pointed at is interactable and returns a bool saying if it is or not. 
func _has_interactable(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 2
	query.exclude = [get_rid()]
	return not space_state.intersect_point(query).is_empty()
