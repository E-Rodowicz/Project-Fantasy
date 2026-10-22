shader_type canvas_item;

void fragment() {
	// COLOR already holds the texture's pixel, with the node's modulate applied.
	float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = vec3(grey);
}