extends WorldBase

## Автогородок: большая автомойка, покрасочная, ремонтный центр, гаражи,
## автосалон, заправка и парковка. Здесь же мини-игры по сбору деталей.

func _init() -> void:
	zone_id = "autotown"
	zone_title = "Автогородок"
	ground_kind = "grass"
	terrain_size = Vector2(300, 300)
	spawn_pos = Vector3(0, 0.6, 36)
	spawn_yaw = 0.0


func welcome_key() -> String:
	return "autotown_welcome"


func raw_height(x: float, z: float) -> float:
	return sin(x * 0.02) * 0.08 + cos(z * 0.03) * 0.06


func _build_zone() -> void:
	# ring road and access roads
	add_road(Vector3(-110, 0, 0), Vector3(110, 0, 0), 12.0)
	add_road(Vector3(0, 0, -110), Vector3(0, 0, 110), 12.0)
	add_road(Vector3(-110, 0, -40), Vector3(110, 0, -40), 9.0)
	add_road(Vector3(-110, 0, 40), Vector3(110, 0, 40), 9.0)
	make_traffic_light(Vector3(-7, 0, 7), PI * 0.25)
	make_traffic_light(Vector3(7, 0, -7), -PI * 0.75)

	# --- big car wash (blue arches and bubbling pool)
	var cw := root_box(Vector3(-40, 0, -30), 0.0, Vector3(20, 6, 16), Color(0.7, 0.9, 1.0), "Автомойка")
	Scenery.part(self, Scenery.rbox(Vector3(4, 4.5, 0.6), 0.1), MatLib.plastic(Color(0.25, 0.6, 0.95)), Vector3(-40, 2.5, -20))
	Scenery.lamp(self, Vector3(-30, 0, -18))
	# --- paint shop (orange roof, big windows)
	Scenery.warehouse(self, Vector3(40, 0, -34), 0.0, Color(0.98, 0.7, 0.4))
	Scenery.part(self, Scenery.rbox(Vector3(9, 0.8, 0.3), 0.05), MatLib.plastic(Color(0.25, 0.4, 0.9)), Vector3(40, 6.8, -26.7))
	# --- repair center (red roof, lift hall)
	Scenery.warehouse(self, Vector3(-40, 0, 26), PI, Color(0.96, 0.96, 0.92))
	Scenery.part(self, Scenery.rbox(Vector3(9, 0.8, 0.3), 0.05), MatLib.plastic(Color(0.95, 0.25, 0.2)), Vector3(-40, 6.8, 19.3))
	# --- garages (row of three roll-up doors)
	for i in 3:
		var gx := 8.0 + i * 12.0
		Scenery.solid(self, Vector3(10, 4.5, 8), Vector3(gx, 2.25, 34), MatLib.wall(Color(0.85, 0.9, 0.95)), "concrete")
		Scenery.part(self, Scenery.rbox(Vector3(6, 3.2, 0.2), 0.05), MatLib.plastic(Color(0.95, 0.6, 0.2 + i * 0.2)), Vector3(gx, 1.6, 29.9))
		var prof := PackedVector2Array([Vector2(-5.6, 0), Vector2(5.6, 0), Vector2(0, 2.4)])
		Scenery.part(self, MeshGen.extrude_profile(prof, 8.6, 4, 1.0), MatLib.roof(Color(0.4, 0.45, 0.55)), Vector3(gx, 4.5, 34), Vector3(0, 0, 0))
	# --- dealership (glass showroom with cars on display)
	Scenery.shop(self, Vector3(96, 0, 0), -PI * 0.5, Color(0.92, 0.96, 1.0), Color(0.2, 0.5, 0.95), "Автосалон")
	var showroom := ["sport", "suv", "van", "pickup", "police"]
	for i in showroom.size():
		var d := VehicleDB.get_vehicle(showroom[i])
		if d != null:
			VehicleManager.decor(d, self, Vector3(84, 0.1, -10 + i * 6.0), -PI * 0.5, [Color(0.95, 0.3, 0.3), Color(0.3, 0.8, 0.4), Color(0.2, 0.6, 1.0), Color(1, 0.8, 0.2), Color(0.9, 0.9, 0.95)][i])
	# --- fuel station and parking lot
	Scenery.gas_station(self, Vector3(-110, 0, 56), PI * 0.5)
	Scenery.solid(self, Vector3(38, 0.08, 16), Vector3(20, 0.04, 62), MatLib.ground("concrete"), "concrete")
	for i in 6:
		Scenery.part(self, Scenery.rbox(Vector3(0.12, 0.02, 4.4), 0.02), MatLib.road_mark(), Vector3(4 + i * 6.0 - 15.0, 0.1, 62))
	var cars := ["car_red", "suv", "van", "tractor", "sport"]
	for i in cars.size():
		var d2 := VehicleDB.get_vehicle(cars[i])
		if d2 != null and d2.kind != "tractor":
			VehicleManager.decor(d2, self, Vector3(4 + i * 6.0 - 15.0, 0.1, 62.0), 0.0, [Color(0.95, 0.3, 0.3), Color(0.3, 0.8, 0.4), Color(0.2, 0.6, 1.0), Color(1, 0.8, 0.2), Color(0.9, 0.9, 0.95)][i])
	# --- trees, flowers, lamps
	for i in 22:
		var p := Vector3(-140 + (i % 11) * 28.0 + sin(i) * 4.0, 0, -140 + (i / 11) * 260.0)
		if absf(p.x) < 60 and absf(p.z) < 70:
			continue
		Scenery.tree_round(self, p, 1.1, Color(0.35, 0.72, 0.3))
	for i in 6:
		Scenery.flower_patch(self, Vector3(-20 + i * 9.0, 0, -58), 3.0, 14)
	for p in [Vector3(-20, 0, 14), Vector3(20, 0, 14), Vector3(-72, 0, 0), Vector3(72, 0, 0)]:
		Scenery.lamp(self, p)
	# --- living: birds and a rabbit
	var living := Living.new()
	living.name = "Living"
	add_child(living)
	living.setup(self)
	living.add_bird(Vector3(0, 0, -40), 16.0, 9.0)
	living.add_bird(Vector3(60, 0, 40), 12.0, 10.0)
	living.add_animal("rabbit", Vector3(-70, 0, -60), 5.0)
	living.add_butterfly(Vector3(-20, 0, -58), 6.0)

	# --- stations
	add_station("carwash", "Автомойка", Vector3(-40, 0, -6), "", Color(0.4, 0.85, 1.0))
	add_station("paint", "Покраска", Vector3(40, 0, -18), "", Color(1.0, 0.6, 0.3))
	add_station("repair", "Ремонт", Vector3(-40, 0, 12), "", Color(1.0, 0.4, 0.4))
	add_station("garage", "Гараж", Vector3(8, 0, 22), "", Color(0.5, 0.85, 1.0))
	add_station("garage", "Автосалон", Vector3(84, 0, 18), "", Color(0.6, 0.9, 1.0))
	add_station("minigame", "Собери детали", Vector3(0, 0, -22), "parts_collect", Color(0.9, 0.9, 0.4))
	add_station("minigame", "Найди деталь", Vector3(-80, 0, -22), "sort_parts", Color(0.6, 1.0, 0.7))
	add_station("minigame", "Гонка по гаражам", Vector3(60, 0, 60), "garage_race", Color(1.0, 0.7, 0.3))
	add_station("minigame", "Парковка", Vector3(16, 0, 62), "parking_city", Color(0.4, 0.9, 0.5))
	add_station("gift", "Подарок", Vector3(-100, 0, 90), "", Color(1.0, 0.7, 0.2))


func root_box(pos: Vector3, yaw: float, size: Vector3, color: Color, title: String) -> Node3D:
	var r := Scenery.root(self, "Building", pos, yaw)
	Scenery.solid(r, size, Vector3(0, size.y * 0.5, 0), MatLib.wall(color), "concrete")
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 96
	sign.pixel_size = 0.014
	sign.outline_size = 14
	sign.outline_modulate = Color(0.1, 0.4, 0.8)
	sign.position = Vector3(0, size.y + 1.0, size.z * 0.5 + 0.2)
	r.add_child(sign)
	return r
