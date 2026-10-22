shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
// Protective bubble: fresnel rim with a slow hexagon-ish shimmer.

uniform vec3 tint : source_color = vec3(0.35, 0.85, 1.0);
uniform float fade = 1.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	float bands = 0.5 + 0.5 * sin(UV.y * 60.0 + TIME * 3.0) * sin(UV.x * 80.0 - TIME * 2.0);
	float a = (rim * 0.9 + bands * 0.08) * fade;
	ALBEDO = tint * a;
	ALPHA = a;
}
