extends RefCounted
class_name CombatantInfo

const PLAYER_DISPLAY_NAME: String = "Nihil"


static func get_display_name(combatant: Node) -> String:
	if not is_instance_valid(combatant):
		return "???"
	if combatant.is_in_group("player"):
		return PLAYER_DISPLAY_NAME
	if "stats" in combatant and combatant.stats != null:
		return combatant.stats.character_name
	return combatant.name


static func get_portrait(combatant: Node) -> Texture2D:
	if not is_instance_valid(combatant):
		return null
	var sprite_node: Node = find_sprite_node(combatant)
	if sprite_node == null:
		return null

	if sprite_node is AnimatedSprite2D:
		var frames: SpriteFrames = sprite_node.sprite_frames
		if frames == null:
			return null
		if not frames.has_animation(sprite_node.animation):
			return null
		return frames.get_frame_texture(sprite_node.animation, sprite_node.frame)

	if sprite_node is Sprite2D:
		var base: Texture2D = sprite_node.texture
		if base == null:
			return null
		if sprite_node.hframes <= 1 and sprite_node.vframes <= 1 and not sprite_node.region_enabled:
			return base

		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = base
		if sprite_node.region_enabled and sprite_node.hframes <= 1 and sprite_node.vframes <= 1:
			atlas.region = sprite_node.region_rect
			return atlas

		var frame_w: float = float(base.get_width()) / float(sprite_node.hframes)
		var frame_h: float = float(base.get_height()) / float(sprite_node.vframes)
		var col: int = sprite_node.frame % sprite_node.hframes
		var row: int = int(sprite_node.frame / sprite_node.hframes)
		atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
		return atlas

	return null


static func find_sprite_node(root: Node) -> Node:
	for child in root.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
		var deeper: Node = find_sprite_node(child)
		if deeper != null:
			return deeper
	return null


# [A,A,A,B,C] becomes [{A,3,start 0},{B,1,start 3},{C,1,start 4}].
# "start" is the index in the raw list where the run begins, i.e. how many turns away it is.
static func collapse_runs(raw: Array) -> Array:
	var entries: Array = []
	for i in range(raw.size()):
		if not is_instance_valid(raw[i]):
			continue
		var combatant: Node = raw[i]
		if entries.size() > 0 and entries[entries.size() - 1]["combatant"] == combatant:
			entries[entries.size() - 1]["count"] += 1
		else:
			entries.append({"combatant": combatant, "count": 1, "start": i})
	return entries
