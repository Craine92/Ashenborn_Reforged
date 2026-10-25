shader_type spatial;
render_mode unshaded;

uniform vec4 ember_color : source_color = vec4(1.0, 0.24, 0.035, 1.0);
uniform float strength = 3.2;

void fragment() {
	float pulse = 0.78 + sin(TIME * 2.4 + UV.x * 6.283) * 0.17 + sin(TIME * 0.71) * 0.05;
	ALBEDO = ember_color.rgb * 0.42;
	EMISSION = ember_color.rgb * strength * pulse;
	ALPHA = ember_color.a;
}
