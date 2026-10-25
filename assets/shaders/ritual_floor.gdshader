shader_type spatial;
render_mode diffuse_burley;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 tiles = UV * 20.0;
	vec2 cell = fract(tiles);
	float mortar = 1.0 - smoothstep(0.025, 0.065, min(min(cell.x, 1.0 - cell.x), min(cell.y, 1.0 - cell.y)));
	float worn = noise(UV * 38.0) * 0.65 + noise(UV * 125.0) * 0.35;
	float crack_line = 1.0 - smoothstep(0.0, 0.028, abs(sin(UV.x * 67.0 + noise(UV * 16.0) * 9.0 + UV.y * 21.0)));
	vec3 base = mix(vec3(0.014, 0.018, 0.022), vec3(0.052, 0.058, 0.060), worn);
	ALBEDO = base * (1.0 - mortar * 0.62 - crack_line * 0.19);
	ROUGHNESS = 0.89 + worn * 0.08;
}
