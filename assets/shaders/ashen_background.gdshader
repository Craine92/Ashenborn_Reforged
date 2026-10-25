shader_type canvas_item;

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
	vec2 uv = UV;
	vec2 centered = uv - vec2(0.5);
	float aspect = 1.7778;
	centered.x *= aspect;

	float smoke_a = noise(uv * 5.0 + vec2(TIME * 0.018, -TIME * 0.009));
	float smoke_b = noise(uv * 11.0 + vec2(-TIME * 0.011, TIME * 0.014));
	float smoke = smoke_a * 0.7 + smoke_b * 0.3;

	vec3 charcoal = vec3(0.009, 0.012, 0.016);
	vec3 slate = vec3(0.035, 0.043, 0.050);
	vec3 color = mix(charcoal, slate, smoke * 0.72);

	float glow = exp(-8.0 * length(centered - vec2(0.0, 0.13)));
	color += vec3(0.19, 0.045, 0.012) * glow * (0.35 + smoke * 0.65);

	vec2 ember_grid = floor(vec2(uv.x * 130.0, uv.y * 80.0 - TIME * 2.2));
	float ember_seed = hash(ember_grid);
	float ember = step(0.993, ember_seed);
	float ember_fade = smoothstep(1.0, 0.2, uv.y) * smoothstep(0.0, 0.35, uv.y);
	color += vec3(0.9, 0.19, 0.025) * ember * ember_fade * 0.75;

	float vignette = smoothstep(0.9, 0.2, length(centered));
	color *= 0.38 + vignette * 0.62;
	COLOR = vec4(color, 1.0);
}
