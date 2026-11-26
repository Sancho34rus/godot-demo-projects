extends Workshop

## Автомойка: грязная машина → вода из пистолета → цветная пена → вращающиеся щётки
## → смывание → вытирание → блестящий финал. Каждое действие меняет грязь,
## пену, влажность и блеск кузова на самой модели.

const PHASES := [
	"Смой грязь водой!",
	"Намажь пеной!",
	"Щётки помогут!",
	"Смой пену водой!",
	"Вытри досуха!",
	"Ура! Блестит!",
]
const PHASE_ICONS := ["water", "bubbles", "brush", "water", "check", "trophy"]

var phase := 0
var dirt := 0.0
var foam := 0.0
var wet := 0.0
var _spray: CPUParticles3D
var _bubbles: CPUParticles3D
var _brush_l: Node3D
var _brush_r: Node3D
var _gun: Node3D
var _hold := false
var _wipe_last := Vector2.ZERO
var _wiping := false
var _wipe_amount := 0.0
var _phase_label: Label
var _bar: ProgressBar
var _action: TouchButton
var _icon_ctrl: Control
var _sfx_t := 0.0
var _done := false


func _title() -> String:
	return "Автомойка"


func _build_scene_content() -> void:
	# arch and posts of the wash bay
	var steel := MatLib.plastic(Color(0.25, 0.6, 0.95))
	for x in [-4.6, 4.6]:
		Scenery.part(self, Scenery.rbox(Vector3(0.5, 5.2, 0.5), 0.1), steel, Vector3(x, 2.6, 0.0))
	Scenery.part(self, Scenery.rbox(Vector3(9.8, 0.6, 0.6), 0.1), steel, Vector3(0, 5.2, 0.0))
	for i in 3:
		Scenery.part(self, Scenery.ball(Vector3(0.22, 0.22, 0.22), 8), MatLib.emissive(Color(0.5, 0.9, 1.0), 1.2), Vector3(-3 + i * 3, 5.0, 0.0))
	# rotating brushes on both sides
	var bristle := MatLib.plastic(Color(0.98, 0.5, 0.75))
	var bristle2 := MatLib.plastic(Color(0.55, 0.9, 1.0))
	_brush_l = _make_brush(Vector3(-3.6, 0, 0), bristle)
	_brush_r = _make_brush(Vector3(3.6, 0, 0), bristle2)
	# water gun in the hand
	_gun = Node3D.new()
	_gun.position = Vector3(2.0, 1.2, 4.2)
	add_child(_gun)
	Scenery.part(_gun, Scenery.rbox(Vector3(0.18, 0.3, 0.9), 0.05), MatLib.plastic(Color(1.0, 0.45, 0.15)), Vector3(0, 0, 0))
	Scenery.part(_gun, Scenery.cyl(0.06, 0.06, 0.6, 8), MatLib.plastic(Color(0.2, 0.7, 1.0)), Vector3(0, 0.05, -0.7), Vector3(90, 0, 0))
	_spray = _particles(Color(0.6, 0.86, 1.0, 0.85), 60, 0.55, 0.06, 0.16)
	_spray.position = Vector3(0, 0, -1.1)
	_spray.direction = Vector3(0, 0, -1)
	_spray.initial_velocity_min = 6.0
	_spray.initial_velocity_max = 9.0
	_spray.gravity = Vector3(0, -3, 0)
	_spray.spread = 6.0
	_gun.add_child(_spray)
	_bubbles = _particles(Color(1, 1, 1, 0.85), 80, 1.6, 0.08, 0.2)
	_bubbles.position = Vector3(0, 0.6, 0)
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(data.width * 0.7, 0.6, data.length * 0.5)
	_bubbles.direction = Vector3(0, 1, 0)
	_bubbles.initial_velocity_min = 0.2
	_bubbles.initial_velocity_max = 0.8
	_bubbles.gravity = Vector3(0, 0.3, 0)
	add_child(_bubbles)
	dirt = float(style().get("dirt", 0.0))
	if dirt < 0.3:
		dirt = 0.85
		save_style("dirt", dirt)
		AudioManager.say("dirty_car")
	wet = 0.0
	foam = 0.0
	model.set_dirt(dirt)


func _make_brush(pos: Vector3, mat: Material) -> Node3D:
	var n := Node3D.new()
	n.position = pos + Vector3(0, 1.6, 0)
	add_child(n)
	Scenery.part(n, Scenery.cyl(0.9, 0.9, 3.8, 14), mat, Vector3.ZERO)
	for i in 10:
		var a := TAU * float(i) / 10.0
		Scenery.part(n, Scenery.rbox(Vector3(0.1, 3.6, 0.2), 0.04), mat, Vector3(cos(a) * 0.92, 0, sin(a) * 0.92))
	return n


func _particles(color: Color, amount: int, life: float, min_s: float, max_s: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount if SettingsManager.quality() > 0.5 else amount / 2
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.explosiveness = 0.0
	var m := SphereMesh.new()
	m.radius = max_s
	m.height = max_s * 2.0
	m.radial_segments = 6
	m.rings = 3
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	p.scale_amount_min = min_s / max_s
	p.scale_amount_max = 1.0
	return p


func _build_ui() -> void:
	var col := UIKit.col(14)
	col.position = Vector2(1280 - 380, 40)
	ui_root.add_child(col)
	_phase_label = UIKit.label(PHASES[0], 34, UIKit.TEXT)
	_phase_label.custom_minimum_size = Vector2(340, 0)
	_phase_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_phase_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(340, 22)
	_bar.max_value = 1.0
	col.add_child(_bar)
	_icon_ctrl = Control.new()
	_icon_ctrl.custom_minimum_size = Vector2(90, 90)
	_icon_ctrl.draw.connect(func() -> void: Icons.draw_icon(_icon_ctrl, PHASE_ICONS[phase], Rect2(Vector2.ZERO, Vector2(90, 90)), UIKit.ACCENT))
	col.add_child(_icon_ctrl)
	_action = UIKit.icon_button(PHASE_ICONS[0], "", Color(0.45, 0.85, 1.0, 0.95), Vector2(220, 220))
	_action.position = Vector2(1280 - 260, 720 - 260)
	_action.hold_mode = true
	ui_root.add_child(_action)
	var again := UIKit.icon_button("check", "", Color(0.5, 1.0, 0.6, 0.95), Vector2(120, 120))
	again.position = Vector2(1280 - 420, 720 - 150)
	again.tapped.connect(func() -> void: SceneRouter.back_to_world())
	again.visible = false
	again.name = "Done"
	ui_root.add_child(again)
	_refresh_ui()


func _refresh_ui() -> void:
	_phase_label.text = PHASES[phase]
	_icon_ctrl.queue_redraw()
	_action.icon = PHASE_ICONS[phase]
	_action.queue_redraw()
	var prog := 0.0
	match phase:
		0: prog = 1.0 - clampf(dirt / 0.85, 0.0, 1.0)
		1: prog = clampf(foam, 0.0, 1.0)
		2: prog = 1.0 - clampf(dirt / 0.1, 0.0, 1.0)
		3: prog = clampf(wet, 0.0, 1.0)
		4: prog = 1.0 - clampf(wet, 0.0, 1.0)
		_: prog = 1.0
	_bar.value = prog
	_action.visible = phase < 5
	var again := ui_root.get_node_or_null("Done")
	if again != null:
		again.visible = phase >= 5


func _process(delta: float) -> void:
	super._process(delta)
	_brush_l.rotation.y += delta * 4.0 * (1.0 if _brush_active() else 0.15)
	_brush_r.rotation.y -= delta * 4.0 * (1.0 if _brush_active() else 0.15)
	_hold = _action != null and _action.is_down and phase < 5
	_gun.position.z = lerpf(_gun.position.z, 3.0 if phase != 4 else 4.2, delta * 2.0)
	_spray.emitting = _hold and (phase == 0 or phase == 3)
	_bubbles.emitting = foam > 0.05 and phase < 5
	_bubbles.amount_ratio = clampf(foam, 0.05, 1.0)
	_sfx_t -= delta
	match phase:
		0:
			if _hold:
				dirt = maxf(0.0, dirt - delta * 0.22)
				_sfx(delta, "water")
				if dirt <= 0.3:
					_next(1)
		1:
			if _hold:
				foam = minf(1.0, foam + delta * 0.38)
				_sfx(delta, "foam")
				if foam >= 0.95:
					_next(2)
		2:
			if _hold:
				foam = maxf(0.0, foam - delta * 0.28)
				dirt = maxf(0.0, dirt - delta * 0.16)
				_sfx(delta, "brush")
				if foam <= 0.02 and dirt <= 0.1:
					_next(3)
		3:
			if _hold:
				wet = minf(1.0, wet + delta * 0.4)
				foam = maxf(0.0, foam - delta * 0.5)
				dirt = maxf(0.0, dirt - delta * 0.1)
				_sfx(delta, "water")
				if wet >= 0.9 and foam <= 0.02:
					_next(4)
		4:
			pass
		5:
			if not _done:
				_done = true
				_reveal()
	_apply_visuals()


func _has_turn_lock() -> bool:
	return true


func _brush_active() -> bool:
	return _hold and phase == 2


func _sfx(delta: float, name_: String) -> void:
	if _sfx_t <= 0.0:
		_sfx_t = 0.35
		AudioManager.play_sfx(name_, -8.0, 1.0 + randf() * 0.2)


func _apply_visuals() -> void:
	model.set_dirt(dirt)
	model.set_foam(foam)
	model.set_wet(wet)
	model.set_scratch(0.0)


func _next(p: int) -> void:
	phase = p
	AudioManager.play_success()
	match p:
		1: AudioManager.say("foam_try")
		2: AudioManager.say("brushes")
		3: AudioManager.say("rinse")
		4: AudioManager.say("dry")
	_refresh_ui()
	save_style("dirt", dirt)


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if phase != 4:
		return
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		var rel: Vector2 = (event as InputEventScreenDrag).relative if event is InputEventScreenDrag else (event as InputEventMouseMotion).relative
		var amount := rel.length() * 0.0018
		wet = maxf(0.0, wet - amount)
		_wipe_amount += amount
		if _wipe_amount > 0.05:
			_wipe_amount = 0.0
			AudioManager.play_sfx("swish", -10.0, 1.0)
		if wet <= 0.02:
			_next(5)


func _reveal() -> void:
	dirt = 0.0
	foam = 0.0
	wet = 0.0
	_apply_visuals()
	save_style("dirt", 0.0)
	save_style("wet", 0.0)
	save_style("foam", 0.0)
	var cw: Dictionary = GameState.washing
	cw[data.id] = int(cw.get(data.id, 0)) + 1
	GameState.washing = cw
	GameState.add_stat("wash")
	QuestSystem.report("wash_done", 1)
	world_reward(5, "Блестит!")
	AudioManager.say("great")
	var tw := create_tween()
	tw.tween_property(model, "rotation:y", model.rotation.y + TAU, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bubbles.emitting = false
	var sparks := _particles(Color(1.0, 0.95, 0.5, 0.9), 40, 1.2, 0.05, 0.12)
	sparks.position = Vector3(0, 1.4, 0)
	sparks.explosiveness = 0.9
	sparks.direction = Vector3(0, 1, 0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 2.0
	sparks.initial_velocity_max = 4.0
	sparks.emitting = true
	add_child(sparks)
	_refresh_ui()
