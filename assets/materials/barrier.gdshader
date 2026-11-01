shader_type spatial;
render_mode cull_back, diffuse_burley;
// 0.15.3 track barriers: vertex colours (body / cap / stripes) plus concrete
// grain, panel joints every 3 m and a darker dusty foot, with relief from
// screen-space derivatives (the barrier mesh has no tangents or UVs).

global uniform sampler2D yaska_noise : filter_linear_mipmap, repeat_enable;
varying vec3 lin_col;
varying vec3 wpos;
varying vec3 wnrm;
varying float foot;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 bump_normal(vec3 pos, vec3 nrm, float h) {
	vec3 dpdx = dFdx(pos);
	vec3 dpdy = dFdy(pos);
	vec3 r1 = cross(dpdy, nrm);
	vec3 r2 = cross(nrm, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * nrm - grad);
}

void vertex() {
	lin_col = srgb_to_linear(COLOR.rgb);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	foot = VERTEX.y;
}

void fragment() {
	float vertical = 1.0 - smoothstep(0.4, 0.7, abs(wnrm.y));
	vec2 side_uv = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
	vec2 uv = mix(wpos.xz, side_uv, vertical);
	float grain = texture(yaska_noise, uv * 0.09).r;
	float coarse = texture(yaska_noise, uv * 0.012).r;
	float along = (wpos.x + wpos.z) / 3.0;
	float jw = max(fwidth(along), 0.002) * 1.5;
	float joint = clamp(1.0 - smoothstep(0.0, 0.03 + jw, 1.0 - abs(fract(along) - 0.5) * 2.0), 0.0, 1.0) * vertical;
	float fade = 1.0 - smoothstep(30.0, 60.0, length(VERTEX));
	NORMAL = bump_normal(VERTEX, NORMAL, (grain * 0.004 - joint * 0.012) * fade);
	vec3 col = lin_col * (0.9 + 0.14 * coarse) * (1.0 - 0.3 * joint);
	ALBEDO = col;
	ROUGHNESS = 0.82 - 0.1 * coarse;
}
