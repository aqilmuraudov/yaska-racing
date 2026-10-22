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
	float n = vnoise(wp * 0.35) * 0.6 + vnoise(wp * 1.7) * 0.4;
	float grain = mix(0.5, hash12(floor(wp * 18.0)), detail);
	vec3 asphalt = mix(asphalt_color, asphalt_light, n * 0.7 + grain * 0.15);
	// Darker racing line in the middle from tyre wear.
	asphalt *= 1.0 - 0.07 * (1.0 - smoothstep(0.0, hw * 0.6, abs(lat)));

	// Cobbles: staggered rectangular setts with mortar.
	vec2 cp = vec2(lat / 0.55, s / 0.42);
	cp.x += mod(floor(cp.y), 2.0) * 0.5;
	vec2 cell = floor(cp);
	vec2 cf = fract(cp);
	float edge = min(min(cf.x, 1.0 - cf.x) * 0.55, min(cf.y, 1.0 - cf.y) * 0.42);
	float mortar = 1.0 - smoothstep(0.015, 0.05, edge);
	mortar *= detail;
	float stone_var = hash12(cell);
	vec3 cobble = mix(cobble_color * (0.86 + 0.22 * stone_var), cobble_dark, mortar * 0.8);

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
	vec3 col = mix(base, line_color, marks * 0.92);

	ALBEDO = col;
	ROUGHNESS = mix(0.82, 0.65, cob) - marks * 0.1;
	SPECULAR = 0.35;
}
