shader_type spatial;
render_mode diffuse_burley;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(91.7, 271.9))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float broad = noise(UV * vec2(7.0, 5.0));
	float coarse = noise(UV * vec2(23.0, 15.0));
	float fine = noise(UV * vec2(110.0, 72.0));
	float fracture_field = abs(sin(UV.x * 42.0 + noise(UV * 9.0) * 8.0 + UV.y * 13.0));
	float fracture = 1.0 - smoothstep(0.0, 0.055, fracture_field);
	float second_fracture = 1.0 - smoothstep(0.0, 0.035, abs(sin(UV.y * 57.0 - noise(UV * 13.0) * 5.0)));
	float cracks = max(fracture, second_fracture * 0.52) * step(0.36, coarse);
	vec3 stone_a = vec3(0.025, 0.031, 0.035);
	vec3 stone_b = vec3(0.105, 0.112, 0.111);
	vec3 mineral = vec3(0.125, 0.112, 0.091) * smoothstep(0.70, 0.95, broad);
	ALBEDO = mix(stone_a, stone_b, broad * 0.55 + coarse * 0.28 + fine * 0.08) + mineral * 0.12;
	ALBEDO *= 1.0 - cracks * 0.78;
	ROUGHNESS = clamp(0.72 + coarse * 0.20 + cracks * 0.08, 0.0, 1.0);
	METALLIC = 0.025;
}
