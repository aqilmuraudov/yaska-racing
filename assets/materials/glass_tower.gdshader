shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Mobile-friendly "reflective" glass for the landmark towers: no screen or
// probe reads. A vertical sky gradient, a fresnel sky tint, floor lines and
// mullions that fade out with distance, and a strong sun glint from the
// regular specular term. Uses local-space coordinates of the mesh.

uniform vec3 glass_low : source_color = vec3(0.04, 0.24, 0.66);
uniform vec3 glass_high : source_color = vec3(0.30, 0.66, 0.98);
uniform vec3 sky_tint : source_color = vec3(0.86, 0.94, 1.0);
uniform vec3 frame_color : source_color = vec3(0.80, 0.90, 1.0);
uniform float height = 100.0;
uniform float floor_h = 4.2;
uniform float mullion_w = 3.0;
uniform float sparkle = 0.25;
// Flame Towers LED skin: animated orange/red flame tongues (0 = off).
uniform float flame_led = 0.0;
uniform vec3 flame_hot : source_color = vec3(1.0, 0.78, 0.2);
uniform vec3 flame_red : source_color = vec3(0.95, 0.18, 0.04);

varying vec3 lpos;

void vertex() {
	lpos = VERTEX;
}

float band(float x, float w) {
	float f = abs(fract(x) - 0.5) * 2.0; // 1 at the line, 0 between
	float aa = max(fwidth(x) * 2.0, 0.001);
	return smoothstep(1.0 - w - aa, 1.0 - w + aa, f);
}

void fragment() {
	float t = clamp(lpos.y / height, 0.0, 1.0);
	vec3 col = mix(glass_low, glass_high, smoothstep(0.0, 1.0, t));
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 2.0);
	col = mix(col, sky_tint, fres * 0.4);
	float dist = length(VERTEX);
	float fade = 1.0 - smoothstep(180.0, 700.0, dist);
	float lines = max(band(lpos.y / floor_h, 0.1), band((lpos.x + lpos.z) / mullion_w, 0.06) * 0.6);
	col = mix(col, frame_color, lines * 0.45 * fade);
	ALBEDO = col;
	ROUGHNESS = 0.12;
	METALLIC = 0.35;
	SPECULAR = 0.9;
	EMISSION = col * sparkle * (0.4 + fres);
	if (flame_led > 0.0) {
		float h = lpos.x * 0.9 + lpos.z * 0.7;
		float wob = sin(h * 0.11 + TIME * 1.7) * 2.2 + sin(h * 0.27 - TIME * 2.6) * 1.1;
		float tongue = sin(h * 0.16 + wob) * 0.5 + 0.5; // 1 at the tongue centre
		float rise = t + 0.18 * sin(TIME * 1.3 + h * 0.05);
		float flame = smoothstep(rise - 0.05, rise + 0.35, tongue) * (1.0 - smoothstep(0.82, 1.0, t));
		float pulse = 0.75 + 0.25 * sin(TIME * 0.9);
		vec3 fc = mix(flame_red, flame_hot, smoothstep(0.55, 1.0, tongue) * (1.0 - t));
		// 0.10.1 show: 10 s of flames, then 6 s of the waving national flag
		// (blue / red / green bands), with a 1 s cross-fade.
		float cyc = mod(TIME, 16.0);
		float flag_k = smoothstep(9.5, 10.5, cyc) * (1.0 - smoothstep(15.0, 16.0, cyc));
		float fy = t + 0.05 * sin(h * 0.12 - TIME * 3.0);
		vec3 flag_c = fy > 0.62 ? vec3(0.0, 0.62, 0.9) : (fy > 0.36 ? vec3(0.95, 0.12, 0.2) : vec3(0.0, 0.7, 0.3));
		float flag_on = 1.0 - smoothstep(0.86, 0.96, t);
		vec3 led_c = mix(fc * flame * pulse * 1.6, flag_c * flag_on * 1.3, flag_k);
		float led_a = mix(flame * 0.6, flag_on * 0.7, flag_k);
		ALBEDO = mix(ALBEDO, led_c * 0.35, led_a * flame_led);
		EMISSION += led_c * flame_led;
	}
}
