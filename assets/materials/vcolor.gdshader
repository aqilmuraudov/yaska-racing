shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Shared material for merged props and karts: albedo from vertex RGB,
// roughness from vertex alpha. Lets many coloured parts render in one draw.

uniform float rim_amount = 0.0;
uniform float metallic_amount = 0.0;
// Painted-toy gloss: smooth parts (low roughness in vertex alpha) get a
// clear-coat highlight, rough parts (fur, tyres, fabric) stay matte.
uniform float gloss = 0.0;
uniform float saturation = 1.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
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
