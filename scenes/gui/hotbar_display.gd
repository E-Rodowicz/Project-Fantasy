extends CanvasLayer

@onready var hotbar_container: HBoxContainer = $anchor/hotbar_container
# Slots. Index 0 = Key 1, etc.
var slot_labels: Array = []
# Text on each slot.
var key_names: Array = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
var hud_enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_slots()
	_update_display()
	
func _process(_delta: float) -> void:
	if not hud_enabled:
		visible = false
		return
	# Hides hotbar when menu is open.
	visible = not GameMenuManager.is_open
	if visible:
		_update_display()

func _build_slots() -> void:
	for i in range(10):
		var slot: Label = Label.new()
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Each slot gets a fixed width so they line up evenly.
		slot.custom_minimum_size = Vector2(100, 0)
		hotbar_container.add_child(slot)
		slot_labels.append(slot)

func _update_display () -> void:
	for i in range(10):
		var ability_id: String = PlayerData.get_hotbar_ability(i)
		var display_name: String = "---"
		
		if ability_id == "basic_attack":
			display_name = "Attack"
		elif ability_id != "":
			var data: Dictionary = AbilityDB.get_ability(ability_id)
			display_name = data.get("name", ability_id)
			
		slot_labels[i].text = "[" + key_names[i] + "]" + display_name
		
		# During combat, check if this slot is the one currently being used/aimed.
		var is_active: bool = false
		if BattleManager.active and BattleManager.player_turn != null:
			is_active = (BattleManager.player_turn.active_hotbar_slot == i)
		
		if is_active:
			slot_labels[i].modulate = Color.YELLOW
		else:
			slot_labels[i].modulate = Color.WHITE
