extends WorldBase

## Природа: холмы, лес, озеро с рыбками, речка с мостом, луга и секретные
## места с подарками. Здесь живёт больше всего животных и птиц.

const LAKE_POS := Vector3(-60, 0, -50)
const RIVER_Z := 60.0


func _init() -> void:
	zone_id = "nature"
	zone_title = "Природа"
	ground_kind = "grass"
	terrain_size = Vector2(360, 360)
	spawn_pos = Vector3(0, 0.8, 30)
	spawn_yaw = 0.0


func welcome_key() -> String:
	return "nature_welcome"


func raw_height(x: float, z: float) -> float:
	var hills := sin(x * 0.018) * 2.8 + cos(z * 0.022) * 2.4 + sin((x - z) * 0.011) * 2.0
	# keep the meadow near the spawn flat
	var meadow := clampf((Vector2(x, z) - Vector2(0, 30)).length() / 26.0, 0.0, 1.0)
	hills *= meadow
	# lake bowl
	var dl := Vector2(x - LAKE_POS.x, z - LAKE_POS.z).length()
	if dl < 26.0:
		var k := clampf((dl - 18.0) / 8.0, 0.0, 1.0)
		hills = lerpf(-1.8, hills, k)
	# river channel
	var river_c := RIVER_Z + sin(x * 0.02) * 4.0
	var dr := absf(z - river_c)
	if dr < 7.0:
		var kr := clampf((dr - 3.0) / 4.0, 0.0, 1.0)
		hills = lerpf(-1.2, hills, kr)
	return hills


func _build_zone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# dirt roads for journeys, the bridge over the river
	add_road(Vector3(-150, 0, 30), Vector3(-20, 0, 30), 7.0, "dirt", false)
	add_road(Vector3(20, 0, 30), Vector3(150, 0, 30), 7.0, "dirt", false)
	add_road(Vector3(0, 0, 30), Vector3(0, 0, 60), 7.0, "dirt", false)
	add_road(Vector3(0, 0, 60), Vector3(-60, 0, 110), 6.0, "dirt", false)
	add_road(Vector3(-120, 0, -20), Vector3(-120, 0, 30), 6.0, "dirt", false)
	Scenery.bridge(self, Vector3(-12, 0, RIVER_Z), Vector3(12, 0, RIVER_Z), 7.0, 0.0)
	# river and lake water (surfaces sit just above the bed)
	var pts := []
	for i in 9:
		var x := -180.0 + i * 45.0
		pts.append(Vector3(x, -0.3, RIVER_Z + sin(x * 0.02) * 4.0))
	Scenery.river(self, pts, 14.0)
	Scenery.lake(self, LAKE_POS + Vector3(0, -0.35, 0), 24.0)
	# meadows with flowers and haystacks
	for i in 8:
		Scenery.flower_patch(self, Vector3(rng.randf_range(-140, 140), 0, rng.randf_range(-140, 140)), 6.0, 24)
	for i in 3:
		Scenery.hay_bale(self, Vector3(60 + i * 2.0, 0, -20), rng.randf() * TAU)
	# forest: many trees, groves on the hills
	for i in 110:
		var p := Vector3(rng.randf_range(-170, 170), 0, rng.randf_range(-170, 170))
		if Vector2(p.x, p.z).length() < 28.0:
			continue
		if p.distance_to(LAKE_POS) < 32.0:
			continue
		if absf(p.z - RIVER_Z) < 9.0:
			continue
		if rng.randf() < 0.55:
			Scenery.tree_pine(self, p, rng.randf_range(1.2, 2.0))
		else:
			Scenery.tree_round(self, p, rng.randf_range(1.1, 1.8), Color(rng.randf_range(0.3, 0.45), 0.7, 0.3))
	for i in 40:
		Scenery.bush(self, Vector3(rng.randf_range(-160, 160), 0, rng.randf_range(-160, 160)), rng.randf_range(0.9, 1.4))
	# secret cabin
	Scenery.house(self, Vector3(120, 0, -110), PI * 0.5, Color(0.85, 0.65, 0.45), Color(0.4, 0.3, 0.2), Vector3(5.0, 3.0, 4.2))

	# living nature
	var living := Living.new()
	living.name = "Living"
	add_child(living)
	living.setup(self)
	for i in 4:
		living.add_animal("rabbit", Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-40, 40)), 6.0)
	living.add_animal("horse", Vector3(70, 0, 30), 8.0)
	living.add_animal("sheep", Vector3(-80, 0, 10), 8.0)
	living.add_animal("duck", LAKE_POS + Vector3(30, -0.2, 0), 2.0)
	living.add_fish(LAKE_POS + Vector3(0, -1.2, 0), 14.0, -1.1)
	living.add_fish(LAKE_POS + Vector3(0, -1.2, 0), 10.0, -1.0)
	for i in 5:
		living.add_bird(Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-120, 120)), 15.0, 12.0 + i * 0.5)
	for i in 8:
		living.add_butterfly(Vector3(rng.randf_range(-120, 120), 0, rng.randf_range(-120, 120)), 6.0)

	# --- stations and secret spots
	add_station("minigame", "Лови рыбок", LAKE_POS + Vector3(0, 0, 30), "fish_catch", Color(0.5, 0.9, 1.0))
	add_station("minigame", "Спаси зверюшек", Vector3(70, 0, 52), "animal_rescue", Color(1.0, 0.7, 0.4))
	add_station("minigame", "Найди спрятанное", Vector3(-110, 0, 70), "hidden_items", Color(1.0, 0.9, 0.4))
	add_station("minigame", "Лесная тропа", Vector3(-30, 0, -90), "meadow_route", Color(0.6, 1.0, 0.6))
	add_station("minigame", "Мост через речку", Vector3(40, 0, 78), "bridge_cross", Color(0.7, 0.85, 1.0))
	add_station("garage", "Гараж", Vector3(-6, 0, 16), "", Color(0.4, 0.8, 1.0))
	add_station("gift", "Секретный подарок", Vector3(150, 0, 140), "", Color(1.0, 0.7, 0.2))
	add_station("gift", "Тайник", Vector3(-160, 0, -140), "", Color(1.0, 0.7, 0.2))
	add_station("gift", "Сюрприз", Vector3(160, 0, -150), "", Color(1.0, 0.7, 0.2))
