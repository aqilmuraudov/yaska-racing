shader_type canvas_item;
// Optional radial speed blur (accessibility: off by default, never shown
// with "reduce flashing"). Samples the screen a few times towards the centre.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5, 0.55);
	float edge = smoothstep(0.15, 0.6, length(dir));
	vec4 acc = vec4(0.0);
	float s = strength * edge * 0.06;
	for (int i = 0; i < 6; i++) {
		acc += texture(screen_tex, uv - dir * s * float(i) / 5.0);
	}
	COLOR = acc / 6.0;
	COLOR.a = edge * clamp(strength, 0.0, 1.0);
}
