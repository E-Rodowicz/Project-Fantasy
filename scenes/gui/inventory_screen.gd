extends Control

# Da panels.
@onready var equipment_panel = $equipment_panel
@onready var item_info = $item_info
@onready var slot_items = $slot_items
@onready var types_panel = $types_panel
@onready var item_list = $item_list

# Equipment panel
@onready var slot_items_list = $slot_items/slot_items_list

# Item info
@onready var info_name = $item_info/info_name
@onready var info_type = $item_info/info_type
@onready var info_weight = $item_info/info_weight
@onready var info_desc = $item_info/info_desc

# Types panel
@onready var types_list = $types_panel/types_list

# Item list
@onready var item_list_container = $item_list/item_list_container

# Navigation states. Note: An "enum" is a mass way to give loads of constants a value. Its like
# declaring constants but you just move their order around from top (0) to bottom (x) to change
# their value.
enum State {
	PANEL_SELECT,
	EQUIPMENT_ACTIVE,
	SLOT_ITEMS_ACTIVE,
	TYPES_ACTIVE,
	ITEM_LIST_ACTIVE
}

var current_state: State = State.PANEL_SELECT
# 0 is equipment (left), 1 is inventory (right).
var selected_panel: int = 0

# Equipment slots
var equipment_slots: Array = []
var selected_slot_index: int = 0

# Item types
const ITEM_TYPES = ["all", "weapon", "armour", "consumable", "material", "misc"]
var selected_type_index: int = 0

# Item lists
var current_slot_items: Array = []
var current_list_items: Array = []
var selected_slot_item_index: int = 0
var selected_list_item_index: int = 0

# Equipped items. Stores item by slot name.
var equipped_items: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Populate equipment slots array with all 20 slot buttons. ORDER MATTERS HERE!!!
	equipment_slots = [
		$equipment_panel/slot_head,
		$equipment_panel/slot_amulet,
		$equipment_panel/slot_left_shoulder,
		$equipment_panel/slot_right_shoulder,
		$equipment_panel/slot_left_arm,
		$equipment_panel/slot_right_arm,
		$equipment_panel/slot_left_hand,
		$equipment_panel/slot_right_hand,
		$equipment_panel/slot_left_weapon,
		$equipment_panel/slot_right_weapon,
		$equipment_panel/slot_left_ring,
		$equipment_panel/slot_right_ring,
		$equipment_panel/slot_cape,
		$equipment_panel/slot_chest,
		$equipment_panel/slot_left_thigh,
		$equipment_panel/slot_right_thigh,
		$equipment_panel/slot_left_calf,
		$equipment_panel/slot_right_calf,
		$equipment_panel/slot_left_boot,
		$equipment_panel/slot_right_boot,
	]
	
	# Restores position of the selected panel of the inventory.
	selected_panel = GameMenuManager.saved_inventory_panel
	_highlight_panel_select()
	
	# Populates types list labels.
	_update_types_highlight()
	
	# Starts in panel select state.
	_enter_panel_select()
	
# All of the "enter" functions below basically set the current state, adjust visibility, call the
# (temporary) text highlights and call the update funcs (func stands for "fun uncle", btw).
func _enter_panel_select() -> void:
	current_state = State.PANEL_SELECT
	selected_list_item_index = 0
	slot_items.visible = false
	item_list.visible = false
	_clear_info_panel()
	_highlight_panel_select()

# The bool inputs for these decide if the index resets, going to the default slot of 0. If it comes
# back as true, index of the selected item/slot/whatever does not reset.
func _enter_equipment_active(from_back: bool = false) -> void:
	current_state = State.EQUIPMENT_ACTIVE
	if not from_back:
		selected_slot_index = 0
	slot_items.visible = true
	_update_slot_highlight()
	_update_slot_items_list()

func _enter_slot_items_active(from_back: bool = false) -> void:
	current_state = State.SLOT_ITEMS_ACTIVE
	if not from_back:
		selected_slot_item_index = 0
	_update_slot_item_highlight()
	_update_info_panel_from_slot_items()

func _enter_types_active(from_back: bool = false) -> void:
	current_state = State.TYPES_ACTIVE
	selected_list_item_index = 0
	item_list.visible = true
	if not from_back:
		selected_type_index = 0
	_update_types_highlight()
	_update_item_list()

func _enter_item_list_active(from_back: bool = false) -> void:
	current_state = State.ITEM_LIST_ACTIVE
	if not from_back:
		selected_list_item_index = 0
	_update_item_list_highlight()
	_update_info_panel_from_item_list()

# Clears info panel... I need to stop commenting on obvious functions.
func _clear_info_panel() -> void:
	info_name.text = ""
	info_type.text = ""
	info_weight.text = ""
	info_desc.text = ""
	
func _highlight_panel_select() -> void:
	# Dims either the right or left side if the opposite is selected.
	var left_active: bool = selected_panel == 0
	equipment_panel.modulate = Color.WHITE if left_active else Color.DARK_GRAY
	slot_items.modulate = Color.WHITE if left_active else Color.DARK_GRAY
	types_panel.modulate = Color.WHITE if not left_active else Color.DARK_GRAY
	item_list.modulate = Color.WHITE if not left_active else Color.DARK_GRAY
	item_info.modulate = Color.WHITE
	
# Need to start using statics as per below. Don't forget!
func _update_slot_highlight() ->void:
	for i: int in range(equipment_slots.size()):
		equipment_slots[i].modulate = Color.YELLOW if i == selected_slot_index else Color.WHITE

# Fetches items for current slot and populates current slot items array.
func _update_slot_items_list() -> void:
	for child in slot_items_list.get_children():
		child.queue_free()

	selected_slot_item_index = 0
	var slot_name: String = equipment_slots[selected_slot_index].name
	current_slot_items.clear()
	
	for item: Dictionary in PlayerData.inventory:
		if _item_fits_slot(item, slot_name):
			current_slot_items.append(item)
	
	for item: Dictionary in current_slot_items:
		var label: Label = Label.new()
		# Shows equpped status if item has the equipped tag. Combines it with name to make the text.
		var equipped_text: String = " [Equipped]" if item.get("equipped", false) else ""
		label.text = item.get("name", "Unknown") + equipped_text
		# Adds the custom label.
		slot_items_list.add_child(label)
	
	_update_info_panel_from_slot_items()

# Example in comments of how this works if trying to fit iron pauldron on left shoulder:
func _item_fits_slot(item: Dictionary, slot_name: String) -> bool:
	# Gets "shoulder" slot from the iron pauldron data.
	var item_slot: String = item.get("slot", "")
	# Gets the current slot name, strips the _slot and leaves us with "left_shoulder".
	var clean_slot: String = slot_name.replace("slot_", "")
	
	# Loops through the symmetrical slot types. When it finds "shoulder"...
	var symmetrical: Array = ["shoulder", "arm", "thigh", "calf", "weapon", "ring"]
	for s: String in symmetrical:
		# Does left_shoulder contain the word "shoulder" from the array? Yes. Does the item_slot =
		# "shoulder"? Yes. As both are true, returns true bool. If this was a left gauntlet, nothing
		# in this array would fit, hence it would go to...
		if clean_slot.contains(s) and item_slot == s:
			return true
	
	# ...this, meaning the tag, "left_hand" would have to fit the cleaned up slot name "left_hand"
	# in order to go into the slot. If it does fit, it returns true.
	return item_slot == clean_slot

# The below is complicated.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	
	# Goes to relevant function according to current state.
	match current_state:
		State.PANEL_SELECT:
			_input_panel_select(event)
		State.EQUIPMENT_ACTIVE:
			_input_equipment_active(event)
		State.SLOT_ITEMS_ACTIVE:
			_input_slot_items_active(event)
		State.TYPES_ACTIVE:
			_input_types_active(event)
		State.ITEM_LIST_ACTIVE:
			_input_item_list_active(event)
			
# Inputs and highlight/update calls for when you are picking between the two panels.
func _input_panel_select(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") and not event.is_echo():
		selected_panel = 0
		GameMenuManager.saved_inventory_panel = 0
		_highlight_panel_select()
	if event.is_action_pressed("ui_right") and not event.is_echo():
		selected_panel = 1
		GameMenuManager.saved_inventory_panel = 1
		_highlight_panel_select()
	if event.is_action_pressed("interact") and not event.is_echo():
		if selected_panel == 0:
			_enter_equipment_active(true)
		else:
			_enter_types_active(true)

# Inputs and highlight/update calls for when you are in the equipment menu, picking between slots.
func _input_equipment_active(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and not event.is_echo():
		# Note: "min" caps the top and "max" caps the bottom. Kinda opposite of what their names
		# might suggest... max(a,b) returns whatever value is larger, so if you try to go below
		# 0, it would return 0.
		selected_slot_index = max(0, selected_slot_index - 1)
		_update_slot_highlight()
		_update_slot_items_list()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		# min(a,b) returns whatever value is smaller, meaning you cannot go above the index of the
		# number of slots you have.
		selected_slot_index = min(equipment_slots.size() - 1, selected_slot_index + 1)
		_update_slot_highlight()
		_update_slot_items_list()
	if event.is_action_pressed("interact") and not event.is_echo():
		if not current_slot_items.is_empty():
			_enter_slot_items_active()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		slot_items.visible = false
		_enter_panel_select()
		get_viewport().set_input_as_handled()

# Inputs and highlight/update calls for when you are in the slot items list.
func _input_slot_items_active(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and not event.is_echo():
		selected_slot_item_index = max(0, selected_slot_item_index - 1)
		_update_slot_item_highlight()
		_update_info_panel_from_slot_items()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		selected_slot_item_index = min(current_slot_items.size() - 1, selected_slot_item_index + 1)
		_update_slot_item_highlight()
		_update_info_panel_from_slot_items()
	if event.is_action_pressed("interact") and not event.is_echo():
		_equip_item()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		# Note: The ture here sends a true bool to the function so that it does not reset position
		# when going backwars with a Q input.
		_enter_equipment_active(true)
		get_viewport().set_input_as_handled()

# Inputs and highlight/update calls for when you are selecing a type in the left side panel.
func _input_types_active(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and not event.is_echo():
		selected_type_index = max(0, selected_type_index - 1)
		_update_types_highlight()
		_update_item_list()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		selected_type_index = min(ITEM_TYPES.size() - 1, selected_type_index + 1)
		_update_types_highlight()
		_update_item_list()
	if event.is_action_pressed("interact") and not event.is_echo():
		if not current_list_items.is_empty():
			_enter_item_list_active()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		item_list.visible = false
		_enter_panel_select()
		get_viewport().set_input_as_handled()

# Inputs and highlight/update calls for when you have picked an inventory type and are looking
# through its filtered item list.
func _input_item_list_active(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") and not event.is_echo():
		selected_list_item_index = max(0, selected_list_item_index - 1)
		_update_item_list_highlight()
		_update_info_panel_from_item_list()
	if event.is_action_pressed("ui_down") and not event.is_echo():
		selected_list_item_index = min(current_list_items.size() - 1, selected_list_item_index + 1)
		_update_item_list_highlight()
		_update_info_panel_from_item_list()
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_enter_types_active(true)
		get_viewport().set_input_as_handled()

# EQUPS ITEM!
func _equip_item() -> void:
	var saved_index: int = selected_slot_index
	var slot_name: String = equipment_slots[selected_slot_index].name
	var item: Dictionary = current_slot_items[selected_slot_item_index]
	
	# If item is already equipped in THIS slot, unequips it.
	if equipped_items.get(slot_name) == item:
		item["equipped"] = false
		equipped_items.erase(slot_name)
	else:
		# Unequips from any slot it might already be in.
		for s: String in equipped_items.keys():
			if equipped_items[s] == item:
				equipped_items[s]["equipped"] = false
				equipped_items.erase(s)
				break
		
		# Unequips whatever is currently in the target slot.
		if equipped_items.has(slot_name):
			equipped_items[slot_name]["equipped"] = false
		
		# Equips to a new slot.
		item["equipped"] = true
		equipped_items[slot_name] = item
	
	_update_slot_items_list()
	_enter_equipment_active(true)
	selected_slot_index = saved_index
	_update_slot_highlight()
	# This updates the slot item list a second time. This is needed because _enter_equipment_active
	# internally calls _update_slot_items_list before we restore selected_slot_index, meaning the
	# first rebuild might be on the wrong slot. This second call ensures the list shows items for 
	# the correct slot after the index is restored. It's slightly redundant calling it twice but
	# guarantees correctness.
	_update_slot_items_list()

func _update_slot_item_highlight() -> void:
	for i: int in range(slot_items_list.get_child_count()):
		var label: Label = slot_items_list.get_child(i)
		label.modulate = Color.YELLOW if i == selected_slot_item_index else Color.WHITE

func _update_info_panel_from_slot_items() -> void:
	if current_slot_items.is_empty():
		_clear_info_panel()
		return
	var item: Dictionary = current_slot_items[selected_slot_item_index]
	_populate_info_panel(item)

func _populate_info_panel(item: Dictionary) -> void:
	info_name.text = item.get("name", "Unknown")
	info_type.text = item.get("type", "")
	info_weight.text = "Weight: " + str(item.get("weight", 0))
	info_desc.text = item.get("desc", "")

func _update_item_list() -> void:
	for child in item_list_container.get_children():
		child.queue_free()
	
	selected_list_item_index = 0
	current_list_items.clear()
	var selected_type: String = ITEM_TYPES[selected_type_index]
	
	for item: Dictionary in PlayerData.inventory:
		if selected_type == "all" or item.get("type", "") == selected_type:
			current_list_items.append(item)
	
	for item: Dictionary in current_list_items:
		var label: Label = Label.new()
		var equipped_text: String = " [Equipped]" if item.get("equipped", false) else ""
		label.text = item.get("name", "Unknown") + equipped_text
		item_list_container.add_child(label)
	
	_update_info_panel_from_item_list()

func _update_item_list_highlight() -> void:
	for i: int in range(item_list_container.get_child_count()):
		var label: Label = item_list_container.get_child(i)
		label.modulate = Color.YELLOW if i == selected_list_item_index else Color.WHITE

func _update_info_panel_from_item_list() -> void:
	if current_list_items.is_empty():
		_clear_info_panel()
		return
	var item: Dictionary = current_list_items[selected_list_item_index]
	_populate_info_panel(item)
	
func _update_types_highlight() -> void:
	for i: int in range(types_list.get_child_count()):
		types_list.get_child(i).modulate = Color.YELLOW if i == selected_type_index else Color.WHITE
