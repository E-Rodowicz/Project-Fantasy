extends Resource

# One stat's look and text, saved as its own .tres file in res://data/stats/. A Resource is a data
# object Godot can save, load and edit in the Inspector, so every stat is set up once and reused
# anywhere: the stats screen, dialogue, tutorials.
class_name StatDef

@export var id: String = ""
@export var short_name: String = ""
@export var display_name: String = ""
# @export_multiline gives a bigger text box in the Inspector.
@export_multiline var description: String = ""
# Draw icons in white and greys. The colour below tints them, the same way it colours the name.
@export var icon: Texture2D = null
@export var colour: Color = Color.WHITE
# Percentage stats show a % and turn green above 0 and red below 0.
@export var is_percent: bool = false
# Colours the number on a scale instead: scale_min is bright red, the middle is white, and
# scale_max is bright green. Values outside the range stay at full red or green.
@export var uses_colour_scale: bool = false
@export var scale_min: int = 0
@export var scale_max: int = 10
