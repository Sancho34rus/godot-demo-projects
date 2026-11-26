class_name Hud
extends Control

## In-game touch interface: steering, gas, brake, action, camera, lights,
## machine specials, quest card, stars and a friendly helper bubble.
## Simple mode (for small children) keeps only steering, one big GO button
## and the action button.

var world: WorldBase
var gas: TouchButton
var brake: TouchButton
var left: TouchButton
var right: TouchButton
var action: TouchButton
var camera_btn: TouchButton
var menu_btn: TouchButton
var lights_btn: TouchButton
var specials: Array = []
var _special_defs: Array = []

var _quest_card: PanelContainer
var _quest_title: Label
var _quest_bar: ProgressBar
var _quest_icon: Control
var _stars_label: Label
var _speed_label: Label
var _cargo_label: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _bubble: PanelContainer
var _bubble_label: Label
var _bubble_timer := 0.0
var _cam_label: Label
var _cam_timer := 0.0
var _kmh := 0.0
var _last_special_count := -1
var _current_prompt: Station


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	get_viewport().size_changed.connect(_layout)
	GameState.stars_changed.connect(_on_stars)
	QuestSystem.quest_changed.connect(_refresh_quest)
	QuestSystem.quest_completed.connect(_on_quest_done)
	_on_stars(GameState.stars)
	_refresh_quest()
	call_deferred("_layout")


func bind(w: WorldBase) -> void:
	world = w
	if w != null and w.player != null:
		w.player.speed_changed.connect(_on_speed)
		w.player.special_used.connect(_on_special_used)
	_rebuild_specials()


func _build() -> void:
	var simple := SettingsManager.controls == "simple"
	left = UIKit.icon_button("arrow_left", "", UIKit.CARD, Vector2(150, 150))
	right = UIKit.icon_button("arrow_right", "", UIKit.CARD, Vector2(150, 150))
	gas = UIKit.icon_button("gas", "ГАЗ", Color(0.35, 0.86, 0.42, 0.95), Vector2(210, 210))
	brake = UIKit.icon_button("brake", "СТОП", Color(0.98, 0.42, 0.36, 0.95), Vector2(150, 150))
	action = UIKit.icon_button("action", "", Color(1.0, 0.8, 0.25, 0.95), Vector2(130, 130))
	camera_btn = UIKit.icon_button("camera", "", UIKit.CARD, Vector2(96, 96))
	menu_btn = UIKit.icon_button("menu", "", UIKit.CARD, Vector2(96, 96))
	lights_btn = UIKit.icon_button("drive", "", UIKit.CARD, Vector2(96, 96))
	for b in [left, right, gas, brake, action, camera_btn, menu_btn, lights_btn]:
		add_child(b)
		b.hold_mode = b in [left, right, gas, brake]
	left.tooltip_text = "Влево"
	gas.label_text = "ГАЗ"
	if simple:
		brake.visible = false
		gas.label_text = "ЕДЕМ"
	camera_btn.tapped.connect(_on_camera)
	menu_btn.tapped.connect(_on_menu)
	lights_btn.tapped.connect(_on_lights)
	action.tapped.connect(_on_action)

	_quest_card = UIKit.panel(UIKit.CARD, 26.0)
	add_child(_quest_card)
	var qrow := UIKit.row(14)
	_quest_card.add_child(qrow)
	_quest_icon = Control.new()
	_quest_icon.custom_minimum_size = Vector2(64, 64)
	_quest_icon.draw.connect(_draw_quest_icon)
	qrow.add_child(_quest_icon)
	var qcol := UIKit.col(4)
	qcol.custom_minimum_size = Vector2(300, 0)
	qrow.add_child(qcol)
	_quest_title = UIKit.label("", 24, UIKit.TEXT)
	_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qcol.add_child(_quest_title)
	_quest_bar = ProgressBar.new()
	_quest_bar.show_percentage = false
	_quest_bar.custom_minimum_size = Vector2(260, 16)
	qcol.add_child(_quest_bar)

	_stars_label = UIKit.label("★ 0", 34, UIKit.ACCENT)
	add_child(_stars_label)
	_speed_label = UIKit.label("0 км/ч", 26, UIKit.TEXT)
	add_child(_speed_label)
	_cargo_label = UIKit.label("", 24, UIKit.TEXT)
	add_child(_cargo_label)
	_cam_label = UIKit.label("", 26, UIKit.TEXT)
	add_child(_cam_label)

	_prompt_panel = UIKit.panel(UIKit.CARD, 26.0)
	_prompt_panel.visible = false
	add_child(_prompt_panel)
	_prompt_label = UIKit.label("", 28, UIKit.TEXT)
	_prompt_panel.add_child(_prompt_label)

	_bubble = UIKit.panel(Color(0.1, 0.14, 0.22, 0.92), 30.0)
	_bubble.visible = false
	add_child(_bubble)
	_bubble_label = UIKit.label("", 30, UIKit.TEXT)
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.custom_minimum_size = Vector2(460, 0)
	_bubble.add_child(_bubble_label)


func _layout() -> void:
	if not is_inside_tree():
		return
	var vs := get_viewport_rect().size
	var m := 28.0
	var sc := clampf(minf(vs.x / 1280.0, vs.y / 720.0), 0.6, 1.4)
	_place(left, Vector2(m, vs.y - 170 * sc), 150 * sc)
	_place(right, Vector2(m + 170 * sc, vs.y - 170 * sc), 150 * sc)
	_place(gas, Vector2(vs.x - 230 * sc, vs.y - 230 * sc), 210 * sc)
	_place(brake, Vector2(vs.x - 400 * sc, vs.y - 170 * sc), 150 * sc)
	_place(action, Vector2(vs.x - 400 * sc, vs.y - 330 * sc), 130 * sc)
	_place(camera_btn, Vector2(vs.x - 120 * sc, m), 96 * sc)
	_place(menu_btn, Vector2(m, m), 96 * sc)
	_place(lights_btn, Vector2(m + 116 * sc, m), 96 * sc)
	_quest_card.position = Vector2(vs.x * 0.5 - 220 * sc, m)
	_quest_card.scale = Vector2.ONE * sc
	_stars_label.position = Vector2(vs.x - 300 * sc, m + 110 * sc)
	_speed_label.position = Vector2(vs.x * 0.5 - 60 * sc, vs.y - 60 * sc)
	_cargo_label.position = Vector2(vs.x * 0.5 - 120 * sc, vs.y - 96 * sc)
	_cam_label.position = Vector2(vs.x - 260 * sc, m + 180 * sc)
	_prompt_panel.position = Vector2(vs.x * 0.5 - 200 * sc, vs.y - 230 * sc)
	_bubble.position = Vector2(vs.x * 0.5 - 230 * sc, vs.y * 0.22)
	_bubble.scale = Vector2.ONE * sc
	_layout_specials(vs, sc)


func _place(c: Control, pos: Vector2, size_px: float) -> void:
	c.position = pos
	c.size = Vector2(size_px, size_px)
	c.custom_minimum_size = Vector2(size_px, size_px)


func _layout_specials(vs: Vector2, sc: float) -> void:
	for i in specials.size():
		var b: TouchButton = specials[i]
		var s := 110.0 * sc
		b.size = Vector2(s, s)
		b.custom_minimum_size = b.size
		b.position = Vector2(vs.x - (150 + i * 128) * sc, vs.y - 470 * sc)


func _rebuild_specials() -> void:
	for b in specials:
		if is_instance_valid(b):
			b.queue_free()
	specials.clear()
	_special_defs.clear()
	if world == null or world.player == null:
		return
	if SettingsManager.controls == "simple":
		return
	_special_defs = world.player.special_buttons()
	for d in _special_defs:
		var b := UIKit.icon_button(String(d["icon"]), String(d["label"]), Color(0.55, 0.78, 1.0, 0.95), Vector2(110, 110))
		b.hold_mode = false
		b.font_size = 20
		var action_name: String = String(d["action"])
		b.tapped.connect(func() -> void: _on_special(action_name))
		add_child(b)
		specials.append(b)
	_layout()


func _process(delta: float) -> void:
	if world == null or world.player == null or not is_instance_valid(world.player):
		return
	var pl: VehicleController = world.player
	var t := 0.0
	var s := 0.0
	if gas.is_down or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		t = 1.0
	if brake.is_down or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		t = -1.0
	if SettingsManager.controls == "simple" and t == 0.0:
		t = 0.0
	if left.is_down or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		s -= 1.0
	if right.is_down or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		s += 1.0
	if SettingsManager.camera_invert:
		s = -s
	pl.throttle = t
	pl.steer_input = clampf(s, -1.0, 1.0)
	_bubble_timer = maxf(0.0, _bubble_timer - delta)
	if _bubble_timer <= 0.0 and _bubble.visible:
		_bubble.visible = false
	_cam_timer = maxf(0.0, _cam_timer - delta)
	_cam_label.visible = _cam_timer > 0.0
	_update_cargo()
	if _last_special_count != _special_defs.size():
		_last_special_count = _special_defs.size()
	if Input.is_key_pressed(KEY_SPACE) and not Input.is_key_pressed(KEY_CTRL):
		pass
	_update_speed_label()


func _update_speed_label() -> void:
	var v := int(round(_kmh))
	_speed_label.text = "%d км/ч" % v if SettingsManager.show_fps == false else "%d км/ч · %d FPS" % [v, Engine.get_frames_per_second()]


func _update_cargo() -> void:
	var pl := world.player
	if pl == null:
		return
	if pl.cargo_max > 0.0:
		_cargo_label.text = "Груз: %d/%d" % [int(pl.cargo), int(pl.cargo_max)]
	else:
		_cargo_label.text = ""


func _on_speed(kmh: float) -> void:
	_kmh = kmh


func _on_stars(total: int) -> void:
	_stars_label.text = "★ %d" % total


func _refresh_quest() -> void:
	var q := QuestSystem.active
	if q.is_empty():
		_quest_title.text = "Новое задание скоро!"
		_quest_bar.value = 0
	else:
		_quest_title.text = "%s\n%d / %d" % [String(q.get("title", "")), int(q.get("progress", 0)), int(q.get("target", 1))]
		_quest_bar.max_value = maxf(1.0, float(q.get("target", 1)))
		_quest_bar.value = float(q.get("progress", 0))
	_quest_icon.queue_redraw()


func _draw_quest_icon() -> void:
	var icon: String = String(QuestSystem.active.get("icon", "star"))
	Icons.draw_icon(_quest_icon, icon, Rect2(Vector2.ZERO, Vector2(64, 64)), UIKit.ACCENT)


func _on_quest_done(_q: Dictionary) -> void:
	UIManager.toast("Задание выполнено! Молодец!", "trophy", Color(1.0, 0.85, 0.3))
	AudioManager.play_success()
	AudioManager.say("success")


func _on_special_used(action_name: String) -> void:
	AudioManager.play_click()


func _on_special(action_name: String) -> void:
	if world == null or world.player == null:
		return
	if action_name == "tool":
		world.player.cycle_tool()
		return
	var pl: VehicleController = world.player
	pl.do_special(action_name, true)


func _on_camera() -> void:
	if world == null or world.camera == null:
		return
	world.camera.cycle_mode()
	_cam_label.text = world.camera.mode_name()
	_cam_timer = 1.6
	AudioManager.play_click()


func _on_lights() -> void:
	if world != null and world.player != null:
		world.player.toggle_lights()
		AudioManager.play_click()


func _on_menu() -> void:
	AudioManager.play_click()
	SaveSystem.save_now()
	SceneRouter.goto_menu()


func _on_action() -> void:
	if world == null:
		return
	world.try_interact()


func set_prompt(s: Station) -> void:
	_current_prompt = s
	if s == null:
		_prompt_panel.visible = false
		return
	_prompt_label.text = "Нажми  •  " + s.title
	_prompt_panel.visible = true


func show_bubble(text: String, seconds: float = 4.0) -> void:
	_bubble_label.text = text
	_bubble.visible = true
	_bubble_timer = seconds


func show_camera_name(name_: String) -> void:
	_cam_label.text = name_
	_cam_timer = 1.6


func _draw() -> void:
	pass
