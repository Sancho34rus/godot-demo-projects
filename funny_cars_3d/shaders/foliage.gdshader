shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Wind-swayed vegetation (trees, bushes, grass, flowers).
uniform vec4 leaf_color : source_color = vec4(0.32, 0.68, 0.26, 1.0);
uniform vec4 leaf_color2 : source_color = vec4(0.22, 0.52, 0.22, 1.0);
uniform float sway_amount : hint_range(0.0, 2.0) = 0.12;
uniform float sway_speed = 1.2;
uniform float sway_height = 1.0;
uniform float translucency : hint_range(0.0, 1.0) = 0.25;

varying vec3 obj_pos;
varying float v_noise;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	obj_pos = VERTEX;
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = hash12(origin.xz * 0.37 + origin.y) * 6.28;
	float h = clamp(VERTEX.y / max(sway_height, 0.001), 0.0, 1.0);
	float w = sin(TIME * sway_speed + phase) + 0.35 * sin(TIME * sway_speed * 2.3 + phase * 1.7);
	VERTEX.x += w * sway_amount * h * h;
	VERTEX.z += cos(TIME * sway_speed * 0.9 + phase * 1.3) * sway_amount * 0.6 * h * h;
	v_noise = hash12(obj_pos.xz * 4.0 + vec2(obj_pos.y));
}

void fragment() {
	vec3 col = mix(leaf_color.rgb, leaf_color2.rgb, v_noise * 0.8);
	col *= 0.88 + 0.24 * v_noise;
	ALBEDO = col;
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
	BACKLIGHT = col * translucency;
}
