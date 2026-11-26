extends Node3D

## Главное меню: анимированный мир с машинкой на поворотном круге, облаками
## и солнцем. Крупные кнопки-картинки ведут в территории и мастерские.

const BUTTONS := [
	{"id": "ride", "title": "Поездка", "icon": "drive", "color": Color(0.35, 0.7, 1.0)},
	{"id": "farm", "title": "Ферма", "icon": "farm", "color": Color(0.5, 0.85, 0.35)},
	{"id": "construction", "title": "Стройка", "icon": "build", "color": Color(1.0, 0.7, 0.25)},
	{"id": "car_wash", "title": "Автомойка", "icon": "water", "color": Color(0.4, 0.9, 1.0)},
	{"id": "paint", "title": "Покраска", "icon": "paint", "color": Color(1.0, 0.5, 0.7)},
	{"id": "repair", "title": "Ремонт", "icon": "wrench", "color": Color(0.95, 0.45, 0.4)},
	{"id": "garage", "title": "Гараж", "icon": "garage", "color": Color(0.7, 0.6, 1.0)},
]

const TERRITORY_BUTTONS := ["city", "farm", "construction", "autotown", "nature"]

var car: VehicleModel
var clouds: Array = []
var _sun: DirectionalLight3D
var _t := 0.0
var _panel: Control
var _ui: Control
var _stars_label: Label
var _car_label: Label
var _settings_panel: Control
var _pending_reset := false


func _ready() -> void:
	SaveSystem.ensure_loaded()
	_build_world()
	_build_ui()
	AudioManager.play_music("music_menu", 1.0)
	AudioManager.say("hello")
	UIManager.fade_from_black(0.6)


func _exit_tree() -> void:
	UIManager.clear_hud()


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = MatLib.make_environment("day")
	env.environment.glow_enabled = true
	add_child(env)
	_sun = MatLib.make_sun(Vector3(-40, -30, 0), 1.4)
	_sun.shadow_enabled = SettingsManager.shadows_enabled()
	add_child(_sun)
	# meadow with a little hill
	var ground := MeshInstance3D.new()
	ground.mesh = MeshGen.heightfield(Vector2(160, 160), 48, Callable(self, "_hill"), 14.0)
	ground.material_override = MatLib.ground("grass")
	add_child(ground)
	var body := StaticBody3D.new()
	add_child(body)
	var cs := CollisionShape3D.new()
	cs.shape = ground.mesh.create_trimesh_shape()
	body.add_child(cs)
	# turntable and car
	Scenery.part(self, Scenery.cyl(3.0, 3.0, 0.3, 48), MatLib.steel(), Vector3(0, 0.15, 0))
	Scenery.part(self, MeshGen.torus(3.0, 0.1, 40, 8), MatLib.chrome(), Vector3(0, 0.3, 0), Vector3(90, 0, 0))
	_spawn_car()
	# scenery around the car: trees, flowers and houses for a cheerful feel
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 14:
		var a := TAU * float(i) / 14.0
		var p := Vector3(cos(a) * 26.0, 0, sin(a) * 26.0)
		if i % 3 == 0:
			Scenery.tree_pine(self, p, rng.randf_range(1.2, 1.8))
		else:
			Scenery.tree_round(self, p, rng.randf_range(1.2, 1.8), Color(0.38, 0.72, 0.32))
	Scenery.flower_patch(self, Vector3(-6, 0, 8), 4.0, 30)
	Scenery.flower_patch(self, Vector3(8, 0, 6), 3.0, 20)
	Scenery.house(self, Vector3(-22, 0, -14), 0.8, Color(1.0, 0.93, 0.78), Color(0.8, 0.32, 0.25), Vector3(6, 3.4, 5))
	# clouds drift across the sky
	for i in 6:
		var c := Node3D.new()
		c.position = Vector3(rng.randf_range(-40, 40), rng.randf_range(16, 22), rng.randf_range(-40, 20))
		add_child(c)
		var mat := MatLib.plastic(Color(1, 1, 1))
		for k in 4:
			Scenery.part(c, Scenery.ball(Vector3(2.4 + k * 0.4, 1.6, 1.8), 10), mat, Vector3(k * 2.2 - 3.3, 0, rng.randf_range(-0.5, 0.5)))
		clouds.append(c)
	# birds and butterflies keep the menu alive
	var cam := Camera3D.new()
	cam.name = "MenuCamera"
	cam.fov = 48.0
	cam.position = Vector3(0, 3.6, 13.0)
	add_child(cam)
	cam.look_at(Vector3(0, 1.7, 0), Vector3.UP)
	cam.make_current()


func _hill(x: float, z: float) -> float:
	var d := Vector2(x, z).length()
	return maxf(0.0, 6.0 - d * 0.1) * sin(x * 0.05) * 0.2 + maxf(0.0, 3.0 - d * 0.08)


func _spawn_car() -> void:
	if car != null and is_instance_valid(car):
		car.queue_free()
	var d := GameState.current_vehicle()
	car = VehicleManager.decor(d, self, Vector3(0, 0.3, 0), 0.0)
	car.scale = Vector3.ONE * clampf(3.0 / maxf(d.length, 1.0), 0.6, 1.2)
	if _car_label != null:
		_car_label.text = d.title


func _build_ui() -> void:
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIManager.attach_hud(_ui)
	var title := UIKit.label("МИР ВЕСЁЛЫХ МАШИНОК 3D", 46, UIKit.ACCENT)
	title.position = Vector2(40, 26)
	_ui.add_child(title)
	_stars_label = UIKit.label("", 34, UIKit.TEXT)
	_stars_label.position = Vector2(1020, 34)
	_ui.add_child(_stars_label)
	_car_label = UIKit.label("", 28, UIKit.TEXT)
	_car_label.position = Vector2(40, 96)
	_ui.add_child(_car_label)
	GameState.stars_changed.connect(func(_n: int) -> void: _refresh_stars())
	_refresh_stars()
	_car_label.text = GameState.current_vehicle().title

	# big picture buttons along the bottom
	var row := UIKit.row(16)
	row.position = Vector2(40, 470)
	_ui.add_child(row)
	for b in BUTTONS:
		var bid := String(b["id"])
		var btn := UIKit.icon_button(String(b["icon"]), String(b["title"]), Color(b["color"]).darkened(0.25), Vector2(150, 150), false)
		btn.hold_mode = false
		btn.font_size = 22
		btn.custom_minimum_size = Vector2(150, 150)
		btn.tapped.connect(func() -> void: _on_button(bid))
		row.add_child(btn)
	var settings := UIKit.icon_button("settings", "", UIKit.CARD, Vector2(96, 96))
	settings.position = Vector2(1280 - 120, 20 + 96 + 10)
	settings.tapped.connect(_open_settings)
	_ui.add_child(settings)
	_build_settings()
	_build_territory_panel()
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")


func _layout() -> void:
	var vs := get_viewport_rect().size
	for c in _ui.get_children():
		if c is HBoxContainer:
			c.position = Vector2((vs.x - c.size.x) * 0.5, vs.y - 190)


func _refresh_stars() -> void:
	_stars_label.text = "★ %d" % GameState.stars


func _on_button(id: String) -> void:
	AudioManager.play_click()
	match id:
		"ride":
			_panel.visible = true
		"farm":
			SceneRouter.goto_territory("farm")
		"construction":
			SceneRouter.goto_territory("construction")
		"car_wash":
			SceneRouter.goto_workshop("car_wash")
		"paint":
			SceneRouter.goto_workshop("paint")
		"repair":
			SceneRouter.goto_workshop("repair")
		"garage":
			SceneRouter.goto_workshop("garage")


func _build_territory_panel() -> void:
	_panel = UIKit.panel(Color(0.06, 0.09, 0.15, 0.93), 34.0)
	_panel.visible = false
	_panel.position = Vector2(180, 110)
	_panel.custom_minimum_size = Vector2(920, 300)
	_ui.add_child(_panel)
	var col := UIKit.col(14)
	_panel.add_child(col)
	var head := UIKit.row(12)
	col.add_child(head)
	head.add_child(UIKit.label("Куда поедем?", 34, UIKit.ACCENT))
	var close := UIKit.icon_button("close", "", UIKit.CARD, Vector2(70, 70))
	close.tapped.connect(func() -> void: _panel.visible = false)
	head.add_child(close)
	var grid := UIKit.row(12)
	col.add_child(grid)
	var names := {"city": ["Город", "car", Color(0.4, 0.7, 1.0)], "farm": ["Ферма", "farm", Color(0.5, 0.85, 0.35)], "construction": ["Стройка", "build", Color(1.0, 0.7, 0.25)], "autotown": ["Автогородок", "garage", Color(0.7, 0.6, 1.0)], "nature": ["Природа", "map", Color(0.4, 0.9, 0.6)]}
	for tid in TERRITORY_BUTTONS:
		var info: Array = names[tid]
		var unlocked := SceneRouter.is_territory_unlocked(tid)
		var b := UIKit.icon_button(String(info[1]) if unlocked else "lock", String(info[0]), Color(info[2]).darkened(0.3) if unlocked else Color(0.2, 0.2, 0.25), Vector2(156, 156), false)
		b.hold_mode = false
		b.font_size = 20
		b.custom_minimum_size = Vector2(156, 156)
		var id2 := tid
		b.tapped.connect(func() -> void: SceneRouter.goto_territory(id2))
		grid.add_child(b)


func _build_settings() -> void:
	_settings_panel = UIKit.panel(Color(0.06, 0.09, 0.15, 0.95), 34.0)
	_settings_panel.visible = false
	_settings_panel.position = Vector2(240, 40)
	_settings_panel.custom_minimum_size = Vector2(800, 0)
	_ui.add_child(_settings_panel)
	var col := UIKit.col(12)
	_settings_panel.add_child(col)
	var head := UIKit.row(12)
	col.add_child(head)
	head.add_child(UIKit.label("Настройки", 34, UIKit.ACCENT))
	var close := UIKit.icon_button("close", "", UIKit.CARD, Vector2(70, 70))
	close.tapped.connect(func() -> void: _settings_panel.visible = false)
	head.add_child(close)
	_toggle_row(col, "Музыка", "music_on")
	_toggle_row(col, "Звуки", "sfx_on")
	_toggle_row(col, "Голоса", "voice_on")
	_toggle_row(col, "Простое управление (для малышей)", "simple_mode")
	_toggle_row(col, "Показывать FPS", "show_fps")
	_option_row(col, "Графика", "graphics", ["low", "medium", "high"], {"low": "Экономная", "medium": "Обычная", "high": "Красивая"})
	var extra := UIKit.row(12)
	col.add_child(extra)
	var restore := UIKit.icon_button("back", "Восстановить копию", UIKit.CARD, Vector2(360, 80), false)
	restore.hold_mode = false
	restore.font_size = 22
	restore.custom_minimum_size = Vector2(360, 80)
	restore.tapped.connect(func() -> void:
		var ok := SaveSystem.restore_backup()
		UIManager.toast("Копия восстановлена!" if ok else "Копии пока нет", "check", UIKit.ACCENT)
		_refresh_stars()
		_spawn_car()
	)
	extra.add_child(restore)
	var reset := UIKit.icon_button("close", "Начать заново", Color(0.7, 0.3, 0.3, 0.95), Vector2(360, 80), false)
	reset.hold_mode = false
	reset.font_size = 22
	reset.custom_minimum_size = Vector2(360, 80)
	reset.tapped.connect(_on_reset)
	extra.add_child(reset)


func _toggle_row(col: VBoxContainer, text: String, key: String) -> void:
	var r := UIKit.row(12)
	col.add_child(r)
	var lab := UIKit.label(text, 26, UIKit.TEXT)
	lab.custom_minimum_size = Vector2(480, 0)
	r.add_child(lab)
	var b := UIKit.icon_button("check", "", UIKit.CARD, Vector2(74, 74))
	b.hold_mode = false
	b.custom_minimum_size = Vector2(74, 74)
	var refresh := func() -> void:
		b.base_color = Color(0.4, 0.9, 0.5, 0.95) if _setting_value(key) else Color(0.35, 0.35, 0.4, 0.95)
		b.icon = "check" if _setting_value(key) else "mute"
		b.queue_redraw()
	refresh.call()
	b.tapped.connect(func() -> void:
		_toggle_setting(key)
		refresh.call()
	)
	r.add_child(b)


func _option_row(col: VBoxContainer, text: String, key: String, options: Array, labels: Dictionary) -> void:
	var r := UIKit.row(12)
	col.add_child(r)
	var lab := UIKit.label(text, 26, UIKit.TEXT)
	lab.custom_minimum_size = Vector2(480, 0)
	r.add_child(lab)
	for o in options:
		var ob := UIKit.icon_button("star", String(labels[o]), UIKit.CARD, Vector2(150, 74), false)
		ob.hold_mode = false
		ob.font_size = 18
		ob.custom_minimum_size = Vector2(150, 74)
		var val := String(o)
		ob.tapped.connect(func() -> void:
			SettingsManager.set_value(key, val)
			SettingsManager.apply_graphics()
			UIManager.toast("Графика: " + String(labels[val]), "star", UIKit.ACCENT)
		)
		r.add_child(ob)


func _setting_value(key: String) -> bool:
	match key:
		"simple_mode":
			return SettingsManager.controls == "simple"
		"music_on":
			return SettingsManager.music_on
		"sfx_on":
			return SettingsManager.sfx_on
		"voice_on":
			return SettingsManager.voice_on
		"show_fps":
			return SettingsManager.show_fps
	return false


func _toggle_setting(key: String) -> void:
	match key:
		"simple_mode":
			SettingsManager.set_value("controls", "full" if SettingsManager.controls == "simple" else "simple")
		"music_on":
			SettingsManager.set_value("music_on", not SettingsManager.music_on)
			AudioManager.apply_settings()
		"sfx_on":
			SettingsManager.set_value("sfx_on", not SettingsManager.sfx_on)
			AudioManager.apply_settings()
		"voice_on":
			SettingsManager.set_value("voice_on", not SettingsManager.voice_on)
		"show_fps":
			SettingsManager.set_value("show_fps", not SettingsManager.show_fps)
	AudioManager.play_click()


func _open_settings() -> void:
	AudioManager.play_click()
	_settings_panel.visible = not _settings_panel.visible


func _on_reset() -> void:
	if not _pending_reset:
		_pending_reset = true
		UIManager.toast("Нажми ещё раз, чтобы начать заново", "close", Color(1, 0.5, 0.4))
		get_tree().create_timer(3.0).timeout.connect(func() -> void: _pending_reset = false)
		return
	_pending_reset = false
	SaveSystem.wipe()
	GameState.reset_to_defaults()
	SaveSystem.save_now()
	_refresh_stars()
	_spawn_car()
	UIManager.toast("Новая игра!", "star", UIKit.ACCENT)


func _process(delta: float) -> void:
	_t += delta
	if car != null and is_instance_valid(car):
		car.rotation.y += delta * 0.5
		car.position.y = 0.3 + sin(_t * 1.6) * 0.03
	for c in clouds:
		c.position.x += delta * 0.8
		if c.position.x > 45.0:
			c.position.x = -45.0
	_sun.rotation_degrees.y = -35.0 + sin(_t * 0.05) * 10.0
