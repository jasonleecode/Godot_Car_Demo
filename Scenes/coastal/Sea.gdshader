shader_type spatial;
render_mode cull_disabled;
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform float terrain_extent = 900.0;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_position.x * 0.16 + TIME * 0.7) * cos(world_position.z * 0.19 + TIME * 0.45) * 0.07;
}
void fragment() {
	vec2 p = world_position.xz;
	vec2 terrain_uv = (p / terrain_extent + vec2(1.0)) * 0.5;
	float seabed = texture(height_map,terrain_uv).r;
	float depth = max(0.0,-seabed);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float detail_fade = 1.0 - smoothstep(0.15, 2.0, footprint);
	float phase_a = p.x * 0.65 + p.y * 0.45 + TIME * 1.1;
	float phase_b = p.x * 1.5 - p.y * 0.75 - TIME * 0.8;
	float ripple = (sin(phase_a) * 0.6 + sin(phase_b) * 0.4) * detail_fade;
	float long_wave = sin(p.x * 0.25 + p.y * 0.4 + TIME);
	vec3 shallow = vec3(0.04, 0.23, 0.27);
	vec3 deep = vec3(0.012, 0.075, 0.18);
	vec3 color = mix(shallow, deep, smoothstep(1.0, 24.0, depth));
	float foam = (1.0 - smoothstep(0.2, 1.4, abs(depth - 0.6 + long_wave*0.15))) * smoothstep(-0.35, 0.6, ripple);
	ALBEDO = mix(color + ripple * 0.025, vec3(0.83, 0.94, 0.91), foam * 0.65);
	float dx = (cos(phase_a) * 0.039 + cos(phase_b) * 0.06) * detail_fade;
	float dz = (cos(phase_a) * 0.027 - cos(phase_b) * 0.03) * detail_fade;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-dx, 1.0, -dz)), 0.0)).xyz);
	ROUGHNESS = 0.36;
	METALLIC = 0.08;
	SPECULAR = 0.45;
}
