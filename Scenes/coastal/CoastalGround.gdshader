shader_type spatial;
varying vec3 world_position;
varying vec3 terrain_color;
varying float cliff;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	terrain_color = COLOR.rgb;
	cliff = 1.0-smoothstep(0.40,0.82,NORMAL.y);
}
void fragment() {
	vec3 p = world_position;
	float footprint = max(length(dFdx(p)),length(dFdy(p)));
	float fade = 1.0-smoothstep(0.2,1.8,footprint);
	float grain = fract(sin(dot(floor(p*8.0),vec3(12.9898,78.233,42.41)))*43758.5453);
	float joint_y = 1.0-smoothstep(0.02,0.08,abs(sin(p.y*0.44+p.x*0.09+sin(p.z*0.18)*0.4)));
	float joint_x = 1.0-smoothstep(0.015,0.06,abs(sin(p.x*0.31+p.z*0.27+sin(p.y*0.16))));
	float weathering = sin(p.x*0.63+p.z*0.3)*cos(p.y*0.73)*0.06;
	vec3 color = pow(terrain_color,vec3(2.2));
	color *= 1.0+(grain-0.5)*0.20*fade+weathering*cliff;
	color *= 1.0-cliff*(joint_y*0.20+joint_x*0.12)*mix(0.4,1.0,fade);
	ALBEDO = color;
	ROUGHNESS = 0.96;
}
