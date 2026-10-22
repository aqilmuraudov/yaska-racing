shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Stylised Caspian water: turquoise shallows, deeper blue at grazing angles,
// procedural ripples, no screen reads (cheap on mobile).

uniform vec3 shallow : source_color = vec3(0.16, 0.74, 0.76);
uniform vec3 deep : source_color = vec3(0.07, 0.36, 0.58);
uniform vec3 sparkle : source_color = vec3(0.95, 0.98, 1.0);
uniform float ripple_scale = 0.08;
uniform float speed = 0.35;

varying vec3 world_pos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x),
		mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
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
	ALBEDO = mix(col, sparkle, spark * 0.35);
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
