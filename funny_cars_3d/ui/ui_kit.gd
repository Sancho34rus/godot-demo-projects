class_name UIKit
extends RefCounted

## Shared look & feel helpers: rounded panels, big buttons, labels.

const CARD := Color(0.12, 0.17, 0.27, 0.86)
const CARD_LIGHT := Color(0.98, 0.99, 1.0, 0.94)
const ACCENT := Color(1.0, 0.79, 0.25)
const TEXT := Color(0.99, 0.99, 1.0)
const TEXT_DARK := Color(0.17, 0.22, 0.3)


static func rounded(color: Color, radius: float = 24.0, border: float = 0.0, border_color: Color = Color(1, 1, 1, 0.5)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = int(radius)
	sb.corner_radius_top_right = int(radius)
	sb.corner_radius_bottom_left = int(radius)
	sb.corner_radius_bottom_right = int(radius)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	if border > 0.0:
		sb.border_width_left = int(border)
		sb.border_width_right = int(border)
		sb.border_width_top = int(border)
		sb.border_width_bottom = int(border)
		sb.border_color = border_color
	return sb


static func panel(color: Color = CARD, radius: float = 26.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", rounded(color, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String, size: int = 26, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func col(separation: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


static func row(separation: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


static func spacer(size: Vector2 = Vector2(0, 0)) -> Control:
	var c := Control.new()
	c.custom_minimum_size = size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## Big icon button used by menus and shops.
static func icon_button(icon: String, text: String, color: Color, size: Vector2, radius_shape: bool = false) -> TouchButton:
	var b := TouchButton.new()
	b.icon = icon
	b.label_text = text
	b.base_color = color
	b.round_shape = radius_shape
	b.custom_minimum_size = size
	b.font_size = 26
	b.hold_mode = false
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c
