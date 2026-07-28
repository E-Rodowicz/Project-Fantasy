shader_type canvas_item;
render_mode unshaded, blend_add;

// Local-space X in pixels. Anything past this is thrown away.
uniform float cut_beyond = 10000.0;

varying float local_x;

void vertex() {
	local_x = VERTEX.x;
}

void fragment() {
	if (local_x > cut_beyond) {
		discard;
	}
}