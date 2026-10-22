shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Shared material for merged props and karts: albedo from vertex RGB,
// roughness from vertex alpha. Lets many coloured parts render in one draw.

uniform float rim_amount = 0.0;
uniform float metallic_amount = 0.0;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb);
	ROUGHNESS = clamp(COLOR.a, 0.05, 1.0);
	METALLIC = metallic_amount;
	RIM = rim_amount;
	RIM_TINT = 0.5;
}
