shader_type spatial;
// 0.10.2 showroom turntable: blue checker top with a glowing rim band.
render_mode specular_schlick_ggx;
uniform vec3 color_a : source_color = vec3(0.09, 0.36, 0.92);
uniform vec3 color_b : source_color = vec3(0.50, 0.80, 1.0);
uniform vec3 glow : source_color = vec3(0.25, 0.8, 1.0);
uniform float radius = 2.7;
uniform float cell = 0.42;
uniform float pulse = 0.0;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float r = length(lp.xz);
	vec2 c = floor(lp.xz / cell);
	float chk = mod(c.x + c.y, 2.0);
	vec3 col = mix(color_a, color_b, chk * 0.85);
	float band = smoothstep(radius - 0.42, radius - 0.3, r) * (1.0 - smoothstep(radius - 0.18, radius - 0.06, r));
	float edge = smoothstep(radius - 0.1, radius, r);
	ALBEDO = mix(col, vec3(0.06, 0.2, 0.6), max(band, edge));
	EMISSION = glow * (band * (2.2 + pulse) + 0.06 + chk * 0.05);
	ROUGHNESS = 0.22;
	METALLIC = 0.05;
}
