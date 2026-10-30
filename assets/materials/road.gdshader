shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Procedural road surface. UV.y = distance along the track (m),
// UV2.x = signed lateral offset (m), UV2.y = half width (m),
// COLOR.r = Old City cobble blend (0 asphalt, 1 cobbles).

uniform vec3 asphalt_color : source_color = vec3(0.30, 0.30, 0.33);
uniform vec3 asphalt_light : source_color = vec3(0.40, 0.39, 0.41);
uniform vec3 cobble_color : source_color = vec3(0.70, 0.62, 0.50);
uniform vec3 cobble_dark : source_color = vec3(0.45, 0.39, 0.32);
uniform vec3 line_color : source_color = vec3(0.97, 0.96, 0.92);
uniform vec3 accent_color : source_color = vec3(1.0, 0.78, 0.22);
uniform float lane_count = 3.0;
// Painted texture tiers (TextureLibrary): asphalt tiles every 4 m, setts
// tile 3.3 × 3.36 m. Markings stay procedural so they are always crisp.
uniform sampler2D asphalt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cobble_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 asphalt_tint = vec3(1.12, 1.07, 1.0);
uniform float detail_fade_distance = 60.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x),
		mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

// Anti-aliased band: 1 inside [a, b].
float band(float x, float a, float b) {
	float w = max(fwidth(x), 0.001);
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

void fragment() {
	float lat = UV2.x;
	float hw = UV2.y;
	float s = UV.y;
	float dist = length(VERTEX);
	float detail = 1.0 - smoothstep(detail_fade_distance * 0.5, detail_fade_distance, dist);

	// Asphalt: soft mottling plus fine grain that fades with distance.
	vec2 wp = vec2(lat, s);
	float n = vnoise(wp * 0.05);
	vec3 asphalt = texture(asphalt_tex, wp * 0.25).rgb * asphalt_tint * (0.94 + 0.12 * n);
	// Darker racing line in the middle from tyre wear.
	asphalt *= 1.0 - 0.07 * (1.0 - smoothstep(0.0, hw * 0.6, abs(lat)));

	// Cobbles: staggered rectangular setts with mortar.
	vec3 cobble = texture(cobble_tex, vec2(lat / 3.3, s / 3.36)).rgb;
	float mortar = 0.0;

	float cob = clamp(COLOR.r, 0.0, 1.0);
	vec3 base = mix(asphalt, cobble, cob);

	// Markings: solid edge lines, dashed lane dividers.
	float edge_line = band(abs(lat), hw - 0.75, hw - 0.4);
	float lane_w = (hw * 2.0) / lane_count;
	float lane_line = 0.0;
	for (float i = 1.0; i < 4.0; i += 1.0) {
		if (i < lane_count) {
			float x = -hw + lane_w * i;
			lane_line += band(lat, x - 0.12, x + 0.12);
		}
	}
	float dash = step(0.55, fract(s / 9.0));
	lane_line *= dash * detail * (1.0 - cob);
	float marks = clamp(edge_line * (1.0 - cob * 0.4) + lane_line, 0.0, 1.0);
	// 0.9.6: worn paint (patchy, thinner where tyres run) and repair patches.
	float wear = vnoise(wp * vec2(1.6, 0.35)) * 0.6 + vnoise(wp * 3.1) * 0.4;
	marks *= mix(1.0, smoothstep(0.18, 0.62, wear), 0.55 * detail);
	float patch = smoothstep(0.62, 0.66, vnoise(wp * vec2(0.18, 0.06) + 7.3)) * (1.0 - cob);
	base *= 1.0 - 0.1 * patch;
	vec3 col = mix(base, line_color, marks * 0.92);
	// Soft darker gutter along both edges frames the driving surface.
	col *= 1.0 - 0.18 * smoothstep(hw - 1.4, hw - 0.1, abs(lat)) * (1.0 - edge_line);

	ALBEDO = col;
	// Roughness varies with the grain; the polished racing line and painted
	// lines are a little smoother and catch the low sun.
	float line_polish = 1.0 - smoothstep(0.0, hw * 0.5, abs(lat));
	ROUGHNESS = clamp(mix(0.86, 0.62, cob) - marks * 0.18 - line_polish * 0.12 * (1.0 - cob) + (n - 0.5) * 0.12 + patch * 0.06, 0.35, 1.0);
	SPECULAR = 0.4;
}
