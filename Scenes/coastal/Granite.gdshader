shader_type spatial;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 p = world_position;
	float grain = fract(sin(dot(floor(p * 11.0),vec3(12.9898,78.233,42.41)))*43758.5453);
	float coarse = sin(p.x*1.3+p.z*0.7)*sin(p.y*1.8-p.x*0.6)*0.5+0.5;
	float seam = 1.0-smoothstep(0.025,0.11,abs(sin(p.y*0.65+p.x*0.13+sin(p.z*0.3)*0.35)));
	vec3 stone = mix(vec3(0.49,0.48,0.43),vec3(0.69,0.67,0.59),coarse*0.5+grain*0.5);
	ALBEDO = pow(stone,vec3(2.2))*(1.0-seam*0.21);
	ROUGHNESS = 0.97;
}
