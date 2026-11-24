shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_alpha_prepass;

uniform vec4 shallow_color : source_color = vec4(0.30, 0.78, 0.86, 1.0);
uniform vec4 deep_color : source_color = vec4(0.07, 0.40, 0.66, 1.0);
uniform float wave_speed = 1.0;
uniform float wave_strength : hint_range(0.0, 0.5) = 0.055;
uniform float wave_scale = 0.7;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float alpha_base : hint_range(0.0, 1.0) = 0.78;

varying vec3 world_pos;

void vertex() {
	float t = TIME * wave_speed;
	vec3 p = VERTEX;
	float w = sin(p.x * wave_scale + t * 1.3) * 0.5 + sin(p.z * wave_scale * 1.3 - t * 1.05) * 0.5;
	w += sin((p.x + p.z) * wave_scale * 2.2 + t * 1.9) * 0.25;
	p.y += w * wave_strength;
	VERTEX = p;
	float dx = cos(p.x * wave_scale + t * 1.3) * wave_strength * wave_scale;
	float dz = cos(p.z * wave_scale * 1.3 - t * 1.05) * wave_strength * wave_scale;
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv1 = world_pos.xz * 0.06 + vec2(TIME * 0.018, TIME * 0.012);
	vec2 uv2 = world_pos.xz * 0.15 - vec2(TIME * 0.014, TIME * 0.019);
	float n1 = texture(noise_tex, uv1).r;
	float n2 = texture(noise_tex, uv2).r;
	float n = clamp(n1 * 0.6 + n2 * 0.4, 0.0, 1.0);
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.2, 0.85, n));
	ALPHA = clamp(alpha_base + n * 0.18, 0.0, 1.0);
	ROUGHNESS = mix(0.05, 0.20, n);
	METALLIC = 0.15;
	SPECULAR = 0.7;
	EMISSION = vec3(0.02, 0.07, 0.09) * n;
}
