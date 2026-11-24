class_name TouchButton
extends Control

## Large, kid-friendly button that works with real multi-touch
## (two fingers can hold steering and gas at the same time).

signal pressed_down
signal pressed_up
signal tapped

@export var icon := "arrow_left"
@export var label_text := ""
@export var base_color := Color(0.45, 0.75, 1.0, 0.92)
@export var icon_color := Color(1, 1, 1, 0.98)
@export var round_shape := true
@export var font_size := 28
@export var hold_mode := true
@export var small_icon := false

var is_down := false
var enabled := true
var pulse := 0.0

var _finger := -1
var _hover := false
var _press_scale := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_process_input(true)
	set_process(true)


func _process(delta: float) -> void:
	var target := 0.94 if is_down else 1.0
	_press_scale = lerpf(_press_scale, target, clampf(delta * 16.0, 0.0, 1.0))
	if pulse > 0.0:
		pulse = maxf(pulse - delta * 2.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var s := minf(size.x, size.y)
	var center := size * 0.5
	var col := base_color
	if not enabled:
		col = Color(0.6, 0.62, 0.66, 0.55)
	elif not is_down:
		col = base_color.lightened(0.06)
	var grow := 1.0 + sin(pulse * PI) * 0.12
	var body := Rect2(Vector2.ZERO, size)
	if round_shape:
		var rad := s * 0.5 * _press_scale * grow
		draw_circle(center + Vector2(0, s * 0.03), rad * 0.99, Color(0, 0, 0, 0.18))
		draw_circle(center, rad, col)
		draw_circle(center, rad * 0.86, col.lightened(0.12))
		body = Rect2(center - Vector2(rad * 0.7, rad * 0.7), Vector2(rad * 1.4, rad * 1.4))
	else:
		var box := r.grow(-s * 0.06)
		draw_style_box(_box(Color(0, 0, 0, 0.16), s * 0.26), box.translated(Vector2(0, s * 0.035)))
		draw_style_box(_box(col, s * 0.24), box)
		body = box.grow(-s * 0.16)
	var icon_rect := body
	if label_text != "":
		icon_rect = Rect2(body.position + body.size * Vector2(0.0, 0.0), Vector2(body.size.x, body.size.y * 0.58))
	var icon_size := icon_rect.size
	if small_icon:
		icon_size *= 0.62
	var centred := Rect2(icon_rect.position + (icon_rect.size - icon_size) * 0.5, icon_size)
	Icons.draw_icon(self, icon, centred, icon_color)
	if label_text != "":
		var font := get_theme_default_font()
		var fs := int(minf(font_size, body.size.y * 0.26))
		var text_pos := Vector2(body.position.x, body.position.y + body.size.y * 0.9)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, body.size.x, fs, icon_color)


func _box(color: Color, radius: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = int(radius)
	sb.corner_radius_top_right = int(radius)
	sb.corner_radius_bottom_left = int(radius)
	sb.corner_radius_bottom_right = int(radius)
	return sb


func set_down(down: bool) -> void:
	if not enabled:
		down = false
	if is_down == down:
		return
	is_down = down
	if is_down:
		pressed_down.emit()
		if not hold_mode:
			tapped.emit()
			get_tree().create_timer(0.12).timeout.connect(_auto_release)
	else:
		pressed_up.emit()


func _auto_release() -> void:
	if not is_instance_valid(self):
		return
	if is_down:
		is_down = false
		pressed_up.emit()


func _inside(global_pos: Vector2) -> bool:
	return get_global_rect().has_point(global_pos)


func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree():
		return
	if UIManager != null and UIManager.input_blocked and not UIManager.is_modal_child(self):
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _finger == -1 and _inside(t.position):
			_finger = t.index
			AudioManager.play_click()
			SettingsManager.vibrate(12)
			set_down(true)
			get_viewport().set_input_as_handled()
		elif not t.pressed and _finger == t.index:
			_finger = -1
			set_down(false)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _finger and not _inside(d.position):
			_finger = -1
			set_down(false)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _inside(mb.position):
				_finger = 0
				AudioManager.play_click()
				set_down(true)
				get_viewport().set_input_as_handled()
			elif not mb.pressed and _finger == 0:
				_finger = -1
				set_down(false)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _finger == 0 and is_down:
			var mm := event as InputEventMouseMotion
			if not _inside(mm.position):
				_finger = -1
				set_down(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_finger = -1
		is_down = false
