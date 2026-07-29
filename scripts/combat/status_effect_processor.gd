class_name StatusEffectProcessor
extends RefCounted

const HIT_FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const BURN_TICK: PackedScene = preload("res://scenes/effects/burn_tick_effect.tscn")

var combatant: Node = null
var combatants: Array = []
var world_layer: TileMapLayer = null

# Processes all active status effects for the combatant. Returns true if the combatant survived.
func process(p_combatant: Node, p_combatants: Array, p_world_layer: TileMapLayer) -> bool:
	combatant = p_combatant
	combatants = p_combatants
	world_layer = p_world_layer

	await _process_focus()
	await _process_fire()

	# Fire may have killed them, and the await above gives the queue_free time to land.
	if not _is_alive():
		return false

	_process_blink_dodge()

	return _is_alive()
	
# ============================================================
# FOCUS
# ============================================================
func _process_focus() -> void:
	if not combatant.is_in_group("player"):
		return
	if PlayerData.pending_focus.is_empty():
		return

	var focus_data: Dictionary = PlayerData.pending_focus
	PlayerData.pending_focus = {}

	var reticle: Node = focus_data.get("reticle")
	var target: Node = focus_data.get("target")

	if target == null or not is_instance_valid(target):
		CombatLog.add(combatant.name + "'s focused shot finds no target!")
		await _resolve_focus_reticle(reticle, false)
		return

	var alive: bool = true
	if target.is_in_group("player"):
		alive = PlayerData.current_hp > 0
	else:
		alive = target.current_hp > 0
	if not alive:
		CombatLog.add(combatant.name + "'s focus target has already fallen!")
		await _resolve_focus_reticle(reticle, false)
		return

	var base_damage: int = focus_data.get("base_damage", 1)
	var damage_percent: float = focus_data.get("damage_percent", 2.0)
	var crit_chance: float = focus_data.get("crit_chance", 0.10)
	var crit_percent: float = focus_data.get("crit_percent", 5.0)
	var hit_modifier: float = focus_data.get("hit_modifier", 0.0)

	var is_crit: bool = randf() < crit_chance
	if is_crit:
		damage_percent = crit_percent

	# Use a temporary ability instance so we get the full arrow + effects pipeline.
	# Created before the hit roll so the miss path can use it too.
	var ability_instance: BaseAbility = AbilityDB.create_ability("focus")
	ability_instance.attacker_position = combatant.global_position
	ability_instance.caster = combatant

	var hit_chance: float = CombatantStats.hit_chance_for(target, hit_modifier)
	if randf() >= hit_chance:
		CombatLog.add(combatant.name + "'s focused shot misses " + target.name + "!")
		CombatEffects.play_dodge_reaction(target, combatant.global_position)
		await ability_instance.play_miss_projectile(target.global_position, target.get_parent())
		await _resolve_focus_reticle(reticle, false)
		return

	var final_damage: int = maxi(1, roundi(base_damage * damage_percent))
	if is_crit:
		CombatLog.add("CRITICAL! " + combatant.name + "'s focused shot hits " + target.name + " for " + str(final_damage) + "!")
	else:
		CombatLog.add(combatant.name + "'s focused shot hits " + target.name + " for " + str(final_damage) + "!")

	await _resolve_focus_reticle(reticle, true)
	await ability_instance._deal_damage(target, final_damage)
	
func _resolve_focus_reticle(reticle: Node, landed: bool) -> void:
	if reticle == null or not is_instance_valid(reticle):
		return

	var sprite: AnimatedSprite2D = reticle.get_node_or_null("Sprite")
	if sprite == null:
		reticle.queue_free()
		return

	if landed:
		var flash_material: ShaderMaterial = ShaderMaterial.new()
		flash_material.shader = HIT_FLASH_SHADER
		flash_material.set_shader_parameter("flash_amount", 1.0)
		sprite.material = flash_material
		await world_layer.get_tree().create_timer(0.12).timeout
	else:
		var fade_tween: Tween = sprite.create_tween()
		fade_tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
		await fade_tween.finished

	if is_instance_valid(reticle):
		reticle.queue_free()
	
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

	# Burn animation — damage lands partway through it.
	var fx: AnimatedSprite2D = CombatEffects.spawn_effect(BURN_TICK, world_layer.get_parent(), combatant.global_position)
	var burn_time: float = CombatEffects.effect_duration(fx)
	await world_layer.get_tree().create_timer(burn_time * 0.2).timeout

	# Deals damage.
	if combatant.is_in_group("player"):
		PlayerData.take_damage(fire_damage)
		if PlayerData.current_hp <= 0:
			BattleManager.remove_combatant(combatant)
	else:
		combatant.take_damage(fire_damage)

	if _is_alive():
		# Burn has no attacker, so pick a direction at random. Cardinals only, so the
		# 2px nudge lands on whole pixels.
		var dirs: Array = [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
		var push: Vector2 = dirs[randi() % dirs.size()]
		await CombatEffects.play_hit_reaction(combatant, combatant.global_position - push * 8.0, true)
		_remove_stacks("fire", 1)
		_try_spread_fire(fire_stacks)
	else:
		await world_layer.get_tree().create_timer(burn_time * 0.8).timeout
		
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
			CombatEffects.float_label("Fire!", world_layer.get_parent(), target.global_position, Color(0.855, 0.123, 0.0, 1.0))

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
	
func _process_blink_dodge() -> void:
	if not combatant.is_in_group("player"):
		return
	if _get_stacks("blink_dodge") > 0:
		_remove_stacks("blink_dodge", 1)
		CombatLog.add("Blink dodge fades.")

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
