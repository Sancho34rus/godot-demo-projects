extends Workshop

## Гараж: выбор машинки из коллекции, открытие новых по звёздочкам, покупка
## украшений для личной территории (за звёздочки) и показ достижений.

const DECOR := [
	{"id": "lamp", "title": "Фонарь", "cost": 2, "icon": "star"},
	{"id": "flowers", "title": "Клумба", "cost": 3, "icon": "seed"},
	{"id": "flag", "title": "Флажки", "cost": 4, "icon": "trophy"},
	{"id": "fence", "title": "Заборчик", "cost": 5, "icon": "lock"},
]

var _cards: HBoxContainer
var _decor_row: HBoxContainer
var _props: Node3D
var _info: Label
var _sel_title: Label


func _title() -> String:
	return "Гараж"


func _build_scene_content() -> void:
	_props = Node3D.new()
	add_child(_props)
	_refresh_props()


func _rebuild_car() -> void:
	if model != null and is_instance_valid(model):
		model.queue_free()
	data = GameState.current_vehicle()
	model = VehicleManager.decor(data, self, Vector3.ZERO, 0.0)
	_sel_title.text = data.title


func _refresh_props() -> void:
	for c in _props.get_children():
		c.queue_free()
	if GameState.has_decor("lamp"):
		Scenery.lamp(_props, Vector3(-4.5, 0, 3.0))
		Scenery.lamp(_props, Vector3(4.5, 0, 3.0))
	if GameState.has_decor("flowers"):
		Scenery.flower_patch(_props, Vector3(0, 0, 4.5), 4.0, 22)
	if GameState.has_decor("flag"):
		for x in [-6.0, 6.0]:
			Scenery.part(_props, Scenery.cyl(0.04, 0.04, 3.4, 6), MatLib.steel(), Vector3(x, 1.7, -5.0))
			Scenery.part(_props, Scenery.rbox(Vector3(0.9, 0.5, 0.04), 0.02), MatLib.plastic(Color(0.98, 0.5, 0.2)), Vector3(x + 0.5, 3.2, -5.0))
	if GameState.has_decor("fence"):
		Scenery.fence(_props, Vector3(-9.0, 0, 6.0), Vector3(9.0, 0, 6.0))


func _build_ui() -> void:
	_sel_title = UIKit.label(data.title, 44, UIKit.TEXT)
	_sel_title.position = Vector2(300, 150)
	ui_root.add_child(_sel_title)
	_info = UIKit.label("", 30, UIKit.TEXT)
	_info.position = Vector2(900, 150)
	ui_root.add_child(_info)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 520)
	scroll.size = Vector2(1240, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui_root.add_child(scroll)
	_cards = UIKit.row(10)
	scroll.add_child(_cards)
	for d in VehicleDB.all():
		var vd: VehicleData = d
		var owned := GameState.is_owned(vd.id)
		var color := Color(0.12, 0.16, 0.24, 0.92) if owned else Color(0.08, 0.08, 0.1, 0.85)
		var b := UIKit.icon_button("car" if owned else "lock", vd.title if owned else "★ " + str(vd.unlock_stars), color, Vector2(176, 176), false)
		b.hold_mode = false
		b.font_size = 18
		b.custom_minimum_size = Vector2(176, 176)
		if owned:
			b.tapped.connect(func() -> void: _choose(vd.id))
		else:
			b.tapped.connect(func() -> void: UIManager.toast("Откроется, когда соберёшь ★%d" % vd.unlock_stars, "lock", UIKit.ACCENT))
		_cards.add_child(b)
	var deco := UIKit.label("Украшения территории:", 28, UIKit.TEXT)
	deco.position = Vector2(20, 410)
	ui_root.add_child(deco)
	_decor_row = UIKit.row(12)
	_decor_row.position = Vector2(20, 450)
	ui_root.add_child(_decor_row)
	_refresh_decor_buttons()
	_rebuild_car()
	_refresh_info()


func _refresh_info() -> void:
	_info.text = "★ %d   Машинок: %d/%d   Достижений: %d" % [GameState.stars, GameState.owned.size(), VehicleDB.all().size(), GameState.achievements.size()]


func _choose(id: String) -> void:
	AudioManager.play_click()
	GameState.select_vehicle(id)
	_rebuild_car()
	UIManager.toast("Машинка выбрана!", "check", UIKit.ACCENT)


func _refresh_decor_buttons() -> void:
	for c in _decor_row.get_children():
		c.queue_free()
	for item in DECOR:
		var it: Dictionary = item
		var got := GameState.has_decor(String(it["id"]))
		var label := String(it["title"]) if got else "%s ★%d" % [it["title"], it["cost"]]
		var b := UIKit.icon_button(String(it["icon"]), label, Color(0.3, 0.8, 0.5, 0.95) if got else UIKit.CARD, Vector2(200, 100), false)
		b.hold_mode = false
		b.font_size = 20
		b.custom_minimum_size = Vector2(200, 100)
		var iid := String(it["id"])
		var cost := int(it["cost"])
		b.tapped.connect(func() -> void: _buy_decor(iid, cost))
		_decor_row.add_child(b)


func _buy_decor(id: String, cost: int) -> void:
	if GameState.has_decor(id):
		UIManager.toast("Уже украшено!", "check", UIKit.ACCENT)
		return
	if GameState.stars < cost:
		UIManager.toast("Нужно ★%d — собирай звёздочки!" % cost, "star", UIKit.ACCENT)
		return
	GameState.add_stars(-cost)
	GameState.add_decor(id)
	AudioManager.play_unlock()
	_refresh_props()
	_refresh_decor_buttons()
	_refresh_info()
