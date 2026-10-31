shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Shared material for merged props and karts: albedo from vertex RGB,
// roughness from vertex alpha. Lets many coloured parts render in one draw.

uniform float rim_amount = 0.0;
uniform float metallic_amount = 0.0;
uniform float gloss = 0.0; // used by vcolor_gloss.gdshader (karts) only
uniform float saturation = 1.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// 0.13.0: sRGB->linear once per vertex (was 2 pow per pixel on every prop).
varying vec3 lin_col;
varying vec3 wpos;
// Contact shadows painted at load time (AoMap): the lowest ~1.8 m of walls,
// trunks and sidewalks inside a footprint get darker, like real AO.
global uniform sampler2D yaska_ao : filter_linear_mipmap, repeat_disable;
global uniform vec4 yaska_ao_rect;
float ao_at(vec2 xz) {
	vec2 uv = (xz - yaska_ao_rect.xy) * yaska_ao_rect.zw;
	float a = texture(yaska_ao, uv).r;
	bool inside = yaska_ao_rect.z > 0.0 && uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0;
	return inside ? a : 1.0;
}

void vertex() {
	lin_col = srgb_to_linear(COLOR.rgb);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = lin_col;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	float low = 1.0 - smoothstep(0.2, 1.8, wpos.y);
	ALBEDO = max(mix(vec3(l), c, saturation), vec3(0.0)) * mix(1.0, ao_at(wpos.xz), low);
	float r = clamp(COLOR.a, 0.05, 1.0);
	ROUGHNESS = r;
	SPECULAR = 0.5 + 0.3 * (1.0 - smoothstep(0.3, 0.6, r));
	METALLIC = metallic_amount;
	RIM = rim_amount;
	RIM_TINT = 0.5;
}
