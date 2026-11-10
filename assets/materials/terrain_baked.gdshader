shader_type spatial;
render_mode cull_back, diffuse_burley;
// 0.18.0 Qarabağ: the Blender-baked terrain (tools/blender/karabakh_terrain.py).
// albedo_tex holds colour x AO for the whole area (planar UVs from the mesh);
// close to the camera the shared world-space noise breaks the 0.6 m texels
// into grass / leaf-litter speckle, fading out with distance (no shimmer far).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float detail_strength = 0.22;
uniform float detail_fade = 70.0;
uniform float brightness = 1.0;

global uniform sampler2D yaska_noise : filter_linear_mipmap, repeat_enable;
global uniform sampler2D yaska_ao : filter_linear_mipmap, repeat_disable;
global uniform vec4 yaska_ao_rect; // x0, z0, 1/width, 1/depth; z = 0 -> off

varying vec3 world_pos;

float ao_at(vec2 xz) {
	vec2 uv = (xz - yaska_ao_rect.xy) * yaska_ao_rect.zw;
	float a = texture(yaska_ao, uv).r;
	bool inside = yaska_ao_rect.z > 0.0 && uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0;
	return inside ? a : 1.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = texture(albedo_tex, UV).rgb;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(detail_fade * 0.4, detail_fade, dist);
	float n1 = texture(yaska_noise, world_pos.xz * 0.11).r;
	float n2 = texture(yaska_noise, world_pos.xz * 0.37 + vec2(0.31, 0.77)).r;
	float d = (n1 * 0.6 + n2 * 0.4) - 0.5;
	base *= 1.0 + d * detail_strength * 2.0 * fade;
	ALBEDO = base * brightness * ao_at(world_pos.xz);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
