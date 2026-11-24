class_name VehicleDB
extends RefCounted

## The whole garage in one data file. 20 machines, each with its own model,
## physics feel, sound and (for work machines) working attachments.

static var _all: Array = []
static var _by_id: Dictionary = {}


static func all() -> Array:
	if _all.is_empty():
		_build()
	return _all


static func get_vehicle(id: String) -> VehicleData:
	all()
	if _by_id.has(id):
		return _by_id[id]
	return _by_id["car_red"]


static func ids() -> Array:
	all()
	return _by_id.keys()


static func by_category(cat: String) -> Array:
	var out: Array = []
	for v in all():
		if cat == "all" or v.category == cat:
			out.append(v)
	return out


static func _mk(d: Dictionary) -> VehicleData:
	var v := VehicleData.new()
	for k in d.keys():
		v.set(k, d[k])
	_all.append(v)
	_by_id[v.id] = v
	return v


static func _build() -> void:
	_mk({
		"id": "car_red", "title": "Красная машинка", "kind": "car", "category": "car",
		"length": 4.0, "width": 1.78, "height": 1.42,
		"mass": 1200.0, "max_speed": 26.0, "power": 13.0, "steer_deg": 33.0,
		"wheel_radius": 0.34, "wheel_width": 0.24, "wheel_x": 0.78,
		"wheel_z_front": 1.26, "wheel_z_rear": -1.22,
		"color": Color(0.93, 0.24, 0.21), "unlock_stars": 0, "engine_pitch": 1.0,
		"description": "Быстрая и весёлая городская машинка.",
	})
	_mk({
		"id": "sport", "title": "Спорткар", "kind": "sport", "category": "car",
		"length": 4.35, "width": 1.92, "height": 1.12,
		"mass": 1150.0, "max_speed": 38.0, "power": 20.0, "steer_deg": 30.0,
		"wheel_radius": 0.35, "wheel_width": 0.28, "wheel_x": 0.84,
		"wheel_z_front": 1.35, "wheel_z_rear": -1.30,
		"color": Color(0.99, 0.83, 0.24), "unlock_stars": 6, "engine_pitch": 1.35,
		"description": "Очень быстрый и блестящий спорткар.",
	})
	_mk({
		"id": "suv", "title": "Внедорожник", "kind": "suv", "category": "car",
		"length": 4.6, "width": 2.0, "height": 1.92,
		"mass": 2100.0, "max_speed": 27.0, "power": 17.0, "steer_deg": 32.0,
		"wheel_radius": 0.46, "wheel_width": 0.32, "wheel_x": 0.88,
		"wheel_z_front": 1.42, "wheel_z_rear": -1.42,
		"color": Color(0.3, 0.62, 0.36), "unlock_stars": 4, "engine_pitch": 0.85,
		"description": "Проедет по грязи, песку и траве.",
	})
	_mk({
		"id": "van", "title": "Семейный минивэн", "kind": "van", "category": "car",
		"length": 4.9, "width": 2.0, "height": 2.0,
		"mass": 2200.0, "max_speed": 24.0, "power": 15.0, "steer_deg": 32.0,
		"wheel_radius": 0.37, "wheel_width": 0.26, "wheel_x": 0.86,
		"wheel_z_front": 1.5, "wheel_z_rear": -1.5,
		"color": Color(0.55, 0.4, 0.9), "unlock_stars": 8, "engine_pitch": 0.92,
		"description": "Большая добрая машинка для всей семьи.",
	})
	_mk({
		"id": "pickup", "title": "Пикап", "kind": "pickup", "category": "work",
		"length": 5.1, "width": 2.02, "height": 1.85,
		"mass": 2300.0, "max_speed": 25.0, "power": 16.0, "steer_deg": 32.0,
		"wheel_radius": 0.42, "wheel_width": 0.3, "wheel_x": 0.88,
		"wheel_z_front": 1.6, "wheel_z_rear": -1.55,
		"color": Color(0.85, 0.45, 0.2), "unlock_stars": 10, "engine_pitch": 0.9,
		"description": "Возит сено, доски и подарки.",
	})
	_mk({
		"id": "truck", "title": "Грузовик", "kind": "truck", "category": "work",
		"length": 7.2, "width": 2.4, "height": 3.05,
		"mass": 6800.0, "max_speed": 22.0, "power": 24.0, "steer_deg": 30.0,
		"wheel_radius": 0.55, "wheel_width": 0.36, "wheel_x": 1.06,
		"wheel_z_front": 2.35, "wheel_z_rear": -2.25, "wheel_z_extra": -3.4,
		"color": Color(0.28, 0.58, 0.9), "unlock_stars": 12, "engine_pitch": 0.6,
		"engine_sound": "engine_truck",
		"description": "Большой грузовик с прицепом-кузовом.",
	})
	_mk({
		"id": "dump", "title": "Самосвал", "kind": "dump", "category": "work",
		"length": 7.4, "width": 2.6, "height": 3.1,
		"mass": 9000.0, "max_speed": 20.0, "power": 26.0, "steer_deg": 30.0,
		"wheel_radius": 0.6, "wheel_width": 0.4, "wheel_x": 1.14,
		"wheel_z_front": 2.4, "wheel_z_rear": -2.2, "wheel_z_extra": -3.3,
		"color": Color(0.99, 0.72, 0.15), "unlock_stars": 14, "engine_pitch": 0.5,
		"engine_sound": "engine_truck", "special": "dump",
		"description": "Кузов поднимается и высыпает песок.",
	})
	_mk({
		"id": "tractor", "title": "Трактор", "kind": "tractor", "category": "work",
		"length": 4.3, "width": 2.0, "height": 2.5,
		"mass": 3600.0, "max_speed": 20.0, "power": 18.0, "steer_deg": 34.0,
		"wheel_radius": 0.62, "wheel_width": 0.42, "wheel_x": 0.82,
		"wheel_z_front": 1.45, "wheel_z_rear": -1.35,
		"color": Color(0.32, 0.72, 0.32), "unlock_stars": 0, "engine_pitch": 0.55,
		"engine_sound": "engine_tractor", "special": "tractor",
		"description": "Пашет, сеет, поливает и собирает урожай.",
	})
	_mk({
		"id": "tractor_trailer", "title": "Трактор с прицепом", "kind": "tractor",
		"category": "work",
		"length": 4.6, "width": 2.0, "height": 2.5,
		"mass": 4600.0, "max_speed": 18.0, "power": 19.0, "steer_deg": 34.0,
		"wheel_radius": 0.62, "wheel_width": 0.42, "wheel_x": 0.82,
		"wheel_z_front": 1.45, "wheel_z_rear": -1.35,
		"color": Color(0.9, 0.4, 0.24), "unlock_stars": 16, "engine_pitch": 0.55,
		"engine_sound": "engine_tractor", "special": "tractor",
		"attachment": "trailer",
		"description": "Трактор с большим прицепом для урожая.",
	})
	_mk({
		"id": "excavator", "title": "Экскаватор", "kind": "excavator", "category": "work",
		"length": 5.6, "width": 2.7, "height": 3.1,
		"mass": 6200.0, "max_speed": 11.0, "power": 16.0, "steer_deg": 40.0,
		"wheel_radius": 0.34, "wheel_width": 0.55, "wheel_x": 1.05,
		"wheel_z_front": 1.7, "wheel_z_rear": -1.7, "tracked": true,
		"color": Color(0.99, 0.72, 0.15), "unlock_stars": 0, "engine_pitch": 0.42,
		"engine_sound": "engine_heavy", "special": "excavator",
		"description": "Копает песок и грузит его в самосвал.",
	})
	_mk({
		"id": "bulldozer", "title": "Бульдозер", "kind": "bulldozer", "category": "work",
		"length": 5.4, "width": 3.0, "height": 2.85,
		"mass": 8200.0, "max_speed": 13.0, "power": 22.0, "steer_deg": 38.0,
		"wheel_radius": 0.36, "wheel_width": 0.6, "wheel_x": 1.18,
		"wheel_z_front": 1.65, "wheel_z_rear": -1.65, "tracked": true,
		"color": Color(0.99, 0.65, 0.13), "unlock_stars": 18, "engine_pitch": 0.38,
		"engine_sound": "engine_heavy", "special": "bulldozer",
		"description": "Толкает грунт широким отвалом.",
	})
	_mk({
		"id": "loader", "title": "Фронтальный погрузчик", "kind": "loader", "category": "work",
		"length": 5.1, "width": 2.6, "height": 3.0,
		"mass": 7200.0, "max_speed": 17.0, "power": 22.0, "steer_deg": 40.0,
		"wheel_radius": 0.62, "wheel_width": 0.44, "wheel_x": 1.05,
		"wheel_z_front": 1.55, "wheel_z_rear": -1.55,
		"color": Color(0.95, 0.55, 0.16), "unlock_stars": 20, "engine_pitch": 0.44,
		"engine_sound": "engine_heavy", "special": "loader",
		"description": "Поднимает ковшом песок и кирпичи.",
	})
	_mk({
		"id": "roller", "title": "Каток", "kind": "roller", "category": "work",
		"length": 4.7, "width": 2.2, "height": 2.45,
		"mass": 6200.0, "max_speed": 15.0, "power": 16.0, "steer_deg": 34.0,
		"wheel_radius": 0.6, "wheel_width": 0.42, "wheel_x": 0.92,
		"wheel_z_front": 1.35, "wheel_z_rear": -1.4,
		"color": Color(0.98, 0.78, 0.2), "unlock_stars": 22, "engine_pitch": 0.5,
		"engine_sound": "engine_heavy", "special": "roller",
		"description": "Уплотняет дорогу гладким барабаном.",
	})
	_mk({
		"id": "crane", "title": "Подъёмный кран", "kind": "crane", "category": "work",
		"length": 6.6, "width": 2.6, "height": 3.6,
		"mass": 9600.0, "max_speed": 14.0, "power": 20.0, "steer_deg": 32.0,
		"wheel_radius": 0.58, "wheel_width": 0.4, "wheel_x": 1.1,
		"wheel_z_front": 2.1, "wheel_z_rear": -2.0, "wheel_z_extra": -3.0,
		"color": Color(0.28, 0.6, 0.95), "unlock_stars": 26, "engine_pitch": 0.48,
		"engine_sound": "engine_heavy", "special": "crane",
		"description": "Поднимает грузы высоко-высоко.",
	})
	_mk({
		"id": "fire", "title": "Пожарная машина", "kind": "fire", "category": "emergency",
		"length": 7.6, "width": 2.5, "height": 3.15,
		"mass": 8200.0, "max_speed": 26.0, "power": 26.0, "steer_deg": 30.0,
		"wheel_radius": 0.55, "wheel_width": 0.36, "wheel_x": 1.08,
		"wheel_z_front": 2.4, "wheel_z_rear": -2.1, "wheel_z_extra": -3.2,
		"color": Color(0.92, 0.18, 0.16), "unlock_stars": 10, "engine_pitch": 0.62,
		"engine_sound": "engine_truck", "special": "fire",
		"description": "Может полить огород и помыть машину.",
	})
	_mk({
		"id": "police", "title": "Полицейская машина", "kind": "police", "category": "emergency",
		"length": 4.5, "width": 1.86, "height": 1.5,
		"mass": 1900.0, "max_speed": 34.0, "power": 20.0, "steer_deg": 33.0,
		"wheel_radius": 0.34, "wheel_width": 0.26, "wheel_x": 0.8,
		"wheel_z_front": 1.4, "wheel_z_rear": -1.35,
		"color": Color(0.95, 0.96, 0.98), "unlock_stars": 12, "engine_pitch": 1.15,
		"special": "police",
		"description": "С мигалками и весёлой сиреной.",
	})
	_mk({
		"id": "ambulance", "title": "Скорая помощь", "kind": "ambulance", "category": "emergency",
		"length": 5.8, "width": 2.2, "height": 2.8,
		"mass": 3100.0, "max_speed": 28.0, "power": 20.0, "steer_deg": 32.0,
		"wheel_radius": 0.4, "wheel_width": 0.28, "wheel_x": 0.94,
		"wheel_z_front": 1.85, "wheel_z_rear": -1.8,
		"color": Color(0.96, 0.97, 0.98), "unlock_stars": 14, "engine_pitch": 0.95,
		"special": "ambulance",
		"description": "Белая машинка с красным крестиком.",
	})
	_mk({
		"id": "garbage", "title": "Мусоровоз", "kind": "garbage", "category": "work",
		"length": 7.0, "width": 2.4, "height": 3.2,
		"mass": 8600.0, "max_speed": 19.0, "power": 24.0, "steer_deg": 30.0,
		"wheel_radius": 0.55, "wheel_width": 0.36, "wheel_x": 1.06,
		"wheel_z_front": 2.3, "wheel_z_rear": -2.1, "wheel_z_extra": -3.2,
		"color": Color(0.35, 0.72, 0.45), "unlock_stars": 24, "engine_pitch": 0.58,
		"engine_sound": "engine_truck", "special": "garbage",
		"description": "Собирает мусор и делает город чистым.",
	})
	_mk({
		"id": "bus", "title": "Автобус", "kind": "bus", "category": "big",
		"length": 10.2, "width": 2.55, "height": 3.2,
		"mass": 10500.0, "max_speed": 22.0, "power": 28.0, "steer_deg": 30.0,
		"wheel_radius": 0.52, "wheel_width": 0.34, "wheel_x": 1.1,
		"wheel_z_front": 3.3, "wheel_z_rear": -3.1,
		"color": Color(0.34, 0.76, 0.9), "unlock_stars": 18, "engine_pitch": 0.55,
		"engine_sound": "engine_truck",
		"description": "Весёлый автобус для зверят.",
	})
	_mk({
		"id": "tow", "title": "Эвакуатор", "kind": "tow", "category": "work",
		"length": 6.1, "width": 2.2, "height": 2.5,
		"mass": 4200.0, "max_speed": 24.0, "power": 19.0, "steer_deg": 31.0,
		"wheel_radius": 0.44, "wheel_width": 0.3, "wheel_x": 0.96,
		"wheel_z_front": 1.95, "wheel_z_rear": -1.9,
		"color": Color(0.99, 0.82, 0.24), "unlock_stars": 28, "engine_pitch": 0.8,
		"engine_sound": "engine_truck", "special": "tow",
		"description": "Помогает машинкам, которые застряли.",
	})
