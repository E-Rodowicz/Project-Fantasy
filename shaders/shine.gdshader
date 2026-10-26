shader_type canvas_item;

// Where the band is, measured along a slanted line, in canvas units. Set from GDScript.
uniform float shine_pos = -100000.0;
uniform float shine_width = 4.0;
// How much the band leans. 0 is straight up and down.
uniform float shine_slant = 0.5;
// How far towards white the band pushes. 1 is fully white.
uniform float shine_strength = 0.8;

varying vec2 world_pos;

void vertex() {
	// MODEL_MATRIX turns this node's own coordinates into canvas coordinates, the same space
	// get_global_rect() uses in GDScript, so the icon, name and number all share one band.
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float along = world_pos.x + world_pos.y * shine_slant;
	// 1 inside the band, 0 outside. A hard edge suits pixel art better than a soft glow.
	float in_band = step(abs(along - shine_pos), shine_width * 0.5);
	// Near-black pixels (the outline) are left alone, so it doesn't turn grey.
	float lit = in_band * shine_strength * step(0.1, max(COLOR.r, max(COLOR.g, COLOR.b)));
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), lit);
}