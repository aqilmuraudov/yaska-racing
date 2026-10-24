shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Karts and drivers: vcolor.gdshader plus a clear-coat lobe on smooth parts.
// Kept separate so the many merged props do not pay for clear-coat shading.
// Shared material for merged props and karts: albedo from vertex RGB,
// roughness from vertex alpha. Lets many coloured parts render in one draw.

uniform float rim_amount = 0.0;
uniform float metallic_amount = 0.0;
// Painted-toy gloss: smooth parts (low roughness in vertex alpha) get a
// clear-coat highlight, rough parts (fur, tyres, fabric) stay matte.
uniform float gloss = 0.0;
uniform float saturation = 1.0;
// Camera-occlusion fade for rival karts (KartVisual): an ordered-dither
// "screen door" that stays in the opaque pass (instance transparency has no
// effect on this opaque shader, and a transparent pass would cost more).
instance uniform float occlusion_fade : hint_range(0.0, 1.0) = 0.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	if (occlusion_fade > 0.001) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		if ((BAYER[p.y * 4 + p.x] + 0.5) / 16.0 < occlusion_fade) {
			discard;
		}
	}
	vec3 c = srgb_to_linear(COLOR.rgb);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	ALBEDO = max(mix(vec3(l), c, saturation), vec3(0.0));
	float r = clamp(COLOR.a, 0.05, 1.0);
	ROUGHNESS = r;
	float smooth_part = 1.0 - smoothstep(0.3, 0.6, r);
	CLEARCOAT = gloss * smooth_part;
	CLEARCOAT_ROUGHNESS = 0.12;
	SPECULAR = 0.5 + 0.3 * smooth_part;
	METALLIC = metallic_amount;
	RIM = rim_amount;
	RIM_TINT = 0.5;
}
