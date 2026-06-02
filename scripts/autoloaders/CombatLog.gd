extends Node

signal message_added(text: String)

var messages: Array = []
const MAX_MESSAGES: int = 50

func add(text: String) -> void:
	messages.append(text)
	if messages.size() > MAX_MESSAGES:
		# Removes oldest message.
		messages.pop_front()
	# Emits a signal so that anything listening knows there's a new message.
	message_added.emit(text)
	
func clear() -> void:
	messages.clear()
