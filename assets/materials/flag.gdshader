shader_type spatial;
render_mode cull_disabled, diffuse_burley;
// Lightweight waving flag. UV.x = 0 at the hoist (pole), 1 at the fly end.
// Vertex waves grow towards the fly end; normals follow the wave so the
// folds catch the light. The texture is the correctly prepared national
// flag (tools/gen_textures.py: blue / red / green, crescent and star).

uniform sampler2D flag_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float flag_length = 24.0;
uniform float amplitude = 1.1;
uniform float wave_len = 9.0;
uniform float speed = 2.2;

void vertex() {
	float u = UV.x;
	float k = TAU / wave_len;
	float ph = VERTEX.z * k - TIME * speed + UV.y * 0.8;
	float a = amplitude * u;
	VERTEX.x += sin(ph) * a;
	VERTEX.y -= u * u * 0.6; // slight sag at the fly end
	float slope = cos(ph) * a * k;
	NORMAL = normalize(vec3(-1.0, 0.0, slope));
}

void fragment() {
	vec3 c = texture(flag_tex, UV).rgb;
	ALBEDO = c;
	ROUGHNESS = 0.8;
	SPECULAR = 0.2;
	// Fold shading so the waves read from far away.
	AO = 0.85 + 0.15 * abs(dot(NORMAL, vec3(0.0, 0.0, 1.0)));
}
