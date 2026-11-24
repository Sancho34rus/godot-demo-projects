extends Node

## Long-term progression: machines and territories unlocked by stars,
## friendly achievements, no timers, no penalties.

signal achievement_unlocked(id: String)

const NATURE_STARS := 8
const UIColor_TROPHY := Color(1.0, 0.83, 0.35)

const ACHIEVEMENTS := [
	{"id": "first_wash", "stat": "wash", "need": 1, "title": "Первый чистюля", "icon": "water"},
	{"id": "washer", "stat": "wash", "need": 5, "title": "Мастер мойки", "icon": "water"},
	{"id": "painter", "stat": "paint", "need": 5, "title": "Художник", "icon": "paint"},
	{"id": "mechanic", "stat": "repair", "need": 4, "title": "Мастер на все руки", "icon": "wrench"},
	{"id": "farmer", "stat": "harvest", "need": 10, "title": "Весёлый фермер", "icon": "farm"},
	{"id": "builder", "stat": "dig", "need": 10, "title": "Юный строитель", "icon": "build"},
	{"id": "driver", "stat": "drive_m", "need": 2000, "title": "Путешественник", "icon": "car"},
	{"id": "gift_hunter", "stat": "gifts", "need": 3, "title": "Кладоискатель", "icon": "gift"},
	{"id": "crane_master", "stat": "cranes", "need": 2, "title": "Крановщик", "icon": "crane"},
	{"id": "parking_master", "stat": "parking", "need": 3, "title": "Парковка — легко!", "icon": "car"},
]


func _ready() -> void:
	GameState.stars_changed.connect(_on_stars_changed)
	GameState.stat_changed.connect(_on_stat_changed)
	call_deferred("refresh")


func refresh() -> void:
	_check_unlocks()
	_check_achievements()


func _on_stars_changed(_total: int) -> void:
	_check_unlocks()


func _on_stat_changed(_name: String, _value: int) -> void:
	_check_achievements()


func _check_unlocks() -> void:
	var total := GameState.stars
	for v in VehicleDB.all():
		if v.unlock_stars <= 0:
			continue
		if total >= v.unlock_stars and not GameState.is_owned(v.id):
			if GameState.unlock_vehicle(v.id):
				_notify_vehicle(v)
	if total >= NATURE_STARS and not ("nature" in GameState.unlocked_territories):
		GameState.unlock_territory("nature")
		_notify("Новая территория!", "Секретная поляна открыта", "map", Color(0.55, 1.0, 0.7))


func _notify_vehicle(v: VehicleData) -> void:
	_notify("Новая машинка!", v.title, "car", Color(0.5, 0.85, 1.0))


func _notify(title: String, subtitle: String, icon: String, color: Color) -> void:
	AudioManager.play_unlock()
	SettingsManager.vibrate(40)
	if UIManager == null:
		return
	UIManager.call_deferred("unlock_card", title, subtitle, icon, color)


func _check_achievements() -> void:
	for a in ACHIEVEMENTS:
		var id := String(a["id"])
		if id in GameState.achievements:
			continue
		var stat := String(a["stat"])
		var value := int(GameState.stats.get(stat, 0))
		if value >= int(a["need"]):
			if GameState.add_achievement(id):
				achievement_unlocked.emit(id)
				for t in ACHIEVEMENTS:
					if String(t["id"]) == id:
						_notify("Достижение!", String(t["title"]), String(t["icon"]), UIColor_TROPHY)




func unlocked_count() -> int:
	return GameState.owned.size()


func total_vehicles() -> int:
	return VehicleDB.all().size()
