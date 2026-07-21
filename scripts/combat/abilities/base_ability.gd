class_name BaseAbility
extends  RefCounted

const BLOOD_EFFECT: PackedScene = preload("res://scenes/effects/blood_effect.tscn")
const HIT_FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const ARROW_EFFECT: PackedScene = preload("res://scenes/effects/arrow_projectile.tscn")
const ARROW_SPEED: float = 240.0

var data: Dictionary = {}
var attacker_position: Vector2 = Vector2.ZERO
var attack_direction: Vector2i = Vector2i.ZERO

func setup(ability_data: Dictionary) -> void:
	data = ability_data
	
func get_targeting_type() -> String:
	return data.get("targeting", "")
	
# Override in each ability: return which tiles are affected.
func get_target_tiles(player_tile: Vector2i, direction: Vector2i, world_layer: TileMapLayer) -> Array:
	return []
	
# Override in each ability: do the thing.
func execute(caster: Node, tiles: Array, all_combatants: Array, world_layer: TileMapLayer) -> void:
	pass

# Find who is standing on a tile.
func combatant_on_tile(tile: Vector2i, all_combatants: Array, world_layer: TileMapLayer) -> Node:
	for c in all_combatants:
		if world_layer.local_to_map(c.global_position) == tile:
			return c
	for e in world_layer.get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e in all_combatants:
			continue
		if world_layer.local_to_map(e.global_position) == tile:
			return e
	return null
	
# Roll weapon damage for the caster.
func roll_weapon_damage(caster: Node) -> int:
	if caster.is_in_group("player"):
		var weapon: Dictionary = PlayerData.get_equipped_weapon()
		if weapon.is_empty():
			return 1
		var result: Dictionary = ItemDB.calculate_damage(weapon, PlayerData.get_stats_dict())
		return randi_range(result["min"], result["max"])
	else:
		return randi_range(caster.stats.base_damage_min, caster.stats.base_damage_max)

func get_hit_modifier() -> float:
	return data.get("hit_modifier", 0.0)
	
func get_hit_chance(target: Node) -> float:
	return CombatantStats.hit_chance_for(target, get_hit_modifier())
	
func _deal_damage(target: Node, amount: int) -> void:
	var hit_pos: Vector2 = target.global_position
	var effect_parent: Node = target.get_parent()
	var is_player: bool = target.is_in_group("player")

	if not is_player and data.get("requires_ranged_weapon", false):
		await _fly_arrow(attacker_position, hit_pos, effect_parent)

	if not is_player:
		await effect_parent.get_tree().create_timer(0.04).timeout

		if data.get("causes_blood", true):
			var blood: AnimatedSprite2D = BLOOD_EFFECT.instantiate()
			blood.process_mode = Node.PROCESS_MODE_ALWAYS
			effect_parent.add_child(blood)
			blood.global_position = hit_pos

	if is_player:
		PlayerData.take_damage(amount)
	else:
		target.take_damage(amount)

	if not is_player and is_instance_valid(target):
		await _play_hit_reaction(target)
		
func _apply_status_effect(target: Node, effect_id: String, stacks: int) -> void:
	if target.is_in_group("player"):
		PlayerData.add_status_effect(effect_id, stacks)
	else:
		target.add_status_effect(effect_id, stacks)
		
func _engage_if_needed(target: Node) -> void:
	if target.is_in_group("enemy") and target not in BattleManager.combatants:
		BattleManager.add_combatant(target)

func _get_target_sprite(target: Node) -> CanvasItem:
	for child in target.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null

func _play_hit_reaction(target: Node) -> void:
	var sprite: CanvasItem = _get_target_sprite(target)
	if sprite == null:
		return

	var original_pos: Vector2 = target.global_position
	var dir: Vector2 = (target.global_position - attacker_position).normalized()
	var nudge_offset: Vector2 = dir * 2.0

	var shader_mat: ShaderMaterial = ShaderMaterial.new()
	shader_mat.shader = HIT_FLASH_SHADER
	var old_material: Material = sprite.material
	sprite.material = shader_mat

	var flash_set: Callable = func(val: float) -> void:
		shader_mat.set_shader_parameter("flash_amount", val)

	flash_set.call(1.0)

	# Flash.
	var flash_tween: Tween = target.create_tween()
	flash_tween.tween_method(flash_set, 1.0, 0.0, 0.05)
	flash_tween.tween_method(flash_set, 0.0, 1.0, 0.05)
	flash_tween.tween_method(flash_set, 1.0, 0.0, 0.05)

	# Nudge — separate tween, starts on the same frame.
	var nudge_tween: Tween = target.create_tween()
	nudge_tween.tween_property(target, "global_position", original_pos + nudge_offset, 0.05)
	nudge_tween.tween_property(target, "global_position", original_pos, 0.1)

	await nudge_tween.finished
	sprite.material = old_material

func _fly_arrow(from: Vector2, to: Vector2, parent: Node) -> void:
	var arrow: AnimatedSprite2D = ARROW_EFFECT.instantiate()
	arrow.process_mode = Node.PROCESS_MODE_ALWAYS
	arrow.rotation = (to - from).angle()
	parent.add_child(arrow)
	arrow.global_position = from

	var dist: float = from.distance_to(to)
	var duration: float = dist / ARROW_SPEED
	var tween: Tween = arrow.create_tween()
	tween.tween_property(arrow, "global_position", to, duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	arrow.queue_free()
