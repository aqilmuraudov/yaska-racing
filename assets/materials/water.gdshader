shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Stylised Caspian water: turquoise shallows, deeper blue at grazing angles,
// procedural ripples, no screen reads (cheap on mobile).

uniform vec3 shallow : source_color = vec3(0.08, 0.80, 0.84);
uniform vec3 deep : source_color = vec3(0.02, 0.36, 0.74);
uniform vec3 sparkle : source_color = vec3(0.95, 0.98, 1.0);
uniform float ripple_scale = 0.08;
uniform float speed = 0.35;
uniform vec3 sky_tint : source_color = vec3(1.0, 0.78, 0.55); // golden-hour reflection (0.9.2)

varying vec3 world_pos;
global uniform float yaska_night;

// 0.11.2: one mipmapped fetch of the shared tileable noise (tools/gen_noise.py)
// instead of 4 hashes per call - cheaper on phones and no far-distance shimmer.
global uniform sampler2D yaska_noise : filter_linear_mipmap, repeat_enable;
float vnoise(vec2 p) {
	return texture(yaska_noise, p * 0.015625).r;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(world_pos.x * 0.05 + TIME * 0.8) * 0.12 + cos(world_pos.z * 0.07 + TIME * 0.6) * 0.1;
}

void fragment() {
	vec2 p = world_pos.xz * ripple_scale;
	float t = TIME * speed;
	float h1 = vnoise(p + vec2(t, t * 0.6));
	float h2 = vnoise(p * 2.3 - vec2(t * 0.8, -t * 0.4));
	float h = h1 * 0.6 + h2 * 0.4;
	vec3 n = normalize(vec3((h1 - 0.5) * 0.35, 1.0, (h2 - 0.5) * 0.35));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	float dist = length(VERTEX);
	vec3 col = mix(shallow, deep, clamp(fres * 1.4 + smoothstep(30.0, 250.0, dist) * 0.5, 0.0, 1.0));
	float spark = smoothstep(0.78, 0.92, h) * (1.0 - smoothstep(60.0, 160.0, dist));
	col = mix(col, sky_tint, fres * 0.45);
	vec3 day_col = mix(col, sparkle, spark * 0.35);
	// 0.11.2 night (global yaska_night 0..1): deep navy sea that reflects a
	// little moonlight at grazing angles instead of the bright day turquoise.
	vec3 night_col = mix(vec3(0.020, 0.060, 0.120), vec3(0.006, 0.018, 0.055), clamp(fres * 1.4 + smoothstep(30.0, 250.0, dist) * 0.5, 0.0, 1.0));
	night_col += vec3(0.10, 0.13, 0.22) * fres * 0.6;
	ALBEDO = mix(day_col, night_col, yaska_night);
	// Sun glint by day, cool moon flecks by night; both feed the glow.
	float glint = spark * (1.0 - smoothstep(40.0, 140.0, dist));
	EMISSION = mix(sky_tint * 0.6, vec3(0.55, 0.65, 0.95) * 0.45, yaska_night) * glint;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
