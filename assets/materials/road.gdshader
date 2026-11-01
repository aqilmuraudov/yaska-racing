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

// 0.11.2: one mipmapped fetch of the shared tileable noise (tools/gen_noise.py)
// instead of 4 hashes per call - cheaper on phones and no far-distance shimmer.
global uniform sampler2D yaska_noise : filter_linear_mipmap, repeat_enable;
float vnoise(vec2 p) {
	return texture(yaska_noise, p * 0.015625).r;
}

// Anti-aliased band: 1 inside [a, b].
float band(float x, float a, float b) {
	float w = max(fwidth(x), 0.001);
	return smoothstep(a - w, a + w, x) * (1.0 - smoothstep(b - w, b + w, x));
}

varying vec2 road_xz;

// 0.15.3: relief without tangents - bump from a height value through screen
// space derivatives (Mikkelsen). Aggregate grain on asphalt, sunken mortar
// between cobbles; fades out with distance (no shimmer, cheap far away).
uniform float asphalt_bump = 0.006;
uniform float cobble_bump = 0.03;
vec3 bump_normal(vec3 pos, vec3 nrm, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	vec3 r1 = cross(dpdy, nrm);
	vec3 r2 = cross(nrm, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * nrm - grad);
}
global uniform float yaska_night; // 0.13.0: wet asphalt at night
// 0.13.0 contact shadows painted at load time (AoMap): 1 = open ground.
global uniform sampler2D yaska_ao : filter_linear_mipmap, repeat_disable;
global uniform vec4 yaska_ao_rect; // x0, z0, 1/width, 1/depth; z = 0 -> off
float ao_at(vec2 xz) {
	vec2 uv = (xz - yaska_ao_rect.xy) * yaska_ao_rect.zw;
	float a = texture(yaska_ao, uv).r; // fetched unconditionally: uniform control flow
	bool inside = yaska_ao_rect.z > 0.0 && uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0;
	return inside ? a : 1.0;
}

void vertex() {
	road_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
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

	// Relief: luminance of the textures as height (dark = low).
	float h_asph = dot(texture(asphalt_tex, wp * 0.25).rgb, vec3(0.33));
	float h_cob = dot(cobble, vec3(0.33));
	float hgt = mix(h_asph * asphalt_bump, h_cob * cobble_bump, cob) * detail * (1.0 - marks);
	NORMAL = bump_normal(VERTEX, NORMAL, hgt);
	// Buildings and trees right beside the road shade its edge a little.
	ALBEDO = col * mix(1.0, ao_at(road_xz), 0.75);
	// Roughness varies with the grain; the polished racing line and painted
	// lines are a little smoother and catch the low sun.
	float line_polish = 1.0 - smoothstep(0.0, hw * 0.5, abs(lat));
	ROUGHNESS = clamp(mix(0.86, 0.62, cob) - marks * 0.18 - line_polish * 0.12 * (1.0 - cob) + (n - 0.5) * 0.12 + patch * 0.06, 0.35, 1.0);
	// Night: damp road - smoother and a touch darker, so the moon, the headlight
	// and the lamp streaks (NightGlow) read as reflections.
	ROUGHNESS = mix(ROUGHNESS, ROUGHNESS * 0.42, yaska_night * 0.85);
	ALBEDO *= 1.0 - 0.14 * yaska_night;
	SPECULAR = 0.4;
}
