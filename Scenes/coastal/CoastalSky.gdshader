shader_type sky;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}
void sky() {
	float up = max(EYEDIR.y, 0.0);
	vec3 blue = mix(vec3(0.32,0.58,0.76), vec3(0.025,0.20,0.48), pow(up, 0.38));
	vec2 p = EYEDIR.xz / max(up + 0.12, 0.12) * 3.4;
	float n = noise(p) * 0.55 + noise(p*2.1) * 0.26 + noise(p*4.3) * 0.13 + noise(p*8.5) * 0.06;
	float cloud = smoothstep(0.54, 0.69, n) * smoothstep(0.01,0.16,up);
	vec3 cloud_color = mix(vec3(0.73,0.82,0.87), vec3(1.0,0.99,0.94), smoothstep(0.52,0.76,n));
	COLOR = mix(blue,cloud_color,cloud*0.96);
}
