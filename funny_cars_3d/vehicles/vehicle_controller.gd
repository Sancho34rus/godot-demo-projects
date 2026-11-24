class_name VehicleController
extends VehicleBody3D

## Drives one machine: surface-aware physics, working wheels/tracks, lights,
## dust, engine sound and the special mechanisms of work machines.

signal speed_changed(kmh: float)
signal surface_changed(surface_name: String)
signal special_used(action: String)
signal cargo_changed(amount: float)

const SURFACE_GRIP := {
	"asphalt": 1.0, "asphalt_new": 1.05, "concrete": 1.0, "tile": 1.0,
	"grass": 0.82, "grass_dark": 0.8, "field": 0.78, "plowed": 0.7,
	"dirt": 0.72, "mud": 0.5, "sand": 0.62, "gravel": 0.8, "soil": 0.7,
	"snow": 0.55, "water": 0.45,
}

var data: VehicleData
var model: VehicleModel
var wheel_nodes: Array = []
var camera_target: Node3D
var engine_audio: AudioStreamPlayer3D
var dust: CPUParticles3D
var headlight_l: SpotLight3D
var headlight_r: SpotLight3D
var spray: CPUParticles3D

var throttle := 0.0          # -1 .. 1
var steer_input := 0.0       # -1 .. 1
var controls_enabled := true
var lights_on := false
var siren_on := false
var kid_mode := false
var water_on := false

var current_surface := "asphalt"
var grip := 1.0
var speed := 0.0
var accel_target := 6.0
var tool := ""               # farm implement currently mounted
var cargo := 0.0
var cargo_kind := ""         # "crop", "hay", "sand", "box", "animal"
var cargo_max := 0.0
var mechanism: Dictionary = {}   # current angles / states of special parts
var held: Dictionary = {}

var _flip_timer := 0.0
var _track_offset := 0.0
var _distance_accum := 0.0
var _brake_timer := 0.0
var _initialized := false


func setup(d: VehicleData) -> void:
	if _initialized:
		return
	_initialized = true
	data = d
	mass = d.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, d.height * 0.3, 0)
	angular_damp = 1.4
	linear_damp = 0.05
	contact_monitor = true
	max_contacts_reported = 6
	collision_layer = 2
	collision_mask = 1 | 4
	accel_target = _accel_for(d.kind)
	cargo_max = 0.0
	match d.kind:
		"dump", "truck", "garbage", "tow", "pickup", "tractor":
			cargo_max = 6.0
		"excavator":
			cargo_max = 4.0
		"loader":
			cargo_max = 5.0
		"crane":
			cargo_max = 1.0
		_:
			cargo_max = 0.0
	if d.id == "tractor_trailer":
		cargo_max = 14.0

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(d.width * 0.92, d.height * 0.66, d.length * 0.94)
	shape.shape = box
	shape.position = Vector3(0, d.height * 0.48, 0)
	add_child(shape)

	model = VehicleModel.new()
	model.name = "Model"
	add_child(model)
	model.build(d)
	_build_wheels()
	_build_audio()
	_build_effects()
	_build_lights()
	_build_camera_target()
	_apply_style_from_state()
	_init_mechanisms()


func _accel_for(kind: String) -> float:
	match kind:
		"sport": return 8.0
		"car": return 5.6
		"police": return 6.4
		"suv": return 4.9
		"van": return 4.2
		"pickup": return 4.4
		"ambulance": return 3.6
		"truck": return 2.9
		"fire": return 3.1
		"garbage": return 2.5
		"dump": return 2.4
		"crane": return 2.2
		"bus": return 2.6
		"tow": return 3.2
		"tractor": return 3.2
		"excavator": return 2.4
		"bulldozer": return 2.2
		"loader": return 2.8
		"roller": return 2.4
		_: return 4.0


# --------------------------------------------------------------------- build ---
func _build_wheels() -> void:
	var positions := data.wheel_positions()
	for i in 4:
		var w := VehicleWheel3D.new()
		w.name = "Wheel%d" % i
		w.position = positions[i]
		w.wheel_radius = data.wheel_radius
		w.wheel_rest_length = 0.18
		w.wheel_friction_slip = 3.0
		w.suspension_travel = 0.24
		w.suspension_stiffness = 6.4
		w.suspension_max_force = 9000.0
		w.damping_compression = 0.85
		w.damping_relaxation = 0.9
		w.use_as_steering = i < 2
		w.use_as_traction = true
		w.wheel_roll_influence = 0.08
		add_child(w)
		wheel_nodes.append(w)
		if i < model.wheel_visuals.size():
			var vis: Node3D = model.wheel_visuals[i]
			w.add_child(vis)
			vis.position = Vector3.ZERO
			vis.rotation = Vector3.ZERO
			if data.tracked:
				vis.visible = false


func _build_audio() -> void:
	engine_audio = AudioManager.make_engine_player(data.engine_sound)
	engine_audio.position = Vector3(0, data.height * 0.45, 0)
	engine_audio.volume_db = -16.0
	add_child(engine_audio)
	if engine_audio.stream != null:
		engine_audio.play()


func _build_effects() -> void:
	dust = CPUParticles3D.new()
	dust.amount = SettingsManager.particles_amount()
	dust.lifetime = 1.1
	dust.local_coords = false
	dust.emitting = false
	dust.direction = Vector3(0, 1, 0)
	dust.spread = 55.0
	dust.initial_velocity_min = 0.5
	dust.initial_velocity_max = 2.2
	dust.gravity = Vector3(0, -1.2, 0)
	dust.scale_amount_min = 0.12
	dust.scale_amount_max = 0.42
	dust.color = Color(0.78, 0.7, 0.56, 0.55)
	var puff := SphereMesh.new()
	puff.radius = 0.28
	puff.height = 0.56
	puff.radial_segments = 6
	puff.rings = 3
	dust.mesh = puff
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.8, 0.72, 0.58, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.vertex_color_use_as_albedo = true
	dust.material_override = dm
	dust.position = Vector3(0, 0.2, data.wheel_z_rear)
	add_child(dust)

	# water spray for wet machines / fire truck / wash
	spray = CPUParticles3D.new()
	spray.amount = 28
	spray.lifetime = 0.7
	spray.local_coords = false
	spray.emitting = false
	spray.direction = Vector3(0, -0.2, -1)
	spray.spread = 18.0
	spray.initial_velocity_min = 4.0
	spray.initial_velocity_max = 7.0
	spray.gravity = Vector3(0, -6.0, 0)
	spray.scale_amount_min = 0.06
	spray.scale_amount_max = 0.18
	var drop := SphereMesh.new()
	drop.radius = 0.09
	drop.height = 0.18
	drop.radial_segments = 5
	drop.rings = 2
	spray.mesh = drop
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.65, 0.85, 1.0, 0.72)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spray.material_override = sm
	spray.position = Vector3(0, data.height * 0.6, -data.length * 0.5)
	add_child(spray)


func _build_lights() -> void:
	headlight_l = _make_headlight(Vector3(-data.width * 0.3, data.height * 0.55, -data.length * 0.48), 0.22)
	headlight_r = _make_headlight(Vector3(data.width * 0.3, data.height * 0.55, -data.length * 0.48), -0.22)


func _make_headlight(pos: Vector3, yaw: float) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = pos
	l.rotation_degrees = Vector3(-4, yaw, 0)
	l.spot_range = 26.0
	l.spot_angle = 38.0
	l.light_energy = 2.2
	l.light_color = Color(1.0, 0.96, 0.86)
	l.shadow_enabled = false
	l.visible = false
	add_child(l)
	return l


func _build_camera_target() -> void:
	camera_target = Node3D.new()
	camera_target.name = "CameraTarget"
	camera_target.position = Vector3(0, data.height * 0.85, -data.length * 0.1)
	add_child(camera_target)


# -------------------------------------------------------------------- visuals ---
func _apply_style_from_state() -> void:
	var st := GameState.style(data.id)
	model.apply_style(
		Color(String(st.get("color", "ff3c35"))),
		Color(String(st.get("accent", "f2f6ff"))),
		Color(String(st.get("rim", "ccd3dc"))),
		int(st.get("sticker", 0))
	)
	model.set_dirt(float(st.get("dirt", 0.0)))
	model.set_wet(float(st.get("wet", 0.0)))
	var missing: Array = st.get("wheels_missing", [])
	for m in missing:
		model.set_wheel_visible(int(m), false)
	if bool(st.get("light_broken", false)):
		model.set_lights(false)
		lights_on = false


func apply_style_now() -> void:
	_apply_style_from_state()


func set_lights(on: bool) -> void:
	lights_on = on
	model.set_lights(on)
	if headlight_l != null:
		headlight_l.visible = on
	if headlight_r != null:
		headlight_r.visible = on


func toggle_lights() -> void:
	set_lights(not lights_on)


# ------------------------------------------------------------------ mechanisms ---
func _init_mechanisms() -> void:
	mechanism = {"step_boom": 0, "step_stick": 0, "step_bucket": 0, "step_arm": 0}


func special_buttons() -> Array:
	match data.kind:
		"excavator":
			return [
				{"action": "boom", "icon": "crane", "label": "Стрела"},
				{"action": "bucket", "icon": "bucket", "label": "Ковш"},
				{"action": "swing", "icon": "action", "label": "Поворот"},
			]
		"bulldozer":
			return [{"action": "blade", "icon": "build", "label": "Отвал"}]
		"loader":
			return [
				{"action": "arm", "icon": "crane", "label": "Стрела"},
				{"action": "bucket", "icon": "bucket", "label": "Ковш"},
			]
		"crane":
			return [
				{"action": "boom", "icon": "crane", "label": "Стрела"},
				{"action": "swing", "icon": "action", "label": "Поворот"},
				{"action": "hook", "icon": "gift", "label": "Крюк"},
			]
		"dump":
			return [{"action": "bed", "icon": "build", "label": "Кузов"}]
		"garbage":
			return [{"action": "bed", "icon": "bucket", "label": "Бак"}]
		"tow":
			return [{"action": "bed", "icon": "build", "label": "Площадка"}]
		"tractor", "tractor_trailer":
			return [{"action": "tool", "icon": "tractor", "label": "Прицепное"}]
		"fire":
			return [{"action": "water", "icon": "water", "label": "Вода"}]
		"police", "ambulance":
			return [{"action": "siren", "icon": "sound", "label": "Сирена"}]
		"roller":
			return []
		_:
			return []


func do_special(action: String, pressed: bool) -> void:
	held[action] = pressed
	if not pressed:
		return
	match action:
		"boom":
			if data.kind == "excavator":
				mechanism["step_boom"] = (int(mechanism.get("step_boom", 0)) + 1) % 3
				_tween_rotation(model.pivots.get("boom"), Vector3(_boom_angle(int(mechanism["step_boom"])), 0, 0), 0.9)
				_tween_rotation(model.pivots.get("stick"), Vector3(_stick_angle(int(mechanism["step_boom"])), 0, 0), 0.9)
			elif data.kind == "crane":
				mechanism["step_boom"] = 1 - int(mechanism.get("step_boom", 0))
				_tween_rotation(model.pivots.get("boom"), Vector3(-55.0 - 25.0 * float(mechanism["step_boom"]), 0, 0), 1.4)
		"bucket":
			mechanism["step_bucket"] = (int(mechanism.get("step_bucket", 0)) + 1) % 3
			if data.kind == "loader":
				_tween_rotation(model.pivots.get("bucket"), Vector3(_bucket_angle(int(mechanism["step_bucket"])), 0, 0), 0.7)
			else:
				_tween_rotation(model.pivots.get("bucket"), Vector3(_bucket_angle(int(mechanism["step_bucket"])), 0, 0), 0.7)
		"arm":
			mechanism["step_arm"] = (int(mechanism.get("step_arm", 0)) + 1) % 3
			_tween_rotation(model.pivots.get("arm"), Vector3(_arm_angle(int(mechanism["step_arm"])), 0, 0), 0.9)
		"swing":
			var turret: Node3D = model.pivots.get("turret")
			if turret != null:
				var current: float = turret.rotation.y
				var step: float = PI * 0.5 if data.kind == "crane" else PI / 3.0
				var tw := create_tween()
				tw.tween_property(turret, "rotation:y", current + step, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				model.set_track_offset(0.3)
		"blade":
			mechanism["blade_up"] = not bool(mechanism.get("blade_up", false))
			_tween_rotation(model.pivots.get("blade"), Vector3(-24.0 if mechanism["blade_up"] else 6.0, 0, 0), 0.8)
		"bed":
			mechanism["bed_up"] = not bool(mechanism.get("bed_up", false))
			var target := 52.0 if mechanism["bed_up"] else 0.0
			if data.kind == "tow" or data.kind == "garbage":
				target = -28.0 if mechanism["bed_up"] else 0.0
			_tween_rotation(model.pivots.get("bed"), Vector3(0, 0, target), 1.0)
		"hook":
			mechanism["hook_down"] = not bool(mechanism.get("hook_down", false))
			var hook: Node3D = model.mounts.get("hook")
			if hook != null:
				var tw := create_tween()
				tw.tween_property(hook, "position:y", -6.5 if mechanism["hook_down"] else -2.05, 1.2)
		"tool":
			cycle_tool()
		"water":
			water_on = not water_on
			_set_water(water_on)
		"siren":
			siren_on = not siren_on
			model.set_lights(siren_on or lights_on)
			if siren_on:
				AudioManager.play_sfx("siren", -8.0, 1.0)
	special_used.emit(action)


func _tween_rotation(node: Node3D, target_deg: Vector3, time: float) -> void:
	if node == null:
		return
	var tw := create_tween()
	tw.tween_property(node, "rotation_degrees", target_deg, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _boom_angle(step: int) -> float:
	match step:
		1: return 32.0
		2: return 18.0
		_: return 2.0


func _stick_angle(step: int) -> float:
	match step:
		1: return -38.0
		2: return -8.0
		_: return -14.0


func _bucket_angle(step: int) -> float:
	match step:
		1: return 55.0
		2: return 95.0
		_: return 0.0


func _arm_angle(step: int) -> float:
	match step:
		1: return -34.0
		2: return -6.0
		_: return 8.0


func _set_water(on: bool) -> void:
	if spray != null:
		spray.emitting = on
	if on:
		AudioManager.play_sfx("water", -10.0, 1.1)
	water_on = on


const TOOLS := ["", "plow", "seeder", "sprayer", "harvester", "fork"]


## Cycles farm implements on the tractor's hitch (none, plow, seeder, sprayer,
## harvester, fork). Each implement is built and attached to the hitch mount.
func cycle_tool() -> void:
	var idx := TOOLS.find(tool)
	set_tool(TOOLS[(idx + 1) % TOOLS.size()])
	AudioManager.play_sfx("hydraulic", -10.0, 1.0)
	special_used.emit("tool")


## Farm / construction systems mount an implement on the tractor.
func set_tool(new_tool: String) -> void:
	tool = new_tool
	var mount: Node3D = model.mounts.get("tool")
	if mount == null:
		return
	for c in mount.get_children():
		c.queue_free()
	if new_tool == "" or new_tool == "none":
		return
	var tool_node = FarmTools.build(new_tool, data)
	if tool_node is Node3D:
		mount.add_child(tool_node)


func get_mount(mount_name: String) -> Node3D:
	if model == null:
		return null
	return model.mounts.get(mount_name)


func bucket_tip() -> Vector3:
	var tip := get_mount("bucket_tip")
	if tip != null:
		return tip.global_position
	return global_position + -global_transform.basis.z * (data.length * 0.6)


# ------------------------------------------------------------------ physics ---
func _physics_process(delta: float) -> void:
	if data == null:
		return
	_update_surface()
	var fwd := -global_transform.basis.z
	speed = linear_velocity.dot(fwd)
	speed_changed.emit(absf(speed) * 3.6)
	var t: float = clampf(throttle, -1.0, 1.0) if controls_enabled else 0.0
	var s: float = clampf(steer_input, -1.0, 1.0) if controls_enabled else 0.0
	_apply_engine(t, delta)
	_apply_steering(s, delta)
	_check_flip(delta)
	_distance_accum += absf(speed) * delta
	if _distance_accum > 40.0:
		GameState.add_stat("drive_m", int(_distance_accum))
		_distance_accum = 0.0


func _apply_engine(t: float, delta: float) -> void:
	var n: int = maxi(wheel_nodes.size(), 1)
	var braking := false
	var force := 0.0
	var target_brake := 0.0
	if absf(t) < 0.05:
		# gentle automatic braking, never punishing
		target_brake = 2.2 if absf(speed) > 0.7 else 5.0
	else:
		var dir: float = signf(t)
		if dir < 0.0 and speed > 0.9:
			# brake first, reverse only after stopping
			target_brake = 9.0
			braking = true
		elif dir * speed < -data.max_speed * 0.5:
			target_brake = 2.0
		else:
			var accel: float = accel_target * (0.75 + 0.25 * grip)
			if data.tracked:
				accel *= 0.85
			if dir < 0.0:
				accel *= 0.62
			var speed_ratio: float = absf(speed) / maxf(data.max_speed, 1.0)
			var power_curve: float = clampf(1.0 - speed_ratio * speed_ratio, 0.0, 1.0)
			force = dir * data.mass * accel * power_curve / float(n)
			if kid_mode:
				force *= 0.85
	for w in wheel_nodes:
		w.engine_force = force
		w.brake = target_brake if braking or absf(t) < 0.05 else 0.0
		w.wheel_friction_slip = lerpf(2.2, 3.2, grip)


func _apply_steering(s: float, delta: float) -> void:
	var speed_factor: float = lerpf(1.0, 0.55, clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0))
	var target: float = s * deg_to_rad(data.steer_deg) * speed_factor
	if kid_mode and absf(s) < 0.05:
		target = 0.0
	steering = lerpf(steering, target, clampf(delta * 7.0, 0.0, 1.0))


func _update_surface() -> void:
	var body: Node = null
	for w in wheel_nodes:
		if w.is_in_contact():
			var b: Node3D = w.get_contact_body()
			if b != null:
				body = b
				break
	if body != null and body.has_meta("surface"):
		var surf := String(body.get_meta("surface"))
		if surf != current_surface:
			current_surface = surf
			surface_changed.emit(surf)
		grip = float(SURFACE_GRIP.get(current_surface, 0.9))
	elif body != null:
		current_surface = "grass"
		grip = 0.85


func _check_flip(delta: float) -> void:
	var up := global_transform.basis.y
	if up.dot(Vector3.UP) < 0.25 and absf(speed) < 3.0:
		_flip_timer += delta
		if _flip_timer > 2.2:
			_flip_timer = 0.0
			upright()
	else:
		_flip_timer = 0.0


func upright() -> void:
	var pos := global_position + Vector3(0, 1.2, 0)
	var basis := Basis(Vector3.UP, rotation.y)
	global_transform = Transform3D(basis, pos)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	AudioManager.play_sfx("click", -8.0, 0.8)


# ------------------------------------------------------------------ animation ---
func _process(delta: float) -> void:
	if data == null or model == null:
		return
	# wheel spin for decorative axles and tracks
	var wheel_rot: float = speed / maxf(data.wheel_radius, 0.05)
	for v in model.extra_wheel_visuals:
		if is_instance_valid(v):
			v.rotation.x += wheel_rot * delta
	if data.tracked:
		_track_offset += speed * delta * 0.22
		model.set_track_offset(_track_offset)
	if model.pivots.has("drum"):
		var drum: Node3D = model.pivots["drum"]
		if drum != null:
			drum.rotation.x += wheel_rot * delta
	# engine sound follows the throttle and speed
	if engine_audio != null and engine_audio.stream != null:
		var ratio: float = clampf(absf(speed) / maxf(data.max_speed, 1.0), 0.0, 1.0)
		var target_pitch: float = (0.75 + ratio * 0.9 + absf(throttle) * 0.18) * data.engine_pitch
		engine_audio.pitch_scale = lerpf(engine_audio.pitch_scale, target_pitch, delta * 4.0)
		engine_audio.volume_db = lerpf(engine_audio.volume_db, -20.0 + 8.0 * ratio, delta * 3.0)
	# dust when driving on soft ground
	if dust != null:
		var soft: bool = current_surface in ["dirt", "sand", "mud", "gravel", "field", "plowed", "soil", "grass"]
		dust.emitting = soft and absf(speed) > 3.0
		dust.color = Color(0.86, 0.78, 0.6, 0.55) if current_surface != "mud" else Color(0.4, 0.32, 0.22, 0.6)
	# trailer lags behind the tractor while turning
	if model.trailer_node != null:
		var steer_angle := steering
		model.trailer_node.rotation.y = lerpf(model.trailer_node.rotation.y, -steer_angle * 1.6, delta * 2.5)


func sync_state() -> void:
	# persist amount of dirt / wetness produced by driving on mud
	if data == null:
		return
	var st := GameState.style(data.id)
	var dirty: float = clampf(float(st.get("dirt", 0.0)) + 0.0, 0.0, 1.0)
	if current_surface in ["mud", "sand", "dirt", "soil"] and absf(speed) > 6.0:
		dirty = clampf(dirty + 0.02, 0.0, 1.0)
		GameState.set_style_value(data.id, "dirt", dirty)
		model.set_dirt(dirty)
