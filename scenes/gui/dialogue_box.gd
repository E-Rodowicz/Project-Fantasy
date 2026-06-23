# This just means its UI.
extends CanvasLayer

# @onready delays the assignment of information until the scene is ready. Otherwise it would look
# into the nodes immideitely and crash as the info from the dictionaries is not there yet.
@onready var nine_patch: NinePatchRect = $NinePatchRect
@onready var speaker_label: Label = $NinePatchRect/speaker_label
@onready var text_label: RichTextLabel = $NinePatchRect/VBoxContainer/text_label
@onready var choices_container: VBoxContainer = $NinePatchRect/VBoxContainer/choices_container
@onready var arrow_label: Label = $NinePatchRect/ArrowIndicator

var choice_labels: Array = []
var choice_tweens: Array = []

var overflow_text: String = ""
var has_overflow: bool = false
var overflow_check_frame: int = -1

# Text reveal state.
var full_text: String = ""
var speed_map: Dictionary = {}
var wait_map: Dictionary = {}
var base_char_speed: float = 0.020
var current_speed: float = 1.0
var char_timer: float = 0.0
var current_char: int = 0
var is_revealing: bool = false
var text_fully_revealed: bool = false
var waiting: bool = false
var wait_timer: float = 0.0

# Arrow bob.
var arrow_tween: Tween = null
var arrow_base_x: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	arrow_base_x = arrow_label.position.x
	arrow_label.visible = false
	
	
func _process(delta: float) -> void:
	if overflow_check_frame >= 0 and Engine.get_process_frames() >= overflow_check_frame:
		overflow_check_frame = -1
		_check_overflow()
	if is_revealing:
		_process_reveal(delta)
			
func _process_reveal(delta: float) -> void:
	if waiting:
		wait_timer -= delta
		if wait_timer <= 0.0:
			waiting = false
		return
		
	char_timer += delta
	var delay: float = base_char_speed / current_speed
	
	while char_timer >= delay and current_char < full_text.length():
		if speed_map.has(current_char):
			current_speed = speed_map[current_char]
			delay = base_char_speed / current_speed
			
		if wait_map.has(current_char):
			waiting = true
			wait_timer = wait_map[current_char]
			char_timer = 0.0
			return
			
		current_char += 1
		text_label.visible_characters = current_char
		char_timer -= delay
	
	if current_char >= full_text.length():
		_finish_reveal()
		
func _start_arrow_bob() -> void:
	if arrow_tween:
		arrow_tween.kill()
	arrow_tween = create_tween().set_loops()
	arrow_tween.tween_property(arrow_label, "position:x", arrow_base_x + 5.0, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	arrow_tween.tween_property(arrow_label, "position:x", arrow_base_x, 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		
func _finish_reveal() -> void:
	is_revealing = false
	text_fully_revealed = true
	text_label.visible_characters = -1
	arrow_label.visible = true
	_start_arrow_bob()
	
func skip_reveal() -> void:
	is_revealing = false
	text_fully_revealed = true
	text_label.visible_characters = -1
	arrow_label.visible = true
	_start_arrow_bob()
	
func slide_in() -> void:
	var target_y: float = nine_patch.position.y
	nine_patch.position.y += 450
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(nine_patch, "position:y", target_y, 0.7)

func slide_out(callback: Callable) -> void:
	arrow_label.visible = false
	if arrow_tween:
		arrow_tween.kill()
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(nine_patch, "position:y", nine_patch.position.y + 450, 0.37)
	tween.tween_callback(callback)

# These two functions just push the text into the label and textbox.
func set_speaker(speaker_name: String) -> void:
	speaker_label.text = speaker_name

func set_text(raw_text: String) -> void:
	overflow_text = ""
	has_overflow = false
	full_text = _parse_text(raw_text)
	text_label.text = full_text
	text_label.visible_characters = 0
	current_char = 0
	current_speed = 1.0
	char_timer = 0.0
	is_revealing = true
	text_fully_revealed = false
	waiting = false
	arrow_label.visible = false
	overflow_check_frame = Engine.get_process_frames() + 1

func _parse_text(raw_text: String) -> String:
	speed_map.clear()
	wait_map.clear()
	
	var clean: String = ""
	var i: int = 0
	
	while i < raw_text.length():
		if raw_text[i] == "{":
			var end: int = raw_text.find("}", i)
			if end != -1:
				var tag: String = raw_text.substr(i + 1, end - i - 1)
				if tag.begins_with("s="):
					speed_map[clean.length()] = float(tag.substr(2))
				elif tag.begins_with("w="):
					wait_map[clean.length()] = float(tag.substr(2))
				i = end + 1
				continue
		clean +=  raw_text[i]
		i += 1
		
	return clean

func _check_overflow() -> void:
	var content_height: float = text_label.get_content_height()
	var label_height: float = text_label.size.y
	
	if content_height > label_height:
		var line_height: float = _get_line_height()
		var max_lines: int = max(int(label_height / line_height), 1)
		
		var split_pos: int = full_text.length() - 1
		while split_pos > 0 and text_label.get_character_line(split_pos) >= max_lines:
			split_pos -= 1
		
		var space_pos: int = full_text.rfind(" ", split_pos)
		if space_pos > 0:
			split_pos = space_pos
		
		overflow_text = full_text.substr(split_pos).strip_edges()
		has_overflow = true
		full_text = full_text.substr(0, split_pos) + "..."
		text_label.text = full_text
		
		var new_speed: Dictionary = {}
		for pos in speed_map:
			if pos < split_pos:
				new_speed[pos] = speed_map[pos]
		speed_map = new_speed
		
		var new_wait: Dictionary = {}
		for pos in wait_map:
			if pos < split_pos:
				new_wait[pos] = wait_map[pos]
		wait_map = new_wait
	
	_trim_for_arrow()

func _trim_for_arrow() -> void:
	if full_text.length() < 2:
		return
	
	var line_height: float = _get_line_height()
	var max_line: int = max(int(text_label.size.y / line_height), 1) - 1
	var last_char_line: int = text_label.get_character_line(full_text.length() - 1)
	
	if last_char_line < max_line:
		return
	
	var font: Font = text_label.get_theme_font("normal_font")
	var font_size: int = text_label.get_theme_font_size("normal_font_size")
	var reserved: float = arrow_label.size.x + 12.0
	var available: float = text_label.size.x - reserved
	
	var safety: int = 20
	while safety > 0:
		safety -= 1
		
		# Find where the last line starts
		var line_start: int = 0
		for i in range(full_text.length()):
			if text_label.get_character_line(i) == last_char_line:
				line_start = i
				break
		
		var last_line_text: String = full_text.substr(line_start)
		var width: float = font.get_string_size(last_line_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
		if width <= available:
			break
		
		# Strip existing ellipsis before trimming
		if full_text.ends_with("..."):
			full_text = full_text.substr(0, full_text.length() - 3)
		
		var space: int = full_text.rfind(" ")
		if space <= 0:
			break
		
		var moved: String = full_text.substr(space).strip_edges()
		full_text = full_text.substr(0, space) + "..."
		text_label.text = full_text
		
		if has_overflow:
			overflow_text = moved + " " + overflow_text
		else:
			overflow_text = moved
			has_overflow = true
	
	text_label.text = full_text

func _get_line_height() -> float:
	var font: Font = text_label.get_theme_font("normal_font")
	var font_size: int = text_label.get_theme_font_size("normal_font_size")
	var line_sep: int = text_label.get_theme_constant("line_separation")
	return font.get_height(font_size) + line_sep

# Shows choices
func show_choices(choices: Array, selected_index: int) -> void:
	is_revealing = false
	text_fully_revealed = true
	arrow_label.visible = false
	
	# This clears old choices so they dont show on top of new ones.
	for child in choices_container.get_children():
		child.queue_free()
	choice_labels.clear()
	
	# Makes the choices vbox visible and loops through each choice. It loops as there can be any
	# amount of choices.
	choices_container.visible = true
	
	for i in range(choices.size()):
		var label: Label = Label.new()
		label.text = str(i + 1) + ".  " + choices[i]["text"]
		label.add_theme_constant_override("outline_size", 11)
		label.add_theme_color_override("font_outline_color", Color("#414141"))
		choices_container.add_child(label)
		choice_labels.append(label)
	
	update_selection(selected_index)

# Loops through choices, making the picked option yellow, the other's white.
func update_selection(selected_index: int) -> void:
	for t in choice_tweens:
		if t:
			t.kill()
	choice_tweens.clear()
	
	for i in range(choice_labels.size()):
		var tween: Tween = create_tween()
		if i == selected_index:
			tween.tween_property(choice_labels[i], "modulate", Color.YELLOW, 0.15)
		else:
			tween.tween_property(choice_labels[i], "modulate", Color.WHITE, 0.15)
		choice_tweens.append(tween)

# Hides choices when normal dialogue is showing.
func hide_choices() -> void:
	choices_container.visible = false
