shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// 0.14.1 Blender-made static props (tools/blender/oldcity_props.py): colour,
// normal and ORM baked into one atlas per prop set, one draw per MultiMesh.
// albedo.a marks stone: it gets the world-space limestone texture of
// limestone.gdshader on top (crisp close up, no tiling of the bake); orm.a
// marks window glass, which glows warm at night (window_glow, TimeOfDay).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform sampler2D stone_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float block_w = 0.9;
uniform float block_h = 0.42;
uniform float stone_detail = 1.0;
uniform vec3 tex_mean = vec3(0.768, 0.617, 0.371); // linear mean of the limestone texture
uniform float detail_fade = 60.0;
uniform float window_glow = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.78, 0.42);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 a = texture(albedo_tex, UV);
	vec3 c = a.rgb;
	// World-space stone detail, faded out with distance (mip noise far away).
	vec3 n = abs(wnrm);
	vec2 p = n.y > 0.7 ? wpos.xz : (n.x > n.z ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y));
	vec3 tex = texture(stone_tex, vec2(p.x / (block_w * 4.0), -p.y / (block_h * 4.0))).rgb;
	// Relative to the texture's mean colour (E3CEA4), so the bake keeps the
	// tone, AO and material (warm / plinth) and the texture adds the coursing.
	float blk = fract(sin(dot(floor(vec2(p.x / block_w, p.y / block_h)), vec2(12.9898, 78.233))) * 43758.5453);
	float fade = 1.0 - smoothstep(detail_fade * 0.5, detail_fade, length(VERTEX));
	vec3 detail = tex / tex_mean * (0.94 + blk * 0.1);
	c *= mix(vec3(1.0), detail, a.a * stone_detail * fade);
	ALBEDO = c;
	SPECULAR = mix(0.5, 0.25, a.a);
	vec4 orm = texture(orm_tex, UV);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = clamp(orm.g, 0.05, 1.0);
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	EMISSION = glow_color * orm.a * window_glow * 1.4;
}
