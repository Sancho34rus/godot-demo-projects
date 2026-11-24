shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Cartoon-PBR car paint that can be painted, dirtied, washed, foamed and dried
// at runtime. All effects are driven by uniforms, so the mechanic is visual.

uniform vec4 paint_color : source_color = vec4(0.92, 0.22, 0.20, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.25;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.35;
uniform float clearcoat_amount : hint_range(0.0, 1.0) = 0.75;

uniform float dirt : hint_range(0.0, 1.0) = 0.0;
uniform vec4 dirt_color : source_color = vec4(0.36, 0.27, 0.17, 1.0);
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float foam : hint_range(0.0, 1.0) = 0.0;
uniform vec4 foam_tint : source_color = vec4(0.72, 0.93, 1.0, 1.0);
uniform float scratch : hint_range(0.0, 1.0) = 0.0;
uniform float gloss : hint_range(0.0, 1.0) = 1.0;
uniform float sparkle : hint_range(0.0, 1.0) = 1.0;

varying vec3 obj_pos;
varying vec3 world_normal;

float hash13(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash13(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash13(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash13(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash13(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash13(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash13(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash13(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash13(i + vec3(1.0, 1.0, 1.0));
	float nx00 = mix(n000, n100, f.x);
	float nx10 = mix(n010, n110, f.x);
	float nx01 = mix(n001, n101, f.x);
	float nx11 = mix(n011, n111, f.x);
	return mix(mix(nx00, nx10, f.y), mix(nx01, nx11, f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	v += noise3(p) * 0.55;
	v += noise3(p * 2.1) * 0.28;
	v += noise3(p * 4.3) * 0.17;
	return v;
}

void vertex() {
	obj_pos = VERTEX;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base = paint_color.rgb;

	// micro sparkle of metallic paint
	float sp = noise3(obj_pos * 90.0) * sparkle;
	base += (sp - 0.5) * 0.05 * sparkle;

	// scratches / worn edges (repair shop)
	float sc = smoothstep(0.62, 0.95, fbm(obj_pos * 26.0)) * scratch;
	base = mix(base, vec3(0.62, 0.62, 0.64), sc * 0.75);

	// dirt: stronger on the lower body and on horizontal panels
	float low_body = clamp(1.0 - obj_pos.y * 0.85, 0.15, 1.0);
	float d = fbm(obj_pos * 7.0 + vec3(3.0, 1.0, 7.0));
	d = smoothstep(0.32, 0.86, d) * low_body;
	float dirt_mask = clamp(d * dirt * 1.55, 0.0, 1.0);
	base = mix(base, dirt_color.rgb * (0.75 + 0.45 * noise3(obj_pos * 40.0)), dirt_mask);

	// foam bubbles for the car wash
	float f = fbm(obj_pos * 9.0 + vec3(11.0, 5.0, 2.0));
	float foam_mask = smoothstep(0.34, 0.72, f) * foam;
	base = mix(base, foam_tint.rgb, clamp(foam_mask, 0.0, 0.95));

	// wet paint darkens and becomes mirror-like
	base *= mix(1.0, 0.82, wet);

	ALBEDO = base;
	METALLIC = metallic * (1.0 - foam_mask * 0.9);
	ROUGHNESS = clamp(mix(roughness_base, 0.82, dirt_mask) * mix(1.0, 0.45, wet) * mix(1.0, 1.35, foam_mask) / max(gloss, 0.05), 0.03, 1.0);
	SPECULAR = mix(0.35, 0.62, wet);
	CLEARCOAT = clearcoat_amount * (1.0 - dirt_mask * 0.8) * (1.0 - foam_mask);
	CLEARCOAT_ROUGHNESS = mix(0.18, 0.02, wet);
	// bubbles / water droplets glimmer
	EMISSION = foam_tint.rgb * foam_mask * 0.06 + vec3(0.02) * wet;
}
