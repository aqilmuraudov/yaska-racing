shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// 0.14.0 Blender-made karts and drivers (tools/blender/): colour, normal and
// ORM (R occlusion, G roughness, B metallic) baked from a high-poly model into
// one texture set, so a whole kart + driver is a few draws of one material.
// Same painted-toy look as vcolor_gloss.gdshader: saturation boost, rim and a
// clear-coat lobe on smooth parts, plus its camera-occlusion dither.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float saturation = 1.0;
uniform float rim_amount = 0.3;
uniform float gloss = 0.85;
instance uniform float occlusion_fade : hint_range(0.0, 1.0) = 0.0;
// Garage paint (KartPaints): alpha 0 = the model's own colour. orm.a marks the
// paintable body; its baked shading is kept by scaling with the luminance of
// the original body colour (paint_ref_lum, linear).
instance uniform vec4 paint : source_color = vec4(0.0);
// Spinning tyres (KartModel.update_wheels): at speed the tread would strobe
// (it turns more than one tread block per frame), so its detail is blurred
// away: higher mip for colour, flat normal map.
instance uniform float spin_blur : hint_range(0.0, 1.0) = 0.0;
uniform float paint_ref_lum = 0.31;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	if (occlusion_fade > 0.001) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		if ((BAYER[p.y * 4 + p.x] + 0.5) / 16.0 < occlusion_fade) {
			discard;
		}
	}
	vec3 c = texture(albedo_tex, UV, spin_blur * 2.5).rgb;
	vec4 orm4 = texture(orm_tex, UV);
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	if (paint.a > 0.0) {
		c = mix(c, paint.rgb * (l / paint_ref_lum), orm4.a * paint.a);
		l = dot(c, vec3(0.299, 0.587, 0.114));
	}
	ALBEDO = max(mix(vec3(l), c, saturation), vec3(0.0));
	vec3 orm = orm4.rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.6;
	float r = clamp(orm.g, 0.05, 1.0);
	ROUGHNESS = r;
	METALLIC = orm.b;
	NORMAL_MAP = mix(texture(normal_tex, UV).rgb, vec3(0.5, 0.5, 1.0), spin_blur);
	float smooth_part = 1.0 - smoothstep(0.3, 0.6, r);
	CLEARCOAT = gloss * smooth_part;
	CLEARCOAT_ROUGHNESS = 0.12;
	SPECULAR = 0.5 + 0.3 * smooth_part;
	RIM = rim_amount;
	RIM_TINT = 0.5;
}
