extends WorldBase

## Город: перекрёстки со светофорами, магазины, дома, парковки, мост над речкой,
## тоннель, заправка, детская площадка и живые прохожие-животные в парках.

func _init() -> void:
	zone_id = "city"
	zone_title = "Город"
	ground_kind = "grass"
	terrain_size = Vector2(340, 340)
	spawn_pos = Vector3(0, 0.6, 30)
	spawn_yaw = 0.0


func welcome_key() -> String:
	return "city_welcome"


func raw_height(x: float, z: float) -> float:
	var river := 0.0
	if absf(x - 165.0) < 9.0:
		river = -1.4
	return river + sin(x * 0.03) * 0.05 + cos(z * 0.025) * 0.05


func _build_zone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	# --- main avenues and a ring road
	add_road(Vector3(-120, 0, 0), Vector3(120, 0, 0), 10.0)
	add_road(Vector3(0, 0, -120), Vector3(0, 0, 120), 10.0)
	add_road(Vector3(-70, 0, -120), Vector3(-70, 0, 120), 8.0)
	add_road(Vector3(70, 0, -120), Vector3(70, 0, 120), 8.0)
	add_road(Vector3(-120, 0, -70), Vector3(120, 0, -70), 8.0)
	add_road(Vector3(-120, 0, 70), Vector3(120, 0, 70), 8.0)
	# east road to the bridge and west road to the tunnel
	add_road(Vector3(120, 0, 0), Vector3(150, 0, 0), 10.0)
	add_road(Vector3(180, 0, 0), Vector3(200, 0, 0), 10.0)
	add_road(Vector3(-200, 0, 0), Vector3(-120, 0, 0), 10.0)
	for p in [Vector3(-6, 0, -6), Vector3(6, 0, -6), Vector3(-6, 0, 6), Vector3(6, 0, 6)]:
		make_traffic_light(p, atan2(-p.x, -p.z) + PI * 0.25)
	for p in [Vector3(-70, 0, -70), Vector3(70, 0, 70)]:
		make_traffic_light(p + Vector3(6, 0, 6), 0.0)

	# --- river, bridge and tunnel
	var river_pts := [Vector3(165, 0, -220), Vector3(165, 0, -20), Vector3(165, 0, 220)]
	Scenery.river(self, river_pts, 16.0)
	Scenery.bridge(self, Vector3(152, 0, 0), Vector3(178, 0, 0), 10.0, 0.0)
	Scenery.road(self, Vector3(152, 0, 0), Vector3(178, 0, 0), 10.0, "asphalt", true)
	Scenery.tunnel(self, Vector3(-160, 0, 0), PI * 0.5, 10.0, 5.2, 16.0)

	# --- houses in four blocks
	var wall_colors := [Color(1.0, 0.92, 0.75), Color(0.75, 0.9, 1.0), Color(0.98, 0.78, 0.8), Color(0.86, 1.0, 0.8), Color(1.0, 0.95, 0.6)]
	var roof_colors := [Color(0.8, 0.3, 0.25), Color(0.25, 0.4, 0.75), Color(0.6, 0.35, 0.2)]
	for bx in [-100.0, -40.0, 40.0, 100.0]:
		for bz in [-100.0, 100.0]:
			for k in 3:
				var pos := Vector3(bx + (k - 1) * 14.0, 0, bz + rng.randf_range(-3, 3))
				var wall: Color = wall_colors[rng.randi() % wall_colors.size()]
				var roof: Color = roof_colors[rng.randi() % roof_colors.size()]
				Scenery.house(self, pos, PI if bz > 0 else 0.0, wall, roof, Vector3(6.0, 3.2, 5.0))
				Scenery.tree_round(self, pos + Vector3(4.5, 0, -3.0), rng.randf_range(0.9, 1.2), Color(0.35, 0.7, 0.3))
	# shops along the -70 avenue
	var shops := [["Игрушки", Color(0.98, 0.5, 0.5)], ["Булочная", Color(0.98, 0.8, 0.4)], ["Кафе", Color(0.5, 0.85, 0.7)], ["Книги", Color(0.6, 0.7, 1.0)]]
	for i in shops.size():
		var sx := -90.0 + i * 16.0
		Scenery.shop(self, Vector3(sx, 0, -102.0), 0.0, Color(0.96, 0.94, 0.9), shops[i][1], shops[i][0])
	for i in 3:
		Scenery.shop(self, Vector3(96.0 + i * 0.0, 0, -40.0 + i * 16.0), -PI * 0.5, Color(0.9, 0.95, 1.0), Color(0.9, 0.4, 0.4), ["Магазин", "Зоомагазин", "Цветы"][i])

	# --- parking lots with parked cars
	for lot in [Vector3(-40, 0, 24), Vector3(40, 0, 24)]:
		Scenery.solid(self, Vector3(30, 0.08, 14), lot + Vector3(0, 0.03, 0), MatLib.ground("concrete"), "concrete")
		for i in 5:
			var sx := lot.x - 12.0 + i * 6.0
			Scenery.part(self, Scenery.rbox(Vector3(0.12, 0.02, 4.4), 0.02), MatLib.road_mark(), Vector3(sx - 3.0, 0.1, lot.z))
	var parked := ["car_red", "sport", "suv", "van", "pickup", "police", "ambulance", "bus", "fire", "garbage"]
	var colors := [Color(0.2, 0.55, 0.95), Color(0.98, 0.8, 0.2), Color(0.3, 0.8, 0.4), Color(0.9, 0.4, 0.8), Color(0.9, 0.9, 0.95)]
	for i in parked.size():
		var lot_c := Vector3(-40, 0, 24) if i < 5 else Vector3(40, 0, 24)
		var idx := i % 5
		var d := VehicleDB.get_vehicle(parked[i])
		if d == null:
			continue
		var pos := lot_c + Vector3(-12.0 + idx * 6.0, 0.08, 0.0)
		VehicleManager.decor(d, self, pos, PI * 0.5 if i % 2 == 0 else -PI * 0.5, colors[i % colors.size()])
	# --- gas station, playground, lamps, signs
	Scenery.gas_station(self, Vector3(-30, 0, -36), PI * 0.5)
	Scenery.playground(self, Vector3(-102, 0, 40), 0.0)
	for p in [Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(-12, 0, 12), Vector3(12, 0, 12), Vector3(-60, 0, -40), Vector3(60, 0, -40), Vector3(-60, 0, 40), Vector3(60, 0, 40), Vector3(-100, 0, -10), Vector3(100, 0, 10)]:
		Scenery.lamp(self, p)
	Scenery.sign(self, Vector3(7, 0, -7), PI * 0.5 + PI, "stop")
	Scenery.sign(self, Vector3(-7, 0, 7), PI * 0.5, "speed")
	Scenery.sign(self, Vector3(-30, 0, 4), 0.0, "park")
	Scenery.sign(self, Vector3(100, 0, 6), 0.0, "info")
	Scenery.sign(self, Vector3(-150, 0, 6), 0.0, "bump")
	# --- trees and flowers around the city
	for i in 40:
		var p := Vector3(rng.randf_range(-170, 170), 0, rng.randf_range(-160, 160))
		if absf(p.x) < 14 or absf(p.z) < 14 or absf(p.x - 165) < 16:
			continue
		if absf(p.x) > 86 and absf(p.z) < 86 and rng.randf() < 0.6:
			continue
		if rng.randf() < 0.7:
			Scenery.tree_round(self, p, rng.randf_range(0.9, 1.5), Color(rng.randf_range(0.3, 0.45), 0.7, 0.3))
		else:
			Scenery.tree_pine(self, p, rng.randf_range(0.9, 1.5))
	for i in 6:
		Scenery.flower_patch(self, Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-120, 120)), 3.0, 16)
	for i in 14:
		Scenery.bush(self, Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100)), rng.randf_range(0.8, 1.3))

	# --- living city: pigeons and a little dog-like pet park
	var living := Living.new()
	living.name = "Living"
	add_child(living)
	living.setup(self)
	for i in 4:
		living.add_bird(Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(-80, 80)), 12.0, 8.0 + i)
	living.add_animal("rabbit", Vector3(-100, 0, 35), 5.0)
	living.add_animal("duck", Vector3(-150, 0, -40), 3.0)
	living.add_animal("chicken", Vector3(-112, 0, 52), 3.0)
	living.add_butterfly(Vector3(-100, 0, -20), 6.0)
	living.add_butterfly(Vector3(40, 0, 60), 6.0)

	# --- stations: workshops, minigames, gifts
	add_station("garage", "Гараж", Vector3(-20, 0, 26), "", Color(0.4, 0.8, 1.0))
	add_station("minigame", "Парковка", Vector3(-40, 0, 36), "parking_city", Color(0.4, 0.9, 0.5))
	add_station("minigame", "Цвет-поиск", Vector3(40, 0, 36), "color_search", Color(1.0, 0.6, 0.8))
	add_station("minigame", "Грузовая доставка", Vector3(-10, 0, -96), "delivery_city", Color(1.0, 0.8, 0.3))
	add_station("minigame", "Тоннель", Vector3(-136, 0, 8), "tunnel_run", Color(0.6, 0.8, 1.0))
	add_station("minigame", "Заправка", Vector3(-30, 0, -26), "refuel", Color(1.0, 0.5, 0.4))
	add_station("minigame", "Помощь машинке", Vector3(100, 0, -90), "help_car", Color(0.9, 0.7, 1.0))
	add_station("minigame", "Маршрут по городу", Vector3(100, 0, 90), "route_city", Color(0.5, 1.0, 0.9))
	add_station("gift", "Подарок", Vector3(-150, 0, -90), "", Color(1.0, 0.7, 0.2))
	add_station("gift", "Подарок", Vector3(170, 0, 120), "", Color(1.0, 0.7, 0.2))

	# (minigame manager is attached by WorldBase)
