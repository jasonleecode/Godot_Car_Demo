shader_type spatial;
render_mode cull_disabled;
uniform vec4 shallow_color : source_color = vec4(0.24, 0.49, 0.47, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.47, 0.68, 0.61, 1.0);
varying vec3 water_position;
void vertex() {
	water_position = VERTEX;
	NORMAL = normalize(vec3(cos(VERTEX.x * 2.2 + TIME) * 0.04, 1.0, sin(VERTEX.z * 1.8 - TIME) * 0.04));
	VERTEX.y += sin(VERTEX.x * 1.4 + TIME * 1.1) * cos(VERTEX.z * 1.8 - TIME * 0.7) * 0.018;
}
void fragment() {
	float wave = sin(water_position.x * 2.2 + water_position.z * 1.5 + TIME * 1.4);
	float detail = sin(water_position.z * 4.0 - TIME * 1.1) * sin(water_position.x * 3.0 + TIME);
	float glint = pow(max(0.0, wave * detail), 12.0);
	ALBEDO = mix(shallow_color.rgb, ripple_color.rgb, 0.12 + glint * 0.65);
	ROUGHNESS = 0.24;
	METALLIC = 0.15;
}
