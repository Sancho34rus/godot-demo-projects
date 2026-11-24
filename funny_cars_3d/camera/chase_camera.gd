class_name ChaseCamera
extends Camera3D

## Smooth third-person camera with several angles, touch-drag orbit and a
## gentle auto-recenter so a child never loses the car.

const MODE_NAMES := ["Близко", "Далеко", "Сверху", "Из кабины"]

var vehicle: VehicleController
var mode := 0
var distance := 7.0
var height := 2.6

var _pos := Vector3.ZERO
var _look := Vector3.ZERO
var user_yaw := 0.0
var user_pitch := 0.0
var _dragging := false
var _drag_id := -1
var _idle := 0.0
var _initialized := false


func setup(v: VehicleController) -> void:
	vehicle = v
	far = SettingsManager.view_distance()
	fov = 62.0
	near = 0.12
	_snap()


func cycle_mode() -> int:
	mode = (mode + 1) % MODE_NAMES.size()
	_idle = 0.0
	return mode


func mode_name() -> String:
	return MODE_NAMES[mode]


func _snap() -> void:
	if vehicle == null:
		return
	_pos = _desired_position()
	_look = _desired_look()
	global_position = _pos
	if _pos.distance_squared_to(_look) > 0.01:
		look_at(_look, Vector3.UP)
	_initialized = true


func _desired_position() -> Vector3:
	if vehicle == null:
		return Vector3(0, 6, 10)
	var d := vehicle.data
	var base_pos := vehicle.global_position
	var yaw := vehicle.rotation.y + user_yaw
	var basis := Basis(Vector3.UP, yaw)
	match mode:
		0:
			return base_pos + basis * Vector3(0, d.height * 1.5 + 1.4, d.length * 0.62 + 4.2)
		1:
			return base_pos + basis * Vector3(0, d.height * 2.2 + 3.0, d.length * 0.7 + 8.0)
		2:
			return base_pos + basis * Vector3(0, d.length * 0.8 + 8.0, d.length * 0.35)
		_:
			return base_pos + basis * Vector3(0, d.height * 0.95, -d.length * 0.1)


func _desired_look() -> Vector3:
	if vehicle == null:
		return Vector3.ZERO
	var d := vehicle.data
	var basis := Basis(Vector3.UP, vehicle.rotation.y)
	if mode == 3:
		return vehicle.global_position + basis * Vector3(0, d.height * 0.8, -8.0)
	var fwd := -basis.z
	return vehicle.global_position + Vector3(0, d.height * 0.75, 0) + fwd * (2.0 if speed_factor() > 0.2 else 0.0)


func speed_factor() -> float:
	if vehicle == null or vehicle.data == null:
		return 0.0
	return clampf(absf(vehicle.speed) / maxf(vehicle.data.max_speed, 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	if not _initialized:
		_snap()
	if not _dragging:
		_idle += delta
		if _idle > 1.4 and speed_factor() > 0.05:
			user_yaw = lerp_angle(user_yaw, 0.0, clampf(delta * 2.2, 0.0, 1.0))
			user_pitch = lerpf(user_pitch, 0.0, clampf(delta * 2.0, 0.0, 1.0))
	var target_pos := _desired_position()
	if mode == 2:
		target_pos += Vector3(cos(user_yaw), 0, sin(user_yaw)) * (absf(user_yaw) * 3.0)
	target_pos.y += user_pitch * 6.0
	var smooth: float = 8.0 if mode != 3 else 14.0
	if speed_factor() > 0.5:
		smooth = 5.0
	_pos = _pos.lerp(target_pos, clampf(1.0 - exp(-delta * smooth), 0.0, 1.0))
	_look = _look.lerp(_desired_look(), clampf(1.0 - exp(-delta * (smooth + 4.0)), 0.0, 1.0))
	global_position = _pos
	if _pos.distance_squared_to(_look) > 0.05:
		look_at(_look, Vector3.UP)
	var target_fov: float = 62.0 + speed_factor() * 8.0
	fov = lerpf(fov, target_fov, clampf(delta * 3.0, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _drag_id == -1:
			_drag_id = t.index
			_dragging = true
			_idle = 0.0
		elif not t.pressed and t.index == _drag_id:
			_drag_id = -1
			_dragging = false
			_idle = 0.0
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _drag_id:
			user_yaw -= d.relative.x * 0.006
			user_pitch = clampf(user_pitch + d.relative.y * 0.004, -0.45, 0.85)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_idle = 0.0
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging:
			user_yaw -= mm.relative.x * 0.006
			user_pitch = clampf(user_pitch + mm.relative.y * 0.004, -0.45, 0.85)
