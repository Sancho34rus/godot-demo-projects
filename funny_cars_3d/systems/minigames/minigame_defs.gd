class_name MiniGameDefs
extends RefCounted

## Data table of every minigame. Eight generic mechanics (collect, delivery,
## parking, match, checkpoints, dig, water, help) are configured by these
## entries; each gets difficulty scaling from how many games were finished.

const DEFS := {
	# ---- city
	"parking_city": {"type": "parking", "title": "Паркуйся!", "icon": "car", "count": 1, "event": "parking", "stat": "parking", "reward": 3},
	"color_search": {"type": "match", "title": "Найди такой же цвет", "icon": "star", "count": 1, "event": "deliver", "stat": "matches", "reward": 3},
	"delivery_city": {"type": "delivery", "title": "Доставка груза", "icon": "build", "count": 1, "event": "deliver", "stat": "deliveries", "reward": 4, "cargo": "box", "pad_color": Color(0.4, 0.8, 1.0)},
	"tunnel_run": {"type": "checkpoints", "title": "Проезд через тоннель", "icon": "car", "count": 4, "event": "deliver", "stat": "routes", "reward": 3},
	"refuel": {"type": "collect", "title": "Собери канистры", "icon": "gift", "count": 4, "event": "deliver", "stat": "collect", "reward": 3, "item": "can"},
	"help_car": {"type": "help", "title": "Помоги машинке", "icon": "lock", "count": 2, "event": "deliver", "stat": "helps", "reward": 4},
	"route_city": {"type": "checkpoints", "title": "Маршрут по городу", "icon": "map", "count": 6, "event": "deliver", "stat": "routes", "reward": 4},
	# ---- farm
	"fruit_collect": {"type": "collect", "title": "Собери фрукты", "icon": "farm", "count": 6, "event": "harvest", "stat": "collect", "reward": 3, "item": "fruit"},
	"watering": {"type": "water", "title": "Полей растения", "icon": "water", "count": 4, "event": "water", "stat": "waters", "reward": 3},
	"animal_transport": {"type": "delivery", "title": "Перевези животных", "icon": "animal", "count": 1, "event": "deliver_crop", "stat": "deliveries", "reward": 4, "cargo": "animal", "pad_color": Color(1.0, 0.7, 0.3)},
	"hay_delivery": {"type": "delivery", "title": "Привези сено", "icon": "farm", "count": 1, "event": "deliver_crop", "stat": "deliveries", "reward": 4, "cargo": "hay", "pad_color": Color(0.9, 0.8, 0.3)},
	"farm_sort": {"type": "match", "title": "Сортировка по цвету", "icon": "bucket", "count": 2, "event": "harvest", "stat": "matches", "reward": 3},
	"farm_route": {"type": "checkpoints", "title": "Полевая дорога", "icon": "tractor", "count": 5, "event": "plow", "stat": "routes", "reward": 3},
	# ---- construction
	"dig_sand": {"type": "dig", "title": "Копай песок", "icon": "bucket", "count": 4, "event": "dig", "stat": "dig", "reward": 3},
	"sand_load": {"type": "delivery", "title": "Песок в самосвал", "icon": "build", "count": 1, "event": "load", "stat": "deliveries", "reward": 4, "cargo": "sand", "pad_color": Color(0.95, 0.8, 0.5)},
	"materials_delivery": {"type": "delivery", "title": "Строительные материалы", "icon": "build", "count": 1, "event": "deliver", "stat": "deliveries", "reward": 4, "cargo": "box", "pad_color": Color(0.9, 0.5, 0.2)},
	"road_roll": {"type": "checkpoints", "title": "Укатай дорогу", "icon": "tractor", "count": 6, "event": "compact", "stat": "routes", "reward": 3},
	"crate_dig": {"type": "dig", "title": "Откопай клад", "icon": "gift", "count": 6, "event": "dig", "stat": "dig", "reward": 3},
	# ---- autotown
	"parts_collect": {"type": "collect", "title": "Собери детали", "icon": "wrench", "count": 6, "event": "repair_done", "stat": "collect", "reward": 3, "item": "gear"},
	"sort_parts": {"type": "match", "title": "Найди нужную деталь", "icon": "wrench", "count": 2, "event": "repair_done", "stat": "matches", "reward": 3},
	"garage_race": {"type": "checkpoints", "title": "Гонка по гаражам", "icon": "car", "count": 5, "event": "parking", "stat": "routes", "reward": 4},
	# ---- nature
	"hidden_items": {"type": "collect", "title": "Найди спрятанное", "icon": "star", "count": 5, "event": "secret", "stat": "collect", "reward": 4, "item": "hidden"},
	"fish_catch": {"type": "collect", "title": "Лови рыбок", "icon": "star", "count": 5, "event": "secret", "stat": "collect", "reward": 3, "item": "fish"},
	"animal_rescue": {"type": "help", "title": "Спаси зверюшек", "icon": "animal", "count": 3, "event": "secret", "stat": "helps", "reward": 4},
	"meadow_route": {"type": "checkpoints", "title": "Лесная тропа", "icon": "map", "count": 7, "event": "secret", "stat": "routes", "reward": 4},
	"bridge_cross": {"type": "checkpoints", "title": "Мост через речку", "icon": "map", "count": 3, "event": "secret", "stat": "routes", "reward": 3},
}


static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})


## Difficulty grows with finished games (never locks anything, always capped).
static func scaled_count(id: String) -> int:
	var d := get_def(id)
	var base := int(d.get("count", 3))
	var done := int(GameState.stats.get("minigames", 0))
	return clampi(base + int(done / 6), base, base + 3)
