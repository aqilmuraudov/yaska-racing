shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Mobile-friendly "reflective" glass for the landmark towers: no screen or
// probe reads. A vertical sky gradient, a fresnel sky tint, floor lines and
// mullions that fade out with distance, and a strong sun glint from the
// regular specular term. Uses local-space coordinates of the mesh.

uniform vec3 glass_low : source_color = vec3(0.04, 0.24, 0.66);
uniform vec3 glass_high : source_color = vec3(0.30, 0.66, 0.98);
uniform vec3 sky_tint : source_color = vec3(0.86, 0.94, 1.0);
uniform vec3 frame_color : source_color = vec3(0.80, 0.90, 1.0);
uniform float height = 100.0;
uniform float floor_h = 4.2;
uniform float mullion_w = 3.0;
uniform float sparkle = 0.25;

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

float band(float x, float w) {
	float f = abs(fract(x) - 0.5) * 2.0; // 1 at the line, 0 between
	float aa = max(fwidth(x) * 2.0, 0.001);
	return smoothstep(1.0 - w - aa, 1.0 - w + aa, f);
}

void fragment() {
	float t = clamp(lpos.y / height, 0.0, 1.0);
	vec3 col = mix(glass_low, glass_high, smoothstep(0.0, 1.0, t));
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 2.0);
	col = mix(col, sky_tint, fres * 0.4);
	float dist = length(VERTEX);
	float fade = 1.0 - smoothstep(180.0, 700.0, dist);
	float lines = max(band(lpos.y / floor_h, 0.1), band((lpos.x + lpos.z) / mullion_w, 0.06) * 0.6);
	col = mix(col, frame_color, lines * 0.45 * fade);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.35;
	SPECULAR = 0.9;
	EMISSION = col * sparkle * (0.4 + fres);
}
