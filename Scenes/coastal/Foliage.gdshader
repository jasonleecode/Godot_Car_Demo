shader_type spatial;
varying vec3 world_position;
varying vec3 leaf_color;
void vertex() { leaf_color = INSTANCE_CUSTOM.rgb; world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 cell = floor(world_position * 5.0);
	float fleck = fract(sin(dot(cell,vec3(12.9898,78.233,42.41)))*43758.5453);
	ALBEDO = pow(leaf_color,vec3(2.2)) * mix(0.75,1.15,fleck);
	ROUGHNESS = 0.94;
}
