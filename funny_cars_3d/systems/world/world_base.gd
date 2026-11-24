class_name WorldBase
extends Node3D

## Shared logic of every territory: lighting and day cycle, terrain, the
## player's machine, chase camera, HUD, stations and the work systems that
## are attached to a zone. Zones only describe their content in _build_zone().

signal station_used(station: Node)

@export var zone_id := "city"
@export var zone_title := "Город"
@export var ground_kind := "grass"
@export var terrain_size := Vector2(320, 320)
@export var sky_mood := "day"
@export var day_speed := 0.012

var player: VehicleController
var camera: ChaseCamera
var hud: Control
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var terrain: StaticBody3D
var systems: Array = []
var spawn_pos := Vector3(0, 0.6, 0)
var spawn_yaw := 0.0
var _day := 0.32
var _lights: Array = []
var _light_t := 0.0
var _station_prompt := ""
var _stations_cache: Array = []
var _interact_cooldown := 0.0
var _pending_vehicle_swap := false
var _flat_paths: Array = []


func _ready() -> void:
	add_to_group("world")
	_setup_environment()
	_build_zone()
	terrain = _make_terrain()
	add_child(terrain)
	_spawn_player()
	_setup_camera()
	_setup_hud()
	_setup_systems()
	if get_node_or_null("MiniGames") == null:
		var mg := MiniGameManager.new()
		mg.name = "MiniGames"
		add_child(mg)
		systems.append(mg)
	GameState.set_meta("current_zone", zone_id)
	AudioManager.play_music("music_main", 1.2)
	AudioManager.play_ambient(zone_id)
	if QuestSystem.active.is_empty():
		QuestSystem.start_next()
	GameState.vehicle_changed.connect(_on_vehicle_changed)
	UIManager.fade_from_black(0.5)
	SaveSystem.save_now()
	_say_welcome()


func _exit_tree() -> void:
	UIManager.clear_hud()
	if GameState.vehicle_changed.is_connected(_on_vehicle_changed):
		GameState.vehicle_changed.disconnect(_on_vehicle_changed)


# ----------------------------------------------------------- overridables ---
func _build_zone() -> void:
	pass


## Raw terrain shape, overridden by each territory.
func raw_height(_x: float, _z: float) -> float:
	return 0.0


## Final ground height: roads and bridges flatten the terrain beside them so
## that every road lies on the ground and never sinks or floats.
func terrain_height(x: float, z: float) -> float:
	var h := raw_height(x, z)
	for seg in _flat_paths:
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var p := Vector2(x, z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		var inner: float = float(seg["w"]) * 0.5
		if d < inner + 5.0:
			var k := clampf((d - inner) / 5.0, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			h = lerpf(0.0, h, k)
	return h


## Road that is laid on this territory's ground and flattens it.
func add_road(a: Vector3, b: Vector3, width: float = 9.0, kind: String = "asphalt", marks: bool = true) -> Node3D:
	_flat_paths.append({"a": Vector2(a.x, a.z), "b": Vector2(b.x, b.z), "w": width})
	return Scenery.road(self, a, b, width, kind, marks)


func welcome_key() -> String:
	return "hello"


func _setup_systems() -> void:
	pass


# ----------------------------------------------------------------- setup ---
func _setup_environment() -> void:
	world_env = WorldEnvironment.new()
	world_env.environment = MatLib.make_environment(sky_mood)
	var quality := SettingsManager.quality()
	var env := world_env.environment
	env.ssao_enabled = quality > 0.6
	env.glow_enabled = quality > 0.6
	env.glow_intensity = 0.35
	env.fog_enabled = true
	env.fog_density = lerpf(0.002, 0.0045, quality)
	add_child(world_env)
	sun = MatLib.make_sun(Vector3(-52, -35, 0), 1.25)
	sun.shadow_enabled = SettingsManager.shadows_enabled()
	sun.directional_shadow_max_distance = lerpf(60.0, 120.0, quality)
	add_child(sun)


func _make_terrain() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Terrain"
	body.set_meta("surface", ground_kind)
	var res := int(lerpf(56.0, 96.0, SettingsManager.quality()))
	var mesh := MeshGen.heightfield(terrain_size, res, Callable(self, "terrain_height"), 40.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MatLib.ground(ground_kind)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	return body


func _spawn_player() -> void:
	var d := GameState.current_vehicle()
	var pos := spawn_pos
	var meta_spawn = GameState.get_meta("spawn_point", "")
	if meta_spawn is Vector3:
		pos = meta_spawn
	elif String(meta_spawn) != "" and has_method("spawn_for"):
		pos = call("spawn_for", String(meta_spawn))
	player = VehicleManager.spawn(d, self, pos, spawn_yaw)
	player.add_to_group("player")
	player.controls_enabled = true
	player.set_lights(false)


func _setup_camera() -> void:
	camera = ChaseCamera.new()
	camera.name = "ChaseCamera"
	add_child(camera)
	camera.setup(player)
	camera.make_current()


func _setup_hud() -> void:
	hud = load("res://ui/hud.gd").new()
	UIManager.attach_hud(hud)
	hud.bind(self)


func _on_vehicle_changed(_id: String) -> void:
	# swap to the newly selected machine when returning from the garage
	if player != null and player.data != null and player.data.id != GameState.selected:
		var pos := player.global_position + Vector3(0, 1.0, 0)
		var yaw := player.rotation.y
		player.queue_free()
		player = null
		await get_tree().process_frame
		player = VehicleManager.spawn(GameState.current_vehicle(), self, pos, yaw)
		camera.vehicle = player
		camera.setup(player)
		hud.bind(self)


# ------------------------------------------------------------- helpers ---
func add_station(kind: String, title: String, pos: Vector3, game_id: String = "", color: Color = Color(1, 0.8, 0.25), icon: String = "star") -> Station:
	var secret_id := ""
	if kind == "gift":
		secret_id = zone_id + ":" + str(pos.round())
		if secret_id in GameState.secrets_found:
			return null
	var st := Station.new()
	st.set_meta("secret_id", secret_id)
	st.kind = kind
	st.title = title
	st.game_id = game_id
	st.color = color
	st.icon = icon
	st.position = Vector3(pos.x, terrain_height(pos.x, pos.z) + 0.05, pos.z)
	add_child(st)
	_stations_cache.append(st)
	return st


func stations() -> Array:
	var out: Array = []
	for s in _stations_cache:
		if is_instance_valid(s):
			out.append(s)
	return out


func nearest_station(from: Vector3, max_dist: float = 9.0) -> Station:
	var best: Station = null
	var best_d := max_dist
	for s in stations():
		var d := from.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


func player_position() -> Vector3:
	if player != null and is_instance_valid(player):
		return player.global_position
	return Vector3.ZERO


func make_traffic_light(pos: Vector3, yaw: float) -> void:
	var n := Scenery.traffic_light(self, pos, yaw)
	_lights.append(n)


func _process(delta: float) -> void:
	_day = fposmod(_day + delta * day_speed * 0.02, 1.0)
	_update_sun()
	_light_t += delta
	if _light_t > 3.0:
		_light_t = 0.0
		_cycle_traffic_lights()
	_interact_cooldown = maxf(0.0, _interact_cooldown - delta)
	_update_prompt()


func _update_sun() -> void:
	if sun == null:
		return
	# slow sun over a long day; the sky stays bright for kids
	var a := _day * TAU
	sun.rotation_degrees = Vector3(-25.0 - 35.0 * sin(a) * sin(a), -35.0 + _day * 360.0 * 0.05, 0)
	var k := clampf(sin(a) * 1.5 + 0.4, 0.0, 1.0)
	sun.light_energy = lerpf(0.55, 1.35, k)
	sun.light_color = Color(1.0, lerpf(0.82, 0.96, k), lerpf(0.7, 0.9, k))


func _cycle_traffic_lights() -> void:
	var phase := int(Time.get_ticks_msec() / 3000) % 3
	for n in _lights:
		if not is_instance_valid(n):
			continue
		var lights: Array = n.get_meta("lights", [])
		for i in lights.size():
			var m: MeshInstance3D = lights[i]
			var on := (i == 0 and phase == 0) or (i == 1 and phase == 2) or (i == 2 and phase == 1)
			var mat: StandardMaterial3D = m.material_override
			mat.emission_energy_multiplier = 3.0 if on else 0.05


func _update_prompt() -> void:
	if player == null or not is_instance_valid(player):
		return
	var s := nearest_station(player.global_position, 8.0)
	var key := s.title if s != null else ""
	if key != _station_prompt:
		_station_prompt = key
		if hud != null and hud.has_method("set_prompt"):
			hud.call("set_prompt", s)


func try_interact() -> void:
	if _interact_cooldown > 0.0:
		return
	_interact_cooldown = 0.35
	# systems first (active minigame targets, farm/construction jobs, cargo)
	for sys in systems:
		if sys.has_method("on_action") and sys.call("on_action", player):
			return
	var s := nearest_station(player_position(), 8.0)
	if s != null:
		on_station(s)


func on_station(s: Station) -> void:
	station_used.emit(s)
	for sys in systems:
		if sys.has_method("on_station") and sys.call("on_station", s):
			return
	match s.kind:
		"carwash":
			SceneRouter.goto_workshop("car_wash")
		"paint":
			SceneRouter.goto_workshop("paint")
		"repair":
			SceneRouter.goto_workshop("repair")
		"garage":
			SceneRouter.goto_workshop("garage")
		"gift":
			_open_gift(s)


func _open_gift(s: Station) -> void:
	var sid := String(s.get_meta("secret_id", ""))
	if GameState.find_secret(sid):
		AudioManager.play_success()
		reward(2, "Подарок!")
		QuestSystem.report("gift", 1)
		QuestSystem.report("secret", 1)
		AudioManager.say("gift")
		s.set_done(true)
		s.queue_free()
	else:
		UIManager.toast("Этот подарок уже открыт!", "gift", Color(1, 0.8, 0.3))


func reward(stars: int, text: String = "Молодец!") -> void:
	GameState.add_stars(stars)
	AudioManager.play_star()
	UIManager.star_popup(stars, text)
	SettingsManager.vibrate(30)


func _say_welcome() -> void:
	await get_tree().create_timer(1.2).timeout
	AudioManager.say(welcome_key())
