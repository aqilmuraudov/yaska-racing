shader_type spatial;
render_mode cull_back;
// Red / white kerb stripes. UV.y = distance along the track (m).
// 0.15.3: low rumble ridges across the kerb (bump through screen-space
// derivatives, no tangents needed) and a satin painted finish.

uniform vec3 color_a : source_color = vec3(0.86, 0.16, 0.20);
uniform vec3 color_b : source_color = vec3(0.97, 0.96, 0.93);
uniform float stripe_length = 1.6;
uniform float ridge_spacing = 0.4;
uniform float ridge_height = 0.012;

vec3 bump_normal(vec3 pos, vec3 nrm, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	vec3 r1 = cross(dpdy, nrm);
	vec3 r2 = cross(nrm, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * nrm - grad);
}

void fragment() {
	float x = UV.y / stripe_length;
	float w = max(fwidth(x), 0.001);
	float f = fract(x);
	float m = smoothstep(0.5 - w, 0.5 + w, f) - smoothstep(1.0 - w, 1.0, f) + (1.0 - smoothstep(0.0, w, f));
	m = clamp(m, 0.0, 1.0);
	float fade = 1.0 - smoothstep(25.0, 50.0, length(VERTEX));
	float ridge = abs(sin(UV.y * PI / ridge_spacing));
	NORMAL = bump_normal(VERTEX, NORMAL, ridge * ridge_height * fade);
	ALBEDO = mix(color_a, color_b, m) * (0.93 + 0.07 * ridge);
	ROUGHNESS = 0.5;
}
