shader_type spatial;
render_mode cull_back, diffuse_burley;
// World-space coursed limestone (Old City walls and houses). No UVs needed:
// vertical faces use (along-face, height) coordinates, tops use XZ.
// COLOR tints the stone so one material serves many buildings.

uniform vec3 stone : source_color = vec3(0.86, 0.76, 0.58);
uniform vec3 mortar : source_color = vec3(0.74, 0.66, 0.52);
uniform float block_w = 0.9;
uniform float block_h = 0.42;
uniform float detail_fade = 70.0;
// Painted wall texture (TextureLibrary tiers): 2 blocks × 4 courses.
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnrm);
	vec2 p;
	if (n.y > 0.7) {
		p = wpos.xz;
	} else if (n.x > n.z) {
		p = vec2(wpos.z, wpos.y);
	} else {
		p = vec2(wpos.x, wpos.y);
	}
	vec3 tint = srgb_to_linear(COLOR.rgb);
	vec3 tex = texture(stone_tex, vec2(p.x / (block_w * 4.0), -p.y / (block_h * 4.0))).rgb;
	// Gentle warm-to-cool variation over large areas so walls do not tile.
	float big = hash12(floor(p / 7.0));
	// 0.9.7: warm Absheron sandstone, per-block tone variation and a little
	// weathering at the foot of the walls (was near-white in the sun).
	float blk = hash12(floor(vec2(p.x / block_w, p.y / block_h)));
	float grime = 1.0 - 0.14 * (1.0 - smoothstep(0.0, 3.0, wpos.y - floor(wpos.y / 400.0) * 400.0));
	ALBEDO = tex * tint * (stone / vec3(0.92, 0.84, 0.68)) * (0.9 + big * 0.06 + blk * 0.08) * grime;
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
