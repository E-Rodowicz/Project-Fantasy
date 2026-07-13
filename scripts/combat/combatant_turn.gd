extends Node
class_name CombatantTurn

# # Who is being controlled this turn. Replaces the old "player" var.
var combatant: Node = null
var world_layer: TileMapLayer = null
var overlay: BattleOverlay = null
var combatants: Array = []
# When true, AI makes decisions. When false, human uses the cursor.
var ai_controlled: bool = false
var animating: bool = false

var bp_remaining: int = 0
var ap_remaining: int = 0
var is_offhand_attack: bool = false

var mp_label: Label = null
var hit_label: Label = null
var hit_labels: Array = []

# State of everything.
var mp_budget: int = 0
var player_tile: Vector2i = Vector2i.ZERO
var cursor_tile: Vector2i = Vector2i.ZERO
var reachable: Dictionary = {}

# List of confirmed tiles The last one is the final waypoint.
var waypoints: Array = []
# The full path across all waypoint segments.
var full_path: Array = []
# MP spent by the path so far.
var path_cost: int = 0

# Attack state. mode switches the turn between planning movement and aiming an attack.
enum Mode {MOVE, ATTACK, ABILITY}
var mode: int = Mode.MOVE

# The tiles the current attack can reach (the 8 around the player for a basic attack).
var attack_range_tiles: Array = []
# The tile the player has chosen to hit (only meaningful while has_target is true).
var attack_target: Vector2i = Vector2i.ZERO
# True once the first E has locked a target, waiting for the second E to confirm.
var has_target: bool = false
var ranged_target_tiles: Array = []
var ranged_area_tiles: Array = []

# Ability vars.
var active_ability: Dictionary = {}
var ability_direction: Vector2i = Vector2i.ZERO
var ability_tiles: Array = []
var ability_instance: BaseAbility = null
var has_ability_target: bool = false
var status_processor: StatusEffectProcessor = StatusEffectProcessor.new()
var has_acted_this_turn: bool = false
var blink_landing_tile: Vector2i = Vector2i.ZERO

var active_hotbar_slot: int = -1

const CURSOR_MOVE_RATE: float = 0.12
var cursor_move_timer: float = 0.0

var ui_root: Node2D = null

# Emitted when the player ends their turn so BattleManager can advance.
signal turn_finished

func start(p_combatant: Node, p_world: TileMapLayer, p_overlay: BattleOverlay, p_combatants: Array, p_mp: int, p_ai: bool = false) -> void:
	combatant = p_combatant
	world_layer = p_world
	overlay = p_overlay
	combatants = p_combatants
	mp_budget = p_mp
	ai_controlled = p_ai
	
	if combatant.is_in_group("player"):
		bp_remaining = PlayerData.bp_max
		ap_remaining = PlayerData.ap_max
	else:
		bp_remaining = 1
		ap_remaining = 0
	
	has_acted_this_turn = false
	
	if combatant.is_in_group("player"):
		CombatLog.add(combatant.name + "'s turn. (" + str(bp_remaining) + " BP, " + str(ap_remaining) + " AP)")
	
	player_tile = world_layer.local_to_map(combatant.global_position)
	cursor_tile = player_tile
	
	_recalculate_reachable()
	
	ui_root = Node2D.new()
	add_child(ui_root)
	mp_label = _create_floating_label()
	hit_label = _create_floating_label()
	
	var survived: bool = status_processor.process(combatant, combatants, world_layer)
	if not survived:
		turn_finished.emit()
		return
	
	if ai_controlled:
		# When a function uses await, it pauses at that line and lets the rest of the game keep
		# running. When the thing its waiting for finishes, so in this case the tween, it continues
		# where it left of.
		await _run_ai()
	else:
		_redraw()

func _physics_process(delta: float) -> void:
	if ai_controlled:
		return
	if animating:
		return
	# Cursor movement is the same in both modes.
	cursor_move_timer -= delta
	if cursor_move_timer <= 0.0:
		var dir := Vector2i.ZERO
		if Input.is_action_pressed("ui_up"): dir.y -= 1
		if Input.is_action_pressed("ui_down"): dir.y += 1
		if Input.is_action_pressed("ui_left"): dir.x -= 1
		if Input.is_action_pressed("ui_right"): dir.x += 1
		if dir != Vector2i.ZERO:
			# Cursor snaps to nearest target. Works for both melee and ranged.
			if mode == Mode.ATTACK:
				if PlayerData.is_ranged_weapon_equipped():
					var new_tile: Vector2i = cursor_tile + dir
					if _is_tile_on_screen(new_tile):
						cursor_tile = new_tile
						has_target = false
					cursor_move_timer = CURSOR_MOVE_RATE
					_redraw_ranged_attack()
				else:
					var wanted: Vector2i = player_tile + dir
					var dist_x: int = abs(wanted.x - player_tile.x)
					var dist_y: int = abs(wanted.y - player_tile.y)
					var attack_range: int = _get_attack_range()
					if dist_x <= attack_range and dist_y <= attack_range and _is_tile_on_screen(wanted):
						cursor_tile = wanted
						has_target = false
					cursor_move_timer = CURSOR_MOVE_RATE
					_redraw()
			elif mode == Mode.MOVE:
				var new_tile := cursor_tile + dir
				if _is_tile_on_screen(new_tile):
					cursor_tile = new_tile
				cursor_move_timer = CURSOR_MOVE_RATE
				_redraw()
	
	# End turn works from either mode.
	if Input.is_action_just_pressed("end_turn"):
		end_turn()
		return

	if mode == Mode.MOVE:
		if Input.is_action_just_pressed("interact"):
			_on_confirm()
		elif Input.is_action_just_pressed("cancel"):
			_on_cancel()
	elif mode == Mode.ATTACK:
		if Input.is_action_just_pressed("interact"):
			_on_attack_confirm()
		elif Input.is_action_just_pressed("cancel"):
			_on_attack_cancel()
	elif mode == Mode.ABILITY:
		_handle_ability_input()

func _unhandled_input(event: InputEvent) -> void:
	if ai_controlled or animating:
		return
		
	var slot: int = PlayerData.get_hotbar_slot_from_event(event)
	if slot == -1:
		return
		
	_handle_hotbar_press(slot)
	get_viewport().set_input_as_handled()
	
func _handle_hotbar_press(slot: int) -> void:
	var ability_id: String = PlayerData.get_hotbar_ability(slot)
	
	# Empty slot means do nothing.
	if ability_id == "":
		return
		
	# If we're already in this slot's mode, toggle it off (going back to Move).
	if slot == active_hotbar_slot:
		if mode == Mode.ATTACK:
			_exit_attack_mode()
		elif mode == Mode.ABILITY:
			_exit_ability_mode()
		active_hotbar_slot = -1
		return

	# If we're in a different mode, exit that first.
	if mode == Mode.ATTACK:
		_exit_attack_mode()
	elif mode == Mode.ABILITY:
		_exit_ability_mode()
		
	# Enter the new mode.
	if ability_id == "basic_attack":
		_enter_attack_mode()
		if mode == Mode.ATTACK:
			active_hotbar_slot = slot
		else:
			BattleManager.rejected_hotbar_slot = slot
		
	else:
		_enter_ability_mode(ability_id)
		# Only tracks as active is we actually are in the mode, in case we cannot use it due to AP 
		# or something else.
		if mode == Mode.ABILITY:
			active_hotbar_slot = slot
		else:
			BattleManager.rejected_hotbar_slot = slot

func _create_floating_label() -> Label:
	var label: Label = Label.new()
	var font: Font = preload("res://assets/fonts/m3x6.ttf")
	# Material for the text so its completely unshaded.
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	label.z_index = 100
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.visible = false
	ui_root.add_child(label)
	# Makes the text unshaded by the world (This is needed as its not under canvaslayer).
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	label.material = mat

	return label

func _update_floating_labels() -> void:
	if mode == Mode.MOVE and reachable.has(cursor_tile) and cursor_tile != player_tile:
		var total_cost: int = path_cost + reachable[cursor_tile]
		mp_label.text = str(total_cost) + " MP"
		mp_label.position = world_layer.map_to_local(cursor_tile) + Vector2(-8, -6)
		mp_label.visible = true
	elif cursor_tile != player_tile and ((mode == Mode.ATTACK and PlayerData.is_ranged_weapon_equipped()) or (mode == Mode.ABILITY and active_ability.get("targeting") == "ranged")):
		var line: Array = overlay.get_line_tiles(player_tile, cursor_tile)
		var range_cost: int = 0
		for i in range(1, line.size()):
			var prev: Vector2i = line[i - 1]
			var curr: Vector2i = line[i]
			var dx: int = abs(curr.x - prev.x)
			var dy: int = abs(curr.y - prev.y)
			range_cost += 3 if (dx != 0 and dy != 0) else 2
		mp_label.text = str(range_cost) + "R"
		mp_label.position = world_layer.map_to_local(cursor_tile) + Vector2(3, -2)
		mp_label.visible = true
	else:
		mp_label.visible = false
	_update_hit_labels()
		
	# Hit label belongs to ATTACK mode, on an enemy.
	if mode == Mode.ATTACK and _tile_has_combatant(cursor_tile, true):
		var target: Node = _combatant_on_tile(cursor_tile, true)
		if target != null:
			var hit_chance: float = 1.0 - _get_dodge_chance(target)
			hit_label.text = str(roundi(hit_chance * 100)) + "%"
			hit_label.position = world_layer.map_to_local(cursor_tile) + Vector2(6, -10)
			hit_label.visible = true
		else:
			hit_label.visible = false
	else:
		hit_label.visible = false

func _enter_ability_mode(ability_id: String) -> void:
	var ability: Dictionary = AbilityDB.get_ability(ability_id)
	if ability.is_empty():
		return
	if ability.get("requires_first_action", false) and has_acted_this_turn:
		return
	if ability.get("requires_ranged_weapon", false) and not PlayerData.is_ranged_weapon_equipped():
		return
	if not PlayerData.has_ability(ability_id):
		return
	
	var cost: Dictionary = ability.get("cost", {})
	for resource in cost.keys():
		var amount: int = cost[resource]
		match resource:
			"ap":
				if ap_remaining < amount:
					BattleManager.ap_rejected_cost = amount
					return
			"bp":
				if bp_remaining < amount:
					BattleManager.bp_rejected = true
					return
			"mp":
				if mp_budget < amount:
					return
			"sc":
				if PlayerData.get_spell_charges(ability.get("id", "")) < amount:
					return
	
	ability_instance = AbilityDB.create_ability(ability_id)
	if ability_instance == null:
		return
	
	active_ability = ability
	mode = Mode.ABILITY
	_update_floating_labels()
	ability_direction = Vector2i.ZERO
	ability_tiles.clear()
	overlay.clear_all()
	
	# Auto-aims toward the direction with the most enemies. This only works for "direction"
	# abilities, which are orthogonal left, right, top, down aiming abilities directly from the
	# player character.
	if ability_instance.get_targeting_type() == "direction":
		var best_direction: Vector2i = Vector2i.ZERO
		var best_count: int = 0
		var directions: Array = [
			Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(1, 0)
		]
		
		for dir in directions:
			var tiles: Array = ability_instance.get_target_tiles(player_tile, dir, world_layer)
			var count: int = 0
			for tile in tiles:
				if _tile_has_combatant(tile):
					count += 1
			if count > best_count:
				best_count = count
				best_direction = dir
		
		if best_direction != Vector2i.ZERO:
			ability_direction = best_direction
			_build_ability_tiles()
			
	elif ability_instance.get_targeting_type() == "line":
		var best_direction: Vector2i = Vector2i.ZERO
		var best_count: int = 0
		var directions: Array = [
			Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(-1, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(1, 1)
		]
		
		for dir in directions:
			var tiles: Array = ability_instance.get_target_tiles(player_tile, dir, world_layer)
			var count: int = 0
			for tile in tiles:
				if _tile_has_combatant(tile):
					count += 1
			if count > best_count:
				best_count = count
				best_direction = dir
		if best_direction != Vector2i.ZERO:
			ability_direction = best_direction
			_build_ability_tiles()
			
	elif ability_instance.get_targeting_type() == "touch":
		var best_direction: Vector2i = Vector2i.ZERO
		var directions: Array = [
			Vector2i(0, -1), Vector2i(0, 1),
			Vector2i(-1, 0), Vector2i(1, 0),
			Vector2i(-1, -1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(1, 1)
		]
		
		for dir in directions:
			var tile: Vector2i = player_tile + dir
			if world_layer.get_cell_source_id(tile) != -1:
				continue
			if _tile_has_combatant(tile):
				best_direction = dir
				break
		
		if best_direction != Vector2i.ZERO:
			ability_direction = best_direction
			_build_ability_tiles()
		
	elif ability_instance.get_targeting_type() == "blink":
		_build_ability_tiles()
		if ability_tiles.is_empty():
			mode = Mode.MOVE
			active_ability = {}
			ability_instance = null
			return
		
		# Places cursor on nearest target.
		var best_tile: Vector2i = ability_tiles[0]
		var best_dist: int = 999
		for tile in ability_tiles:
			var dist: int = maxi(abs(tile.x - player_tile.x), abs(tile.y - player_tile.y))
			if dist < best_dist:
				best_dist = dist
				best_tile = tile
		cursor_tile = best_tile
		_redraw_blink_movement()
		
	elif ability_instance.get_targeting_type() == "ranged":
		var weapon: Dictionary = PlayerData.get_equipped_weapon()
		var ability_range: int = active_ability.get("ability_range", weapon.get("weapon_range", 12))
		ranged_area_tiles = _calculate_ranged_area(ability_range)
		
		var best_tile: Vector2i = player_tile
		var best_dist: int = 999
		for c in combatants:
			if c == combatant or not is_instance_valid(c):
				continue
			if c.is_in_group("player"):
				continue
			var c_tile: Vector2i = world_layer.local_to_map(c.global_position)
			var dist: int = maxi(abs(c_tile.x - player_tile.x), abs(c_tile.y - player_tile.y))
			if dist < best_dist:
				best_dist = dist
				best_tile = c_tile
		cursor_tile = best_tile
		_redraw_ranged_ability()
		
	_update_floating_labels()


func _handle_ability_input() -> void:
	if active_ability.get("targeting") == "direction":
		var new_direction: Vector2i = Vector2i.ZERO
		
		if Input.is_action_just_pressed("ui_up"):
			new_direction = Vector2i(0, -1)
		elif Input.is_action_just_pressed("ui_down"):
			new_direction = Vector2i(0, 1)
		elif Input.is_action_just_pressed("ui_left"):
			new_direction = Vector2i(-1, 0)
		elif Input.is_action_just_pressed("ui_right"):
			new_direction = Vector2i(1, 0)
		
		if new_direction != Vector2i.ZERO:
			ability_direction = new_direction
			has_ability_target = false
			_build_ability_tiles()
		
		if Input.is_action_just_pressed("interact") and not ability_tiles.is_empty():
			if not has_ability_target:
				has_ability_target = true
				_redraw_ability_confirm()
			else:
				_execute_ability()
		
		if Input.is_action_just_pressed("cancel"):
			if has_ability_target:
				has_ability_target = false
				_build_ability_tiles()
			else:
				_exit_ability_mode()
				
	elif active_ability.get("targeting") == "line":
		var any_pressed: bool = (
			Input.is_action_just_pressed("ui_up") or
			Input.is_action_just_pressed("ui_down") or
			Input.is_action_just_pressed("ui_left") or
			Input.is_action_just_pressed("ui_right")
		)
		
		if any_pressed:
			var new_direction: Vector2i = Vector2i.ZERO
			if Input.is_action_pressed("ui_up"): new_direction.y -= 1
			if Input.is_action_pressed("ui_down"): new_direction.y += 1
			if Input.is_action_pressed("ui_left"): new_direction.x -= 1
			if Input.is_action_pressed("ui_right"): new_direction.x += 1
			
			if new_direction != Vector2i.ZERO:
				ability_direction = new_direction
				has_ability_target = false
				_build_ability_tiles()
				
		if Input.is_action_just_pressed("interact") and not ability_tiles.is_empty():
			if not has_ability_target:
				has_ability_target = true
				_redraw_ability_confirm()
			else:
				_execute_ability()
			
		if Input.is_action_just_pressed("cancel"):
			if has_ability_target:
				has_ability_target = false
				_build_ability_tiles()
			else:
				_exit_ability_mode()
				
	elif active_ability.get("targeting") == "touch":
		var any_pressed: bool = (
			Input.is_action_just_pressed("ui_up") or
			Input.is_action_just_pressed("ui_down") or
			Input.is_action_just_pressed("ui_left") or
			Input.is_action_just_pressed("ui_right")
		)
		
		if any_pressed:
			var new_direction: Vector2i = Vector2i.ZERO
			if Input.is_action_pressed("ui_up"): new_direction.y -= 1
			if Input.is_action_pressed("ui_down"): new_direction.y += 1
			if Input.is_action_pressed("ui_left"): new_direction.x -= 1
			if Input.is_action_pressed("ui_right"): new_direction.x += 1
			
			if new_direction != Vector2i.ZERO:
				ability_direction = new_direction
				has_ability_target = false
				_build_ability_tiles()
				
		if Input.is_action_just_pressed("interact") and not ability_tiles.is_empty():
			if not has_ability_target:
				has_ability_target = true
				_redraw_ability_confirm()
			else:
				_execute_ability()
			
		if Input.is_action_just_pressed("cancel"):
			if has_ability_target:
				has_ability_target = false
				_build_ability_tiles()
			else:
				_exit_ability_mode()

	elif active_ability.get("targeting") == "blink":
		if not has_ability_target:
			# Phase 1: selecting landing tile.
			if cursor_move_timer <= 0.0:
				var moved: bool = false
				var target_tile: Vector2i = cursor_tile
				if Input.is_action_pressed("ui_up"):
					target_tile.y -= 1
					moved = true
				elif Input.is_action_pressed("ui_down"):
					target_tile.y += 1
					moved = true
				elif Input.is_action_pressed("ui_left"):
					target_tile.x -= 1
					moved = true
				elif Input.is_action_pressed("ui_right"):
					target_tile.x += 1
					moved = true

				if moved and _is_tile_on_screen(target_tile):
					cursor_tile = target_tile
					cursor_move_timer = CURSOR_MOVE_RATE
					_build_ability_tiles()
					_redraw_blink_movement()

			if Input.is_action_just_pressed("interact") and cursor_tile in ability_tiles:
				has_ability_target = true
				blink_landing_tile = cursor_tile
				var directions: Array = [
					Vector2i(0, -1), Vector2i(0, 1),
					Vector2i(-1, 0), Vector2i(1, 0),
					Vector2i(-1, -1), Vector2i(1, -1),
					Vector2i(-1, 1), Vector2i(1, 1)
				]
				for dir in directions:
					var tile: Vector2i = blink_landing_tile + dir
					if world_layer.get_cell_source_id(tile) != -1:
						continue
					if _tile_has_combatant(tile):
						cursor_tile = tile
						break
				_redraw_blink_target_select()

			if Input.is_action_just_pressed("cancel"):
				_exit_ability_mode()

		else:
			if cursor_move_timer <= 0.0:
				var any_pressed: bool = (
					Input.is_action_pressed("ui_up") or
					Input.is_action_pressed("ui_down") or
					Input.is_action_pressed("ui_left") or
					Input.is_action_pressed("ui_right")
				)

				if any_pressed:
					var dir: Vector2i = Vector2i.ZERO
					if Input.is_action_pressed("ui_up"): dir.y -= 1
					if Input.is_action_pressed("ui_down"): dir.y += 1
					if Input.is_action_pressed("ui_left"): dir.x -= 1
					if Input.is_action_pressed("ui_right"): dir.x += 1

					if dir != Vector2i.ZERO:
						var wanted: Vector2i = blink_landing_tile + dir
						if world_layer.get_cell_source_id(wanted) == -1 and _is_tile_on_screen(wanted):
							cursor_tile = wanted
							cursor_move_timer = CURSOR_MOVE_RATE
							_redraw_blink_target_select()

			if Input.is_action_just_pressed("interact"):
				_execute_ability()

			if Input.is_action_just_pressed("cancel"):
				has_ability_target = false
				_build_ability_tiles()
				cursor_tile = blink_landing_tile
				_redraw_blink_movement()

	elif active_ability.get("targeting") == "ranged":
		if cursor_move_timer <= 0.0:
			var moved: bool = false
			var target_tile: Vector2i = cursor_tile
			if Input.is_action_pressed("ui_up"):
				target_tile.y -= 1
				moved = true
			elif Input.is_action_pressed("ui_down"):
				target_tile.y += 1
				moved = true
			elif Input.is_action_pressed("ui_left"):
				target_tile.x -= 1
				moved = true
			elif Input.is_action_pressed("ui_right"):
				target_tile.x += 1
				moved = true

			if moved and _is_tile_on_screen(target_tile):
				cursor_tile = target_tile
				cursor_move_timer = CURSOR_MOVE_RATE
				has_ability_target = false
				_redraw_ranged_ability()

		if Input.is_action_just_pressed("interact") and cursor_tile in ranged_area_tiles:
			if not has_ability_target:
				has_ability_target = true
				overlay.clear_all()
				for tile in ranged_area_tiles:
					overlay.paint_light_blue(tile)
				for tile in ranged_target_tiles:
					overlay.paint_bright_green(tile)
				overlay.paint_bright_green(cursor_tile)
				_update_floating_labels()
			else:
				_execute_ability()

		if Input.is_action_just_pressed("cancel"):
			if has_ability_target:
				has_ability_target = false
				_redraw_ranged_ability()
			else:
				_exit_ability_mode()

func _redraw_ability_confirm() -> void:
	overlay.clear_all()
	for tile in ability_tiles:
		overlay.paint_bright_green(tile)
	_update_floating_labels()

func _build_ability_tiles() -> void:
	ability_tiles = ability_instance.get_target_tiles(player_tile, ability_direction, world_layer)
	overlay.clear_all()
	for tile in ability_tiles:
		if _tile_has_combatant(tile, true):
			overlay.paint_purple(tile)
		else:
			overlay.paint_yellow(tile)
	_update_floating_labels()
	
func _execute_ability() -> void:
	var should_end_turn: bool = active_ability.get("ends_turn", false)
	var cost: Dictionary = active_ability.get("cost", {})
	for resource in cost.keys():
		match resource:
			"ap": ap_remaining -= cost[resource]
			"bp": bp_remaining -= cost[resource]
			"mp": mp_budget -= cost[resource]
			"sc": PlayerData.use_spell_charge(active_ability.get("id", ""))
			
	has_acted_this_turn = true
	CombatLog.add(combatant.name + " uses " + active_ability.get("name", "") + "!")
	animating = true
	var execute_tiles: Array = ability_tiles
	if active_ability.get("targeting") == "blink":
		execute_tiles = [blink_landing_tile, cursor_tile]
	elif active_ability.get("targeting") == "ranged":
		execute_tiles = overlay.get_line_tiles(player_tile, cursor_tile).slice(1)
	
	for tile in execute_tiles:
		var target: Node = _combatant_on_tile(tile, true)
		if target != null:
			_engage_if_needed(target)
	
	await ability_instance.execute(combatant, execute_tiles, combatants, world_layer)
	animating = false
	player_tile = world_layer.local_to_map(combatant.global_position)
	BattleManager.check_for_reinforcements()
	_exit_ability_mode()
	
	if should_end_turn:
		end_turn()
	
func _exit_ability_mode() -> void:
	mode = Mode.MOVE
	active_ability = {}
	ability_direction = Vector2i.ZERO
	ability_tiles.clear()
	active_hotbar_slot = -1
	ability_instance = null
	has_ability_target = false
	blink_landing_tile = Vector2i.ZERO
	ranged_area_tiles.clear()
	ranged_target_tiles.clear()
	cursor_tile = player_tile
	_recalculate_reachable()
	_redraw()
	
func _get_attack_range() -> int:
	if combatant.is_in_group("player"):
		var weapon: Dictionary = PlayerData.get_equipped_weapon()
		if weapon.is_empty():
			return 1
		return weapon.get("weapon_range", 1)
	else:
		return 1

func get_slot_block_reasons(slot: int) -> Array:
	var reasons: Array = []
	var ability_id: String = PlayerData.get_hotbar_ability(slot)

	if ability_id == "":
		return reasons

	if ability_id == "basic_attack":
		if bp_remaining <= 0:
			reasons.append("Not enough BP")
		return reasons

	if not PlayerData.has_ability(ability_id):
		reasons.append("Not learned")
		return reasons

	var ability: Dictionary = AbilityDB.get_ability(ability_id)

	if ability.get("requires_first_action", false) and has_acted_this_turn:
		reasons.append("Already acted this turn")

	if ability.get("requires_ranged_weapon", false) and not PlayerData.is_ranged_weapon_equipped():
		reasons.append("Requires ranged weapon")

	var cost: Dictionary = ability.get("cost", {})
	for resource in cost.keys():
		var amount: int = cost[resource]
		match resource:
			"ap":
				if ap_remaining < amount:
					reasons.append("Not enough AP")
			"bp":
				if bp_remaining < amount:
					reasons.append("Not enough BP")
			"mp":
				if mp_budget < amount:
					reasons.append("Not enough MP")
			"sc":
				if PlayerData.get_spell_charges(ability.get("id", "")) < amount:
					reasons.append("No spell charges")

	if ability.get("targeting", "") == "blink":
		var temp_instance: BaseAbility = AbilityDB.create_ability(ability_id)
		if temp_instance != null:
			var tiles: Array = temp_instance.get_target_tiles(player_tile, Vector2i.ZERO, world_layer)
			if tiles.is_empty():
				reasons.append("No valid targets")

	return reasons

func _is_tile_on_screen(tile: Vector2i) -> bool:
	# Converts the tile to its world position.
	var world_pos := world_layer.map_to_local(tile)
	
	# Get the viewport and camera.
	var viewport := combatant.get_viewport()
	
	# Converts world position to screen position. The canvas transform does this. This is a matrix
	# (another word for transforms) that is interal to Godot, which changes world coords to screen
	# pixel coords. It accounts for the camera's position, zoom, rotation, everything. So you
	# multiply it by a world position and get back where that point appears on screen. Don't ask me
	# about the maths, but basically this is saying: "take this world position, apply the camera's
	# scroll and zoom to it, and give me back where it appears on screen in pixels." The * is not a
	# regular multiplication, it is a transfor multiplication. It is a forumla with multiple steps,
	# (for example, converting fahrenheit to celsius is temp * 9/5 + 32). Its first a conversion
	# scale, then it applies the offset. This does the same for the 2D coordiantes. As in, that's
	# what the * does in this case.
	var screen_pos := viewport.get_canvas_transform() * world_pos
	
	# Get the viewport size (Adapts to aspect ratio changes!). This gives the actual screen
	# dimension in pixels, so it would be Vector2(1920, 1080) for example.
	var screen_size := viewport.get_visible_rect().size
	
	# Add margin so the cursor doesnt go to the pixel edge. The margin is -8 to account for the fact
	# that the viewport counts from the centre of the tile, which is 8 pixels off. Making the margin
	# -8 ensures that the max you are able to go out of bounds of the screen is -8 pixels, meaning 
	# the cursor can go to the very edges of the screen but not past the edges. 
	var margin := -8.0

	# Screen coords starts at 0,0 in the top left corner. In the most popular resolution, the
	# bottom right corner of the screen would be 1920,1080. Read on under the returns checks for
	# more info...
	return (
		# "is the tile far enough from the left edge?" If margin is 32, the tile must be at least
		# 32 pixels from the left.
		screen_pos.x >= margin
		#"is the tile far enough from the right edge?" On a 1920-wide screen with margin 32, the
		# tile must be at pixel 1888 or less.
		and screen_pos.x <= screen_size.x - margin
		# Same thing but for the top edge.
		and screen_pos.y >= margin
		# And bottom edge.
		and screen_pos.y <= screen_size.y - margin
		# Clarifying example if the screen was 1920x1080 and margin 32 (names changed to values):
		# return (
		#     screen_pos.x >= 32
		#     and screen_pos.x <= 1888
		#     and screen_pos.y >= 32
		#     and screen_pos.y <= 1048
		# )
		# So the current screen (cursor) position for x must be between 32 and 1888, and for y
		# between 32 and 1048
	)

func _redraw_blink_movement() -> void:
	overlay.clear_all()
	overlay.paint_soft_green(ability_tiles)
	if cursor_tile in ability_tiles:
		overlay.paint_yellow(cursor_tile)
	else:
		overlay.paint_grey(cursor_tile)
	_update_floating_labels()

# Gives the last waypoint, if nothing there, gives player position. This lets us move from that
# point.
func _path_origin() -> Vector2i:
	if waypoints.is_empty():
		return player_tile
	return waypoints.back()

# MP remaining after the chosen path.
func _remaining_mp() -> int:
	return mp_budget - path_cost
	
func _on_confirm() -> void:
	# If the cursor is on the final waypoint, execute move.
	if not waypoints.is_empty() and cursor_tile == waypoints.back():
		await _execute_move()
		return
		
	# If that is not the case, tried to add a new waypoint where the cursor is.
	var blocked := _combatant_tiles()
	# This gets the amount that will be traversed. := means inferred value, so it gets that
	# something is an int if you give it a 5, and gets something is a float if you give it 5.0.
	# Here we declare a segment, and use our find_path function from the battle_overlay to get the
	# path we need (and the find_path function functions with the help of astargrid, but also does
	# other things, like look at the world_layer and checks for blocked tiles, remaining MP, etc).
	var segment := overlay.find_path(_path_origin(), cursor_tile, world_layer, blocked, _remaining_mp())
	
	# Invalid if there is no path or if the path doesnt go anywhere.
	if segment.size() < 2:
		return
		
	var segment_cost := overlay.path_mp_cost(segment)
	
	# Reject if it would exceed remaining MP.
	if segment_cost > _remaining_mp():
		return
		
	# Make the waypoint!
	waypoints.append(cursor_tile)
	# Append the segment minus its first tile. It duplicates the previous end point. This means
	# that the path is added on to what already exists instead of on top of it.
	if full_path.is_empty():
		full_path = segment.duplicate()
	else:
		# Every time a segment is added to the end of the current path (which is the latest
		# waypoint, the last waypoint), exactly one tile at its start overlaps with what's 
		# already in full_path, and it's always at index 0 of that new segment. So always  
		# skipping index 0 of the new segment is the right move, it just prevents overlap.
		for i in range(1, segment.size()):
			full_path.append(segment[i])
			
	path_cost += segment_cost	
	_recalculate_reachable()
	_redraw()
		
func _on_cancel() -> void:
	if waypoints.is_empty():
		return

	# Remove the last waypoint. Rebuild the path from the start. Note: pop_back() removes and
	# returns the last element of an array. pop_front removes and returns the first element.
	waypoints.pop_back()
	_rebuild_path()
	_recalculate_reachable()
	_redraw()

# Makes a new full_path and path_cost from the current waypoint array. It makes a whole new path
# from scratch as its just easier and less prone to errors. So it starts from the player tile,
# rebuilding a path to each waypoint. 
func _rebuild_path() -> void:
	full_path.clear()
	path_cost = 0
	var origin := player_tile
	var blocked := _combatant_tiles()
	for wp in waypoints:
		var segment := overlay.find_path(origin, wp, world_layer, blocked, mp_budget)
		if segment.size() < 2:
			continue
		if full_path.is_empty():
			full_path = segment.duplicate()
		else:
			# This is the same as on confirm, but since we clear the full path at the start of
			# this function, it builds the path from scratch.
			for i in range(1, segment.size()):
				full_path.append(segment[i])
		path_cost += overlay.path_mp_cost(segment)
		origin = wp
		
func _execute_move() -> void:
	# Just teleports the player for now.
	if not waypoints.is_empty():
		var dest: Vector2i = waypoints.back()
		# Note: Map to local means that you take a tiles cord and get the actual pixel position in
		# the world, of that tiles centre. Local to map does the opposite, and takes a world
		# position (Like Vector2 72,-56) and returns the tile which that falls in (Like Vector 2i
		# (4, -3)). Btw i in Vector2i stands for int, regular Vector2 holds floats. Vector2 is for
		# world position as pixels can be fractional, while Vector2i is an in because tiles are a
		# grid, they have no float in betweens. So, things the players sees, like animation, can
		# use floats, but since it is grid based the logic is entirly based on int.
		# Above is a left over from when I used map_to_local as I was bascially teleporting the
		# combatants.
		animating = true
		await _animate_movement(full_path)
		animating = false
		player_tile = dest
	
	# Take away the MP used.
	mp_budget -= path_cost
	
	has_acted_this_turn = true
	
	CombatLog.add(combatant.name + " moves. (" + str(path_cost) + " MP, " + str(mp_budget) + " MP remaining)")
	
	# Clear the path and waypoints, move is done.
	waypoints.clear()
	full_path.clear()
	path_cost = 0
	
	# Reset the cursor to the new position.
	cursor_tile = player_tile
	
	# Recalculate the reachables with the remaining MP amount.
	_recalculate_reachable()
	_redraw()
	BattleManager.check_for_reinforcements()

func _recalculate_reachable() -> void:
	var blocked := _combatant_tiles()
	reachable = overlay.calculate_reachable(_path_origin(), _remaining_mp(), world_layer, blocked)
	
func _redraw() -> void:
	if not BattleManager.active:
		return
	overlay.clear_all()
	if mode == Mode.ATTACK:
		_redraw_attack()
		return
	# Paint all reachable tiles soft green.
	if reachable.size() > 1:
		overlay.paint_soft_green(reachable.keys())
	# Mid green for commited path.
	if full_path.size() > 0:
		overlay.paint_mid_green(full_path)
	# Bright green for all waypoints except the final one.
	for i in range(waypoints.size()):
		if i < waypoints.size() - 1:
			overlay.paint_bright_green(waypoints[i])
	# The final waypoint.
	if not waypoints.is_empty():
		overlay.paint_final_waypoint(waypoints.back())
	# Paint the cursor tile on top with the right colour.
	_paint_cursor()
	_update_floating_labels()
	# Show MP cost when hobering over a reachable tile.
	if reachable.has(cursor_tile) and cursor_tile != player_tile:
		var total_cost: int = path_cost + reachable[cursor_tile]
		mp_label.text = str(total_cost) + "MP"
		mp_label.position = world_layer.map_to_local(cursor_tile)
		mp_label.visible = true
	else:
		mp_label.visible = false

func _calculate_ranged_area(weapon_range: int) -> Array:
	var tiles: Array = []
	var max_dist: int = weapon_range / 2 + 1
	for dx in range(-max_dist, max_dist + 1):
		for dy in range(-max_dist, max_dist + 1):
			var mn: int = mini(abs(dx), abs(dy))
			var mx: int = maxi(abs(dx), abs(dy))
			var cost: int = mn * 3 + (mx - mn) * 2
			if cost > weapon_range:
				continue
			var tile: Vector2i = player_tile + Vector2i(dx, dy)
			var line: Array = overlay.get_line_tiles(player_tile, tile)
			var blocked: bool = false
			for i in range(1, line.size()):
				if world_layer.get_cell_source_id(line[i]) != -1:
					blocked = true
					break
			if not blocked:
				tiles.append(tile)
	return tiles

func _paint_cursor() -> void:
	if not waypoints.is_empty() and cursor_tile == waypoints.back():
		return
	if reachable.has(cursor_tile) and cursor_tile != player_tile:
		overlay.paint_yellow(cursor_tile)
	else:
		overlay.paint_grey(cursor_tile)

func _tile_has_combatant(tile: Vector2i, include_non_combat: bool = false) -> bool:
	for c in combatants:
		if c == combatant:
			continue
		if world_layer.local_to_map(c.global_position) == tile:
			return true
	if include_non_combat:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or e in combatants:
				continue
			if world_layer.local_to_map(e.global_position) == tile:
				return true
	return false

func _combatant_tiles() -> Array:
	var tiles: Array = []
	for c in combatants:
		if c == combatant:
			continue
		# Appends the position of the combatant.
		tiles.append(world_layer.local_to_map(c.global_position))
	return tiles
	
# ============================================================
# ATTACK
# ============================================================

# Switch from movement planning into attack aiming.
func _enter_attack_mode() -> void:
	if bp_remaining <= 0:
		BattleManager.bp_rejected = true
		return
	# Abandon any half-planned movement; choosing to attack is a different action.
	waypoints.clear()
	full_path.clear()
	path_cost = 0
	
	mode = Mode.ATTACK
	_update_floating_labels()
	has_target = false
	_build_attack_range()
	
	if PlayerData.is_ranged_weapon_equipped():
		var weapon: Dictionary = PlayerData.get_equipped_weapon()
		var weapon_range: int = weapon.get("weapon_range", 12)
		var penetration: int = weapon.get("penetration", 0)
		ranged_area_tiles = _calculate_ranged_area(weapon_range)
		
		# Auto-aim, finds the cursor target that hits the most enemies.
		var best_cursor: Vector2i = player_tile
		var best_count: int = 0
		var best_dist: int = 999
		
		for c in combatants:
			if c == combatant or not is_instance_valid(c):
				continue
			if c.is_in_group("player"):
				continue
			var c_tile: Vector2i = world_layer.local_to_map(c.global_position)
			var line: Array = overlay.get_line_tiles(player_tile, c_tile)
			var count: int = 0
			var range_used: int = 0
			var pen_remaining: int = penetration
			
			for i in range(1, line.size()):
				var tile: Vector2i = line[i]
				var prev: Vector2i = line[i - 1]
				var dx: int = abs(tile.x - prev.x)
				var dy: int = abs(tile.y - prev.y)
				range_used += 3 if (dx != 0 and dy != 0) else 2
				if range_used > weapon_range:
					break
				if world_layer.get_cell_source_id(tile) != -1:
					break
				if _tile_has_combatant(tile):
					count += 1
					if pen_remaining <= 0:
						break
					pen_remaining -= 1
			
			var dist: int = maxi(abs(c_tile.x - player_tile.x), abs(c_tile.y - player_tile.y))
			if count > best_count or (count == best_count and dist < best_dist):
				best_count = count
				best_cursor = c_tile
				best_dist = dist
		
		cursor_tile = best_cursor
		_redraw_ranged_attack()
		return
	
	# Snap the cursor onto the first adjacent enemy if there is one, so the common
	# "one enemy right next to me" case is just: press 1, E, E.
	cursor_tile = player_tile
	for t in attack_range_tiles:
		if _tile_has_combatant(t):
			cursor_tile = t
			break
	_redraw()

# Back out of attack mode, returning to movement planning.
func _exit_attack_mode() -> void:
	mode = Mode.MOVE
	has_target = false
	attack_range_tiles.clear()
	ranged_area_tiles.clear()
	cursor_tile = player_tile
	active_hotbar_slot = -1
	_recalculate_reachable()
	_redraw()

# Build the tiles a basic attack can reach: the 8 around the player. Walls are skipped
# so the highlight stays clean (you can't melee into a wall).
func _build_attack_range() -> void:
	attack_range_tiles.clear()
	var attack_range: int = _get_attack_range()
	for dx in range(-attack_range, attack_range + 1):
		for dy in range(-attack_range, attack_range + 1):
			if dx == 0 and dy == 0:
				continue
			var t: Vector2i = player_tile + Vector2i(dx, dy)
			if world_layer.get_cell_source_id(t) != -1:
				continue
			attack_range_tiles.append(t)

# First E chooses a target, second E (without moving) confirms and resolves it.
func _on_attack_confirm() -> void:
	# Ranged attack.
	if PlayerData.is_ranged_weapon_equipped():
		if not has_target:
			if cursor_tile in ranged_area_tiles:
				has_target = true
				overlay.clear_all()
				for tile in ranged_area_tiles:
					overlay.paint_light_blue(tile)
				for tile in ranged_target_tiles:
					overlay.paint_bright_green(tile)
				overlay.paint_bright_green(cursor_tile)
				_update_floating_labels()
			return
		_execute_ranged_attack()
		return
	
	# Melee attack.
	if not has_target:
		if cursor_tile in attack_range_tiles:
			attack_target = cursor_tile
			has_target = true
			_redraw()
		return
	_execute_attack()

# Cancel (Q): first unlocks the target; if there's nothing to unlock, leaves attack mode.
func _on_attack_cancel() -> void:
	if has_target:
		has_target = false
		if PlayerData.is_ranged_weapon_equipped():
			_redraw_ranged_attack()
		else:
			_redraw()
	else:
		_exit_attack_mode()

# Apply the damage and end the turn.
func _execute_attack() -> void:
	var target: Node = _combatant_on_tile(attack_target, true)
	if target == null:
		CombatLog.add(combatant.name + " attacks but hits nothing!")
		bp_remaining -= 1
		has_acted_this_turn = true
		_exit_attack_mode()
		return

	_try_attack(target)

	if combatant.is_in_group("player") and PlayerData.is_dual_wielding():
		is_offhand_attack = true
		_try_attack(target)
		is_offhand_attack = false

	bp_remaining -= 1
	has_acted_this_turn = true
	_exit_attack_mode()

func _execute_ranged_attack() -> void:
	var weapon: Dictionary = PlayerData.get_equipped_weapon()
	var weapon_range: int = weapon.get("weapon_range", 12)
	var penetration_remaining: int = weapon.get("penetration", 0)
	
	var line: Array = overlay.get_line_tiles(player_tile, cursor_tile)
	var range_used: int = 0
	var targets_hit: Array = []
	
	# Walk the projectile path, collecting targets.
	for i in range(1, line.size()):
		var tile: Vector2i = line[i]
		var prev: Vector2i = line[i - 1]
		var dx: int = abs(tile.x - prev.x)
		var dy: int = abs(tile.y - prev.y)
		range_used += 3 if (dx != 0 and dy != 0) else 2
		if range_used > weapon_range:
			break
		if world_layer.get_cell_source_id(tile) != -1:
			break
		var target: Node = _combatant_on_tile(tile, true)
		if target != null:
			targets_hit.append(target)
			if penetration_remaining <= 0:
				break
			penetration_remaining -= 1
	
	# Resolve the attack.
	if targets_hit.is_empty():
		CombatLog.add(combatant.name + " fires but hits nothing!")
	else:
		for target in targets_hit:
			_engage_if_needed(target)
			_try_attack(target)
	
	has_acted_this_turn = true
	bp_remaining -= 1
	has_target = false
	_exit_attack_mode()

func _roll_damage() -> int:
	if combatant.is_in_group("player"):
		var weapon: Dictionary = {}
		if is_offhand_attack:
			weapon = PlayerData.get_offhand_weapon()
		else:
			weapon = PlayerData.get_equipped_weapon()
		if weapon.is_empty():
			return 1
		var result: Dictionary = ItemDB.calculate_damage(weapon, PlayerData.get_stats_dict())
		# Randi range is a builtin that gives back a random int between two values.
		var damage: int = randi_range(result["min"], result["max"])
		# Second attack of dual wield does 50% damage.
		if is_offhand_attack:
			damage = roundi(damage * 0.5)
		return damage
	else:
		return randi_range(combatant.stats.base_damage_min, combatant.stats.base_damage_max)

func _try_attack(target: Node) -> void:
	# Blink dodge: separate roll before regular dodge.
	if target.is_in_group("player") and PlayerData.get_status_stacks("blink_dodge") > 0:
		if randf() < 0.33:
			CombatLog.add(target.name + " blink-dodges " + combatant.name + "'s attack!")
			PlayerData.remove_status_stacks("blink_dodge", 1)
			return
	var hit_chance: float = CombatantStats.hit_chance_for(target, 0.0)
	if randf() >= hit_chance:
		CombatLog.add(combatant.name + " attacks " + target.name + " but misses!")
		return
	
	# Shield block check (only if target is the player).
	if target.is_in_group("player"):
		var shield: Dictionary = PlayerData.get_equipped_shield()
		if not shield.is_empty():
			var block_roll: float = randf()
			if block_roll < shield.get("block_chance", 0.0):
				CombatLog.add(target.name + " blocks " + combatant.name + "'s attack!")
				return
	
	# Damage.
	var damage: int = _roll_damage()
	_apply_damage(target, damage)

# Deals damage to whoever is on the tile. Player HP lives on the PlayerData autoload,
# enemies track their own HP on their node, so we branch on the group.
func _apply_damage(target: Node, amount: int) -> void:
	if target.is_in_group("player"):
		PlayerData.take_damage(amount)
		CombatLog.add(combatant.name + " hits Player for " + str(amount) + " damage. (" + str(PlayerData.current_hp) + "/" + str(PlayerData.max_hp) + " HP)")
		if PlayerData.current_hp <= 0:
			BattleManager.remove_combatant(target)
	else:
		# The enemy node handles its own HP and death (removing itself from the
		# battle and freeing itself when it hits 0).
		target.take_damage(amount)
		CombatLog.add(combatant.name + " hits " + target.name + " for " + str(amount) + " damage.")

# Returns the combatant node standing on a tile, or null. Skips the player so you
# can never target yourself.
func _combatant_on_tile(tile: Vector2i, include_non_combat: bool = false) -> Node:
	for c in combatants:
		if c == combatant:
			continue
		if world_layer.local_to_map(c.global_position) == tile:
			return c
	if include_non_combat:
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or e in combatants:
				continue
			if world_layer.local_to_map(e.global_position) == tile:
				return e
	return null

# Draws the attack overlay: the whole range in red, the hover/target state on top.
func _redraw_attack() -> void:
	if has_target:
		overlay.paint_bright_green(attack_target)
	elif cursor_tile != player_tile:
		if cursor_tile not in attack_range_tiles:
			return
		elif _tile_has_combatant(cursor_tile, true):
			overlay.paint_purple(cursor_tile)
		else:
			overlay.paint_yellow(cursor_tile)
	_update_floating_labels()

func _draw_ranged_path(path_range: int, penetration: int) -> void:
	overlay.clear_all()
	ranged_target_tiles.clear()
	
	for tile in ranged_area_tiles:
		overlay.paint_light_blue(tile)
	
	if cursor_tile == player_tile:
		overlay.paint_grey(cursor_tile)
		_update_floating_labels()
		return
	
	var path_blocked: bool = false
	var range_used: int = 0
	var penetration_remaining: int = penetration
	var line: Array = overlay.get_line_tiles(player_tile, cursor_tile)
	
	for i in range(1, line.size()):
		var tile: Vector2i = line[i]
		var prev: Vector2i = line[i - 1]
		var dx: int = abs(tile.x - prev.x)
		var dy: int = abs(tile.y - prev.y)
		range_used += 3 if (dx != 0 and dy != 0) else 2
		
		if path_blocked:
			overlay.paint_red(tile)
			continue
		if world_layer.get_cell_source_id(tile) != -1:
			overlay.paint_red(tile)
			path_blocked = true
			continue
		if range_used > path_range:
			overlay.paint_red(tile)
			path_blocked = true
			continue
		if _tile_has_combatant(tile, true):
			overlay.paint_purple(tile)
			ranged_target_tiles.append(tile)
			if penetration_remaining <= 0:
				path_blocked = true
			else:
				penetration_remaining -= 1
			continue
		overlay.paint_yellow(tile)
	
	_update_floating_labels()
	
func _redraw_ranged_attack() -> void:
	var weapon: Dictionary = PlayerData.get_equipped_weapon()
	_draw_ranged_path(weapon.get("weapon_range", 12), weapon.get("penetration", 0))
	
func _redraw_ranged_ability() -> void: 
	var weapon: Dictionary = PlayerData.get_equipped_weapon()
	var ability_range: int = active_ability.get("ability_range", weapon.get("weapon_range", 12))
	var ability_pen: int = active_ability.get("penetration", 0)
	_draw_ranged_path(ability_range, ability_pen)

func _redraw_blink_target_select() -> void:
	overlay.clear_all()
	overlay.paint_bright_green(blink_landing_tile)
	if _tile_has_combatant(cursor_tile, true):
		overlay.paint_purple(cursor_tile)
	else:
		overlay.paint_yellow(cursor_tile)
	_update_floating_labels()

func end_turn() -> void:
	overlay.clear_all()
	turn_finished.emit()
	
## AI LOGIC ##
func _run_ai() -> void:
	var target := _find_nearest_target()
	if target == null:
		turn_finished.emit()
		return
		
	var target_tile := world_layer.local_to_map(target.global_position)
	
	# If someone is adjescent, attack and end turn.
	if _is_adjacent(player_tile, target_tile):
		if bp_remaining > 0:
			_try_attack(target)
			bp_remaining -= 1
		turn_finished.emit()
		return
		
	# Find the best tile to move to.
	var destination := _find_best_move(target_tile)
	
	if destination != player_tile:
		var blocked := _combatant_tiles()
		var path := overlay.find_path(player_tile, destination, world_layer, blocked, mp_budget)
		# For now it just teleports to the destination. Later we can use the path var above to add
		# animation.
		await _animate_movement(path)
		player_tile = destination
		# This takes away the cost of the move to that tile from the mp_budget. "reachable" checks
		# the cost and "destination" is the tile it uses to calculate that cost.
		# This var is specifically made for the combat log, so that we can show how much MP was
		# used. If it was mp_budget -= reachable[destination], the amount would not be stored
		# anywhere and we could not display it. We could just grab it from the dictionary again, but
		# its more clean to store it locally.
		var move_cost: int = reachable[destination]
		mp_budget -= move_cost
		CombatLog.add(combatant.name + " moves. (" + str(move_cost) + " MP)")
		BattleManager.check_for_reinforcements()
		
	# After moving, it checks if target is adjacent and attacks.
	if _is_adjacent(player_tile, target_tile) and bp_remaining > 0:
		_try_attack(target)
		bp_remaining -= 1
	
	turn_finished.emit()
	
func _find_nearest_target() -> Node:
	var best_target: Node = null
	var best_distance: float = 999999.0
	
	for c in combatants:
		if c == combatant:
			continue
		# Melee behaviour targets players and allies.
		if c.is_in_group("player") or c.is_in_group("ally"):
			var c_tile := world_layer.local_to_map(c.global_position)
			var dist := _tile_distance(player_tile, c_tile)
			if dist < best_distance:
				best_distance = dist
				best_target = c
				
	return best_target
	
func _find_best_move(target_tile: Vector2i) -> Vector2i:
	# First it tries to reach a tile adjacent to the target.
	var adjacent := _get_adjacent_tiles(target_tile)
	var best_tile: Vector2i = player_tile
	var best_cost: int = 999999
	
	for tile in adjacent:
		if reachable.has(tile) and reachable[tile] < best_cost:
			best_tile = tile
			best_cost = reachable[tile]
			
		if best_tile != player_tile:
			return best_tile
			
	# If ye can't reach the target, finds a real path using a huge amount of fake MP to get the
	# full route around the walls/obsticles.
	var blocked := _combatant_tiles()
	blocked.erase(target_tile)
	var search_budget: int = int(_tile_distance(player_tile, target_tile))
	var path := overlay.find_path(player_tile, target_tile, world_layer, blocked, search_budget)
				
	if path.is_empty():
		return player_tile
		
	# Walks along the path as far as real MP allows.
	var furthest: Vector2i = player_tile
	for tile in path:
		if reachable.has(tile):
			furthest = tile
			
	return furthest

func _get_adjacent_tiles(tile: Vector2i) -> Array:
	var tiles: Array = []
	var attack_range: int = _get_attack_range()
	for dx in range(-attack_range, attack_range + 1):
		for dy in range(-attack_range, attack_range + 1):
			if dx == 0 and dy == 0:
				continue
			var t := tile + Vector2i(dx, dy)
			if world_layer.get_cell_source_id(t) != -1:
				continue
			tiles.append(t)
	return tiles
	
func _is_adjacent(from: Vector2i, to: Vector2i) -> bool:
	var attack_range: int = _get_attack_range()
	return from != to and abs(from.x - to.x) <= attack_range and abs(from.y - to.y) <= attack_range
	
func _tile_distance(a: Vector2i, b: Vector2i) -> float:
	var dx: float = abs(a.x - b.x)
	var dy: float = abs(a.y - b.y)
	var mn: float = min(dx, dy)
	var mx: float = max(dx, dy)
	return mn * 3.0 + (mx - mn) * 2.0

func _animate_movement(path: Array) -> void:
	# Creates a tween for the combatant.
	var tween := combatant.create_tween()
	
	# For each tile in the path (Skipping the first (0) as that's where we start).
	for i in range(1, path.size()):
		var world_pos := world_layer.map_to_local(path[i])
		# This bascially means move from your global position to world_pos (next part of path) in
		# 0.07 seconds.
		tween.tween_property(combatant, "global_position", world_pos, 0.1)
	
	# Wait for the tween to finish before continuing.
	await tween.finished

func _get_dodge_chance(target: Node) -> float:
	if target.is_in_group("player"):
		return 0.05 * PlayerData.dexterity
	return target.stats.get_dodge_chance()

func _targeted_enemy_tiles() -> Array:
	var result: Array = []
	if mode == Mode.ATTACK:
		if PlayerData.is_ranged_weapon_equipped():
			for tile in ranged_target_tiles:
				result.append(tile)
		else:
			if _tile_has_combatant(cursor_tile, true):
				result.append(cursor_tile)
	elif mode == Mode.ABILITY:
		if active_ability.get("targeting") == "blink" and has_ability_target:
			if _tile_has_combatant(cursor_tile, true):
				result.append(cursor_tile)
		elif active_ability.get("targeting") == "ranged":
			for tile in ranged_target_tiles:
				result.append(tile)
		else:
			for tile in ability_tiles:
				if _tile_has_combatant(tile, true):
					result.append(tile)
	return result

func _hit_chance_against(target: Node) -> float:
	if mode == Mode.ABILITY and ability_instance != null:
		return ability_instance.get_hit_chance(target)
	return CombatantStats.hit_chance_for(target, 0.0)
	
func _update_hit_labels() -> void:
	var tiles: Array = _targeted_enemy_tiles()
	while hit_labels.size() < tiles.size():
		hit_labels.append(_create_floating_label())
	for i in range(hit_labels.size()):
		if i < tiles.size():
			var target: Node = _combatant_on_tile(tiles[i], true)
			if target == null:
				hit_labels[i].visible = false
				continue
			var hit_chance: float = _hit_chance_against(target)
			hit_labels[i].text = str(roundi(hit_chance * 100)) + "%"
			hit_labels[i].position = world_layer.map_to_local(tiles[i]) + Vector2(6, -10)
			hit_labels[i].visible = true
		else:
			hit_labels[i].visible = false

func _engage_if_needed(target: Node) -> void:
	if target.is_in_group("enemy") and target not in combatants:
		BattleManager.add_combatant(target)
