shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, depth_draw_opaque;
// 0.13.0 cartoon outline for karts (inverted hull, used as material_overlay
// on the kart body, driver head and torso near the camera only). The hull
// grows with view distance so the line stays about the same thickness.

uniform vec3 color : source_color = vec3(0.07, 0.06, 0.13);
uniform float width = 0.028; // metres at 8 m from the camera

void vertex() {
	float d = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * width * clamp(d / 8.0, 0.7, 2.2);
}

void fragment() {
	ALBEDO = color;
}
