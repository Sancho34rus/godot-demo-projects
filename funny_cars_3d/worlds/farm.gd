extends WorldBase

## Ферма: поля с бороздами, огород и сад, сараи, амбар, сеновал, загон с животными,
## грунтовые дороги, пруд с утками и посевные участки.

var farm: FarmSystem


func _init() -> void:
	zone_id = "farm"
	zone_title = "Ферма"
	ground_kind = "grass"
	terrain_size = Vector2(340, 340)
	spawn_pos = Vector3(4, 0.6, 40)
	spawn_yaw = 0.0


func welcome_key() -> String:
	return "farm_welcome"


func raw_height(x: float, z: float) -> float:
	var pond := 0.0
	if Vector2(x - 70.0, z + 60.0).length() < 14.0:
		pond = -1.2
	return pond + sin(x * 0.02) * 0.3 + cos(z * 0.018) * 0.25 + sin((x + z) * 0.01) * 0.15


func _build_zone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# dirt roads loop around the farm
	add_road(Vector3(-120, 0, 60), Vector3(120, 0, 60), 7.0, "dirt", false)
	add_road(Vector3(-120, 0, -60), Vector3(120, 0, -60), 7.0, "dirt", false)
	add_road(Vector3(-120, 0, -60), Vector3(-120, 0, 60), 7.0, "dirt", false)
	add_road(Vector3(120, 0, -60), Vector3(120, 0, 60), 7.0, "dirt", false)
	add_road(Vector3(0, 0, 60), Vector3(0, 0, 150), 6.0, "dirt", false)
	# barns, silo and farmhouse
	Scenery.barn(self, Vector3(34, 0, -30), 0.0)
	Scenery.silo(self, Vector3(50, 0, -30))
	Scenery.house(self, Vector3(-90, 0, -30), PI * 0.5, Color(0.98, 0.9, 0.78), Color(0.6, 0.25, 0.2), Vector3(7.0, 3.4, 5.5))
	Scenery.barn(self, Vector3(92, 0, 30), -PI * 0.5)
	Scenery.gas_station(self, Vector3(-120, 0, 0), 0.0)
	# hay stacks
	for p in [Vector3(20, 0, -10), Vector3(22, 0, -4), Vector3(-30, 0, 28), Vector3(-26, 0, 32)]:
		Scenery.hay_bale(self, p, rng.randf() * TAU)
	# orchard with fruit trees and a garden fence
	for i in 8:
		var fx := 60.0 + (i % 4) * 9.0
		var fz := 0.0 + (i / 4) * 10.0
		Scenery.tree_fruit(self, Vector3(fx, 0, fz), [Color(0.95, 0.2, 0.2), Color(1.0, 0.7, 0.2), Color(0.9, 0.5, 0.9)][i % 3])
	Scenery.fence(self, Vector3(54, 0, -8), Vector3(98, 0, -8))
	Scenery.fence(self, Vector3(54, 0, 22), Vector3(98, 0, 22))
	for i in 5:
		Scenery.flower_patch(self, Vector3(-40 + i * 13.0, 0, -58), 3.0, 14)
	# pond with ducks
	var pond_pos := Vector3(70, 0, -60)
	Scenery.lake(self, pond_pos + Vector3(0, -0.6, 0), 12.0)
	# decorative fields beyond the plot grid
	Scenery.crop_field(self, Vector3(-40, 0, -48), Vector2(60, 14), "field", 6, Color(0.5, 0.82, 0.3))
	Scenery.crop_field(self, Vector3(-40, 0, 58), Vector2(60, 14), "field", 6, Color(0.9, 0.75, 0.25))
	# trees and bushes
	for i in 50:
		var p := Vector3(rng.randf_range(-160, 160), 0, rng.randf_range(-160, 160))
		if absf(p.x) < 18 and absf(p.z) < 80:
			continue
		if absf(p.x - 70) < 22 and absf(p.z + 60) < 22:
			continue
		if rng.randf() < 0.6:
			Scenery.tree_round(self, p, rng.randf_range(1.0, 1.6), Color(rng.randf_range(0.3, 0.45), 0.7, 0.3))
		else:
			Scenery.tree_pine(self, p, rng.randf_range(1.0, 1.4))
	for i in 20:
		Scenery.bush(self, Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-120, 120)), rng.randf_range(0.8, 1.2))

	# living farm: cows, sheep, birds, butterflies, fish in the pond
	var living := Living.new()
	living.name = "Living"
	add_child(living)
	living.setup(self)
	living.add_animal("cow", Vector3(-90, 0, 40), 8.0)
	living.add_animal("sheep", Vector3(-60, 0, 62), 7.0)
	living.add_animal("sheep", Vector3(-50, 0, 68), 6.0)
	living.add_animal("chicken", Vector3(-12, 0, 56), 4.0)
	living.add_animal("chicken", Vector3(-8, 0, 60), 4.0)
	living.add_animal("pig", Vector3(96, 0, 56), 4.0)
	living.add_animal("duck", pond_pos + Vector3(17, 0, 2), 1.5)
	living.add_animal("duck", pond_pos + Vector3(-16, 0, -4), 1.5)
	living.add_animal("rabbit", Vector3(40, 0, 40), 5.0)
	living.add_fish(pond_pos + Vector3(0, -1.5, 0), 6.0, -1.1)
	living.add_fish(pond_pos + Vector3(0, -1.5, 0), 4.0, -1.0)
	for i in 3:
		living.add_bird(Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60)), 10.0, 10.0 + i)
	for i in 4:
		living.add_butterfly(Vector3(rng.randf_range(-80, 80), 0, rng.randf_range(-80, 80)), 5.0)

	# farm system: plots, hay store, barn, pen
	farm = FarmSystem.new()
	farm.name = "FarmSystem"
	add_child(farm)
	farm.setup(self)
	farm.setup_pen(Vector3(-86, 0, 58))
	systems.append(farm)

	# stations
	add_station("farm_hay", "Сеновал", Vector3(20, 0, -18), "", Color(0.95, 0.85, 0.35))
	add_station("farm_store", "Амбар", Vector3(36, 0, -12), "", Color(0.7, 0.9, 0.4))
	add_station("farm_feed", "Загон", Vector3(-86, 0, 46), "", Color(1.0, 0.7, 0.4))
	add_station("minigame", "Собери фрукты", Vector3(64, 0, 18), "fruit_collect", Color(0.95, 0.4, 0.4))
	add_station("minigame", "Полей растения", Vector3(-18, 0, -40), "watering", Color(0.5, 0.85, 1.0))
	add_station("minigame", "Перевези животных", Vector3(-60, 0, 36), "animal_transport", Color(1.0, 0.8, 0.4))
	add_station("minigame", "Привези сено", Vector3(-20, 0, 12), "hay_delivery", Color(0.95, 0.85, 0.3))
	add_station("minigame", "Сортировка", Vector3(56, 0, 40), "farm_sort", Color(0.6, 0.8, 1.0))
	add_station("minigame", "Полевая дорога", Vector3(-30, 0, -60), "farm_route", Color(0.8, 0.9, 0.5))
	add_station("garage", "Гараж", Vector3(0, 0, 36), "", Color(0.4, 0.8, 1.0))
	add_station("gift", "Подарок", Vector3(100, 0, -70), "", Color(1.0, 0.7, 0.2))

	# tractor and trailer parked near the barn
	VehicleManager.decor(VehicleDB.get_vehicle("tractor"), self, Vector3(40, 0.05, -40), PI * 0.5, Color(0.2, 0.7, 0.3))
	# stand-by tools for the tractor are shown in the implement shed
	Scenery.lamp(self, Vector3(8, 0, 4))
	Scenery.sign(self, Vector3(-8, 0, 48), 0.0, "speed")
