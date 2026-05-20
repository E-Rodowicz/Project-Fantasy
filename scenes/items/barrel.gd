extends StaticBody2D

# Array of IDs the barrel will use to call ItemDB, which holds the info of the items.
@export var inventory: Array = []
var interactable_name: String = "Barrel"
var interact_action: String = "Loot"

# Calls the loot manager to open this specific barrels loot window (hence the (self)).
func interact() -> void:
	LootManager.open_loot(self)
	
# Removes an item from the barrel#s inventory.
func remove_item(item_id: String) -> void:
	inventory.erase(item_id)
	
func is_empty() -> bool:
	# Checks if the barrels array is empty or not. .is_empty is a built in godot function.
	return inventory.is_empty()
