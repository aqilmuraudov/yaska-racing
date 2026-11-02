shader_type spatial;
// 0.17.2 Nizami street paving (photos): dark grey stone with white
// fish-scale arcs across the street. World-space pattern, no texture
// fetch except the shared cobble grain for a little stone variation.
render_mode cull_disabled;

uniform sampler2D cobble_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 stone_color : source_color = vec3(0.30, 0.31, 0.34);
uniform vec3 line_color : source_color = vec3(0.86, 0.85, 0.82);
uniform float scale = 5.0; // metres per scale (arc width)
uniform float line_w = 0.035; // in scale units

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / scale;
	float row = floor(p.y * 2.0);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = vec2(floor(p.x) + 0.5, row * 0.5);
	// Arc: upper half of a circle of radius 0.5 centred on the cell's bottom edge.
	float d = length(p - cell);
	float arc = 1.0 - smoothstep(line_w * 0.6, line_w, abs(d - 0.5));
	arc *= step(cell.y, p.y);
	float grain = texture(cobble_tex, world_pos.xz / 3.0).r;
	vec3 base = stone_color * (0.82 + 0.36 * grain);
	ALBEDO = mix(base, line_color, arc);
	ROUGHNESS = mix(0.8, 0.6, arc);
}
