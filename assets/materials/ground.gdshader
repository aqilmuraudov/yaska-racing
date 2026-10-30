shader_type spatial;
render_mode cull_back, diffuse_burley;
// Stylised ground. COLOR carries the base tint chosen by the generator;
// world-space noise adds variation; COLOR.a = 1 marks off-road strips that
// get a warning edge stripe (UV2.x = distance from the road edge in m).

uniform float noise_scale = 0.18;
uniform float variation = 0.18;
// 0.8.1 vivid grade: greener grass, warmer paving (one mix, no cost).
uniform float saturation = 1.3;
uniform vec3 warn_color : source_color = vec3(0.96, 0.92, 0.80);
// Painted grass (6 m tiles) and promenade paving (4 m tiles), chosen by the
// generator's vertex tint: green → grass, light warm stone → paving.
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 paving_key : source_color = vec3(0.894, 0.839, 0.722);

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
	vec3 tint = COLOR.rgb;
	vec3 col = srgb_to_linear(tint) * (1.0 - variation * 0.5 + variation * n) * (0.96 + 0.08 * speck);
	float green = clamp((tint.g - max(tint.r, tint.b)) * 6.0, 0.0, 1.0);
	vec3 grass = texture(grass_tex, p / 6.0).rgb * (srgb_to_linear(tint) / vec3(0.17, 0.46, 0.10)) * 0.55;
	col = mix(col, grass * (0.9 + 0.2 * n), green);
	float pav = 1.0 - smoothstep(0.03, 0.09, distance(tint, paving_key));
	col = mix(col, texture(paving_tex, p / 4.0).rgb, pav);
	col = max(mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, saturation), vec3(0.0));
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
