extends CanvasLayer

## Global UI layer: HUD hosting, fades, toasts, star popups, modal windows.

var hud_root: Control
var overlay_root: Control
var toast_root: VBoxContainer
var input_blocked := false

var _fade: ColorRect
var _modals: Array = []
var _flash: ColorRect


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	hud_root = Control.new()
	hud_root.name = "HudRoot"
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)

	overlay_root = Control.new()
	overlay_root.name = "OverlayRoot"
	overlay_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_root)

	toast_root = VBoxContainer.new()
	toast_root.name = "Toasts"
	toast_root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_root.position = Vector2(-180, 90)
	toast_root.custom_minimum_size = Vector2(360, 0)
	toast_root.alignment = BoxContainer.ALIGNMENT_CENTER
	toast_root.add_theme_constant_override("separation", 8)
	toast_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_root)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	add_child(_fade)


# ------------------------------------------------------------------- HUD host ---
func attach_hud(hud: Control) -> void:
	clear_hud()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.add_child(hud)


func clear_hud() -> void:
	for c in hud_root.get_children():
		c.queue_free()


func set_hud_visible(v: bool) -> void:
	hud_root.visible = v


# ------------------------------------------------------------------ transitions ---
func fade_to_black(t: float = 0.3) -> void:
	_fade.visible = true
	_fade.color = Color(0, 0, 0, 0)
	var tw := create_tween()
	tw.tween_property(_fade, "color", Color(0, 0, 0, 1), maxf(t, 0.02))
	await tw.finished


func fade_from_black(t: float = 0.3) -> void:
	_fade.visible = true
	_fade.color = Color(0, 0, 0, 1)
	var tw := create_tween()
	tw.tween_property(_fade, "color", Color(0, 0, 0, 0), maxf(t, 0.02))
	await tw.finished
	_fade.visible = false


func flash(color: Color = Color(1, 1, 1, 0.35), t: float = 0.25) -> void:
	_flash.color = color
	var tw := create_tween()
	tw.tween_property(_flash, "color", Color(color.r, color.g, color.b, 0.0), t)


# ------------------------------------------------------------------- messages ---
func toast(text: String, icon: String = "star", color: Color = UIKit.ACCENT, duration: float = 2.6) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.rounded(UIKit.CARD, 26.0, 3.0, color))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIKit.row(12)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(56, 56)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func() -> void:
		Icons.draw_icon(ic, icon, Rect2(4, 4, 48, 48), color))
	row.add_child(ic)
	row.add_child(UIKit.label(text, 26, UIKit.TEXT))
	card.add_child(row)
	card.modulate = Color(1, 1, 1, 0)
	toast_root.add_child(card)
	var tw := create_tween()
	tw.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.18)
	tw.tween_interval(maxf(duration, 0.4))
	tw.tween_property(card, "modulate", Color(1, 1, 1, 0), 0.4)
	tw.tween_callback(card.queue_free)


func star_popup(amount: int = 1, text: String = "") -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.position = Vector2(-120, 150)
	holder.custom_minimum_size = Vector2(240, 80)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := Control.new()
	ic.position = Vector2(70, 8)
	ic.size = Vector2(64, 64)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func() -> void:
		Icons.draw_icon(ic, "star", Rect2(0, 0, 64, 64), UIKit.ACCENT))
	holder.add_child(ic)
	var lbl := UIKit.label("+%d %s" % [amount, text], 44, UIKit.ACCENT)
	lbl.position = Vector2(120, 6)
	lbl.custom_minimum_size = Vector2(200, 64)
	holder.add_child(lbl)
	add_child(holder)
	AudioManager.play_star()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(holder, "position:y", 90.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(holder, "modulate", Color(1, 1, 1, 0), 0.9).set_delay(0.5)
	tw.chain().tween_callback(holder.queue_free)


func unlock_card(title: String, subtitle: String, icon: String = "car", color: Color = Color(0.45, 0.8, 1.0)) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIKit.rounded(UIKit.CARD, 40.0, 5.0, color))
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.custom_minimum_size = Vector2(540, 220)
	card.position = Vector2(-270, -110)
	var box := UIKit.col(10)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(90, 90)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func() -> void:
		Icons.draw_icon(ic, icon, Rect2(0, 0, 90, 90), color))
	box.add_child(ic)
	box.add_child(UIKit.label(title, 40, UIKit.TEXT))
	box.add_child(UIKit.label(subtitle, 24, Color(0.85, 0.9, 1.0)))
	card.add_child(box)
	card.modulate = Color(1, 1, 1, 0)
	card.scale = Vector2(0.8, 0.8)
	add_child(card)
	AudioManager.play_unlock()
	SettingsManager.vibrate(40)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(card, "modulate", Color(1, 1, 1, 1), 0.25)
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.2)
	tw.chain().tween_property(card, "modulate", Color(1, 1, 1, 0), 0.5)
	tw.chain().tween_callback(card.queue_free)


# --------------------------------------------------------------------- modals ---
func show_modal(control: Control, pause_game: bool = false) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_root.add_child(control)
	_modals.append(control)
	input_blocked = true
	if pause_game:
		get_tree().paused = true


func close_modal(control: Control = null) -> void:
	var target: Control = control
	if target == null and not _modals.is_empty():
		target = _modals[_modals.size() - 1]
	if target == null:
		return
	_modals.erase(target)
	if is_instance_valid(target):
		target.queue_free()
	if _modals.is_empty():
		input_blocked = false
		get_tree().paused = false


func is_modal_child(node: Node) -> bool:
	var n := node
	while n != null:
		if n in _modals:
			return true
		n = n.get_parent()
	return false


func has_modal() -> bool:
	return not _modals.is_empty()


func close_all_modals() -> void:
	for m in _modals.duplicate():
		if is_instance_valid(m):
			m.queue_free()
	_modals.clear()
	input_blocked = false
	get_tree().paused = false
