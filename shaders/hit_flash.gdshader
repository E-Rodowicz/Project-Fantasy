shader_type canvas_item;
render_mode unshaded;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = mix(tex,vec4(1.0, 1.0, 1.0, tex.a), flash_amount);
}