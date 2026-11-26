class_name MatLib
extends RefCounted

## Shared material, texture and environment factory.
## Keeps the whole game in one consistent, bright "modern 3D cartoon" style.

# ---------------------------------------------------------------- palette ---
const RED := Color(0.93, 0.24, 0.21)
const BLUE := Color(0.18, 0.52, 0.95)
const SKY_BLUE := Color(0.42, 0.76, 0.98)
const YELLOW := Color(0.99, 0.83, 0.24)
const GREEN := Color(0.34, 0.78, 0.36)
const DARK_GREEN := Color(0.2, 0.55, 0.28)
const ORANGE := Color(1.0, 0.56, 0.16)
const PURPLE := Color(0.62, 0.36, 0.9)
const PINK := Color(1.0, 0.56, 0.8)
const CYAN := Color(0.3, 0.86, 0.9)
const WHITE := Color(0.96, 0.97, 0.98)
const CREAM := Color(0.98, 0.94, 0.84)
const BLACK := Color(0.16, 0.17, 0.2)
const BROWN := Color(0.48, 0.33, 0.2)

const PAINT_PALETTE := [
	Color(0.93, 0.24, 0.21), Color(1.0, 0.55, 0.16), Color(0.99, 0.84, 0.26),
	Color(0.38, 0.8, 0.32), Color(0.24, 0.72, 0.66), Color(0.2, 0.54, 0.95),
	Color(0.5, 0.4, 0.92), Color(1.0, 0.56, 0.8), Color(0.96, 0.96, 0.97),
	Color(0.12, 0.13, 0.16), Color(0.55, 0.36, 0.24), Color(0.72, 0.76, 0.8),
]

const STICKER_COLORS := [
	Color(1.0, 0.95, 0.45), Color(1.0, 0.5, 0.6), Color(0.5, 0.9, 1.0),
	Color(0.65, 1.0, 0.6), Color(0.95, 0.75, 1.0),
]

static var _cache: Dictionary = {}
static var _shaders: Dictionary = {}
static var _noises: Dictionary = {}
static var _noise_tex: Dictionary = {}


static func shader(name: String) -> Shader:
	if _shaders.has(name):
		return _shaders[name]
	var s: Shader = load("res://shaders/%s.gdshader" % name)
	_shaders[name] = s
	return s


static func noise_tex(key: String, seed_value: int = 1, freq: float = 0.09, octaves: int = 3, size: int = 256) -> NoiseTexture2D:
	if _noise_tex.has(key):
		return _noise_tex[key]
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_lacunarity = 2.1
	n.fractal_gain = 0.55
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	_noise_tex[key] = t
	return t


# --------------------------------------------------------------- vehicles ---
## Fresh paint material instance: every part keeps its own dirt / foam state.
static func paint(color: Color = RED, metallic: float = 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader("vehicle_paint")
	m.set_shader_parameter("paint_color", color)
	m.set_shader_parameter("metallic", metallic)
	m.set_shader_parameter("roughness_base", 0.28)
	m.set_shader_parameter("clearcoat_amount", 0.85)
	m.set_shader_parameter("dirt", 0.0)
	m.set_shader_parameter("wet", 0.0)
	m.set_shader_parameter("foam", 0.0)
	m.set_shader_parameter("gloss", 1.0)
	m.set_shader_parameter("scratch", 0.0)
	m.set_shader_parameter("sparkle", 1.0)
	return m


static func cached(key: String, maker: Callable) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material = maker.call()
	_cache[key] = m
	return m


static func glass(tint: Color = Color(0.62, 0.83, 0.95)) -> StandardMaterial3D:
	return cached("glass_%s" % tint.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(tint.r, tint.g, tint.b, 0.68)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.3
		m.roughness = 0.06
		m.metallic_specular = 0.8
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.rim_enabled = true
		m.rim = 0.5
		m.rim_tint = 0.7
		return m) as Material


static func chrome() -> StandardMaterial3D:
	return cached("chrome", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.85, 0.87, 0.9)
		m.metallic = 1.0
		m.roughness = 0.14
		return m) as Material


static func steel() -> StandardMaterial3D:
	return cached("steel", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.62, 0.64, 0.68)
		m.metallic = 0.9
		m.roughness = 0.35
		return m) as Material


static func rubber() -> StandardMaterial3D:
	return cached("rubber", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.1, 0.1, 0.12)
		m.roughness = 0.95
		m.metallic_specular = 0.2
		return m) as Material


static func rim(color: Color = Color(0.78, 0.8, 0.84)) -> StandardMaterial3D:
	return cached("rim_%s" % color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = 0.95
		m.roughness = 0.22
		return m) as Material


static func plastic(color: Color = BLACK) -> StandardMaterial3D:
	return cached("plastic_%s" % color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.6
		m.metallic = 0.05
		return m) as Material


static func emissive(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	return cached("emit_%s_%.2f" % [color.to_html(false), energy], func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.roughness = 0.25
		return m) as Material


static func lamp_on() -> StandardMaterial3D:
	return emissive(Color(1.0, 0.97, 0.78), 3.0)


static func lamp_off() -> StandardMaterial3D:
	return cached("lamp_off", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.9, 0.92, 0.85)
		m.metallic = 0.4
		m.roughness = 0.15
		return m) as Material


# ------------------------------------------------------------------ ground ---
static func ground(kind: String) -> ShaderMaterial:
	if _cache.has("ground_" + kind):
		return _cache["ground_" + kind] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = shader("ground")
	var c1 := Color(0.36, 0.68, 0.28)
	var c2 := Color(0.25, 0.52, 0.2)
	var rough := 0.92
	var wet := 0.0
	var uv := 6.0
	var det := 0.45
	var nkey := "grass"
	match kind:
		"grass":
			c1 = Color(0.4, 0.72, 0.3)
			c2 = Color(0.26, 0.55, 0.24)
			uv = 9.0
		"grass_dark":
			c1 = Color(0.29, 0.56, 0.25)
			c2 = Color(0.2, 0.42, 0.2)
			uv = 7.0
		"asphalt":
			c1 = Color(0.33, 0.34, 0.37)
			c2 = Color(0.25, 0.26, 0.29)
			uv = 5.0
			rough = 0.75
			nkey = "asphalt"
		"asphalt_new":
			c1 = Color(0.22, 0.23, 0.26)
			c2 = Color(0.16, 0.17, 0.2)
			uv = 6.0
			rough = 0.55
			wet = 0.25
			nkey = "asphalt"
		"gravel":
			c1 = Color(0.55, 0.53, 0.48)
			c2 = Color(0.42, 0.4, 0.36)
			uv = 8.0
			nkey = "gravel"
		"dirt":
			c1 = Color(0.52, 0.39, 0.26)
			c2 = Color(0.4, 0.29, 0.19)
			uv = 6.0
			nkey = "dirt"
		"mud":
			c1 = Color(0.38, 0.27, 0.17)
			c2 = Color(0.27, 0.19, 0.12)
			uv = 5.0
			wet = 0.55
			rough = 0.55
			nkey = "dirt"
		"sand":
			c1 = Color(0.9, 0.82, 0.58)
			c2 = Color(0.79, 0.7, 0.47)
			uv = 7.0
			nkey = "sand"
		"soil":
			c1 = Color(0.42, 0.3, 0.19)
			c2 = Color(0.32, 0.22, 0.14)
			uv = 4.0
			nkey = "dirt"
		"concrete":
			c1 = Color(0.74, 0.74, 0.72)
			c2 = Color(0.62, 0.62, 0.6)
			uv = 4.0
			nkey = "concrete"
		"tile":
			c1 = Color(0.85, 0.88, 0.9)
			c2 = Color(0.72, 0.76, 0.8)
			uv = 10.0
			nkey = "concrete"
		"field":
			c1 = Color(0.6, 0.48, 0.3)
			c2 = Color(0.48, 0.37, 0.22)
			uv = 5.0
			nkey = "dirt"
		"plowed":
			c1 = Color(0.36, 0.25, 0.15)
			c2 = Color(0.27, 0.18, 0.11)
			uv = 5.0
			nkey = "dirt"
		"snow":
			c1 = Color(0.95, 0.97, 1.0)
			c2 = Color(0.85, 0.9, 0.98)
			uv = 6.0
	m.set_shader_parameter("base_color", c1)
	m.set_shader_parameter("base_color2", c2)
	m.set_shader_parameter("uv_scale", uv)
	m.set_shader_parameter("roughness_v", rough)
	m.set_shader_parameter("wetness", wet)
	m.set_shader_parameter("detail_strength", det)
	m.set_shader_parameter("detail_tex", noise_tex(nkey, hash(kind), 0.11 if nkey != "concrete" else 0.2, 3))
	_cache["ground_" + kind] = m
	return m


static func water() -> ShaderMaterial:
	return cached("water", func() -> ShaderMaterial:
		var m := ShaderMaterial.new()
		m.shader = shader("water")
		m.set_shader_parameter("noise_tex", noise_tex("water", 77, 0.07, 4))
		return m) as Material as ShaderMaterial


# -------------------------------------------------------------- structures ---
static func wall(color: Color) -> StandardMaterial3D:
	return cached("wall_%s" % color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.albedo_texture = noise_tex("wall", 9, 0.5, 2, 128)
		m.uv1_scale = Vector3(2, 2, 2)
		m.roughness = 0.85
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		return m) as Material


static func roof(color: Color = Color(0.72, 0.27, 0.24)) -> StandardMaterial3D:
	return cached("roof_%s" % color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.6
		m.metallic = 0.15
		m.albedo_texture = noise_tex("roof", 21, 0.35, 2, 128)
		m.uv1_scale = Vector3(3, 3, 3)
		return m) as Material


static func wood(color: Color = Color(0.62, 0.44, 0.26)) -> StandardMaterial3D:
	return cached("wood_%s" % color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.albedo_texture = noise_tex("wood", 33, 0.2, 3, 128)
		m.uv1_scale = Vector3(2.5, 2.5, 2.5)
		m.roughness = 0.8
		return m) as Material


static func window_lit() -> StandardMaterial3D:
	return cached("window_lit", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.55, 0.78, 0.95)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.86, 0.55)
		m.emission_energy_multiplier = 0.55
		m.metallic = 0.5
		m.roughness = 0.08
		return m) as Material


static func road_mark() -> StandardMaterial3D:
	return cached("road_mark", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.97, 0.96, 0.9)
		m.roughness = 0.6
		return m) as Material


# ------------------------------------------------------------------ nature ---
static func foliage(color: Color = Color(0.34, 0.7, 0.3), sway: float = 0.1, height: float = 2.0) -> ShaderMaterial:
	var key := "fol_%s_%.2f_%.2f" % [color.to_html(false), sway, height]
	if _cache.has(key):
		return _cache[key] as ShaderMaterial
	var m := ShaderMaterial.new()
	m.shader = shader("foliage")
	m.set_shader_parameter("leaf_color", color)
	m.set_shader_parameter("leaf_color2", color.darkened(0.28))
	m.set_shader_parameter("sway_amount", sway)
	m.set_shader_parameter("sway_height", height)
	m.set_shader_parameter("translucency", 0.25)
	_cache[key] = m
	return m


static func bark() -> StandardMaterial3D:
	return cached("bark", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.44, 0.31, 0.21)
		m.albedo_texture = noise_tex("bark", 5, 0.35, 3, 128)
		m.uv1_scale = Vector3(3, 3, 3)
		m.roughness = 0.9
		return m) as Material


static func flower(color: Color) -> StandardMaterial3D:
	return cached("flower_%s" % color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.7
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.12
		return m) as Material


static func animal(color: Color) -> StandardMaterial3D:
	return cached("animal_%s" % color.to_html(false), func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.75
		return m) as Material


# --------------------------------------------------------------- atmosphere ---
static func make_environment(mood: String = "day") -> Environment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sun_angle_max = 22.0
	sky_mat.sun_curve = 0.08
	match mood:
		"day":
			sky_mat.sky_top_color = Color(0.28, 0.56, 0.92)
			sky_mat.sky_horizon_color = Color(0.78, 0.9, 0.99)
			sky_mat.ground_horizon_color = Color(0.7, 0.85, 0.95)
			sky_mat.ground_bottom_color = Color(0.35, 0.45, 0.3)
			env.fog_light_color = Color(0.78, 0.88, 0.97)
			env.fog_density = 0.0045
		"sunset":
			sky_mat.sky_top_color = Color(0.36, 0.42, 0.78)
			sky_mat.sky_horizon_color = Color(0.99, 0.72, 0.55)
			sky_mat.ground_horizon_color = Color(0.95, 0.68, 0.5)
			sky_mat.ground_bottom_color = Color(0.3, 0.3, 0.28)
			env.fog_light_color = Color(0.98, 0.78, 0.65)
			env.fog_density = 0.007
		"morning":
			sky_mat.sky_top_color = Color(0.42, 0.66, 0.95)
			sky_mat.sky_horizon_color = Color(0.95, 0.93, 0.85)
			sky_mat.ground_horizon_color = Color(0.88, 0.9, 0.85)
			sky_mat.ground_bottom_color = Color(0.35, 0.42, 0.3)
			env.fog_light_color = Color(0.92, 0.93, 0.9)
			env.fog_density = 0.006
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = 1.15
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.03
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.16
	return env


static func make_sun(rotation_deg: Vector3 = Vector3(-52, -35, 0), energy: float = 1.25) -> DirectionalLight3D:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = rotation_deg
	sun.light_energy = energy
	sun.light_color = Color(1.0, 0.96, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 1.2
	return sun
