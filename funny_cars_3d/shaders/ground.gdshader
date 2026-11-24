shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.36, 0.68, 0.28, 1.0);
uniform vec4 base_color2 : source_color = vec4(0.24, 0.52, 0.2, 1.0);
uniform float uv_scale = 1.0;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.9;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D detail_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.5;
uniform float grain_scale = 3.7;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	float d1 = texture(detail_tex, uv).r;
	float d2 = texture(detail_tex, uv * grain_scale + vec2(0.37, 0.11)).r;
	float m = mix(d1, d2, 0.45);
	vec3 col = mix(base_color.rgb, base_color2.rgb, smoothstep(0.30, 0.78, m));
	col *= 1.0 - detail_strength * 0.35 + detail_strength * 0.7 * m;
	col *= mix(1.0, 0.78, wetness);
	ALBEDO = col;
	ROUGHNESS = mix(roughness_v, 0.18, wetness);
	SPECULAR = mix(0.28, 0.62, wetness);
}
