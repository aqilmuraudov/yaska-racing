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
uniform float window_cells = 1.0; // 1 = windows (random cells lit), 0 = lamps (all lit)
uniform float lit_share = 0.55;
uniform float glass_grid = 1.0;
uniform vec3 frame_color : source_color = vec3(0.85, 0.88, 0.92);
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
	vec4 orm = texture(orm_tex, UV);
	// 0.15.1: world-space window grid on glass (orm.a): floor lines every
	// 3.6 m and mullions every 1.8 m stay crisp at any distance, where one
	// shared atlas for many towers cannot (the old skyscraper shader did this).
	vec2 gp = n.y > 0.7 ? wpos.xz : (n.x > n.z ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y));
	vec2 gf = fract(gp / vec2(1.8, 3.6));
	vec2 gw = fwidth(gp / vec2(1.8, 3.6)) * 1.5;
	float line = max(1.0 - smoothstep(0.0, 0.06 + gw.x, min(gf.x, 1.0 - gf.x)),
		1.0 - smoothstep(0.0, 0.12 + gw.y, min(gf.y, 1.0 - gf.y)));
	float glass = orm.a * (1.0 - step(0.7, n.y));
	c = mix(c, mix(c * 0.6, frame_color, 0.55), line * glass * glass_grid);
	// Gentle sky gradient on glass: darker low, brighter high (reads as reflection).
	c *= mix(1.0, 0.85 + 0.3 * clamp(wpos.y / 60.0, 0.0, 1.0), glass);
	ALBEDO = c;
	SPECULAR = mix(0.5, 0.25, a.a);
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = clamp(orm.g, 0.05, 1.0);
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	// 0.15.1: only a random share of the window cells is lit at night (one
	// cell = ~2.4 m wide x one 3.6 m floor in world space), with a little warmth
	// variation - like the old skyscraper shader. Lamps (window_cells = 0) glow whole.
	vec3 cell = floor(vec3(wpos.x / 1.8, wpos.y / 3.6, wpos.z / 1.8));
	float h = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
	float lit = mix(1.0, step(h, lit_share) * (0.75 + 0.5 * fract(h * 7.31)) * (1.0 - line), window_cells);
	EMISSION = glow_color * orm.a * window_glow * 1.4 * lit;
}
