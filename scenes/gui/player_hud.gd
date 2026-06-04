extends CanvasLayer

@onready var hp_bar: TextureProgressBar = $anchor/hp_bar
@onready var hp_label: Label = $anchor/hp_bar/hp_label

@onready var mp_bar: TextureProgressBar = $anchor/mp_bar
@onready var mp_label: Label = $anchor/mp_bar/mp_label

@onready var bp_icon: TextureRect = $anchor/bp_icon
@onready var bp_label: Label = $anchor/bp_icon/bp_label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# HP
	hp_bar.max_value = PlayerData.max_hp
	hp_bar.value = PlayerData.current_hp
	hp_label.text = str(PlayerData.current_hp) + " / " + str(PlayerData.max_hp)

	# MP
	mp_bar.max_value = PlayerData.mp_max
	if BattleManager.active and BattleManager.player_turn != null:
		mp_bar.value = BattleManager.player_turn.mp_budget
		mp_label.text = str(BattleManager.player_turn.mp_budget) + " / " + str(PlayerData.mp_max)
	else:
		mp_bar.value = PlayerData.mp_max
		mp_label.text = str(PlayerData.mp_max) + " / " + str(PlayerData.mp_max)
	
	# BP
	if BattleManager.active and BattleManager.player_turn != null:
		bp_label.text = str(BattleManager.player_turn.bp_remaining)
	else:
		bp_label.text = str(PlayerData.bp_max)
