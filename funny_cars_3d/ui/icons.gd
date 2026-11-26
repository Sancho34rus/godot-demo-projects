class_name Icons
extends RefCounted

## Vector icons drawn straight onto a CanvasItem, so the game needs no image
## assets and the interface stays crisp on every screen density.

static func draw_icon(ci: CanvasItem, icon: String, rect: Rect2, color: Color) -> void:
	var s: float = minf(rect.size.x, rect.size.y)
	var c: Vector2 = rect.position + rect.size * 0.5
	match icon:
		"arrow_left":
			ci.draw_colored_polygon(_arrow(c, s, -1.0), color)
		"arrow_right":
			ci.draw_colored_polygon(_arrow(c, s, 1.0), color)
		"gas":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.16, -s * 0.3), c + Vector2(s * 0.26, -s * 0.05),
				c + Vector2(s * 0.26, s * 0.05), c + Vector2(-s * 0.16, s * 0.3)]), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.24), Vector2(s * 0.14, s * 0.48)), color)
		"brake":
			ci.draw_circle(c, s * 0.3, color)
			ci.draw_circle(c, s * 0.16, Color(1, 1, 1, 0.55))
		"reverse":
			ci.draw_colored_polygon(_arrow(c, s, -1.0), color)
			ci.draw_arc(c, s * 0.34, PI * 0.6, PI * 1.4, 18, color, s * 0.07)
		"camera":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.18), Vector2(s * 0.6, s * 0.36)), color)
			ci.draw_circle(c + Vector2(0, -s * 0.24), s * 0.1, color)
			ci.draw_circle(c + Vector2(0, 0), s * 0.13, Color(1, 1, 1, 0.85))
		"action", "wrench":
			_draw_wrench(ci, c, s, color)
		"water", "bubbles":
			_draw_drop(ci, c, s, color)
		"foam":
			for i in 3:
				var off := Vector2(cos(float(i) * 2.1) * s * 0.2, sin(float(i) * 2.1) * s * 0.2)
				ci.draw_circle(c + off, s * 0.16, color)
				ci.draw_circle(c + off + Vector2(s * 0.06, -s * 0.06), s * 0.07, Color(1, 1, 1, 0.7))
		"brush":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.05), Vector2(s * 0.35, s * 0.18)), color)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(s * 0.05, -s * 0.05), c + Vector2(s * 0.32, -s * 0.22),
				c + Vector2(s * 0.32, s * 0.22), c + Vector2(s * 0.05, s * 0.13)]), color)
		"paint":
			ci.draw_circle(c + Vector2(s * 0.06, s * 0.06), s * 0.26, color)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.24, s * 0.02), c + Vector2(-s * 0.42, -s * 0.42),
				c + Vector2(-s * 0.02, -s * 0.26)]), color)
			ci.draw_circle(c + Vector2(s * 0.06, s * 0.06), s * 0.11, Color(1, 1, 1, 0.65))
		"car":
			_draw_car(ci, c, s, color)
		"tractor":
			_draw_tractor(ci, c, s, color)
		"crane":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, s * 0.02), Vector2(s * 0.42, s * 0.24)), color)
			ci.draw_line(c + Vector2(-s * 0.1, 0), c + Vector2(s * 0.3, -s * 0.34), color, s * 0.08)
			ci.draw_line(c + Vector2(-s * 0.1, 0), c + Vector2(-s * 0.34, -s * 0.12), color, s * 0.07)
			ci.draw_line(c + Vector2(s * 0.28, -s * 0.32), c + Vector2(s * 0.28, s * 0.02), color, s * 0.04)
			ci.draw_circle(c + Vector2(s * 0.28, s * 0.06), s * 0.08, color)
			ci.draw_circle(c + Vector2(-s * 0.2, s * 0.26), s * 0.09, color.darkened(0.35))
			ci.draw_circle(c + Vector2(s * 0.16, s * 0.26), s * 0.09, color.darkened(0.35))
		"build":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.32, s * 0.02), Vector2(s * 0.64, s * 0.28)), color)
			for i in 3:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.3 + float(i) * s * 0.2, -s * 0.28), Vector2(s * 0.16, s * 0.12)), color)
			ci.draw_line(c + Vector2(-s * 0.34, s * 0.02), c + Vector2(s * 0.34, s * 0.02), color, s * 0.05)
		"farm":
			for i in 4:
				var a: float = -PI * 0.5 + (float(i) - 1.5) * 0.5
				ci.draw_circle(c + Vector2(cos(a) * s * 0.2, sin(a) * s * 0.2), s * 0.12, color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.04, s * 0.1), Vector2(s * 0.08, s * 0.26)), color.darkened(0.3))
		"garage":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.06), Vector2(s * 0.68, s * 0.36)), color)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.42, -s * 0.06), c + Vector2(0, -s * 0.42),
				c + Vector2(s * 0.42, -s * 0.06)]), color.darkened(0.15))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.15, s * 0.08), Vector2(s * 0.3, s * 0.22)), Color(1, 1, 1, 0.55))
		"star":
			_draw_star(ci, c, s, color)
		"gift":
			ci.draw_rect(Rect2(c + Vector2(-s * 0.26, -s * 0.1), Vector2(s * 0.52, s * 0.36)), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.32, -s * 0.24), Vector2(s * 0.64, s * 0.14)), color.darkened(0.12))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.05, -s * 0.24), Vector2(s * 0.1, s * 0.5)), Color(1, 1, 1, 0.75))
			ci.draw_arc(c + Vector2(-s * 0.1, -s * 0.3), s * 0.12, 0, TAU, 12, color, s * 0.05)
			ci.draw_arc(c + Vector2(s * 0.1, -s * 0.3), s * 0.12, 0, TAU, 12, color, s * 0.05)
		"back":
			ci.draw_line(c + Vector2(s * 0.18, -s * 0.26), c + Vector2(-s * 0.16, 0), color, s * 0.09)
			ci.draw_line(c + Vector2(-s * 0.16, 0), c + Vector2(s * 0.18, s * 0.26), color, s * 0.09)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.18, -s * 0.3), c + Vector2(s * 0.3, 0),
				c + Vector2(-s * 0.18, s * 0.3)]), color)
		"settings":
			ci.draw_circle(c, s * 0.2, color)
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.22, c + Vector2(cos(a), sin(a)) * s * 0.36, color, s * 0.09)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.3, -s * 0.12), c + Vector2(-s * 0.12, -s * 0.12),
				c + Vector2(s * 0.1, -s * 0.3), c + Vector2(s * 0.1, s * 0.3),
				c + Vector2(-s * 0.12, s * 0.12), c + Vector2(-s * 0.3, s * 0.12)]), color)
			ci.draw_arc(c + Vector2(s * 0.12, 0), s * 0.2, -0.9, 0.9, 12, color, s * 0.06)
		"mute":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.3, -s * 0.12), c + Vector2(-s * 0.12, -s * 0.12),
				c + Vector2(s * 0.1, -s * 0.3), c + Vector2(s * 0.1, s * 0.3),
				c + Vector2(-s * 0.12, s * 0.12), c + Vector2(-s * 0.3, s * 0.12)]), color)
			ci.draw_line(c + Vector2(s * 0.16, -s * 0.18), c + Vector2(s * 0.36, s * 0.18), color, s * 0.06)
			ci.draw_line(c + Vector2(s * 0.36, -s * 0.18), c + Vector2(s * 0.16, s * 0.18), color, s * 0.06)
		"lock":
			ci.draw_arc(c + Vector2(0, -s * 0.1), s * 0.16, PI, TAU, 16, color, s * 0.07)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, -s * 0.06), Vector2(s * 0.4, s * 0.32)), color)
		"check":
			ci.draw_line(c + Vector2(-s * 0.26, 0), c + Vector2(-s * 0.06, s * 0.22), color, s * 0.1)
			ci.draw_line(c + Vector2(-s * 0.06, s * 0.22), c + Vector2(s * 0.28, -s * 0.22), color, s * 0.1)
		"bucket":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.3, -s * 0.1), c + Vector2(s * 0.3, -s * 0.1),
				c + Vector2(s * 0.2, s * 0.26), c + Vector2(-s * 0.2, s * 0.26)]), color)
			ci.draw_line(c + Vector2(-s * 0.3, -s * 0.1), c + Vector2(-s * 0.12, -s * 0.34), color, s * 0.07)
		"seed":
			for i in 3:
				ci.draw_circle(c + Vector2(-s * 0.18 + float(i) * s * 0.18, s * 0.05), s * 0.1, color)
			ci.draw_line(c + Vector2(0, -s * 0.32), c + Vector2(0, -s * 0.05), color, s * 0.06)
		"animal":
			ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.24, color)
			ci.draw_circle(c + Vector2(-s * 0.22, -s * 0.16), s * 0.1, color)
			ci.draw_circle(c + Vector2(s * 0.22, -s * 0.16), s * 0.1, color)
			ci.draw_circle(c + Vector2(-s * 0.08, s * 0.06), s * 0.04, Color(1, 1, 1, 0.8))
			ci.draw_circle(c + Vector2(s * 0.08, s * 0.06), s * 0.04, Color(1, 1, 1, 0.8))
		"trophy":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(s * 0.2, -s * 0.3),
				c + Vector2(s * 0.12, s * 0.1), c + Vector2(-s * 0.12, s * 0.1)]), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.05, s * 0.1), Vector2(s * 0.1, s * 0.14)), color)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, s * 0.24), Vector2(s * 0.4, s * 0.08)), color)
		"close":
			ci.draw_line(c + Vector2(-s * 0.22, -s * 0.22), c + Vector2(s * 0.22, s * 0.22), color, s * 0.09)
			ci.draw_line(c + Vector2(s * 0.22, -s * 0.22), c + Vector2(-s * 0.22, s * 0.22), color, s * 0.09)
		"menu":
			for i in 3:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.26, -s * 0.22 + float(i) * s * 0.18), Vector2(s * 0.52, s * 0.08)), color)
		"map":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.32, -s * 0.22), c + Vector2(-s * 0.1, -s * 0.3),
				c + Vector2(s * 0.12, -s * 0.2), c + Vector2(s * 0.32, -s * 0.28),
				c + Vector2(s * 0.32, s * 0.24), c + Vector2(s * 0.1, s * 0.32),
				c + Vector2(-s * 0.12, s * 0.2), c + Vector2(-s * 0.32, s * 0.28)]), color)
		"drive":
			_draw_car(ci, c, s, color)
		_:
			ci.draw_circle(c, s * 0.3, color)


static func _arrow(c: Vector2, s: float, dir: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(dir * s * 0.28, 0),
		c + Vector2(-dir * s * 0.1, -s * 0.3),
		c + Vector2(-dir * s * 0.1, -s * 0.1),
		c + Vector2(-dir * s * 0.3, -s * 0.1),
		c + Vector2(-dir * s * 0.3, s * 0.1),
		c + Vector2(-dir * s * 0.1, s * 0.1),
		c + Vector2(-dir * s * 0.1, s * 0.3)])


static func _draw_wrench(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var a := c + Vector2(-s * 0.26, s * 0.24)
	var b := c + Vector2(s * 0.18, -s * 0.14)
	ci.draw_line(a, b, color, s * 0.13)
	ci.draw_arc(c + Vector2(s * 0.24, -s * 0.24), s * 0.16, PI * 1.1, PI * 2.2, 14, color, s * 0.1)
	ci.draw_circle(a, s * 0.09, color)


static func _draw_drop(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s * 0.34),
		c + Vector2(s * 0.22, s * 0.02),
		c + Vector2(s * 0.12, s * 0.26),
		c + Vector2(-s * 0.12, s * 0.26),
		c + Vector2(-s * 0.22, s * 0.02)]), color)
	ci.draw_circle(c + Vector2(-s * 0.04, s * 0.06), s * 0.06, Color(1, 1, 1, 0.55))


static func _draw_star(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + TAU * float(i) / 10.0
		var r: float = s * (0.34 if i % 2 == 0 else 0.16)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, color)


static func _draw_car(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.02), Vector2(s * 0.68, s * 0.2)), color)
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-s * 0.18, -s * 0.02), c + Vector2(-s * 0.08, -s * 0.22),
		c + Vector2(s * 0.12, -s * 0.22), c + Vector2(s * 0.22, -s * 0.02)]), color)
	ci.draw_circle(c + Vector2(-s * 0.19, s * 0.2), s * 0.1, color.darkened(0.45))
	ci.draw_circle(c + Vector2(s * 0.19, s * 0.2), s * 0.1, color.darkened(0.45))


static func _draw_tractor(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.16), Vector2(s * 0.4, s * 0.24)), color)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.3), Vector2(s * 0.24, s * 0.18)), color.darkened(0.15))
	ci.draw_circle(c + Vector2(-s * 0.2, s * 0.16), s * 0.16, color.darkened(0.4))
	ci.draw_circle(c + Vector2(s * 0.18, s * 0.2), s * 0.1, color.darkened(0.4))
	ci.draw_rect(Rect2(c + Vector2(s * 0.1, -s * 0.22), Vector2(s * 0.05, s * 0.12)), color)
