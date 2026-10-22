shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Procedural woven rug inspired by Caucasian carpet layouts: border bands,
// a central medallion and a field of small motifs. UV 0..1 across the rug.

uniform vec3 field : source_color = vec3(0.62, 0.08, 0.12);
uniform vec3 border : source_color = vec3(0.10, 0.16, 0.36);
uniform vec3 motif : source_color = vec3(0.95, 0.78, 0.36);
uniform vec3 accent : source_color = vec3(0.92, 0.9, 0.82);
uniform float seed = 0.0;

float diamond(vec2 p, float r) { return step(abs(p.x) + abs(p.y), r); }

void fragment() {
	vec2 uv = UV;
	vec2 c = uv - 0.5;
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	vec3 col = field;
	if (edge < 0.12) {
		col = border;
		float stripe = step(0.5, fract((uv.x + uv.y) * 14.0 + seed));
		if (edge > 0.04 && edge < 0.09) col = mix(border, motif, stripe * 0.8);
		if (edge < 0.02) col = accent;
	} else {
		// Field of small diamonds
		vec2 g = fract(uv * vec2(6.0, 9.0) + seed * 0.37) - 0.5;
		col = mix(col, motif * 0.9, diamond(g, 0.18));
		col = mix(col, accent, diamond(g, 0.07));
		// Central medallion (stretched diamond with inner layers)
		vec2 m = c * vec2(1.0, 0.62);
		col = mix(col, border, diamond(m, 0.24));
		col = mix(col, motif, diamond(m, 0.18));
		col = mix(col, field * 0.7, diamond(m, 0.11));
		col = mix(col, accent, diamond(m, 0.04));
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
