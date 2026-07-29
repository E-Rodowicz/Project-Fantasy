extends Node

const ICONS: Dictionary = {
	"fire": preload("res://scenes/effects/conditions/condition_fire.tscn")
}

# Combatant -> { effect_id -> icon node }
var _owned: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
func _process(_delta: float) -> void:
	for c in _owned.keys():
		if not is_instance_valid(c):
			_owned.erase(c)
			
	for c in BattleManager.combatants:
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		_refresh(c)
		
func _refresh(c: Node) -> void:
	if not _owned.has(c):
		_owned[c] = {}
	var mine: Dictionary = _owned[c]

	for effect_id in ICONS:
		var stacks: int = _stacks(c, effect_id)
		var icon: Node = mine.get(effect_id)

		if stacks <= 0:
			if icon != null and is_instance_valid(icon):
				icon.dismiss()
			mine.erase(effect_id)
			continue

		if icon == null or not is_instance_valid(icon):
			icon = ICONS[effect_id].instantiate()
			icon.process_mode = Node.PROCESS_MODE_ALWAYS
			c.add_child(icon)
			mine[effect_id] = icon

		icon.set_stacks(stacks)

func _stacks(c: Node, effect_id: String) -> int:
	if c.is_in_group("player"):
		return PlayerData.get_status_stacks(effect_id)
	return c.get_status_stacks(effect_id)
