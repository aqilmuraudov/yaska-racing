shader_type spatial;
render_mode cull_back;
// Red / white kerb stripes. UV.y = distance along the track (m).

uniform vec3 color_a : source_color = vec3(0.86, 0.16, 0.20);
uniform vec3 color_b : source_color = vec3(0.97, 0.96, 0.93);
uniform float stripe_length = 1.6;

void fragment() {
	float x = UV.y / stripe_length;
	float w = max(fwidth(x), 0.001);
	float f = fract(x);
	float m = smoothstep(0.5 - w, 0.5 + w, f) - smoothstep(1.0 - w, 1.0, f) + (1.0 - smoothstep(0.0, w, f));
	m = clamp(m, 0.0, 1.0);
	ALBEDO = mix(color_a, color_b, m);
	ROUGHNESS = 0.6;
}
