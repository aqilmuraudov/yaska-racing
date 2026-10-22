shader_type spatial;
render_mode cull_back, diffuse_burley;
// World-space coursed limestone (Old City walls and houses). No UVs needed:
// vertical faces use (along-face, height) coordinates, tops use XZ.
// COLOR tints the stone so one material serves many buildings.

uniform vec3 stone : source_color = vec3(0.92, 0.84, 0.68);
uniform vec3 mortar : source_color = vec3(0.74, 0.66, 0.52);
uniform float block_w = 0.9;
uniform float block_h = 0.42;
uniform float detail_fade = 70.0;

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
	vec2 bp = vec2(p.x / block_w, p.y / block_h);
	bp.x += mod(floor(bp.y), 2.0) * 0.5;
	vec2 cell = floor(bp);
	vec2 f = fract(bp);
	float e = min(min(f.x, 1.0 - f.x) * block_w, min(f.y, 1.0 - f.y) * block_h);
	float dist = length(VERTEX);
	float detail = 1.0 - smoothstep(detail_fade * 0.5, detail_fade, dist);
	float m = (1.0 - smoothstep(0.012, 0.035, e)) * detail;
	float v = hash12(cell) * 0.12 - 0.06;
	vec3 tint = srgb_to_linear(COLOR.rgb);
	vec3 base = stone * tint * (1.0 + v * detail);
	ALBEDO = mix(base, mortar * tint, m * 0.6);
	ROUGHNESS = 0.88;
	SPECULAR = 0.25;
}
