extends Workshop

## Ремонтный центр. Машинка приезжает с поломками (колесо, спущенная шина,
## фара, мотор, царапина, грязь). Ребёнок выбирает инструмент и нажимает на
## деталь на машинке или перетаскивает запасное колесо на ступицу. Каждый
## инструмент проигрывает понятную анимацию.

const TOOLS := [
	{"id": "wrench", "icon": "wrench", "label": "Ключ"},
	{"id": "pump", "icon": "water", "label": "Насос"},
	{"id": "bulb", "icon": "star", "label": "Фара"},
	{"id": "engine", "icon": "settings", "label": "Мотор"},
	{"id": "brush", "icon": "paint", "label": "Краска"},
	{"id": "sponge", "icon": "bubbles", "label": "Мойка"},
]

var tool := "wrench"
var _colliders: Dictionary = {}
var _tool_btns: Dictionary = {}
var _status: Label
var _smoke: CPUParticles3D
var _engine_pos := Vector3.ZERO
var _light_pos := []
var _done_once := false


func _title() -> String:
	return "Ремонт"


func _build_scene_content() -> void:
	# lift and workbench
	var red := MatLib.plastic(Color(0.9, 0.3, 0.2))
	for x in [-4.8, 4.8]:
		for z in [-2.6, 2.6]:
			Scenery.part(self, Scenery.rbox(Vector3(0.35, 0.5, 0.35), 0.1), red, Vector3(x, 0.25, z))
	Scenery.part(self, Scenery.rbox(Vector3(2.2, 0.8, 1.2), 0.1), MatLib.steel(), Vector3(-9.0, 0.4, -6.0))
	Scenery.part(self, Scenery.rbox(Vector3(2.3, 0.12, 1.3), 0.04), MatLib.wood(Color(0.8, 0.55, 0.3)), Vector3(-9.0, 0.86, -6.0))
	# spare wheels rack on the wall
	for i in 4:
		Scenery.part(self, MeshGen.torus(0.42, 0.16, 16, 8), MatLib.rubber(), Vector3(9.0 + (i % 2) * 1.2, 2.2 + (i / 2) * 1.2, -12.6), Vector3(0, 0, 0))
	# colliders for picking parts with the ray
	_add_collider("body", Vector3(0, data.height * 0.5, 0), Vector3(data.width, data.height, data.length))
	for i in 4:
		var wp := model.wheel_visuals[i].position if i < model.wheel_visuals.size() else Vector3.ZERO
		var wc := _add_collider("wheel%d" % i, wp, Vector3(data.wheel_radius * 2.2, data.wheel_radius * 2.2, data.wheel_radius * 2.2))
		_colliders["wheel%d" % i] = wc
	_engine_pos = Vector3(0, data.height * 0.55, -data.length * 0.42)
	_add_collider("engine", _engine_pos, Vector3(data.width * 0.7, 0.8, 1.2))
	for s in [-1.0, 1.0]:
		var lp := Vector3(s * data.width * 0.3, data.height * 0.55, -data.length * 0.5)
		_light_pos.append(lp)
		_add_collider("light", lp, Vector3(0.7, 0.5, 0.6))
	_smoke = CPUParticles3D.new()
	_smoke.amount = 14
	_smoke.lifetime = 2.2
	_smoke.emitting = false
	_smoke.position = _engine_pos + Vector3(0, 0.6, 0)
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.spread = 25.0
	_smoke.initial_velocity_min = 0.6
	_smoke.initial_velocity_max = 1.2
	_smoke.gravity = Vector3(0, 0.3, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	_smoke.mesh = sm
	_smoke.material_override = MatLib.plastic(Color(0.5, 0.5, 0.52, 0.6))
	add_child(_smoke)
	_roll_issues()
	_refresh_visuals()


func _add_collider(part_name: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.set_meta("part", part_name)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	return b


## The car arrives with things to fix when it has nothing wrong yet, so the
## workshop always has a useful job for the child.
func _roll_issues() -> void:
	var st := style()
	var missing: Array = st.get("wheels_missing", [])
	var broken := missing.size() > 0 or bool(st.get("light_broken", false)) or bool(st.get("engine_broken", false)) or Array(st.get("tire_flat", [])).size() > 0
	if broken:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var choice := rng.randi() % 3
	if choice == 0:
		save_style("wheels_missing", [rng.randi() % 4])
	elif choice == 1:
		save_style("light_broken", true)
		save_style("engine_broken", true)
	else:
		save_style("tire_flat", [rng.randi() % 4])
		save_style("scratch", 0.8)
	AudioManager.say("repair_intro")


func _refresh_visuals() -> void:
	var st := style()
	var missing: Array = st.get("wheels_missing", [])
	var flat: Array = st.get("tire_flat", [])
	for i in 4:
		model.set_wheel_visible(i, not missing.has(i))
		var wv: Node3D = model.wheel_visuals[i] if i < model.wheel_visuals.size() else null
		if wv != null:
			wv.scale = Vector3(1, 0.78 if flat.has(i) else 1.0, 1)
	model.set_lights(not bool(st.get("light_broken", false)))
	_smoke.emitting = bool(st.get("engine_broken", false))
	model.set_scratch(float(st.get("scratch", 0.0)))
	model.set_dirt(float(st.get("dirt", 0.0)))
	if _status != null:
		_status.text = _describe()


func _describe() -> String:
	var st := style()
	var left := 0
	left += Array(st.get("wheels_missing", [])).size()
	left += Array(st.get("tire_flat", [])).size()
	left += 1 if bool(st.get("light_broken", false)) else 0
	left += 1 if bool(st.get("engine_broken", false)) else 0
	left += 1 if float(st.get("scratch", 0.0)) > 0.05 else 0
	if left == 0:
		return "Всё починили! Молодец!"
	return "Осталось починить: %d" % left


func _build_ui() -> void:
	var row := UIKit.row(10)
	row.position = Vector2(300, 170)
	ui_root.add_child(row)
	for t in TOOLS:
		var b := UIKit.icon_button(String(t["icon"]), String(t["label"]), UIKit.CARD, Vector2(150, 110), false)
		b.hold_mode = false
		b.font_size = 22
		b.custom_minimum_size = Vector2(150, 110)
		var tid := String(t["id"])
		b.tapped.connect(func() -> void: _set_tool(tid))
		row.add_child(b)
		_tool_btns[tid] = b
	_status = UIKit.label("", 34, UIKit.ACCENT)
	_status.position = Vector2(20, 640)
	ui_root.add_child(_status)
	_set_tool("wrench")
	_refresh_visuals()


func _set_tool(id: String) -> void:
	tool = id
	AudioManager.play_click()
	for k in _tool_btns:
		var b: TouchButton = _tool_btns[k]
		b.base_color = Color(1.0, 0.8, 0.25, 0.95) if k == id else UIKit.CARD


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
		pressed = true
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
		pressed = true
	if not pressed:
		return
	if pos.y < 200 or pos.y > 620:
		return
	_pick_at(pos)


func _pick_at(screen: Vector2) -> void:
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 60.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var collider = hit["collider"]
	if not collider is StaticBody3D or not collider.has_meta("part"):
		return
	var part_name := String(collider.get_meta("part"))
	_apply_tool(part_name, hit["position"])


func _apply_tool(part_name: String, at: Vector3) -> void:
	var st := style()
	var missing: Array = st.get("wheels_missing", [])
	var flat: Array = st.get("tire_flat", [])
	var wi := -1
	if part_name.begins_with("wheel"):
		wi = int(part_name.substr(5))
	match tool:
		"wrench":
			if wi >= 0:
				if missing.has(wi):
					missing.erase(wi)
					save_style("wheels_missing", missing)
					_tool_anim(at, "wrench")
					_fixed("Колесо на месте!", "Колесо поставлено", 1)
				else:
					missing.append(wi)
					save_style("wheels_missing", missing)
					_tool_anim(at, "wrench")
					AudioManager.play_sfx("click", -4.0, 0.9)
					UIManager.toast("Колесо снято. Поставь его обратно!", "wrench", UIKit.ACCENT)
		"pump":
			if wi >= 0 and flat.has(wi):
				flat.erase(wi)
				save_style("tire_flat", flat)
				_tool_anim(at, "pump")
				_fixed("Шина накачана!", "Шина накачана", 1)
			elif wi >= 0:
				UIManager.toast("Шина уже в порядке", "water", UIKit.ACCENT)
		"bulb":
			if part_name == "light" and bool(st.get("light_broken", false)):
				save_style("light_broken", false)
				_tool_anim(at, "bulb")
				_fixed("Фары горят!", "Фары заменены", 1)
		"engine":
			if part_name == "engine" and bool(st.get("engine_broken", false)):
				save_style("engine_broken", false)
				_tool_anim(at, "engine")
				_fixed("Мотор работает!", "Мотор починен", 2)
		"brush":
			if part_name == "body" and float(st.get("scratch", 0.0)) > 0.0:
				save_style("scratch", 0.0)
				_tool_anim(at, "brush")
				_fixed("Как новенькая краска!", "Покраска", 1)
		"sponge":
			if part_name == "body":
				var d := float(st.get("dirt", 0.0))
				if d > 0.0:
					save_style("dirt", maxf(0.0, d - 0.35))
					_tool_anim(at, "sponge")
					AudioManager.play_sfx("foam", -8.0, 1.1)
					_refresh_visuals()
		_:
			pass
	_refresh_visuals()
	_check_all()


func _fixed(msg: String, what: String, stars: int) -> void:
	AudioManager.play_success()
	AudioManager.say("well_done")
	UIManager.toast(msg, "check", Color(0.5, 1.0, 0.6))
	QuestSystem.report("repair_done", 1)
	GameState.add_stat("repair")
	world_reward(stars, "Починили!")
	_refresh_visuals()


func _check_all() -> void:
	if _describe().begins_with("Всё") and not _done_once:
		_done_once = true
		AudioManager.say("great")
		UIManager.star_popup(3, "Всё готово!")
		GameState.add_stars(3)
		var tw := create_tween()
		tw.tween_property(model, "position:y", 0.25, 0.4).set_trans(Tween.TRANS_BOUNCE)
		tw.tween_property(model, "position:y", 0.0, 0.4)
	elif not _describe().begins_with("Всё"):
		_done_once = false


func _tool_anim(at: Vector3, kind: String) -> void:
	var n := Node3D.new()
	n.position = at + Vector3(0, 1.0, 0.4)
	add_child(n)
	match kind:
		"wrench":
			Scenery.part(n, Scenery.rbox(Vector3(0.12, 0.8, 0.12), 0.04), MatLib.chrome(), Vector3(0, 0, 0), Vector3(0, 0, 30))
			Scenery.part(n, MeshGen.torus(0.18, 0.06, 12, 6), MatLib.chrome(), Vector3(0.1, 0.4, 0))
		"pump":
			Scenery.part(n, Scenery.cyl(0.08, 0.08, 0.9, 10), MatLib.plastic(Color(0.3, 0.7, 1.0)), Vector3(0, 0, 0))
		"bulb":
			Scenery.part(n, MeshGen.ball(0.18, 10, 12), MatLib.emissive(Color(1, 0.95, 0.6), 2.0), Vector3(0, 0, 0))
		"engine":
			Scenery.part(n, MeshGen.ball(0.2, 8, 10), MatLib.emissive(Color(1, 0.6, 0.2), 2.4), Vector3(0, 0, 0))
		"brush":
			Scenery.part(n, Scenery.rbox(Vector3(0.14, 0.7, 0.14), 0.04), MatLib.wood(Color(0.9, 0.7, 0.3)), Vector3(0, 0, 0))
			Scenery.part(n, Scenery.rbox(Vector3(0.36, 0.16, 0.2), 0.04), MatLib.plastic(Color(0.95, 0.4, 0.5)), Vector3(0, -0.45, 0))
		_:
			Scenery.part(n, MeshGen.ball(0.22, 8, 10), MatLib.plastic(Color(0.95, 0.95, 1.0)), Vector3(0, 0, 0))
	var tw := create_tween()
	tw.tween_property(n, "rotation:z", 0.7, 0.18)
	tw.tween_property(n, "rotation:z", -0.7, 0.18)
	tw.tween_property(n, "rotation:z", 0.0, 0.12)
	tw.tween_callback(n.queue_free)
	AudioManager.play_sfx("tool", -6.0, 1.0)
	var sp := CPUParticles3D.new()
	sp.position = at
	sp.amount = 14
	sp.lifetime = 0.6
	sp.one_shot = true
	sp.explosiveness = 1.0
	sp.spread = 180.0
	sp.initial_velocity_min = 1.0
	sp.initial_velocity_max = 2.2
	sp.gravity = Vector3(0, -4, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sp.mesh = sm
	sp.material_override = MatLib.emissive(Color(1, 0.9, 0.5), 1.5)
	add_child(sp)
	sp.emitting = true
	get_tree().create_timer(1.0).timeout.connect(sp.queue_free)
