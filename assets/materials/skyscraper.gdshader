shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// 0.11.0 downtown skyscrapers: glass curtain wall with a clear band per
// floor (spandrel), window mullions and, at sunset/night, random lit
// windows. All in local mesh space, so MultiMesh instances share it.
// No textures or screen reads (mobile friendly).

uniform vec3 glass_low : source_color = vec3(0.10, 0.36, 0.72);
uniform vec3 glass_high : source_color = vec3(0.45, 0.76, 0.98);
uniform vec3 sky_tint : source_color = vec3(0.86, 0.94, 1.0);
uniform vec3 band_color : source_color = vec3(0.93, 0.95, 0.98);
uniform float height = 57.6;
uniform float floor_h = 3.6;
uniform float band = 0.26; // spandrel share of each floor
uniform float win_w = 2.4;
uniform float window_glow = 0.0; // 0 day .. 1 night
uniform vec3 glow_color : source_color = vec3(1.0, 0.8, 0.45);

varying vec3 lpos;
varying vec3 ao_wpos;
// 0.13.0 contact shadows (AoMap) at the foot of towers and malls.
global uniform sampler2D yaska_ao : filter_linear_mipmap, repeat_disable;
global uniform vec4 yaska_ao_rect;
float ao_at(vec2 xz) {
	vec2 uv = (xz - yaska_ao_rect.xy) * yaska_ao_rect.zw;
	float a = texture(yaska_ao, uv).r;
	bool inside = yaska_ao_rect.z > 0.0 && uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0;
	return inside ? a : 1.0;
}

void vertex() {
	ao_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	float t = clamp(lpos.y / height, 0.0, 1.0);
	vec3 glass = mix(glass_low, glass_high, smoothstep(0.0, 1.0, t));
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 2.0);
	glass = mix(glass, sky_tint, fres * 0.45);
	float dist = length(VERTEX);
	float fade = 1.0 - smoothstep(260.0, 900.0, dist);
	float fy = lpos.y / floor_h;
	float fl = fract(fy);
	float aa = max(fwidth(fy) * 1.5, 0.002);
	// Spandrel band at the bottom of each floor: opaque and light.
	float is_band = 1.0 - smoothstep(band - aa, band + aa, fl);
	float along = (lpos.x + lpos.z) / win_w;
	float fx = abs(fract(along) - 0.5) * 2.0;
	float aax = max(fwidth(along) * 2.0, 0.002);
	float mull = smoothstep(0.86 - aax, 0.86 + aax, fx) * fade;
	vec3 col = mix(glass, band_color * 0.82, mull * 0.7);
	col = mix(col, band_color, is_band * mix(0.55, 1.0, fade));
	ALBEDO = col * mix(1.0, ao_at(ao_wpos.xz), 1.0 - smoothstep(0.2, 2.5, ao_wpos.y));
	ROUGHNESS = mix(0.1, 0.7, is_band);
	METALLIC = mix(0.35, 0.0, is_band);
	SPECULAR = mix(0.9, 0.4, is_band);
	EMISSION = glass * 0.18 * (1.0 - is_band) * (0.4 + fres);
	if (window_glow > 0.0) {
		vec2 cell = vec2(floor(along), floor(fy)) + floor(lpos.xz * 0.013) * 17.0;
		float lit = step(0.6, hash2(cell)) * (1.0 - is_band) * (1.0 - mull);
		EMISSION += glow_color * lit * window_glow * 1.2;
	}
}
