class_name Workshop
extends Node3D

## Shared base for the workshop scenes (car wash, paint shop, repair shop,
## garage). The player's machine stands on a turntable in the middle of a
## bright hall; the touch UI is built by each workshop in _build_ui().

var data: VehicleData
var model: VehicleModel
var cam: Camera3D
var ui_root: Control
var spin := 0.0
var _dragging := false


func _ready() -> void:
	add_to_group("workshop")
	var env := WorldEnvironment.new()
	env.environment = MatLib.make_environment("morning")
	env.environment.ssao_enabled = SettingsManager.quality() > 0.6
	env.environment.glow_enabled = true
	add_child(env)
	var sun := MatLib.make_sun(Vector3(-55, -30, 0), 1.3)
	sun.shadow_enabled = SettingsManager.shadows_enabled()
	add_child(sun)
	_build_hall()
	data = GameState.current_vehicle()
	model = VehicleManager.decor(data, self, Vector3.ZERO, 0.0)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.position = Vector3(0, 2.6, 9.5)
	add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	cam.make_current()
	ui_root = Control.new()
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIManager.attach_hud(ui_root)
	_build_scene_content()
	_build_common_ui()
	_build_ui()


func _exit_tree() -> void:
	UIManager.clear_hud()


func _build_hall() -> void:
	var floor_mat := MatLib.ground("tile")
	Scenery.solid(self, Vector3(60, 0.4, 60), Vector3(0, -0.2, 0), floor_mat, "tile")
	var wall := MatLib.wall(Color(0.86, 0.94, 1.0))
	Scenery.solid(self, Vector3(60, 9, 1.0), Vector3(0, 4.5, -14), wall, "concrete")
	Scenery.solid(self, Vector3(1.0, 9, 60), Vector3(-14, 4.5, 0), wall, "concrete")
	Scenery.solid(self, Vector3(1.0, 9, 60), Vector3(14, 4.5, 0), wall, "concrete")
	var trim := MatLib.plastic(Color(0.98, 0.78, 0.2))
	Scenery.part(self, Scenery.rbox(Vector3(60, 0.5, 1.2), 0.1), trim, Vector3(0, 8.6, -13.4))
	# turntable
	Scenery.part(self, Scenery.cyl(2.8, 2.8, 0.14, 40), MatLib.steel(), Vector3(0, 0.07, 0))
	# light rigs
	for x in [-6.0, 6.0]:
		Scenery.part(self, Scenery.rbox(Vector3(2.4, 0.3, 0.6), 0.1), MatLib.emissive(Color(1, 0.98, 0.9), 1.6), Vector3(x, 8.0, -8.0))


func _build_scene_content() -> void:
	pass


func _build_ui() -> void:
	pass


func _build_common_ui() -> void:
	var back := UIKit.icon_button("back", "", UIKit.CARD, Vector2(110, 110))
	back.position = Vector2(24, 20)
	back.custom_minimum_size = Vector2(110, 110)
	back.tapped.connect(func() -> void:
		AudioManager.play_click()
		SaveSystem.save_now()
		SceneRouter.back_to_world()
	)
	ui_root.add_child(back)
	var menu := UIKit.icon_button("menu", "", UIKit.CARD, Vector2(110, 110))
	menu.position = Vector2(150, 20)
	menu.custom_minimum_size = Vector2(110, 110)
	menu.tapped.connect(func() -> void:
		AudioManager.play_click()
		SaveSystem.save_now()
		SceneRouter.goto_menu()
	)
	ui_root.add_child(menu)
	var title := UIKit.label(_title(), 40, UIKit.ACCENT)
	title.position = Vector2(290, 30)
	ui_root.add_child(title)


func _title() -> String:
	return "Мастерская"


func _process(delta: float) -> void:
	spin += delta
	if not _dragging and model != null:
		model.rotation.y += delta * 0.25 * (1.0 if not _has_turn_lock() else 0.0)
	if model != null and model.get_parent() == self:
		pass


func _has_turn_lock() -> bool:
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_dragging = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenDrag and _dragging:
		model.rotation.y -= (event as InputEventScreenDrag).relative.x * 0.01
	elif event is InputEventMouseMotion and _dragging:
		model.rotation.y -= (event as InputEventMouseMotion).relative.x * 0.01


func save_style(key: String, value) -> void:
	GameState.set_style_value(data.id, key, value)


func style() -> Dictionary:
	return GameState.style(data.id)


func apply_look() -> void:
	var st := style()
	model.apply_style(
		Color(String(st.get("color", "ff3c35"))),
		Color(String(st.get("accent", "f2f6ff"))),
		Color(String(st.get("rim", "ccd3dc"))),
		int(st.get("sticker", 0)))


func _finish_visit(stars: int, text: String) -> void:
	world_reward(stars, text)


func world_reward(stars: int, text: String) -> void:
	GameState.add_stars(stars)
	AudioManager.play_star()
	UIManager.star_popup(stars, text)
	SettingsManager.vibrate(30)
