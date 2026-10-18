extends Node

# Loads every StatDef in STATS_FOLDER at startup, so any script can look a stat up by its id.
const STATS_FOLDER: String = "res://data/stats/"

const POSITIVE_COLOUR: Color = Color(0.45, 0.8, 0.45)
const NEGATIVE_COLOUR: Color = Color(0.85, 0.4, 0.4)
const NEUTRAL_COLOUR: Color = Color.WHITE
const SCALE_LOW_COLOUR: Color = Color(1.0, 0.15, 0.15)
const SCALE_HIGH_COLOUR: Color = Color(0.2, 1.0, 0.2)

var stats: Dictionary = {}

func _ready() -> void:
	var dir: DirAccess = DirAccess.open(STATS_FOLDER)
	if dir == null:
		push_error("StatDB: can't open " + STATS_FOLDER)
		return
	for file_name: String in dir.get_files():
		# In an exported game, resource files are listed with ".remap" on the end. Removing it
		# means this works both in the editor and in the finished game.
		var clean_name: String = file_name.trim_suffix(".remap")
		if not clean_name.ends_with(".tres"):
			continue
		var def: StatDef = load(STATS_FOLDER + clean_name) as StatDef
		if def != null:
			stats[def.id] = def

func get_stat(stat_id: String) -> StatDef:
	return stats.get(stat_id, null)

# The colour a stat's number should be, based on its settings.
func value_colour(def: StatDef, value: int) -> Color:
	if def == null:
		return NEUTRAL_COLOUR
	if def.uses_colour_scale:
		return _scale_colour(def, value)
	if not def.is_percent or value == 0:
		return NEUTRAL_COLOUR
	return POSITIVE_COLOUR if value > 0 else NEGATIVE_COLOUR

# inverse_lerp gives how far value sits between two numbers, as 0..1 (5 between 0 and 10 is 0.5).
# Color.lerp then blends two colours by that amount: 0 is the first colour, 1 the second.
func _scale_colour(def: StatDef, value: int) -> Color:
	var middle: float = (def.scale_min + def.scale_max) / 2.0
	if value <= middle:
		var towards_middle: float = clampf(inverse_lerp(def.scale_min, middle, value), 0.0, 1.0)
		return SCALE_LOW_COLOUR.lerp(NEUTRAL_COLOUR, towards_middle)
	var towards_max: float = clampf(inverse_lerp(middle, def.scale_max, value), 0.0, 1.0)
	return NEUTRAL_COLOUR.lerp(SCALE_HIGH_COLOUR, towards_max)

# Text for a RichTextLabel (BBCode on): the stat's icon, then its name, both in its colour.
# For example, "Your [stat] rises" becomes "Your " + StatDB.bbcode("strength") + " rises".
func bbcode(stat_id: String, use_short_name: bool = false) -> String:
	var def: StatDef = get_stat(stat_id)
	if def == null:
		return stat_id
	var hex: String = def.colour.to_html(false)
	var text: String = def.short_name if use_short_name else def.display_name
	var image: String = ""
	if def.icon != null:
		# [img color=...] draws the icon inline with the text, tinted.
		image = "[img color=#" + hex + "]" + def.icon.resource_path + "[/img] "
	return image + "[color=#" + hex + "]" + text + "[/color]"
