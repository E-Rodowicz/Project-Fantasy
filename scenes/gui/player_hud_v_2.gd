extends CanvasLayer

@onready var hp_bar: TextureProgressBar = $StatusBar_bg/hp_bar
@onready var mp_bar: TextureProgressBar = $StatusBar_bg/mp_bar

var hud_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
func _process(_delat: float) -> void:
	if not hud_enabled: 
		visible = false
		return

	visible = not GameMenuManager.is_open
	if visible: 
		_update_display()
	
func _update_display() -> void:
	hp_bar.max_value = 100
	
	var hp_display: int = round(float(PlayerData.current_hp) / PlayerData.max_hp * 100.0)

	# Never lets the bar appear empty while the player is still alive.
	if PlayerData.current_hp > 0:
		hp_display = max(hp_display, 2)
		
	hp_bar.value = hp_display
