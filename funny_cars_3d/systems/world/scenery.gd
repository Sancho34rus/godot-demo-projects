class_name Scenery
extends RefCounted

## Procedural scenery kit: every building, tree, road and prop of the five
## territories is composed here from rounded primitives and the shared
## material library. Nothing is a bare cube: each object is a small assembly.

static var _meshes: Dictionary = {}


# ------------------------------------------------------------ primitives ---
static func _mesh(key: String, maker: Callable) -> Mesh:
	if not _meshes.has(key):
		_meshes[key] = maker.call()
	return _meshes[key]


static func rbox(size: Vector3, radius: float = 0.12) -> Mesh:
	var key := "rb_%.2f_%.2f_%.2f_%.2f" % [size.x, size.y, size.z, radius]
	return _mesh(key, func() -> Mesh: return MeshGen.rounded_box(size, minf(radius, minf(size.x, minf(size.y, size.z)) * 0.45), 2))


static func cyl(r_top: float, r_bot: float, h: float, seg: int = 14) -> Mesh:
	var key := "cy_%.3f_%.3f_%.3f_%d" % [r_top, r_bot, h, seg]
	return _mesh(key, func() -> Mesh: return MeshGen.cylinder(r_top, r_bot, h, seg, true))


static func ball(r: Vector3, seg: int = 14) -> Mesh:
	var key := "ba_%.2f_%.2f_%.2f_%d" % [r.x, r.y, r.z, seg]
	return _mesh(key, func() -> Mesh: return MeshGen.sphere(r, maxi(seg / 2, 5), seg))


static func part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


static func solid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, surface: String = "concrete", rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	body.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)
	part(body, rbox(size, minf(size.x, size.y) * 0.1), mat)
	return body


static func collider_only(parent: Node3D, size: Vector3, pos: Vector3, surface: String = "concrete", rot_y: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rot_y
	body.set_meta("surface", surface)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	parent.add_child(body)
	return body


static func root(parent: Node3D, name_: String, pos: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = pos
	n.rotation.y = yaw
	parent.add_child(n)
	return n


# ---------------------------------------------------------------- roads ---
static func road(parent: Node3D, a: Vector3, b: Vector3, width: float = 7.0, kind: String = "asphalt", marks: bool = true) -> Node3D:
	var d := b - a
	var length := d.length()
	var yaw := atan2(-d.x, -d.z)
	var r := root(parent, "Road", (a + b) * 0.5 + Vector3(0, 0.04, 0), yaw)
	var mat: Material = MatLib.ground(kind)
	solid(r, Vector3(width, 0.1, length), Vector3.ZERO, mat, kind)
	if marks and kind == "asphalt":
		var steps := int(length / 3.2)
		for i in steps:
			var z := -length * 0.5 + 1.6 + float(i) * 3.2
			part(r, rbox(Vector3(0.14, 0.02, 1.6), 0.02), MatLib.road_mark(), Vector3(0, 0.06, z))
		part(r, rbox(Vector3(0.12, 0.02, length - 1.0), 0.02), MatLib.road_mark(), Vector3(-width * 0.5 + 0.5, 0.06, 0))
		part(r, rbox(Vector3(0.12, 0.02, length - 1.0), 0.02), MatLib.road_mark(), Vector3(width * 0.5 - 0.5, 0.06, 0))
	return r


static func sidewalk(parent: Node3D, a: Vector3, b: Vector3, width: float = 2.4) -> void:
	var d := b - a
	var yaw := atan2(-d.x, -d.z)
	var r := root(parent, "Walk", (a + b) * 0.5 + Vector3(0, 0.1, 0), yaw)
	solid(r, Vector3(width, 0.16, d.length()), Vector3.ZERO, MatLib.ground("concrete"), "concrete")


# ------------------------------------------------------------ buildings ---
static func house(parent: Node3D, pos: Vector3, yaw: float, wall: Color, roof_c: Color, size: Vector3 = Vector3(6.0, 3.2, 5.0)) -> Node3D:
	var r := root(parent, "House", pos, yaw)
	solid(r, Vector3(size.x, size.y, size.z), Vector3(0, size.y * 0.5, 0), MatLib.wall(wall), "concrete")
	# gable roof: triangle profile extruded along depth
	var prof := PackedVector2Array([Vector2(-size.x * 0.62, 0), Vector2(size.x * 0.62, 0), Vector2(0, size.x * 0.42)])
	var roof_mesh := MeshGen.extrude_profile(prof, size.z + 0.5, 4, 1.0)
	part(r, roof_mesh, MatLib.roof(roof_c), Vector3(0, size.y, 0), Vector3(0, 0, 0))
	part(r, cyl(0.28, 0.28, 1.6), MatLib.wall(Color(0.7, 0.4, 0.32)), Vector3(size.x * 0.28, size.y + 1.4, -size.z * 0.2))
	# front windows and door
	for i in [-1, 1]:
		part(r, rbox(Vector3(1.2, 1.1, 0.12), 0.05), MatLib.window_lit(), Vector3(i * size.x * 0.27, size.y * 0.5 + 0.15, size.z * 0.5 + 0.02))
		part(r, rbox(Vector3(1.4, 0.12, 0.3), 0.04), MatLib.wood(Color(0.95, 0.94, 0.9)), Vector3(i * size.x * 0.27, size.y * 0.5 - 0.5, size.z * 0.5 + 0.06))
	part(r, rbox(Vector3(1.1, 2.0, 0.14), 0.06), MatLib.wood(Color(0.55, 0.36, 0.22)), Vector3(0, 1.0, size.z * 0.5 + 0.03))
	part(r, ball(Vector3(0.08, 0.08, 0.08), 8), MatLib.chrome(), Vector3(0.36, 1.0, size.z * 0.5 + 0.12))
	# porch and steps
	part(r, rbox(Vector3(2.2, 0.14, 1.1), 0.05), MatLib.wall(Color(0.9, 0.88, 0.8)), Vector3(0, 0.15, size.z * 0.5 + 0.5))
	# flower box
	part(r, rbox(Vector3(1.3, 0.22, 0.3), 0.05), MatLib.wood(Color(0.5, 0.33, 0.2)), Vector3(size.x * 0.27, size.y * 0.5 - 0.15, size.z * 0.5 + 0.2))
	for i in 5:
		part(r, ball(Vector3(0.14, 0.14, 0.14), 8), MatLib.flower([Color(1, 0.4, 0.5), Color(1, 0.85, 0.2), Color(0.95, 0.5, 0.9)][i % 3]), Vector3(size.x * 0.27 - 0.5 + i * 0.25, size.y * 0.5 - 0.02, size.z * 0.5 + 0.22))
	return r


static func shop(parent: Node3D, pos: Vector3, yaw: float, wall: Color, awning: Color, title: String) -> Node3D:
	var r := house(parent, pos, yaw, wall, Color(0.4, 0.35, 0.33), Vector3(7.0, 3.6, 5.0))
	part(r, rbox(Vector3(6.4, 0.3, 1.4), 0.1), MatLib.plastic(awning), Vector3(0, 2.4, 3.0), Vector3(-12, 0, 0))
	for i in 4:
		part(r, rbox(Vector3(0.9, 1.2, 0.12), 0.05), MatLib.window_lit(), Vector3(-2.6 + i * 1.7, 1.2, 2.52))
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.outline_size = 12
	sign.modulate = Color(1, 1, 1)
	sign.outline_modulate = awning.darkened(0.3)
	sign.position = Vector3(0, 3.9, 2.7)
	r.add_child(sign)
	return r


static func barn(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "Barn", pos, yaw)
	solid(r, Vector3(7.0, 4.6, 9.0), Vector3(0, 2.3, 0), MatLib.wood(Color(0.78, 0.2, 0.18)), "concrete")
	var prof := PackedVector2Array([Vector2(-4.2, 0), Vector2(4.2, 0), Vector2(0, 3.2)])
	part(r, MeshGen.extrude_profile(prof, 9.4, 4, 1.0), MatLib.roof(Color(0.35, 0.3, 0.28)), Vector3(0, 4.6, 0))
	part(r, rbox(Vector3(3.6, 3.4, 0.14), 0.05), MatLib.wood(Color(0.7, 0.18, 0.16)), Vector3(0, 1.7, 4.55))
	part(r, rbox(Vector3(3.6, 0.12, 0.2), 0.04), MatLib.wood(Color(0.95, 0.94, 0.88)), Vector3(0, 3.5, 4.6))
	part(r, rbox(Vector3(0.2, 3.4, 0.2), 0.04), MatLib.wood(Color(0.95, 0.94, 0.88)), Vector3(0, 1.7, 4.62))
	part(r, rbox(Vector3(1.0, 1.0, 0.1), 0.02), MatLib.wood(Color(0.92, 0.9, 0.8)), Vector3(0, 6.6, 4.5))
	return r


static func silo(parent: Node3D, pos: Vector3) -> Node3D:
	var r := root(parent, "Silo", pos)
	solid(r, Vector3(3.0, 9.0, 3.0), Vector3(0, 4.5, 0), MatLib.steel(), "concrete")
	part(r, cyl(1.5, 1.5, 9.0, 20), MatLib.wall(Color(0.86, 0.86, 0.82)), Vector3(0, 4.5, 0))
	part(r, cyl(0.02, 1.7, 2.0, 20), MatLib.roof(Color(0.5, 0.5, 0.52)), Vector3(0, 10.0, 0))
	for i in 6:
		part(r, rbox(Vector3(0.15, 0.25, 0.1), 0.02), MatLib.road_mark(), Vector3(0, 2 + i * 1.2, 1.55))
	return r


static func hay_bale(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var r := root(parent, "Hay", pos, yaw)
	var m := MatLib.wood(Color(0.92, 0.75, 0.32))
	solid(r, Vector3(1.4, 1.0, 1.0), Vector3(0, 0.5, 0), m, "grass")
	part(r, cyl(0.5, 0.5, 1.4, 16), m, Vector3(0, 0.5, 0), Vector3(90, 0, 0))
	part(r, rbox(Vector3(1.42, 0.04, 0.5), 0.02), MatLib.wood(Color(0.6, 0.44, 0.2)), Vector3(0, 0.52, 0))
	return r


static func fence(parent: Node3D, a: Vector3, b: Vector3, color: Color = Color(0.96, 0.94, 0.9)) -> void:
	var d := b - a
	var n := maxi(int(d.length() / 1.6), 1)
	var yaw := atan2(-d.x, -d.z)
	var r := root(parent, "Fence", a, yaw)
	var len := d.length()
	for i in n + 1:
		var z := -len * float(i) / float(n)
		part(r, rbox(Vector3(0.12, 1.0, 0.12), 0.04), MatLib.wood(color), Vector3(0, 0.5, z))
	for h in [0.35, 0.7]:
		part(r, rbox(Vector3(0.08, 0.09, len), 0.02), MatLib.wood(color), Vector3(0, h, -len * 0.5))


# -------------------------------------------------------------- nature ---
static func tree_round(parent: Node3D, pos: Vector3, s: float = 1.0, leaf: Color = Color(0.36, 0.7, 0.3)) -> Node3D:
	var r := root(parent, "Tree", pos)
	r.rotation.y = randf() * TAU
	part(r, cyl(0.22 * s, 0.32 * s, 2.4 * s, 10), MatLib.bark(), Vector3(0, 1.2 * s, 0))
	var fol := MatLib.foliage(leaf, 0.12, 4.0 * s)
	part(r, ball(Vector3(2.0 * s, 1.8 * s, 2.0 * s), 14), fol, Vector3(0, 3.4 * s, 0))
	part(r, ball(Vector3(1.4 * s, 1.3 * s, 1.4 * s), 12), fol, Vector3(0.9 * s, 4.5 * s, 0.4 * s))
	part(r, ball(Vector3(1.3 * s, 1.2 * s, 1.3 * s), 12), fol, Vector3(-0.8 * s, 4.2 * s, -0.5 * s))
	solid_collider_cyl(r, 0.3 * s, 2.4 * s)
	return r


static func tree_pine(parent: Node3D, pos: Vector3, s: float = 1.0) -> Node3D:
	var r := root(parent, "Pine", pos)
	r.rotation.y = randf() * TAU
	part(r, cyl(0.18 * s, 0.26 * s, 1.8 * s, 10), MatLib.bark(), Vector3(0, 0.9 * s, 0))
	var fol := MatLib.foliage(Color(0.2, 0.52, 0.3), 0.08, 5.0 * s)
	for i in 3:
		var rad := (2.0 - i * 0.5) * s
		part(r, cyl(0.0, rad, 1.6 * s, 12), fol, Vector3(0, (2.2 + i * 1.1) * s, 0))
	solid_collider_cyl(r, 0.3 * s, 2.0 * s)
	return r


static func tree_fruit(parent: Node3D, pos: Vector3, fruit: Color) -> Node3D:
	var r := tree_round(parent, pos, 0.85, Color(0.42, 0.74, 0.32))
	for i in 9:
		var a := TAU * float(i) / 9.0
		part(r, ball(Vector3(0.18, 0.18, 0.18), 8), MatLib.plastic(fruit), Vector3(cos(a) * 1.4, 3.2 + (i % 3) * 0.4, sin(a) * 1.3))
	return r


static func solid_collider_cyl(parent: Node3D, radius: float, height: float) -> void:
	var body := StaticBody3D.new()
	body.set_meta("surface", "wood")
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = radius
	cy.height = height
	cs.shape = cy
	cs.position = Vector3(0, height * 0.5, 0)
	body.add_child(cs)
	parent.add_child(body)


static func bush(parent: Node3D, pos: Vector3, s: float = 1.0, leaf: Color = Color(0.3, 0.62, 0.3)) -> Node3D:
	var r := root(parent, "Bush", pos)
	var fol := MatLib.foliage(leaf, 0.14, 1.2 * s)
	part(r, ball(Vector3(0.9 * s, 0.7 * s, 0.9 * s), 10), fol, Vector3(0, 0.6 * s, 0))
	part(r, ball(Vector3(0.6 * s, 0.55 * s, 0.6 * s), 8), fol, Vector3(0.6 * s, 0.5 * s, 0.3 * s))
	return r


static func flower_patch(parent: Node3D, center: Vector3, radius: float, count: int = 14) -> void:
	var r := root(parent, "Flowers", center)
	var cols := [Color(1, 0.45, 0.6), Color(1, 0.85, 0.2), Color(0.7, 0.5, 1.0), Color(1, 1, 1)]
	for i in count:
		var a := randf() * TAU
		var d := randf() * radius
		var p := Vector3(cos(a) * d, 0.0, sin(a) * d)
		part(r, cyl(0.02, 0.02, 0.35, 4), MatLib.foliage(Color(0.3, 0.6, 0.25), 0.2, 0.4), p + Vector3(0, 0.17, 0))
		part(r, ball(Vector3(0.12, 0.12, 0.12), 6), MatLib.flower(cols[i % cols.size()]), p + Vector3(0, 0.4, 0))


# ---------------------------------------------------------- city props ---
static func lamp(parent: Node3D, pos: Vector3) -> void:
	var r := root(parent, "Lamp", pos)
	part(r, cyl(0.1, 0.14, 4.2, 10), MatLib.steel(), Vector3(0, 2.1, 0))
	part(r, rbox(Vector3(0.9, 0.12, 0.3), 0.05), MatLib.steel(), Vector3(0.4, 4.1, 0))
	part(r, ball(Vector3(0.28, 0.14, 0.28), 10), MatLib.lamp_on(), Vector3(0.8, 4.0, 0))
	solid_collider_cyl(r, 0.2, 4.2)


static func traffic_light(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "TrafficLight", pos, yaw)
	part(r, cyl(0.12, 0.15, 4.0, 10), MatLib.steel(), Vector3(0, 2.0, 0))
	part(r, rbox(Vector3(0.7, 1.7, 0.6), 0.14), MatLib.plastic(Color(0.12, 0.14, 0.16)), Vector3(0, 3.5, 0))
	var colors := [Color(1, 0.2, 0.18), Color(1, 0.82, 0.2), Color(0.3, 1, 0.45)]
	var lights: Array = []
	for i in 3:
		var lm := MatLib.emissive(colors[i], 0.15)
		var n := part(r, ball(Vector3(0.22, 0.22, 0.12), 8), lm, Vector3(0, 3.9 - i * 0.5, 0.3))
		lights.append(n)
	r.set_meta("lights", lights)
	r.add_to_group("traffic_light")
	solid_collider_cyl(r, 0.2, 4.0)
	return r


static func sign(parent: Node3D, pos: Vector3, yaw: float, kind: String) -> Node3D:
	var r := root(parent, "Sign", pos, yaw)
	part(r, cyl(0.05, 0.06, 2.4, 8), MatLib.steel(), Vector3(0, 1.2, 0))
	match kind:
		"stop":
			part(r, cyl(0.6, 0.6, 0.08, 8), MatLib.plastic(Color(0.9, 0.12, 0.12)), Vector3(0, 2.6, 0.06), Vector3(90, 22.5, 0))
			part(r, rbox(Vector3(0.7, 0.14, 0.02), 0.01), MatLib.plastic(Color(1, 1, 1)), Vector3(0, 2.6, 0.12))
		"speed":
			part(r, cyl(0.6, 0.6, 0.05, 20), MatLib.plastic(Color(1, 1, 1)), Vector3(0, 2.6, 0.05), Vector3(90, 0, 0))
			part(r, cyl(0.52, 0.52, 0.06, 20), MatLib.plastic(Color(0.92, 0.12, 0.12)), Vector3(0, 2.6, 0.06), Vector3(90, 0, 0))
			var l := Label3D.new()
			l.text = "30"
			l.font_size = 80
			l.pixel_size = 0.01
			l.position = Vector3(0, 2.6, 0.12)
			l.modulate = Color(0.1, 0.1, 0.12)
			r.add_child(l)
		"park", "info", "gas", "bump", "turn", "parking":
			var col := Color(0.2, 0.5, 0.95)
			if kind == "bump":
				col = Color(1.0, 0.7, 0.1)
			part(r, rbox(Vector3(1.0, 0.9, 0.07), 0.05), MatLib.plastic(col), Vector3(0, 2.5, 0.05))
			part(r, rbox(Vector3(0.6, 0.5, 0.02), 0.04), MatLib.plastic(Color(1, 1, 1)), Vector3(0, 2.5, 0.1))
			var ic := Label3D.new()
			ic.text = {"park": "P", "info": "i", "gas": "⛽", "bump": "~", "turn": "→", "parking": "P"}[kind]
			ic.font_size = 90
			ic.pixel_size = 0.01
			ic.position = Vector3(0, 2.5, 0.12)
			ic.modulate = Color(0.1, 0.1, 0.12) if kind != "park" and kind != "info" else Color(1, 1, 1)
			r.add_child(ic)
	return r


static func gas_station(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var r := root(parent, "GasStation", pos, yaw)
	solid(r, Vector3(9.0, 0.3, 10.0), Vector3(0, 0.15, 0), MatLib.ground("concrete"), "concrete")
	part(r, rbox(Vector3(2.8, 3.0, 5.0), 0.1), MatLib.wall(Color(0.97, 0.94, 0.86)), Vector3(0, 1.8, -2.0))
	part(r, rbox(Vector3(11.0, 0.4, 0.6), 0.1), MatLib.plastic(Color(0.9, 0.2, 0.2)), Vector3(0, 4.9, 1.6))
	part(r, rbox(Vector3(9.0, 0.5, 6.4), 0.12), MatLib.plastic(Color(0.92, 0.22, 0.2)), Vector3(0, 4.9, 0.0))
	for i in [-1, 1]:
		part(r, cyl(0.16, 0.16, 4.8, 8), MatLib.steel(), Vector3(i * 4.0, 2.4, 0.0))
		part(r, rbox(Vector3(1.5, 0.9, 0.6), 0.2), MatLib.plastic(Color(0.25, 0.6, 0.95)), Vector3(i * 2.6, 1.2, 1.0))
		part(r, cyl(0.12, 0.12, 0.3, 8), MatLib.plastic(Color(0.15, 0.15, 0.15)), Vector3(i * 2.6 + 0.6, 1.3, 1.4))
	var sign_l := Label3D.new()
	sign_l.text = "ЗАПРАВКА"
	sign_l.font_size = 80
	sign_l.pixel_size = 0.012
	sign_l.position = Vector3(0, 4.9, 2.0)
	r.add_child(sign_l)
	return r


static func playground(parent: Node3D, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var r := root(parent, "Playground", pos, yaw)
	solid(r, Vector3(14.0, 0.1, 10.0), Vector3(0, 0.05, 0), MatLib.ground("sand"), "sand")
	# slide
	part(r, rbox(Vector3(0.2, 3.0, 0.3), 0.04), MatLib.plastic(Color(0.95, 0.4, 0.2)), Vector3(-3.2, 1.5, 3.0))
	part(r, rbox(Vector3(1.0, 0.1, 3.6), 0.02), MatLib.plastic(Color(0.3, 0.8, 0.9)), Vector3(-2.2, 1.6, 0.2), Vector3(0, 0, -20))
	part(r, rbox(Vector3(1.0, 1.6, 0.14), 0.04), MatLib.plastic(Color(0.95, 0.85, 0.2)), Vector3(-2.7, 1.6, 0.0))
	for i in 3:
		part(r, cyl(0.08, 0.08, 0.1, 8), MatLib.plastic(Color(0.9, 0.5, 0.2)), Vector3(-3.2, 0.3 + i * 0.2 * 2.0, 0.6 + i * 0.2 * 1.6), Vector3(0, 0, 0))
	part(r, rbox(Vector3(4.0, 0.12, 1.2), 0.05), MatLib.plastic(Color(0.9, 0.6, 0.3)), Vector3(-2.2, 2.5, 0.0))
	# swing frame
	for x in [-1.8, 1.8]:
		part(r, cyl(0.07, 0.07, 3.0, 8), MatLib.steel(), Vector3(x + 4.0, 1.5, -2.6))
	part(r, cyl(0.07, 0.07, 3.6, 8), MatLib.steel(), Vector3(4.0, 2.9, -2.6), Vector3(0, 0, 90))
	for x in [-0.8, 0.8]:
		part(r, cyl(0.02, 0.02, 1.8, 4), MatLib.steel(), Vector3(x + 4.0, 2.0, -2.6))
		part(r, rbox(Vector3(0.5, 0.1, 0.25), 0.04), MatLib.plastic(Color(0.2, 0.5, 0.95)), Vector3(x + 4.0, 1.1, -2.6))
	# seesaw
	part(r, rbox(Vector3(3.2, 0.12, 0.4), 0.05), MatLib.plastic(Color(0.3, 0.75, 0.4)), Vector3(-4.5, 0.6, -3.0), Vector3(0, 0, 8))
	part(r, cyl(0.25, 0.3, 0.5, 8), MatLib.steel(), Vector3(-4.5, 0.25, -3.0))
	# climbing dome
	part(r, MeshGen.torus(1.2, 0.07, 20, 8), MatLib.plastic(Color(0.95, 0.3, 0.45)), Vector3(4.0, 0.9, 2.8), Vector3(90, 0, 0))
	for i in 6:
		var a := TAU * float(i) / 6.0
		part(r, ball(Vector3(0.14, 0.14, 0.14), 6), MatLib.plastic(Color(0.3 + 0.1 * i, 0.8, 1.0)), Vector3(4.0 + cos(a) * 1.2, 0.8, 2.8 + sin(a) * 1.2))
	return r


static func tunnel(parent: Node3D, pos: Vector3, yaw: float, width: float = 7.4, height: float = 5.0, length: float = 14.0) -> Node3D:
	var r := root(parent, "Tunnel", pos, yaw)
	var wall := MatLib.wall(Color(0.72, 0.7, 0.66))
	part(r, rbox(Vector3(1.2, height, length), 0.1), wall, Vector3(-width * 0.5 - 0.6, height * 0.5, 0))
	part(r, rbox(Vector3(1.2, height, length), 0.1), wall, Vector3(width * 0.5 + 0.6, height * 0.5, 0))
	part(r, rbox(Vector3(width + 2.4, 1.2, length), 0.1), MatLib.wall(Color(0.62, 0.6, 0.58)), Vector3(0, height + 0.6, 0))
	# portals
	for z in [-length * 0.5 - 0.1, length * 0.5 + 0.1]:
		part(r, rbox(Vector3(width + 3.4, 1.0, 0.5), 0.1), MatLib.plastic(Color(0.95, 0.35, 0.25)), Vector3(0, height + 1.9, z))
		part(r, rbox(Vector3(width + 2.2, 1.0, 0.25), 0.1), MatLib.plastic(Color(0.98, 0.82, 0.25)), Vector3(0, height + 2.8, z))
	var l := root(r, "Lights", Vector3.ZERO)
	for i in 5:
		part(l, ball(Vector3(0.22, 0.12, 0.22), 6), MatLib.lamp_on(), Vector3(0, height - 0.1, -length * 0.5 + 1.5 + i * (length - 3.0) / 4.0))
	collider_only(r, Vector3(1.2, height, length), Vector3(-width * 0.5 - 0.6, height * 0.5, 0), "concrete")
	collider_only(r, Vector3(1.2, height, length), Vector3(width * 0.5 + 0.6, height * 0.5, 0), "concrete")
	collider_only(r, Vector3(width + 2.4, 1.2, length), Vector3(0, height + 0.6, 0), "concrete")
	return r


static func bridge(parent: Node3D, a: Vector3, b: Vector3, width: float = 8.0, rise: float = 1.2) -> Node3D:
	var d := b - a
	var length := d.length()
	var yaw := atan2(-d.x, -d.z)
	var r := root(parent, "Bridge", (a + b) * 0.5 + Vector3(0, rise * 0.5, 0), yaw)
	var deck := MatLib.ground("concrete")
	var body := collider_only(r, Vector3(width, 0.5, length), Vector3(0, 0.0, 0), "concrete")
	part(r, rbox(Vector3(width, 0.5, length), 0.08), deck, Vector3(0, 0.0, 0))
	part(r, rbox(Vector3(width + 0.6, 0.25, length + 0.6), 0.05), MatLib.wall(Color(0.85, 0.82, 0.76)), Vector3(0, -0.36, 0))
	for z in [-length * 0.5, length * 0.5]:
		for s in [-1, 1]:
			part(r, rbox(Vector3(0.8, rise + 2.2, 1.4), 0.1), MatLib.wall(Color(0.88, 0.86, 0.8)), Vector3(s * (width * 0.5 - 0.3), -(rise + 2.2) * 0.5 + 0.5, z))
	for s in [-1, 1]:
		part(r, rbox(Vector3(0.18, 1.0, length), 0.04), MatLib.plastic(Color(0.95, 0.4, 0.3)), Vector3(s * (width * 0.5), 0.7, 0))
		var n := int(length / 1.5)
		for i in n:
			part(r, cyl(0.05, 0.05, 0.9, 6), MatLib.plastic(Color(0.95, 0.4, 0.3)), Vector3(s * width * 0.5, 0.5, -length * 0.5 + 0.7 + i * 1.5))
	# arch-like supports under the deck
	var arch := MeshGen.torus(width * 0.42, 0.22, 24, 8)
	part(r, arch, MatLib.wall(Color(0.85, 0.8, 0.72)), Vector3(0, -0.6, 0), Vector3(90, 0, 0), Vector3(1, 1, 0.3))
	body.set_meta("surface", "concrete")
	return r


static func crane_tower(parent: Node3D, pos: Vector3, height: float = 22.0, yaw: float = 0.0) -> Node3D:
	var r := root(parent, "TowerCrane", pos, yaw)
	var steel := MatLib.plastic(Color(0.98, 0.72, 0.12))
	solid(r, Vector3(3.0, 0.6, 3.0), Vector3(0, 0.3, 0), MatLib.steel(), "concrete")
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		part(r, cyl(0.1, 0.1, height, 6), steel, Vector3(cos(a) * 0.9, height * 0.5, sin(a) * 0.9))
	for h in range(1, int(height / 2.0) + 1):
		var y := float(h) * 2.0
		part(r, rbox(Vector3(1.9, 0.12, 0.12), 0.02), steel, Vector3(0, y, 0.9))
		part(r, rbox(Vector3(1.9, 0.12, 0.12), 0.02), steel, Vector3(0, y, -0.9))
		part(r, rbox(Vector3(0.12, 0.12, 1.9), 0.02), steel, Vector3(0.9, y, 0))
		part(r, rbox(Vector3(0.12, 0.12, 1.9), 0.02), steel, Vector3(-0.9, y, 0))
	part(r, rbox(Vector3(1.6, 1.4, 1.6), 0.15), MatLib.plastic(Color(0.25, 0.55, 0.9)), Vector3(0, height + 0.6, -1.4))
	part(r, rbox(Vector3(0.2, 0.2, 0.2), 0.05), MatLib.lamp_on(), Vector3(0, height + 1.4, -1.4))
	var jib := root(r, "Jib", Vector3(0, height + 1.2, 0), 0.0)
	part(jib, rbox(Vector3(1.2, 1.0, 22.0), 0.12), steel, Vector3(0, 0, 9.5))
	part(jib, rbox(Vector3(1.0, 1.0, 7.0), 0.1), steel, Vector3(0, 0, -6.0))
	part(jib, rbox(Vector3(0.4, 0.4, 3.0), 0.05), MatLib.plastic(Color(0.2, 0.2, 0.2)), Vector3(0, 0.8, -8.5))
	part(jib, rbox(Vector3(2.0, 0.6, 1.8), 0.12), MatLib.plastic(Color(0.9, 0.2, 0.2)), Vector3(0, -0.6, -9.0))
	part(jib, cyl(0.03, 0.03, 0.1, 4), MatLib.steel(), Vector3(0, 0, 0))
	var cable := root(jib, "Cable", Vector3(0, -0.5, 14.0))
	part(cable, cyl(0.03, 0.03, 9.0, 4), MatLib.steel(), Vector3(0, -4.5, 0))
	var hook := root(cable, "Hook", Vector3(0, -9.0, 0))
	part(hook, MeshGen.torus(0.3, 0.05, 12, 6), MatLib.steel(), Vector3(0, 0, 0), Vector3(90, 0, 0))
	r.set_meta("jib", jib)
	r.set_meta("hook", hook)
	r.set_meta("cable", cable)
	return r


static func warehouse(parent: Node3D, pos: Vector3, yaw: float, color: Color) -> Node3D:
	var r := root(parent, "Warehouse", pos, yaw)
	solid(r, Vector3(16.0, 6.0, 12.0), Vector3(0, 3.0, 0), MatLib.wall(color), "concrete")
	var prof := PackedVector2Array([Vector2(-8.4, 0), Vector2(8.4, 0), Vector2(0, 2.6)])
	part(r, MeshGen.extrude_profile(prof, 12.6, 4, 1.0), MatLib.roof(Color(0.45, 0.46, 0.5)), Vector3(0, 6.0, 0))
	for i in 3:
		part(r, rbox(Vector3(3.6, 4.0, 0.12), 0.04), MatLib.plastic(Color(0.9, 0.9, 0.9)), Vector3(-4.8 + i * 4.8, 2.0, 6.06))
	for i in 4:
		part(r, rbox(Vector3(1.6, 1.4, 0.14), 0.05), MatLib.window_lit(), Vector3(-6.0 + i * 4.0, 4.2, 6.06))
	return r


static func crate(parent: Node3D, pos: Vector3, color: Color, yaw: float = 0.0, size: float = 1.0) -> Node3D:
	var r := root(parent, "Crate", pos, yaw)
	solid(r, Vector3(size, size, size), Vector3(0, size * 0.5, 0), MatLib.wood(color), "wood")
	part(r, rbox(Vector3(size * 1.04, 0.1 * size, size * 1.04), 0.02), MatLib.wood(color.darkened(0.25)), Vector3(0, size * 0.5, 0))
	return r


static func barrel(parent: Node3D, pos: Vector3, color: Color) -> void:
	var r := root(parent, "Barrel", pos)
	part(r, cyl(0.42, 0.42, 1.0, 14), MatLib.plastic(color), Vector3(0, 0.5, 0))
	part(r, MeshGen.torus(0.42, 0.03, 14, 4), MatLib.steel(), Vector3(0, 0.25, 0), Vector3(90, 0, 0))
	part(r, MeshGen.torus(0.42, 0.03, 14, 4), MatLib.steel(), Vector3(0, 0.75, 0), Vector3(90, 0, 0))


static func sand_pile(parent: Node3D, pos: Vector3, size: float = 3.0) -> Node3D:
	var r := root(parent, "SandPile", pos)
	part(r, ball(Vector3(size, size * 0.45, size), 16), MatLib.ground("sand"), Vector3(0, size * 0.22, 0))
	return r


static func lake(parent: Node3D, pos: Vector3, radius: float, depth: float = 0.6) -> Node3D:
	var r := root(parent, "Lake", pos)
	var disc := MeshGen.cylinder(radius, radius, 0.05, 40, true)
	part(r, disc, MatLib.water(), Vector3(0, 0.0, 0))
	return r


static func river(parent: Node3D, pts: Array, width: float) -> Node3D:
	var r := root(parent, "River", Vector3.ZERO)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var d := b - a
		var mid := (a + b) * 0.5
		var seg := root(r, "Seg", Vector3(mid.x, mid.y, mid.z), atan2(-d.x, -d.z))
		part(seg, rbox(Vector3(width, 0.05, d.length() + 0.2), 0.01), MatLib.water(), Vector3(0, 0.0, 0))
	return r


static func animal(parent: Node3D, kind: String, pos: Vector3, yaw: float = 0.0) -> Node3D:
	var r := root(parent, kind.capitalize(), pos, yaw)
	match kind:
		"cow":
			var b := MatLib.animal(Color(0.97, 0.96, 0.92))
			part(r, rbox(Vector3(1.4, 0.95, 2.2), 0.4), b, Vector3(0, 1.1, 0))
			part(r, ball(Vector3(0.4, 0.4, 0.4), 10), MatLib.animal(Color(0.1, 0.1, 0.1)), Vector3(0.3, 1.4, -0.7))
			part(r, rbox(Vector3(0.7, 0.55, 0.7), 0.2), b, Vector3(0, 1.4, -1.2))
			part(r, rbox(Vector3(0.6, 0.3, 0.4), 0.1), MatLib.animal(Color(1, 0.7, 0.75)), Vector3(0, 1.1, -1.6))
			for lx in [-0.45, 0.45]:
				for lz in [-0.75, 0.75]:
					part(r, cyl(0.12, 0.1, 0.9, 8), b, Vector3(lx, 0.45, lz))
			part(r, cyl(0.04, 0.04, 0.8, 4), b, Vector3(0, 1.3, 1.25), Vector3(-30, 0, 0))
			for hx in [-0.2, 0.2]:
				part(r, cyl(0.2, 0.05, 0.4, 6), MatLib.animal(Color(0.9, 0.85, 0.7)), Vector3(hx, 1.8, -1.2), Vector3(0, 0, 0))
		"pig":
			var b2 := MatLib.animal(Color(1.0, 0.7, 0.72))
			part(r, ball(Vector3(0.75, 0.6, 1.0), 14), b2, Vector3(0, 0.7, 0))
			part(r, ball(Vector3(0.52, 0.48, 0.5), 12), b2, Vector3(0, 0.9, -1.0))
			part(r, cyl(0.12, 0.12, 0.14, 8), MatLib.animal(Color(1, 0.55, 0.6)), Vector3(0, 0.9, -1.5), Vector3(90, 0, 0))
			for lx in [-0.4, 0.4]:
				for lz in [-0.5, 0.5]:
					part(r, cyl(0.12, 0.1, 0.5, 8), b2, Vector3(lx, 0.25, lz))
		"sheep":
			var w := MatLib.animal(Color(0.98, 0.98, 0.96))
			for i in 6:
				var a := TAU * float(i) / 6.0
				part(r, ball(Vector3(0.42, 0.42, 0.42), 10), w, Vector3(cos(a) * 0.4, 0.9, sin(a) * 0.5))
			part(r, ball(Vector3(0.45, 0.45, 0.45), 10), w, Vector3(0, 0.95, 0))
			part(r, ball(Vector3(0.22, 0.24, 0.26), 8), MatLib.animal(Color(0.2, 0.18, 0.18)), Vector3(0, 1.1, -0.55))
			for lx in [-0.2, 0.2]:
				for lz in [-0.2, 0.2]:
					part(r, cyl(0.05, 0.04, 0.45, 6), MatLib.animal(Color(0.2, 0.18, 0.18)), Vector3(lx, 0.22, lz))
		"chicken":
			part(r, ball(Vector3(0.22, 0.2, 0.3), 8), MatLib.animal(Color(1, 0.98, 0.94)), Vector3(0, 0.3, 0))
			part(r, ball(Vector3(0.13, 0.13, 0.13), 8), MatLib.animal(Color(1, 0.98, 0.94)), Vector3(0, 0.56, -0.2))
			part(r, cone_mesh(0.05, 0.12), MatLib.animal(Color(1, 0.6, 0.1)), Vector3(0, 0.54, -0.36), Vector3(-90, 0, 0))
			part(r, ball(Vector3(0.05, 0.07, 0.04), 6), MatLib.animal(Color(0.9, 0.15, 0.12)), Vector3(0, 0.68, -0.2))
		"duck":
			part(r, ball(Vector3(0.22, 0.18, 0.3), 8), MatLib.animal(Color(0.98, 0.98, 0.98)), Vector3(0, 0.2, 0))
			part(r, ball(Vector3(0.14, 0.14, 0.14), 8), MatLib.animal(Color(0.1, 0.45, 0.25)), Vector3(0, 0.38, -0.2))
			part(r, rbox(Vector3(0.14, 0.05, 0.1), 0.02), MatLib.animal(Color(1, 0.6, 0.1)), Vector3(0, 0.34, -0.36))
		"rabbit":
			part(r, ball(Vector3(0.25, 0.22, 0.32), 8), MatLib.animal(Color(0.9, 0.8, 0.7)), Vector3(0, 0.3, 0))
			part(r, ball(Vector3(0.16, 0.16, 0.16), 8), MatLib.animal(Color(0.9, 0.8, 0.7)), Vector3(0, 0.5, -0.2))
			for ex in [-0.07, 0.07]:
				part(r, cyl(0.04, 0.03, 0.4, 6), MatLib.animal(Color(0.9, 0.8, 0.7)), Vector3(ex, 0.8, -0.2))
		"horse":
			var hb := MatLib.animal(Color(0.6, 0.38, 0.22))
			part(r, rbox(Vector3(1.0, 0.9, 2.0), 0.4), hb, Vector3(0, 1.4, 0))
			part(r, rbox(Vector3(0.5, 0.9, 0.6), 0.2), hb, Vector3(0, 1.9, -1.1), Vector3(-20, 0, 0))
			part(r, rbox(Vector3(0.45, 0.4, 0.7), 0.15), hb, Vector3(0, 2.2, -1.5))
			for lx in [-0.3, 0.3]:
				for lz in [-0.7, 0.7]:
					part(r, cyl(0.1, 0.08, 1.0, 8), hb, Vector3(lx, 0.5, lz))
		_:
			part(r, ball(Vector3(0.4, 0.4, 0.4), 8), MatLib.animal(Color(0.8, 0.6, 0.4)), Vector3(0, 0.5, 0))
	return r


static func cone_mesh(radius: float, height: float) -> Mesh:
	return _mesh("cone_%.2f_%.2f" % [radius, height], func() -> Mesh: return MeshGen.cone(radius, height, 8))


static func crop_field(parent: Node3D, center: Vector3, size: Vector2, kind: String, rows: int = 8, color: Color = Color(0.4, 0.75, 0.25)) -> Node3D:
	var r := root(parent, "Field", center)
	solid(r, Vector3(size.x, 0.1, size.y), Vector3(0, 0.02, 0), MatLib.ground(kind), kind)
	for i in rows:
		var z := -size.y * 0.5 + (float(i) + 0.5) * size.y / float(rows)
		var stalk := MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = cone_mesh(0.18, 0.7)
		var n := int(size.x / 0.5)
		mm.instance_count = n
		for k in n:
			mm.set_instance_transform(k, Transform3D(Basis(), Vector3(-size.x * 0.5 + 0.25 + k * 0.5, 0.4, z)))
		stalk.multimesh = mm
		stalk.material_override = MatLib.foliage(color, 0.18, 0.8)
		r.add_child(stalk)
	return r
