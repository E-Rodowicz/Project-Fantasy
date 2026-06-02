extends Control

@onready var log_label: RichTextLabel = $PanelContainer/RichTextLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# This bascially means when the message_added signal fires from CombatLog, call the
	# _on_message_added function.
	CombatLog.message_added.connect(_on_message_added)
	visible = false
	
func _process(_delta: float) -> void:
	if BattleManager.active and not visible:
		visible = true
	elif not BattleManager.active and visible:
		visible = false

func _on_message_added(text: String) -> void:
	log_label.append_text(text + "\n")
