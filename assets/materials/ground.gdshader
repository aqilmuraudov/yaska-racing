shader_type spatial;
render_mode cull_back, diffuse_burley;
// Stylised ground. COLOR carries the base tint chosen by the generator;
// world-space noise adds variation; COLOR.a = 1 marks off-road strips that
// get a warning edge stripe (UV2.x = distance from the road edge in m).

uniform float noise_scale = 0.18;
uniform float variation = 0.18;
uniform vec3 warn_color : source_color = vec3(0.96, 0.92, 0.80);

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

varying vec3 world_pos;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float dist = length(VERTEX);
	float detail = 1.0 - smoothstep(40.0, 90.0, dist);
	float n = vnoise(p * noise_scale) * 0.65 + vnoise(p * noise_scale * 4.0) * 0.35 * detail;
	float speck = hash12(floor(p * 6.0)) * detail;
	vec3 col = srgb_to_linear(COLOR.rgb) * (1.0 - variation * 0.5 + variation * n) * (0.96 + 0.08 * speck);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
