extends Node

## Live player state: garage, paints, dirt, stars, discoveries, world progress.

signal stars_changed(total: int)
signal vehicle_changed(id: String)
signal vehicle_unlocked(id: String)
signal stat_changed(name: String, value: int)
signal important_change

const START_VEHICLES := ["car_red", "tractor", "excavator", "dump"]
const TERRITORIES := ["city", "farm", "construction", "autotown", "nature"]
const START_TERRITORIES := ["city", "farm", "construction", "autotown"]

var stars := 0
var owned: Array = []
var selected := "car_red"
var styles: Dictionary = {}          # id -> {color, accent, rim, sticker, dirt, wet, parts}
var unlocked_territories: Array = []
var secrets_found: Array = []
var achievements: Array = []
var stats: Dictionary = {}
var farm: Dictionary = {}
var construction: Dictionary = {}
var washing: Dictionary = {}          # id -> cleanliness 0..1
var garage: Dictionary = {"decor": []}  # bought garage / territory decorations


func _ready() -> void:
	reset_to_defaults()


func reset_to_defaults() -> void:
	stars = 0
	owned = START_VEHICLES.duplicate()
	selected = "car_red"
	styles = {}
	unlocked_territories = START_TERRITORIES.duplicate()
	secrets_found = []
	achievements = []
	stats = {
		"wash": 0, "paint": 0, "repair": 0, "plow": 0, "plant": 0, "water": 0,
		"harvest": 0, "feed": 0, "dig": 0, "load": 0, "deliver": 0, "compact": 0,
		"parking": 0, "quests": 0, "gifts": 0, "drive_m": 0, "cranes": 0,
	}
	farm = {"plots": [], "harvest_stored": 0, "animals_fed": 0}
	construction = {"sand_dug": 0, "road_progress": 0, "crates_placed": 0}
	washing = {}
	for id in owned:
		_style(id)


# ------------------------------------------------------------------- garage ---
func _style(id: String) -> Dictionary:
	if not styles.has(id):
		var d := VehicleDB.get_vehicle(id)
		styles[id] = {
			"color": d.color.to_html(false),
			"accent": "f2f6ff",
			"rim": "ccd3dc",
			"sticker": 0,
			"dirt": 0.0,
			"wet": 0.0,
			"wheels_missing": [],
			"light_broken": false,
			"engine_broken": false,
		}
	return styles[id]


func style(id: String) -> Dictionary:
	return _style(id)


func style_color(id: String) -> Color:
	return Color(_style(id).get("color", "ff3c35"))


func set_style_value(id: String, key: String, value) -> void:
	var s := _style(id)
	s[key] = value
	styles[id] = s
	important_change.emit()


func is_owned(id: String) -> bool:
	return id in owned


func unlock_vehicle(id: String) -> bool:
	if id in owned:
		return false
	owned.append(id)
	_style(id)
	vehicle_unlocked.emit(id)
	important_change.emit()
	return true


func select_vehicle(id: String) -> void:
	selected = id
	vehicle_changed.emit(id)
	important_change.emit()


func add_stars(n: int) -> void:
	stars = maxi(stars + n, 0)
	stars_changed.emit(stars)
	important_change.emit()


func add_stat(name: String, amount: int = 1) -> void:
	stats[name] = int(stats.get(name, 0)) + amount
	stat_changed.emit(name, int(stats[name]))
	important_change.emit()


func unlock_territory(id: String) -> void:
	if not (id in unlocked_territories):
		unlocked_territories.append(id)
		important_change.emit()


func find_secret(id: String) -> bool:
	if id in secrets_found:
		return false
	secrets_found.append(id)
	add_stat("gifts")
	add_stars(1)
	important_change.emit()
	return true


func add_achievement(id: String) -> bool:
	if id in achievements:
		return false
	achievements.append(id)
	add_stars(2)
	important_change.emit()
	return true


# ------------------------------------------------------------ serialisation ---
func to_dict() -> Dictionary:
	return {
		"stars": stars,
		"owned": owned,
		"selected": selected,
		"styles": styles,
		"territories": unlocked_territories,
		"secrets": secrets_found,
		"achievements": achievements,
		"stats": stats,
		"farm": farm,
		"construction": construction,
		"washing": washing,
		"garage": garage,
	}


func from_dict(d: Dictionary) -> void:
	reset_to_defaults()
	stars = int(d.get("stars", 0))
	owned = Array(d.get("owned", START_VEHICLES.duplicate()))
	selected = String(d.get("selected", "car_red"))
	styles = d.get("styles", {})
	unlocked_territories = Array(d.get("territories", START_TERRITORIES.duplicate()))
	secrets_found = Array(d.get("secrets", []))
	achievements = Array(d.get("achievements", []))
	stats = d.get("stats", stats)
	farm = d.get("farm", farm)
	construction = d.get("construction", construction)
	washing = d.get("washing", {})
	garage = d.get("garage", {"decor": []})
	for id in owned:
		_style(id)
	if not is_owned(selected):
		selected = "car_red"
	stars_changed.emit(stars)


func current_vehicle() -> VehicleData:
	return VehicleDB.get_vehicle(selected)


func has_decor(id: String) -> bool:
	return id in garage.get("decor", [])


func add_decor(id: String) -> void:
	var list: Array = garage.get("decor", [])
	if id not in list:
		list.append(id)
	garage["decor"] = list
	important_change.emit()
