extends Workshop

## Покрасочная мастерская: цвет кузова, полоски, диски и 9 наклеек.
## Каждое нажатие сразу меняет материал на 3D-модели и сохраняется.

const TABS := ["Кузов", "Полоски", "Диски", "Наклейки"]
const STICKER_ICONS := ["star", "gift", "trophy", "animal", "seed", "car", "tractor", "crane", "star"]

var tab := 0
var _tabs_box: HBoxContainer
var _grid: GridContainer
var _painted := false


func _title() -> String:
	return "Покраска"


func _build_scene_content() -> void:
	# paint booth frame and spot lights
	var frame := MatLib.plastic(Color(0.95, 0.5, 0.2))
	for x in [-5.5, 5.5]:
		Scenery.part(self, Scenery.rbox(Vector3(0.4, 4.8, 0.4), 0.1), frame, Vector3(x, 2.4, -1.0))
	Scenery.part(self, Scenery.rbox(Vector3(11.4, 0.4, 0.4), 0.1), frame, Vector3(0, 4.8, -1.0))
	for i in 5:
		Scenery.part(self, Scenery.ball(Vector3(0.3, 0.3, 0.3), 8), MatLib.emissive(Color(1, 0.95, 0.85), 1.5), Vector3(-4 + i * 2, 4.5, -1.0))
	# paint cans on the shelf
	for i in 6:
		Scenery.part(self, Scenery.cyl(0.35, 0.35, 0.8, 12), MatLib.plastic(MatLib.PAINT_PALETTE[i]), Vector3(-10.5 + i * 0.5, 0.4, -6.5))


func _build_ui() -> void:
	_tabs_box = UIKit.row(12)
	_tabs_box.position = Vector2(300, 170)
	ui_root.add_child(_tabs_box)
	for i in TABS.size():
		var b := UIKit.icon_button(["paint", "brush", "car", "star"][i], TABS[i], UIKit.CARD, Vector2(190, 92), false)
		b.hold_mode = false
		b.font_size = 24
		b.custom_minimum_size = Vector2(190, 92)
		var idx := i
		b.tapped.connect(func() -> void: _set_tab(idx))
		_tabs_box.add_child(b)
	var panel := UIKit.panel(Color(0.08, 0.1, 0.16, 0.85), 26.0)
	panel.position = Vector2(20, 320)
	panel.custom_minimum_size = Vector2(1240, 0)
	ui_root.add_child(panel)
	_grid = GridContainer.new()
	_grid.columns = 12
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(_grid)
	var done := UIKit.icon_button("check", "Готово!", Color(0.5, 1.0, 0.6, 0.95), Vector2(190, 92), false)
	done.position = Vector2(1280 - 230, 16)
	done.font_size = 26
	done.hold_mode = false
	done.tapped.connect(_on_done)
	ui_root.add_child(done)
	_set_tab(0)


func _set_tab(i: int) -> void:
	tab = i
	AudioManager.play_click()
	for c in _grid.get_children():
		c.queue_free()
	match tab:
		0:
			_grid.columns = 12
			for col in MatLib.PAINT_PALETTE:
				_swatch(col, "color")
		1:
			_grid.columns = 12
			for col in MatLib.PAINT_PALETTE:
				_swatch(col, "accent")
		2:
			_grid.columns = 12
			for col in MatLib.PAINT_PALETTE:
				_swatch(col, "rim")
		3:
			_grid.columns = 9
			for i2 in 9:
				_sticker_button(i2 + 1)


func _swatch(col: Color, key: String) -> void:
	var b := TouchButton.new()
	b.round_shape = true
	b.hold_mode = false
	b.base_color = Color(col.r, col.g, col.b, 1.0)
	b.icon = ""
	b.custom_minimum_size = Vector2(84, 84)
	b.tapped.connect(func() -> void: _pick(key, col))
	_grid.add_child(b)


func _sticker_button(index: int) -> void:
	var b := UIKit.icon_button(STICKER_ICONS[index - 1], str(index), MatLib.STICKER_COLORS[(index - 1) % MatLib.STICKER_COLORS.size()], Vector2(96, 96))
	b.hold_mode = false
	b.custom_minimum_size = Vector2(96, 96)
	b.tapped.connect(func() -> void: _pick_sticker(index))
	_grid.add_child(b)


func _pick(key: String, col: Color) -> void:
	save_style(key, col.to_html(false))
	apply_look()
	_painted = true
	AudioManager.play_sfx("spray", -6.0, 1.0)
	AudioManager.play_click()
	_burst(col)


func _pick_sticker(index: int) -> void:
	save_style("sticker", index)
	apply_look()
	_painted = true
	AudioManager.play_click()


func _burst(col: Color) -> void:
	var p := CPUParticles3D.new()
	p.amount = 30
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 140.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -6, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.08
	sm.height = 0.16
	p.mesh = sm
	p.material_override = MatLib.plastic(col)
	p.position = Vector3(0, 1.1, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _on_done() -> void:
	if _painted:
		var first := int(GameState.stats.get("paint", 0)) == 0
		GameState.add_stat("paint")
		QuestSystem.report("paint_done", 1)
		world_reward(3 if first else 1, "Красиво!")
		AudioManager.say("painted")
	SaveSystem.save_now()
	SceneRouter.back_to_world()

