shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Rubber track / conveyor with tread that scrolls with the vehicle speed.
uniform vec4 tread_color : source_color = vec4(0.13, 0.13, 0.15, 1.0);
uniform vec4 groove_color : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform float track_offset = 0.0;
uniform float stripes = 14.0;
uniform float roughness_v : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	float s = sin((UV.y + track_offset) * stripes * 6.28318);
	float tread = smoothstep(0.35, 0.75, s);
	ALBEDO = mix(groove_color.rgb, tread_color.rgb, tread);
	ROUGHNESS = roughness_v;
	METALLIC = 0.05;
}
