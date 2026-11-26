extends WorldBase

## Стройка: котлован с песком, горы песка, башенный кран, склады, каток
## и дорога из гравия, которую нужно укатать в асфальт.

var construction: ConstructionSystem


func _init() -> void:
	zone_id = "construction"
	zone_title = "Стройка"
	ground_kind = "dirt"
	terrain_size = Vector2(320, 320)
	spawn_pos = Vector3(0, 0.6, 26)
	spawn_yaw = 0.0


func welcome_key() -> String:
	return "construction_welcome"


func raw_height(x: float, z: float) -> float:
	var pit := ConstructionSystem.PIT_RECT
	var base := sin(x * 0.03) * 0.05 + cos(z * 0.04) * 0.05
	var dx := maxf(pit.position.x - x, maxf(0.0, x - pit.end.x))
	var dz := maxf(pit.position.y - z, maxf(0.0, z - pit.end.y))
	var edge := Vector2(dx, dz).length()
	if edge < 0.01:
		return -2.0 + base
	var k := clampf(edge / 4.0, 0.0, 1.0)
	return lerpf(-2.0, 0.0, k * k * (3.0 - 2.0 * k)) + base


func _build_zone() -> void:
	add_road(Vector3(-130, 0, 0), Vector3(130, 0, 0), 11.0)
	add_road(Vector3(-130, 0, -90), Vector3(-130, 0, 90), 9.0)
	add_road(Vector3(0, 0, 90), Vector3(0, 0, 130), 9.0)
	make_traffic_light(Vector3(-7, 0, -7), PI * 0.25)
	# --- crane, sand, warehouses and barriers are composed by the system
	construction = ConstructionSystem.new()
	construction.name = "ConstructionSystem"
	add_child(construction)
	construction.setup(self)
	systems.append(construction)
	# site fence and work lamps
	Scenery.fence(self, Vector3(-60, 0, 26), Vector3(-10, 0, 26), Color(1.0, 0.8, 0.2))
	for p in [Vector3(-60, 0, -36), Vector3(10, 0, -36), Vector3(-60, 0, 20)]:
		Scenery.lamp(self, p)
	# trees at the edge of the site
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 16:
		var p2 := Vector3(rng.randf_range(-150, 150), 0, rng.randf_range(-150, 150))
		if absf(p2.x) < 90 and absf(p2.z) < 80:
			continue
		Scenery.tree_round(self, p2, rng.randf_range(0.9, 1.3), Color(0.4, 0.7, 0.35))
	# cones and safety signs
	for p3 in [Vector3(-130, 0, -40), Vector3(120, 0, 30)]:
		Scenery.sign(self, p3, 0.0, "stop")
	# living: birds and a rabbit at the edge
	var living := Living.new()
	living.name = "Living"
	add_child(living)
	living.setup(self)
	living.add_bird(Vector3(60, 0, -80), 12.0, 10.0)
	living.add_animal("rabbit", Vector3(-100, 0, 60), 4.0)

	# --- stations
	add_station("minigame", "Котлован", Vector3(-33, 0, -6), "dig_sand", Color(0.95, 0.8, 0.4))
	add_station("minigame", "Песок в самосвал", Vector3(20, 0, 10), "sand_load", Color(0.95, 0.75, 0.5))
	add_station("minigame", "Укатай дорогу", Vector3(20, 0, 60), "road_roll", Color(0.8, 0.8, 0.8))
	add_station("minigame", "Строительство", Vector3(-6, 0, -70), "materials_delivery", Color(1.0, 0.6, 0.3))
	add_station("minigame", "Откопай клад", Vector3(-70, 0, -60), "crate_dig", Color(1.0, 0.85, 0.3))
	add_station("garage", "Гараж", Vector3(-100, 0, -20), "", Color(0.4, 0.8, 1.0))
	add_station("gift", "Подарок", Vector3(120, 0, -60), "", Color(1.0, 0.7, 0.2))
