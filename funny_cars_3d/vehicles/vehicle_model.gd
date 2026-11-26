class_name VehicleModel
extends Node3D

## Builds a complete, detailed 3D model for every machine in the garage.
## Geometry is grouped per material and merged, so a full vehicle costs only
## ~10 draw calls while still having rounded bodies, windows, lights, mirrors,
## exhaust pipes, mudguards, wheels with rims and working attachments.

const FORWARD_ROT := Basis(Vector3.UP, PI * 0.5)

var data: VehicleData

var paint_mats: Array = []          # [ShaderMaterial] main painted parts
var paint_low_mat: ShaderMaterial
var paint_high_mat: ShaderMaterial
var accent_mat: ShaderMaterial      # stripes / second colour
var rim_mat: StandardMaterial3D
var glass_mats: Array = []

var wheel_visuals: Array = []       # WheelMesh nodes (parented to VehicleWheel3D by controller)
var extra_wheel_visuals: Array = [] # decorative axles
var lamp_nodes: Array = []
var tail_nodes: Array = []
var beacon_nodes: Array = []
var headlights: Array = []
var pivots: Dictionary = {}         # special attachment pivots
var mounts: Dictionary = {}         # attachment points ("hitch", "bucket_tip", "trailer"...)
var cargo_root: Node3D
var sticker_root: Node3D
var trailer_node: Node3D

var _bags: Dictionary = {}
var _track_mats: Array = []
var _built := false


static var _wheel_cache: Dictionary = {}


func build(d: VehicleData) -> void:
	data = d
	if _built:
		return
	_built = true
	_bags.clear()
	paint_low_mat = MatLib.paint(d.color)
	paint_high_mat = MatLib.paint(d.color)
	var paint_main := MatLib.paint(d.color)
	paint_mats = [paint_main, paint_low_mat, paint_high_mat]
	accent_mat = MatLib.paint(Color(0.95, 0.96, 0.97), 0.15)
	rim_mat = MatLib.rim(Color(0.8, 0.82, 0.86))
	cargo_root = _node(self, "Cargo")
	sticker_root = _node(self, "Stickers")

	match d.kind:
		"car": _build_car(false)
		"sport": _build_car(true)
		"police": _build_police()
		"suv": _build_suv()
		"van": _build_van()
		"pickup": _build_pickup()
		"truck": _build_truck("truck")
		"dump": _build_truck("dump")
		"crane": _build_crane()
		"fire": _build_truck("fire")
		"garbage": _build_truck("garbage")
		"ambulance": _build_van(true)
		"bus": _build_bus()
		"tow": _build_tow()
		"tractor": _build_tractor()
		"excavator": _build_excavator()
		"bulldozer": _build_bulldozer()
		"loader": _build_loader()
		"roller": _build_roller()
		_: _build_car(false)

	_flush_all()
	_build_wheels()
	if d.attachment == "trailer":
		_build_trailer()
	apply_style(d.color, Color(0.95, 0.96, 0.97), Color(0.8, 0.82, 0.86), 0)
	set_lights(false)


# ------------------------------------------------------------------ helpers ---
func _node(parent: Node3D, n: String) -> Node3D:
	var node := Node3D.new()
	node.name = n
	parent.add_child(node)
	return node


func _bag(key: String) -> Array:
	if not _bags.has(key):
		_bags[key] = [[], []]
	return _bags[key]


func _add(key: String, mesh: Mesh, xf: Transform3D = Transform3D.IDENTITY) -> void:
	var bag := _bag(key)
	bag[0].append(mesh)
	bag[1].append(xf)


func _add_box(key: String, size: Vector3, pos: Vector3, radius: float = 0.04, rot_deg: Vector3 = Vector3.ZERO) -> void:
	_add(key, MeshGen.rounded_box(size, minf(radius, minf(size.x, minf(size.y, size.z)) * 0.49), 3),
		MeshGen.trs(pos, rot_deg))


func _add_cyl(key: String, radius: float, height: float, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, segments: int = 14, r_top: float = -1.0) -> void:
	var rt := radius if r_top < 0.0 else r_top
	_add(key, MeshGen.cylinder(rt, radius, height, segments, true), MeshGen.trs(pos, rot_deg))


func _add_ball(key: String, radius: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> void:
	_add(key, MeshGen.sphere(radius, 8, 12), MeshGen.trs(pos, rot_deg))


func _add_profile(key: String, profile: PackedVector2Array, width: float, offset: Vector3 = Vector3.ZERO, cap_scale: float = 0.93) -> void:
	_add(key, MeshGen.extrude_profile(profile, width, 5, cap_scale), Transform3D(FORWARD_ROT, offset))


## Round the corners of a 2D silhouette so no shape looks like a plain box.
func _round_poly(points: PackedVector2Array, radius: float, seg: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := points.size()
	for i in n:
		var prev := points[(i - 1 + n) % n]
		var cur := points[i]
		var next := points[(i + 1) % n]
		var d1 := (prev - cur)
		var d2 := (next - cur)
		var l1 := d1.length()
		var l2 := d2.length()
		if l1 < 0.0001 or l2 < 0.0001:
			out.append(cur)
			continue
		d1 /= l1
		d2 /= l2
		var dot := clampf(d1.dot(d2), -1.0, 1.0)
		var ang := acos(dot)
		if ang > PI - 0.15:
			out.append(cur)
			continue
		var cut := minf(radius / maxf(sin(ang * 0.5), 0.2), minf(l1, l2) * 0.45)
		var a := cur + d1 * cut
		var b := cur + d2 * cut
		for s in seg + 1:
			var t := float(s) / float(seg)
			var p := a.lerp(cur, t).lerp(cur.lerp(b, t), t)
			out.append(p)
	return out


func _flush_all() -> void:
	for key in _bags.keys():
		var bag: Array = _bags[key]
		if bag[0].is_empty():
			continue
		var merged := MeshGen.combine(bag[0], bag[1])
		_make_mesh(key, merged, self)
	_bags.clear()


func _make_mesh(key: String, mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "M_" + key
	mi.mesh = mesh
	mi.material_override = _material_for(key)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if key in ["dark", "chrome", "lamp", "tail", "beacon", "detail"]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _material_for(key: String) -> Material:
	match key:
		"paint": return paint_mats[0]
		"paint_low": return paint_low_mat
		"paint_high": return paint_high_mat
		"accent": return accent_mat
		"glass": return MatLib.glass()
		"dark": return MatLib.plastic(MatLib.BLACK)
		"chrome": return MatLib.chrome()
		"steel": return MatLib.steel()
		"rubber": return MatLib.rubber()
		"wood": return MatLib.wood()
		"lamp": return MatLib.lamp_off()
		"tail": return MatLib.emissive(Color(0.85, 0.1, 0.08), 0.8)
		"beacon": return MatLib.emissive(Color(1.0, 0.62, 0.1), 0.6)
		"white": return MatLib.plastic(MatLib.WHITE)
		"cargo": return MatLib.plastic(Color(0.42, 0.42, 0.45))
		"track": return _track_material()
		_: return MatLib.plastic(Color(0.5, 0.5, 0.5))


func _track_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = MatLib.shader("track")
	_track_mats.append(m)
	return m


# -------------------------------------------------------------------- wheels ---
func _wheel_geometry(radius: float, width: float) -> Array:
	var key := "%.3f_%.3f" % [radius, width]
	if _wheel_cache.has(key):
		return _wheel_cache[key]
	var minor: float = maxf(width * 0.5, 0.06)
	var major: float = maxf(radius - minor, 0.08)
	# tyre: torus + tread lugs, built around Y then turned onto the X axis
	var lugs := 14
	var tyre_meshes: Array = [MeshGen.torus(major, minor, 20, 10)]
	var tyre_xfs: Array = [Transform3D.IDENTITY]
	for i in lugs:
		var ang := TAU * float(i) / float(lugs)
		var pos := Vector3(cos(ang) * (major + minor * 0.55), 0, sin(ang) * (major + minor * 0.55))
		tyre_meshes.append(MeshGen.rounded_box(Vector3(width * 0.75, 0.05, 0.09), 0.02, 2))
		tyre_xfs.append(MeshGen.trs(pos, Vector3(0, rad_to_deg(-ang) + 90.0, 0)))
	var tyre := MeshGen.combine(tyre_meshes, tyre_xfs)
	# rim
	var rim_parts: Array = []
	var rim_xfs: Array = []
	var rim_r: float = maxf(radius - width * 0.62, 0.08)
	rim_parts.append(MeshGen.cylinder(rim_r, rim_r, width * 0.68, 16, true))
	rim_xfs.append(Transform3D.IDENTITY)
	rim_parts.append(MeshGen.cylinder(rim_r * 0.42, rim_r * 0.5, width * 0.8, 12, true))
	rim_xfs.append(Transform3D.IDENTITY)
	for i in 5:
		var ang := TAU * float(i) / 5.0
		rim_parts.append(MeshGen.rounded_box(Vector3(width * 0.2, rim_r * 1.5, rim_r * 0.42), 0.02, 2))
		rim_xfs.append(MeshGen.trs(Vector3(0, cos(ang) * rim_r * 0.55, sin(ang) * rim_r * 0.55), Vector3(rad_to_deg(ang), 0, 0)))
	var rim := MeshGen.combine(rim_parts, rim_xfs)
	# rotate from Y-axis to X-axis
	var to_x := Transform3D(Basis(Vector3(0, 0, 1), -PI * 0.5), Vector3.ZERO)
	var res := [MeshGen.combine([tyre], [to_x]), MeshGen.combine([rim], [to_x])]
	_wheel_cache[key] = res
	return res


func make_wheel_node(radius: float, width: float, mirrored: bool = false) -> Node3D:
	var geo := _wheel_geometry(radius, width)
	var root := Node3D.new()
	var tyre := MeshInstance3D.new()
	tyre.mesh = geo[0]
	tyre.material_override = MatLib.rubber()
	root.add_child(tyre)
	var rim := MeshInstance3D.new()
	rim.mesh = geo[1]
	rim.material_override = rim_mat
	root.add_child(rim)
	# brake disc / hub detail
	var hub := MeshInstance3D.new()
	hub.mesh = MeshGen.cylinder(radius * 0.24, radius * 0.24, width * 0.9, 10, true)
	hub.material_override = MatLib.chrome()
	hub.rotation_degrees = Vector3(0, 0, 90)
	root.add_child(hub)
	root.name = "WheelVisual"
	if mirrored:
		root.rotation_degrees.y = 180.0
	return root


func _build_wheels() -> void:
	wheel_visuals.clear()
	for i in 4:
		var v := make_wheel_node(data.wheel_radius, data.wheel_width, i % 2 == 1)
		wheel_visuals.append(v)
	if data.wheel_z_extra != 0.0:
		for sx in [-1.0, 1.0]:
			var v2 := make_wheel_node(data.wheel_radius, data.wheel_width, sx < 0.0)
			v2.position = Vector3(sx * data.wheel_x, data.wheel_radius, data.wheel_z_extra)
			add_child(v2)
			extra_wheel_visuals.append(v2)


func _add_decorative_axle(z: float, dual: bool = false) -> void:
	for sx in [-1.0, 1.0]:
		var v := make_wheel_node(data.wheel_radius, data.wheel_width, sx < 0.0)
		v.position = Vector3(sx * data.wheel_x, data.wheel_radius, z)
		add_child(v)
		extra_wheel_visuals.append(v)
		if dual:
			var v3 := make_wheel_node(data.wheel_radius, data.wheel_width, sx < 0.0)
			v3.position = Vector3(sx * (data.wheel_x + data.wheel_width * 1.05), data.wheel_radius, z)
			add_child(v3)
			extra_wheel_visuals.append(v3)


func _tracks(z_center: float) -> void:
	var track_len := absf(z_center) * 2.0 + 1.1
	var tx := data.wheel_x + data.wheel_width * 0.15
	for sx in [-1.0, 1.0]:
		_add_box("track", Vector3(data.wheel_width, 0.52, track_len), Vector3(sx * tx, 0.3, 0.0), 0.2)
		# track frame
		_add_box("steel", Vector3(data.wheel_width * 0.7, 0.3, track_len * 0.72), Vector3(sx * tx, 0.34, 0.0), 0.08)
		# road wheels
		for i in 4:
			var z: float = -track_len * 0.33 + track_len * 0.22 * float(i)
			_add_cyl("steel", 0.16, data.wheel_width * 0.62, Vector3(sx * tx, 0.24, z), Vector3(0, 0, 90), 10)
		# drive sprocket + idler
		_add_cyl("steel", 0.24, data.wheel_width * 0.55, Vector3(sx * tx, 0.4, -track_len * 0.42), Vector3(0, 0, 90), 12)
		_add_cyl("steel", 0.24, data.wheel_width * 0.55, Vector3(sx * tx, 0.4, track_len * 0.42), Vector3(0, 0, 90), 12)


# ------------------------------------------------------------------- shared ---
func _add_mirror(x: float, y: float, z: float) -> void:
	var arm_len := 0.22
	_add_cyl("dark", 0.022, arm_len, Vector3(x + signf(x) * arm_len * 0.5, y, z), Vector3(0, 0, 90), 6)
	_add_box("dark", Vector3(0.05, 0.14, 0.1), Vector3(x + signf(x) * arm_len, y + 0.02, z), 0.02)
	_add_box("glass", Vector3(0.012, 0.11, 0.08), Vector3(x + signf(x) * (arm_len + 0.026), y + 0.02, z), 0.01)


func _add_wheel_arch(sx: float, z: float, radius: float, len: float) -> void:
	_add_box("dark", Vector3(0.06, radius * 1.5, len), Vector3(sx * (data.width * 0.5 + 0.01), radius * 0.94, z), 0.05)


# ---------------------------------------------------------------------- cars ---
func _build_car(sport: bool) -> void:
	var L := data.length * 0.5
	var W := data.width * 0.5
	var wr := data.wheel_radius
	var h0: float = 0.26 + wr * 0.35
	var belt: float = h0 + (0.5 if sport else 0.55) * (data.height - h0)
	var nose: float = h0 + (0.3 if sport else 0.36)
	var tail: float = h0 + (0.34 if sport else 0.4)

	var lower := PackedVector2Array([
		Vector2(L, nose - 0.06),
		Vector2(L - 0.06, nose + 0.1),
		Vector2(L * 0.52, nose + 0.16),
		Vector2(L * 0.16, belt - 0.02),
		Vector2(-L * 0.2, belt),
		Vector2(-L * 0.62, tail + 0.06),
		Vector2(-L + 0.04, tail),
		Vector2(-L, nose - 0.02),
		Vector2(-L + 0.12, h0 - 0.1),
		Vector2(L - 0.12, h0 - 0.1),
	])
	_add_profile("paint", _round_poly(lower, 0.13, 5), data.width * 0.98)
	# sills / low trim
	_add_box("paint_low", Vector3(data.width * 1.0, 0.1, data.length * 0.62), Vector3(0, h0 - 0.08, 0), 0.05)

	# cabin shell
	var cab_front: float = L * (0.05 if sport else 0.12)
	var cab_rear: float = -L * (0.58 if sport else 0.52)
	var roof_y: float = data.height
	var cabin := PackedVector2Array([
		Vector2(cab_front, belt - 0.04),
		Vector2(cab_front - 0.34, roof_y - 0.03),
		Vector2(cab_rear + 0.3, roof_y),
		Vector2(cab_rear, belt - 0.04),
	])
	cabin = _round_poly(cabin, 0.09, 4)
	_add_profile("glass", cabin, data.width * 0.88, Vector3.ZERO, 0.97)
	# roof
	_add_box("paint_high", Vector3(data.width * 0.9, 0.09, absf(cab_front - cab_rear) * 0.78),
		Vector3((cab_front + cab_rear) * 0.5, roof_y - 0.015, 0), 0.04)
	# pillars
	for sx in [-1.0, 1.0]:
		var x1: float = sx * data.width * 0.44
		_add("paint_high", MeshGen.between(Vector3(x1, belt - 0.02, -(cab_front - 0.02)), Vector3(sx * data.width * 0.42, roof_y - 0.05, -(cab_front - 0.32)), 0.045, 6))
		_add("paint_high", MeshGen.between(Vector3(x1, belt - 0.02, -(cab_rear + 0.02)), Vector3(sx * data.width * 0.42, roof_y - 0.06, -(cab_rear + 0.26)), 0.045, 6))

	# bumpers & grille
	_add_box("paint_low", Vector3(data.width * 0.99, 0.17, 0.22), Vector3(0, h0 + 0.06, -L + 0.02), 0.07)
	_add_box("paint_low", Vector3(data.width * 0.97, 0.16, 0.2), Vector3(0, h0 + 0.08, L - 0.02), 0.07)
	_add_box("dark", Vector3(data.width * 0.62, 0.16, 0.06), Vector3(0, h0 + 0.3, -L + 0.03), 0.03)
	# headlights + spotlights
	for sx in [-1.0, 1.0]:
		_add_box("lamp", Vector3(0.3, 0.14, 0.1), Vector3(sx * data.width * 0.32, h0 + 0.32, -L + 0.01), 0.05)
		_add_box("tail", Vector3(0.26, 0.13, 0.08), Vector3(sx * data.width * 0.34, h0 + 0.36, L - 0.01), 0.04)
		_add_mirror(sx * data.width * 0.5, belt + 0.1, -(cab_front - 0.06))
		_add_box("chrome", Vector3(0.012, 0.03, 0.13), Vector3(sx * (W + 0.005), belt - 0.12, -L * 0.12), 0.01)
	# exhaust
	_add_cyl("chrome", 0.04, 0.12, Vector3(-data.width * 0.28, h0 - 0.02, L - 0.02), Vector3(90, 0, 0), 8)
	# wheel arches
	for sx in [-1.0, 1.0]:
		_add_wheel_arch(sx, data.wheel_z_front, wr, wr * 2.1)
		_add_wheel_arch(sx, data.wheel_z_rear, wr, wr * 2.1)
	# underbody
	_add_box("dark", Vector3(data.width * 0.86, 0.12, data.length * 0.86), Vector3(0, h0 - 0.12, 0), 0.04)

	if sport:
		# rear wing
		_add_box("paint_high", Vector3(data.width * 0.82, 0.05, 0.3), Vector3(0, data.height - 0.02, L * 0.72), 0.02)
		for sx in [-1.0, 1.0]:
			_add_box("dark", Vector3(0.06, 0.16, 0.08), Vector3(sx * data.width * 0.3, data.height - 0.12, L * 0.72), 0.02)
		# side vents
		for sx in [-1.0, 1.0]:
			_add_box("dark", Vector3(0.02, 0.14, 0.4), Vector3(sx * (W + 0.01), belt - 0.18, -L * 0.32), 0.02)
	else:
		# small roof antenna + plate
		_add_cyl("dark", 0.012, 0.2, Vector3(0, data.height + 0.08, L * 0.28), Vector3.ZERO, 6)
		_add_box("white", Vector3(0.3, 0.09, 0.02), Vector3(0, h0 + 0.03, -L - 0.005), 0.01)


func _build_police() -> void:
	_build_car(false)
	# light bar
	_add_box("dark", Vector3(data.width * 0.55, 0.07, 0.16), Vector3(0, data.height + 0.04, -0.1), 0.03)
	for sx in [-1.0, 1.0]:
		_add_beacon(Vector3(sx * data.width * 0.18, data.height + 0.1, -0.1), Vector3(0.24, 0.09, 0.14), Color(0.2, 0.45, 1.0)))
	# stripe
	for sx in [-1.0, 1.0]:
		_add_box("accent", Vector3(0.02, 0.16, data.length * 0.5), Vector3(sx * (data.width * 0.5 + 0.012), 0.78, 0), 0.02)


func _add_beacon(pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = MeshGen.rounded_box(size, minf(size.y, size.z) * 0.4, 3)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.4
	m.roughness = 0.2
	mi.material_override = m
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	beacon_nodes.append(mi)
	return mi


func _build_suv() -> void:
	var L := data.length * 0.5
	var W := data.width * 0.5
	var wr := data.wheel_radius
	var h0: float = 0.32 + wr * 0.4
	var belt: float = h0 + 0.62
	var roof: float = data.height

	var lower := PackedVector2Array([
		Vector2(L, h0 + 0.2),
		Vector2(L - 0.05, belt + 0.02),
		Vector2(L * 0.55, belt + 0.06),
		Vector2(L * 0.2, belt + 0.04),
		Vector2(-L + 0.14, belt + 0.04),
		Vector2(-L, belt - 0.04),
		Vector2(-L, h0 + 0.1),
		Vector2(-L + 0.14, h0 - 0.12),
		Vector2(L - 0.14, h0 - 0.12),
	])
	_add_profile("paint", _round_poly(lower, 0.16, 5), data.width * 0.99)

	var cabin := PackedVector2Array([
		Vector2(L * 0.22, belt),
		Vector2(L * 0.04, roof - 0.02),
		Vector2(-L * 0.72, roof),
		Vector2(-L * 0.86, belt),
	])
	_add_profile("glass", _round_poly(cabin, 0.12, 4), data.width * 0.9, Vector3.ZERO, 0.97)
	_add_box("paint_high", Vector3(data.width * 0.92, 0.1, data.length * 0.62), Vector3(-L * 0.26, roof - 0.02, 0), 0.05)
	# roof rails
	for sx in [-1.0, 1.0]:
		_add_box("dark", Vector3(0.06, 0.06, data.length * 0.6), Vector3(sx * data.width * 0.38, roof + 0.07, -L * 0.24), 0.03)
	# fender flares & bumpers
	for sx in [-1.0, 1.0]:
		_add_wheel_arch(sx, data.wheel_z_front, wr * 1.05, wr * 2.0)
		_add_wheel_arch(sx, data.wheel_z_rear, wr * 1.05, wr * 2.0)
		_add_mirror(sx * data.width * 0.5, belt + 0.18, -L * 0.1)
		_add_box("lamp", Vector3(0.32, 0.18, 0.1), Vector3(sx * data.width * 0.3, belt - 0.06, -L + 0.02), 0.05)
		_add_box("tail", Vector3(0.16, 0.34, 0.1), Vector3(sx * data.width * 0.4, belt + 0.06, L - 0.02), 0.04)
	_add_box("paint_low", Vector3(data.width * 0.99, 0.22, 0.24), Vector3(0, h0 + 0.02, -L + 0.02), 0.08)
	_add_box("paint_low", Vector3(data.width * 0.97, 0.2, 0.22), Vector3(0, h0 + 0.06, L - 0.02), 0.08)
	_add_box("steel", Vector3(data.width * 0.7, 0.16, 0.1), Vector3(0, h0 + 0.3, -L - 0.02), 0.04)
	# spare wheel on the back
	var spare := make_wheel_node(wr * 0.95, data.wheel_width * 0.9)
	spare.position = Vector3(0, belt + 0.12, L + 0.08)
	spare.rotation_degrees = Vector3(0, 0, 0)
	spare.scale = Vector3(0.85, 0.85, 0.85)
	add_child(spare)
	_add_box("dark", Vector3(data.width * 0.86, 0.14, data.length * 0.88), Vector3(0, h0 - 0.16, 0), 0.04)


func _build_van(ambulance: bool = false) -> void:
	var L := data.length * 0.5
	var h0: float = 0.3 + data.wheel_radius * 0.4
	var belt: float = h0 + 0.5
	var roof: float = data.height
	var body := PackedVector2Array([
		Vector2(L, h0 + 0.36),
		Vector2(L - 0.12, belt + 0.3),
		Vector2(L - 0.5, roof - 0.12),
		Vector2(-L + 0.16, roof - 0.02),
		Vector2(-L, roof - 0.18),
		Vector2(-L, h0 + 0.02),
		Vector2(-L + 0.16, h0 - 0.12),
		Vector2(L - 0.16, h0 - 0.12),
	])
	_add_profile("paint", _round_poly(body, 0.16, 5), data.width * 0.99, Vector3.ZERO, 0.95)
	# windscreen + side windows
	_add_box("glass", Vector3(data.width * 0.86, 0.5, 0.06), Vector3(0, belt + 0.34, -L + 0.42), 0.05, Vector3(-18, 0, 0))
	for sx in [-1.0, 1.0]:
		_add_box("glass", Vector3(0.06, 0.46, data.length * 0.22), Vector3(sx * (data.width * 0.5 - 0.01), belt + 0.36, -L * 0.1), 0.05)
		_add_box("glass", Vector3(0.06, 0.44, data.length * 0.18), Vector3(sx * (data.width * 0.5 - 0.01), belt + 0.36, L * 0.42), 0.05)
		_add_mirror(sx * data.width * 0.5, belt + 0.3, -L + 0.5)
		_add_box("lamp", Vector3(0.3, 0.16, 0.1), Vector3(sx * data.width * 0.32, h0 + 0.22, -L + 0.02), 0.05)
		_add_box("tail", Vector3(0.16, 0.4, 0.08), Vector3(sx * data.width * 0.4, belt + 0.1, L - 0.01), 0.04)
		_add_box("dark", Vector3(0.02, 0.04, data.length * 0.32), Vector3(sx * (data.width * 0.5 + 0.006), belt - 0.1, L * 0.2), 0.01)
	_add_box("paint_low", Vector3(data.width * 0.99, 0.2, 0.22), Vector3(0, h0 + 0.04, -L + 0.02), 0.07)
	_add_box("paint_low", Vector3(data.width * 0.97, 0.2, 0.2), Vector3(0, h0 + 0.06, L - 0.02), 0.07)
	# rear doors
	_add_box("dark", Vector3(0.02, roof - h0 - 0.2, 0.02), Vector3(0, (roof + h0) * 0.5, L + 0.01), 0.01)
	# roof vent
	_add_box("white", Vector3(0.5, 0.14, 0.5), Vector3(0, roof + 0.05, L * 0.35), 0.05)
	_add_box("dark", Vector3(data.width * 0.86, 0.14, data.length * 0.9), Vector3(0, h0 - 0.16, 0), 0.04)
	if ambulance:
		for sx in [-1.0, 1.0]:
			_add_box("accent", Vector3(0.015, 0.18, data.length * 0.8), Vector3(sx * (data.width * 0.5 + 0.008), belt + 0.02, 0), 0.02)
		# red crosses
		for sx in [-1.0, 1.0]:
			_add_box("tail", Vector3(0.02, 0.3, 0.1), Vector3(sx * (data.width * 0.5 + 0.02), belt + 0.3, L * 0.42), 0.01)
			_add_box("tail", Vector3(0.02, 0.1, 0.3), Vector3(sx * (data.width * 0.5 + 0.02), belt + 0.3, L * 0.42), 0.01)
		_add_beacon(Vector3(0, roof + 0.16, -L * 0.4), Vector3(0.7, 0.14, 0.2), Color(0.25, 0.5, 1.0)))


func _build_pickup() -> void:
	var L := data.length * 0.5
	var h0: float = 0.32 + data.wheel_radius * 0.4
	var belt: float = h0 + 0.62
	var roof: float = data.height
	# chassis + cab
	_add_box("dark", Vector3(data.width * 0.9, 0.16, data.length * 0.94), Vector3(0, h0 - 0.1, 0), 0.04)
	var cab := PackedVector2Array([
		Vector2(L * 0.34, belt),
		Vector2(L * 0.2, roof - 0.02),
		Vector2(-L * 0.22, roof),
		Vector2(-L * 0.34, belt),
		Vector2(-L * 0.3, h0 - 0.05),
		Vector2(L * 0.28, h0 - 0.05),
	])
	_add_profile("paint", _round_poly(cab, 0.12, 4), data.width * 0.96)
	_add_profile("glass", _round_poly(PackedVector2Array([
		Vector2(L * 0.3, belt + 0.02),
		Vector2(L * 0.18, roof - 0.06),
		Vector2(-L * 0.2, roof - 0.04),
		Vector2(-L * 0.3, belt + 0.02),
	]), 0.08, 3), data.width * 0.9, Vector3.ZERO, 0.97)
	_add_box("paint_high", Vector3(data.width * 0.94, 0.09, L * 0.5), Vector3(-L * 0.02, roof - 0.03, 0), 0.04)
	# bed
	_add_box("paint", Vector3(data.width * 0.94, 0.1, L * 0.78), Vector3(0, belt - 0.06, L * 0.55), 0.05)
	for sx in [-1.0, 1.0]:
		_add_box("paint", Vector3(0.08, 0.42, L * 0.78), Vector3(sx * data.width * 0.45, belt + 0.14, L * 0.55), 0.03)
	_add_box("paint", Vector3(data.width * 0.94, 0.42, 0.08), Vector3(0, belt + 0.14, L * 0.94), 0.03)
	_add_box("cargo", Vector3(data.width * 0.82, 0.04, L * 0.72), Vector3(0, belt + 0.0, L * 0.55), 0.01)
	# wheels arches, lights, mirrors
	for sx in [-1.0, 1.0]:
		_add_wheel_arch(sx, data.wheel_z_front, data.wheel_radius, data.wheel_radius * 2.2)
		_add_wheel_arch(sx, data.wheel_z_rear, data.wheel_radius, data.wheel_radius * 2.2)
		_add_mirror(sx * data.width * 0.5, belt + 0.2, -L * 0.14)
		_add_box("lamp", Vector3(0.28, 0.16, 0.1), Vector3(sx * data.width * 0.32, h0 + 0.36, -L + 0.02), 0.05)
		_add_box("tail", Vector3(0.14, 0.3, 0.1), Vector3(sx * data.width * 0.42, belt + 0.06, L - 0.03), 0.04)
	_add_box("paint_low", Vector3(data.width * 0.99, 0.2, 0.24), Vector3(0, h0 + 0.1, -L + 0.02), 0.08)
	_add_box("dark", Vector3(data.width * 0.5, 0.2, 0.06), Vector3(0, h0 + 0.34, -L + 0.02), 0.03)
	cargo_root.position = Vector3(0, belt + 0.05, L * 0.55)


func _build_truck(kind: String) -> void:
	var L := data.length * 0.5
	var wr := data.wheel_radius
	var h0: float = 0.3 + wr * 0.65
	var belt: float = h0 + 0.85
	var cab_len: float = 2.1 if kind != "fire" else 2.2
	# chassis rails
	for sx in [-1.0, 1.0]:
		_add_box("dark", Vector3(0.16, 0.3, data.length * 0.92), Vector3(sx * data.width * 0.3, h0 - 0.16, 0), 0.05)
	_add_box("dark", Vector3(data.width * 0.66, 0.12, data.length * 0.8), Vector3(0, h0 - 0.02, 0), 0.03)
	# cab
	var cab_z: float = -L + cab_len * 0.5
	var cab := PackedVector2Array([
		Vector2(cab_len * 0.5, h0 + 0.5),
		Vector2(cab_len * 0.44, belt + 0.55),
		Vector2(-cab_len * 0.46, belt + 0.6),
		Vector2(-cab_len * 0.5, h0 - 0.02),
		Vector2(cab_len * 0.5, h0 - 0.02),
	])
	var cab_fwd := _round_poly(cab, 0.1, 4)
	# cab profile is defined in the Z/Y plane here, so extrude along X directly
	_add("paint", MeshGen.extrude_profile(cab_fwd, data.width * 0.98, 5, 0.95), Transform3D(FORWARD_ROT, Vector3(0, 0, cab_z)))
	# windscreen
	_add_box("glass", Vector3(data.width * 0.84, 0.62, 0.06), Vector3(0, belt + 0.28, cab_z - cab_len * 0.44), 0.05, Vector3(-8, 0, 0))
	for sx in [-1.0, 1.0]:
		_add_box("glass", Vector3(0.06, 0.5, cab_len * 0.42), Vector3(sx * data.width * 0.49, belt + 0.26, cab_z - cab_len * 0.1), 0.04)
		_add_mirror(sx * data.width * 0.52, belt + 0.3, cab_z - cab_len * 0.4)
		_add_cyl("chrome", 0.05, 0.9, Vector3(sx * data.width * 0.44, belt + 0.75, cab_z + cab_len * 0.4), Vector3.ZERO, 8)
		_add_box("lamp", Vector3(0.34, 0.2, 0.12), Vector3(sx * data.width * 0.3, h0 + 0.18, -L + 0.02), 0.05)
	_add_box("steel", Vector3(data.width * 0.9, 0.34, 0.18), Vector3(0, h0 - 0.12, -L - 0.06), 0.06)
	_add_box("dark", Vector3(data.width * 0.6, 0.2, 0.06), Vector3(0, h0 + 0.5, -L + 0.02), 0.03)
	# mudguards
	for sx in [-1.0, 1.0]:
		for z in [data.wheel_z_rear, data.wheel_z_extra]:
			if z != 0.0:
				_add_box("dark", Vector3(0.5, 0.1, 1.0), Vector3(sx * data.wheel_x, data.wheel_radius * 1.75, z), 0.04)

	var body_start: float = cab_z + cab_len * 0.5
	if kind == "dump":
		_build_dump_bed(body_start, L, h0 + 0.2)
	elif kind == "fire":
		_build_fire_body(body_start, L, h0)
	elif kind == "garbage":
		_build_garbage_body(body_start, L, h0)
	else:
		# plain cargo box with ribs
		var box_len: float = L - body_start - 0.15
		var box_h: float = 2.0
		_add_box("accent", Vector3(data.width * 0.98, box_h, box_len), Vector3(0, h0 + box_h * 0.5 + 0.1, body_start + box_len * 0.5), 0.08)
		for i in int(box_len / 0.7):
			var zz := body_start + 0.4 + float(i) * 0.7
			for sx in [-1.0, 1.0]:
				_add_box("paint_high", Vector3(0.05, box_h * 0.94, 0.09), Vector3(sx * (data.width * 0.5 + 0.015), h0 + box_h * 0.5 + 0.1, zz), 0.02)
		_add_box("dark", Vector3(data.width * 0.9, 0.1, box_len * 0.96), Vector3(0, h0 + 0.08, body_start + box_len * 0.5), 0.02)
		_add_box("tail", Vector3(0.16, 0.16, 0.06), Vector3(data.width * 0.36, h0 + 1.1, L - 0.02), 0.03)
		cargo_root.position = Vector3(0, h0 + 0.16, body_start + box_len * 0.5)


func _build_dump_bed(body_start: float, L: float, y0: float) -> void:
	var bed_len: float = L - body_start - 0.1
	var pivot := _node(self, "BedPivot")
	pivot.position = Vector3(0, y0 + 0.05, body_start)
	pivots["bed"] = pivot
	var parts: Array = []
	var xfs: Array = []
	# floor
	parts.append(MeshGen.rounded_box(Vector3(data.width * 0.96, 0.14, bed_len), 0.05, 3))
	xfs.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, bed_len * 0.5)))
	# side walls
	for sx in [-1.0, 1.0]:
		parts.append(MeshGen.rounded_box(Vector3(0.1, 0.95, bed_len), 0.04, 3))
		xfs.append(Transform3D(Basis.IDENTITY, Vector3(sx * data.width * 0.45, 0.52, bed_len * 0.5)))
	# front wall + tailgate
	parts.append(MeshGen.rounded_box(Vector3(data.width * 0.96, 0.95, 0.1), 0.04, 3))
	xfs.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.52, 0.06)))
	parts.append(MeshGen.rounded_box(Vector3(data.width * 0.96, 0.8, 0.1), 0.04, 3))
	xfs.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.46, bed_len - 0.05)))
	# ribs
	for i in int(bed_len / 0.8):
		var zz := 0.5 + float(i) * 0.8
		for sx in [-1.0, 1.0]:
			parts.append(MeshGen.rounded_box(Vector3(0.06, 0.9, 0.1), 0.02, 2))
			xfs.append(Transform3D(Basis.IDENTITY, Vector3(sx * (data.width * 0.5 - 0.02), 0.5, zz)))
	var mi := MeshInstance3D.new()
	mi.mesh = MeshGen.combine(parts, xfs)
	mi.material_override = paint_mats[0]
	pivot.add_child(mi)
	# hydraulic cylinder under the bed
	_add_cyl("chrome", 0.09, 1.2, Vector3(0, y0 - 0.25, body_start + bed_len * 0.35), Vector3(90, 0, 0), 10)
	cargo_root.position = Vector3(0, y0 + 0.2, body_start + bed_len * 0.5)


func _build_fire_body(body_start: float, L: float, h0: float) -> void:
	var body_len: float = L - body_start - 0.1
	var h: float = 1.9
	_add_box("paint", Vector3(data.width * 0.99, h, body_len), Vector3(0, h0 + h * 0.5 + 0.1, body_start + body_len * 0.5), 0.1)
	_add_box("accent", Vector3(data.width * 1.005, 0.22, body_len * 0.99), Vector3(0, h0 + h * 0.55, body_start + body_len * 0.5), 0.03)
	# equipment lockers
	for sx in [-1.0, 1.0]:
		for i in 3:
			var zz := body_start + 0.35 + float(i) * body_len * 0.3
			_add_box("steel", Vector3(0.06, 0.5, body_len * 0.24), Vector3(sx * (data.width * 0.5 + 0.01), h0 + 0.55, zz), 0.03)
	# ladder on the roof
	for sx in [-1.0, 1.0]:
		_add_box("steel", Vector3(0.07, 0.07, body_len * 0.92), Vector3(sx * 0.35, h0 + h + 0.24, body_start + body_len * 0.5), 0.03)
	for i in 6:
		_add_box("steel", Vector3(0.7, 0.05, 0.05), Vector3(0, h0 + h + 0.24, body_start + 0.4 + float(i) * body_len * 0.15), 0.02)
	# hose reel
	_add("dark", MeshGen.torus(0.24, 0.1, 14, 8), MeshGen.trs(Vector3(0, h0 + h + 0.05, body_start + 0.3), Vector3(0, 0, 90)))
	_add_cyl("steel", 0.06, 0.5, Vector3(0, h0 + h + 0.05, body_start + 0.3), Vector3(90, 0, 0), 8)
	_add_beacon(Vector3(0, h0 + h + 0.45, body_start + body_len * 0.75), Vector3(0.8, 0.16, 0.25), Color(1.0, 0.2, 0.15)))
	cargo_root.position = Vector3(0, h0 + 0.2, body_start + body_len * 0.4)


func _build_garbage_body(body_start: float, L: float, h0: float) -> void:
	var body_len: float = L - body_start - 0.1
	_add_box("paint", Vector3(data.width * 0.99, 1.9, body_len * 0.82), Vector3(0, h0 + 1.05, body_start + body_len * 0.45), 0.12)
	_add_box("accent", Vector3(data.width * 1.002, 0.18, body_len * 0.8), Vector3(0, h0 + 1.55, body_start + body_len * 0.45), 0.03)
	# rear loading bin on a pivot
	var pivot := _node(self, "BinPivot")
	pivot.position = Vector3(0, h0 + 0.35, body_start + body_len * 0.88)
	pivots["bed"] = pivot
	var parts: Array = []
	var xfs: Array = []
	parts.append(MeshGen.rounded_box(Vector3(data.width * 0.9, 0.9, 0.7), 0.08, 3))
	xfs.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0.35)))
	parts.append(MeshGen.rounded_box(Vector3(data.width * 0.92, 0.12, 0.75), 0.04, 3))
	xfs.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0.35)))
	var mi := MeshInstance3D.new()
	mi.mesh = MeshGen.combine(parts, xfs)
	mi.material_override = paint_mats[0]
	pivot.add_child(mi)
	for sx in [-1.0, 1.0]:
		_add_box("steel", Vector3(0.08, 0.7, 0.08), Vector3(sx * data.width * 0.4, h0 + 0.9, body_start + body_len * 0.86), 0.02)
	cargo_root.position = Vector3(0, h0 + 0.4, body_start + body_len * 0.35)


func _build_bus() -> void:
	var L := data.length * 0.5
	var h0: float = 0.34 + data.wheel_radius * 0.5
	var roof: float = data.height
	var body := PackedVector2Array([
		Vector2(L, h0 + 0.5),
		Vector2(L - 0.1, roof - 0.35),
		Vector2(L - 0.45, roof - 0.04),
		Vector2(-L + 0.18, roof - 0.02),
		Vector2(-L, roof - 0.28),
		Vector2(-L, h0 + 0.02),
		Vector2(-L + 0.18, h0 - 0.14),
		Vector2(L - 0.18, h0 - 0.14),
	])
	_add_profile("paint", _round_poly(body, 0.18, 5), data.width * 0.99, Vector3.ZERO, 0.96)
	# window strip
	for sx in [-1.0, 1.0]:
		for i in 7:
			var zz: float = -L + 0.9 + float(i) * (data.length - 1.6) / 7.0
			_add_box("glass", Vector3(0.06, 0.72, (data.length - 1.6) / 7.0 * 0.82), Vector3(sx * (data.width * 0.5 - 0.01), roof - 0.62, zz), 0.04)
		_add_mirror(sx * data.width * 0.5, roof - 0.9, -L + 0.35)
		_add_box("lamp", Vector3(0.3, 0.2, 0.12), Vector3(sx * data.width * 0.3, h0 + 0.4, -L + 0.02), 0.05)
		_add_box("tail", Vector3(0.18, 0.4, 0.12), Vector3(sx * data.width * 0.4, h0 + 0.5, L - 0.02), 0.04)
	# windscreen + doors
	_add_box("glass", Vector3(data.width * 0.86, 0.85, 0.08), Vector3(0, roof - 0.72, -L + 0.12), 0.06)
	_add_box("glass", Vector3(data.width * 0.8, 0.7, 0.08), Vector3(0, roof - 0.78, L - 0.1), 0.06)
	_add_box("accent", Vector3(data.width * 0.885, 0.14, data.length * 0.98), Vector3(0, roof - 1.15, 0), 0.02)
	_add_box("dark", Vector3(data.width * 0.4, 0.2, 0.3), Vector3(0, roof + 0.08, -L * 0.5), 0.03)
	for sx in [-1.0, 1.0]:
		_add_wheel_arch(sx, data.wheel_z_front, data.wheel_radius, data.wheel_radius * 2.4)
		_add_wheel_arch(sx, data.wheel_z_rear, data.wheel_radius, data.wheel_radius * 2.4)
	_add_box("paint_low", Vector3(data.width * 1.0, 0.26, 0.24), Vector3(0, h0 + 0.02, -L + 0.02), 0.08)
	_add_box("paint_low", Vector3(data.width * 0.99, 0.24, 0.22), Vector3(0, h0 + 0.04, L - 0.02), 0.08)
	_add_box("dark", Vector3(data.width * 0.88, 0.16, data.length * 0.92), Vector3(0, h0 - 0.16, 0), 0.04)


func _build_tow() -> void:
	var L := data.length * 0.5
	var h0: float = 0.32 + data.wheel_radius * 0.5
	var belt: float = h0 + 0.8
	var cab := PackedVector2Array([
		Vector2(2.0, h0 + 0.5),
		Vector2(1.85, belt + 0.55),
		Vector2(-0.4, belt + 0.62),
		Vector2(-0.5, h0 - 0.02),
		Vector2(2.0, h0 - 0.02),
	])
	_add("paint", MeshGen.extrude_profile(_round_poly(cab, 0.1, 4), data.width * 0.96, 5, 0.95),
		Transform3D(FORWARD_ROT, Vector3(0, 0, -L + 1.25)))
	_add_box("glass", Vector3(data.width * 0.82, 0.55, 0.06), Vector3(0, belt + 0.3, -L + 1.0), 0.05, Vector3(-8, 0, 0))
	for sx in [-1.0, 1.0]:
		_add_box("glass", Vector3(0.06, 0.44, 0.7), Vector3(sx * data.width * 0.47, belt + 0.26, -L + 1.5), 0.04)
		_add_mirror(sx * data.width * 0.5, belt + 0.3, -L + 0.9)
		_add_box("lamp", Vector3(0.3, 0.16, 0.1), Vector3(sx * data.width * 0.3, h0 + 0.2, -L + 0.02), 0.05)
	# flat bed with ramp
	var bed_len: float = 2.9
	var bed_z0: float = -L + 2.6
	_add_box("paint_low", Vector3(data.width * 0.97, 0.16, bed_len), Vector3(0, h0 + 0.28, bed_z0 + bed_len * 0.5), 0.05)
	for sx in [-1.0, 1.0]:
		_add_box("paint_low", Vector3(0.08, 0.3, bed_len), Vector3(sx * data.width * 0.45, h0 + 0.42, bed_z0 + bed_len * 0.5), 0.03)
	var ramp := _node(self, "RampPivot")
	ramp.position = Vector3(0, h0 + 0.34, bed_z0 + bed_len)
	pivots["bed"] = ramp
	var rm := MeshInstance3D.new()
	rm.mesh = MeshGen.rounded_box(Vector3(data.width * 0.95, 0.1, 1.1), 0.04, 3)
	rm.position = Vector3(0, 0, 0.55)
	rm.material_override = paint_mats[2]
	ramp.add_child(rm)
	# winch
	_add_cyl("steel", 0.14, 0.5, Vector3(0, h0 + 0.5, bed_z0 + 0.25), Vector3(0, 0, 90), 10)
	_add_cyl("chrome", 0.03, 0.35, Vector3(0, h0 + 0.5, bed_z0 + 0.4), Vector3(90, 0, 0), 6)
	_add_box("dark", Vector3(data.width * 0.86, 0.14, data.length * 0.9), Vector3(0, h0 - 0.1, 0), 0.04)
	for sx in [-1.0, 1.0]:
		_add_wheel_arch(sx, data.wheel_z_front, data.wheel_radius, data.wheel_radius * 2.2)
	cargo_root.position = Vector3(0, h0 + 0.4, bed_z0 + bed_len * 0.5)
	_add_beacon(Vector3(0, belt + 0.7, -L + 1.7), Vector3(0.6, 0.14, 0.2), Color(1.0, 0.6, 0.1)))


func _build_crane() -> void:
	_build_truck("truck")
	# remove visual clutter: add turret on the bed
	var turret := _node(self, "Turret")
	turret.position = Vector3(0, 1.0, 0.4)
	pivots["turret"] = turret
	var base_parts: Array = [MeshGen.cylinder(0.95, 1.05, 0.4, 18, true)]
	var base_xfs: Array = [Transform3D.IDENTITY]
	var mi := MeshInstance3D.new()
	mi.mesh = MeshGen.combine(base_parts, base_xfs)
	mi.material_override = paint_mats[0]
	turret.add_child(mi)
	# counterweight + operator cab
	var cw := MeshInstance3D.new()
	cw.mesh = MeshGen.combine([
		MeshGen.rounded_box(Vector3(2.0, 0.9, 1.2), 0.12, 3),
		MeshGen.rounded_box(Vector3(1.1, 1.3, 1.1), 0.12, 3),
	], [MeshGen.trs(Vector3(0, 0.7, 1.0)), MeshGen.trs(Vector3(1.0, 0.95, 0.4))])
	cw.material_override = paint_mats[0]
	turret.add_child(cw)
	var cab_glass := MeshInstance3D.new()
	cab_glass.mesh = MeshGen.rounded_box(Vector3(1.0, 0.9, 1.0), 0.12, 3)
	cab_glass.position = Vector3(1.0, 1.0, 0.4)
	cab_glass.material_override = MatLib.glass()
	turret.add_child(cab_glass)
	# boom (two telescopic sections)
	var boom_pivot := _node(turret, "BoomPivot")
	boom_pivot.position = Vector3(0, 1.0, -0.3)
	pivots["boom"] = boom_pivot
	var boom := MeshInstance3D.new()
	boom.mesh = MeshGen.combine([
		MeshGen.rounded_box(Vector3(0.5, 0.5, 4.2), 0.1, 3),
		MeshGen.rounded_box(Vector3(0.36, 0.36, 2.6), 0.08, 3),
	], [MeshGen.trs(Vector3(0, 0, -2.0)), MeshGen.trs(Vector3(0, 0, -4.6))])
	boom.material_override = paint_mats[2]
	boom_pivot.add_child(boom)
	# cable + hook
	var cable := MeshInstance3D.new()
	cable.name = "Cable"
	cable.mesh = MeshGen.cylinder(0.025, 0.025, 2.0, 6, true)
	cable.material_override = MatLib.plastic(MatLib.BLACK)
	cable.position = Vector3(0, -1.0, -5.4)
	boom_pivot.add_child(cable)
	var hook := MeshInstance3D.new()
	hook.name = "Hook"
	hook.mesh = MeshGen.combine([
		MeshGen.rounded_box(Vector3(0.3, 0.3, 0.3), 0.06, 3),
		MeshGen.torus(0.16, 0.05, 12, 6),
	], [MeshGen.t(0.0, -0.1, 0.0), MeshGen.trs(Vector3(0, -0.35, 0), Vector3(90, 0, 0))])
	hook.material_override = MatLib.steel()
	hook.position = Vector3(0, -2.05, -5.4)
	boom_pivot.add_child(hook)
	mounts["hook"] = hook
	mounts["cable"] = cable
	# outriggers
	for sx in [-1.0, 1.0]:
		_add_box("steel", Vector3(0.9, 0.12, 0.12), Vector3(sx * data.width * 0.62, 0.5, -0.6), 0.04)
		_add_box("steel", Vector3(0.12, 0.5, 0.12), Vector3(sx * data.width * 0.95, 0.3, -0.6), 0.03)


func _build_tractor() -> void:
	var L := data.length * 0.5
	var wr := data.wheel_radius
	var h0: float = 0.34 + wr * 0.45
	var hood_y: float = h0 + 0.55
	# chassis
	_add_box("dark", Vector3(data.width * 0.5, 0.22, data.length * 0.9), Vector3(0, h0 - 0.05, 0), 0.04)
	# hood / engine
	var hood := PackedVector2Array([
		Vector2(L, h0 + 0.16),
		Vector2(L - 0.05, hood_y + 0.06),
		Vector2(L * 0.1, hood_y + 0.16),
		Vector2(-L * 0.15, h0 + 0.2),
		Vector2(-L * 0.1, h0 - 0.05),
		Vector2(L - 0.12, h0 - 0.05),
	])
	_add_profile("paint", _round_poly(hood, 0.1, 4), data.width * 0.62)
	# grille + lights
	_add_box("dark", Vector3(data.width * 0.5, 0.3, 0.06), Vector3(0, hood_y - 0.02, -L + 0.01), 0.03)
	for sx in [-1.0, 1.0]:
		_add_box("lamp", Vector3(0.14, 0.14, 0.08), Vector3(sx * data.width * 0.2, hood_y + 0.04, -L + 0.02), 0.03)
	# exhaust
	_add_cyl("steel", 0.05, 0.75, Vector3(data.width * 0.24, hood_y + 0.3, -L * 0.25), Vector3.ZERO, 8)
	_add_cyl("dark", 0.062, 0.06, Vector3(data.width * 0.24, hood_y + 0.7, -L * 0.25), Vector3.ZERO, 8)
	# cab
	var cab_z: float = L * 0.28
	var cab := PackedVector2Array([
		Vector2(0.65, h0 + 0.1),
		Vector2(0.62, data.height - 0.12),
		Vector2(-0.62, data.height),
		Vector2(-0.7, h0 + 0.1),
	])
	_add("paint", MeshGen.extrude_profile(_round_poly(cab, 0.1, 4), data.width * 0.8, 5, 0.95),
		Transform3D(FORWARD_ROT, Vector3(0, 0, cab_z)))
	_add_box("glass", Vector3(data.width * 0.66, 0.72, 0.06), Vector3(0, h0 + 0.92, cab_z - 0.62), 0.04)
	for sx in [-1.0, 1.0]:
		_add_box("glass", Vector3(0.05, 0.62, 1.0), Vector3(sx * data.width * 0.39, h0 + 0.95, cab_z), 0.04)
		_add_mirror(sx * data.width * 0.42, h0 + 1.2, cab_z - 0.6)
	_add_box("paint_high", Vector3(data.width * 0.84, 0.1, 1.4), Vector3(0, data.height - 0.04, cab_z), 0.05)
	_add_beacon(Vector3(0, data.height + 0.1, cab_z - 0.3), Vector3(0.18, 0.14, 0.18), Color(1.0, 0.55, 0.1)))
	# rear fenders
	for sx in [-1.0, 1.0]:
		_add_box("paint", Vector3(0.1, 0.5, wr * 2.4), Vector3(sx * data.width * 0.5, wr * 1.1, data.wheel_z_rear), 0.06)
	# hitch + implement mount
	var hitch := _node(self, "Hitch")
	hitch.position = Vector3(0, 0.55, L + 0.15)
	mounts["hitch"] = hitch
	var mount := _node(self, "ToolMount")
	mount.position = Vector3(0, 0.45, L + 0.1)
	mounts["tool"] = mount
	_add_box("steel", Vector3(0.5, 0.12, 0.3), Vector3(0, 0.45, L + 0.1), 0.03)
	# hitch ball
	_add_ball("chrome", Vector3(0.07, 0.07, 0.07), Vector3(0, 0.55, L + 0.16))


# -------------------------------------------------------------- work machines ---
func _build_excavator() -> void:
	_tracks(1.7)
	# rotating house
	_add_box("paint", Vector3(data.width * 0.9, 0.35, data.length * 0.9), Vector3(0, 0.85, -0.1), 0.12)
	var turret := _node(self, "Turret")
	turret.position = Vector3(0, 0.95, 0)
	pivots["turret"] = turret
	var house := MeshInstance3D.new()
	house.mesh = MeshGen.combine([
		MeshGen.rounded_box(Vector3(data.width * 0.9, 1.1, 2.4), 0.14, 4),
		MeshGen.rounded_box(Vector3(data.width * 0.86, 0.9, 1.0), 0.12, 3),
	], [MeshGen.trs(Vector3(0, 0.55, 0.55)), MeshGen.trs(Vector3(0, 0.5, -0.9))])
	house.material_override = paint_mats[0]
	turret.add_child(house)
	# counterweight
	var cw := MeshInstance3D.new()
	cw.mesh = MeshGen.rounded_box(Vector3(data.width * 0.86, 1.0, 0.55), 0.14, 4)
	cw.position = Vector3(0, 0.5, 1.75)
	cw.material_override = paint_mats[1]
	turret.add_child(cw)
	# cab
	var cab := MeshInstance3D.new()
	cab.mesh = MeshGen.rounded_box(Vector3(0.95, 1.25, 1.05), 0.12, 4)
	cab.position = Vector3(-data.width * 0.22, 1.15, -0.35)
	cab.material_override = MatLib.glass()
	turret.add_child(cab)
	var cab_frame := MeshInstance3D.new()
	cab_frame.mesh = MeshGen.combine([
		MeshGen.rounded_box(Vector3(1.05, 0.12, 1.15), 0.05, 3),
		MeshGen.rounded_box(Vector3(1.02, 0.18, 1.1), 0.05, 3),
	], [MeshGen.trs(Vector3(0, 1.8, 0)), MeshGen.trs(Vector3(0, 0.52, 0))])
	cab_frame.position = Vector3(-data.width * 0.22, 0, -0.35)
	cab_frame.material_override = paint_mats[2]
	turret.add_child(cab_frame)
	# boom + stick + bucket
	var boom_pivot := _node(turret, "BoomPivot")
	boom_pivot.position = Vector3(data.width * 0.2, 0.75, -1.0)
	pivots["boom"] = boom_pivot
	var boom := MeshInstance3D.new()
	boom.mesh = MeshGen.combine([
		MeshGen.rounded_box(Vector3(0.42, 0.55, 2.9), 0.1, 3),
		MeshGen.rounded_box(Vector3(0.3, 0.3, 0.5), 0.08, 3),
	], [MeshGen.trs(Vector3(0, 0, -1.45)), MeshGen.trs(Vector3(0, 0.1, -2.9))])
	boom.position = Vector3(0, 0.2, 0)
	boom.rotation_degrees = Vector3(35, 0, 0)
	boom.material_override = paint_mats[0]
	boom_pivot.add_child(boom)
	var stick_pivot := _node(boom_pivot, "StickPivot")
	stick_pivot.position = Vector3(0, 0.2 + sin(deg_to_rad(35)) * 2.9, -cos(deg_to_rad(35)) * 2.9)
	pivots["stick"] = stick_pivot
	var stick := MeshInstance3D.new()
	stick.mesh = MeshGen.rounded_box(Vector3(0.32, 0.4, 2.2), 0.08, 3)
	stick.position = Vector3(0, 0, -1.1)
	stick.rotation_degrees = Vector3(-25, 0, 0)
	stick.material_override = paint_mats[1]
	stick_pivot.add_child(stick)
	var bucket_pivot := _node(stick_pivot, "BucketPivot")
	bucket_pivot.position = Vector3(0, -sin(deg_to_rad(25)) * 2.2, -cos(deg_to_rad(25)) * 2.2)
	pivots["bucket"] = bucket_pivot
	var bucket := MeshInstance3D.new()
	bucket.mesh = MeshGen.combine([
		MeshGen.rounded_box(Vector3(1.15, 0.75, 0.8), 0.12, 4),
		MeshGen.rounded_box(Vector3(1.15, 0.16, 0.9), 0.05, 3),
	], [MeshGen.trs(Vector3(0, -0.15, -0.3)), MeshGen.trs(Vector3(0, 0.16, -0.42))])
	bucket.material_override = MatLib.steel()
	bucket_pivot.add_child(bucket)
	for i in 5:
		var tooth := MeshInstance3D.new()
		tooth.mesh = MeshGen.rounded_box(Vector3(0.14, 0.2, 0.22), 0.04, 2)
		tooth.position = Vector3(-0.44 + float(i) * 0.22, -0.5, -0.72)
		tooth.material_override = MatLib.steel()
		bucket_pivot.add_child(tooth)
	mounts["bucket"] = bucket_pivot
	var tip := _node(bucket_pivot, "BucketTip")
	tip.position = Vector3(0, -0.55, -0.85)
	mounts["bucket_tip"] = tip
	# hydraulic cylinders (decorative but attached correctly)
	for sx in [-1.0, 1.0]:
		var cyl := MeshInstance3D.new()
		cyl.mesh = MeshGen.cylinder(0.08, 0.08, 1.3, 10, true)
		cyl.position = Vector3(sx * 0.34, 0.5, -0.9)
		cyl.rotation_degrees = Vector3(70, 0, 0)
		cyl.material_override = MatLib.chrome()
		boom_pivot.add_child(cyl)


func _build_bulldozer() -> void:
	_tracks(1.65)
	# body
	_add_box("paint", Vector3(data.width * 0.62, 0.95, 2.6), Vector3(0, 1.05, 0.2), 0.14)
	_add_box("paint", Vector3(data.width * 0.55, 0.5, 2.1), Vector3(0, 1.7, 0.5), 0.1)
	for sx in [-1.0, 1.0]:
		_add_box("paint", Vector3(0.16, 0.5, 2.6), Vector3(sx * data.width * 0.33, 1.0, 0.2), 0.06)
	# cab
	_add_box("glass", Vector3(data.width * 0.5, 0.85, 1.05), Vector3(0, 2.0, -0.55), 0.1)
	_add_box("paint_high", Vector3(data.width * 0.54, 0.12, 1.15), Vector3(0, 2.45, -0.55), 0.05)
	_add_box("dark", Vector3(data.width * 0.46, 0.1, 0.95), Vector3(0, 1.58, -0.55), 0.04)
	# exhaust
	_add_cyl("steel", 0.06, 0.8, Vector3(-data.width * 0.2, 2.2, 0.3), Vector3.ZERO, 8)
	# blade pivot
	var blade := _node(self, "BladePivot")
	blade.position = Vector3(0, 0.55, -data.length * 0.5 - 0.35)
	pivots["blade"] = blade
	var blade_mesh := MeshInstance3D.new()
	var prof := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(-0.55, 0.25), Vector2(-0.5, 1.0),
		Vector2(-0.35, 1.15), Vector2(0.0, 0.55),
	])
	var bl := MeshGen.extrude_profile(_round_poly(prof, 0.08, 3), data.width * 1.02, 5, 0.96)
	blade_mesh.mesh = MeshGen.combine([bl], [Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO)])
	blade_mesh.material_override = paint_mats[0]
	blade.add_child(blade_mesh)
	# blade arms
	for sx in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		arm.mesh = MeshGen.rounded_box(Vector3(0.16, 0.22, 1.3), 0.05, 3)
		arm.position = Vector3(sx * data.width * 0.3, 0.35, 0.55)
		arm.material_override = paint_mats[1]
		blade.add_child(arm)
	# ripper at the back
	var ripper := _node(self, "RipperPivot")
	ripper.position = Vector3(0, 0.6, data.length * 0.4)
	pivots["ripper"] = ripper
	for sx in [-1.0, 1.0]:
		var tooth := MeshInstance3D.new()
		tooth.mesh = MeshGen.rounded_box(Vector3(0.16, 0.9, 0.2), 0.04, 2)
		tooth.position = Vector3(sx * 0.5, -0.2, 0.2)
		tooth.rotation_degrees = Vector3(-18, 0, 0)
		tooth.material_override = MatLib.steel()
		ripper.add_child(tooth)
	_add_beacon(Vector3(0, 2.6, -0.55), Vector3(0.2, 0.14, 0.2), Color(1.0, 0.55, 0.1)))


func _build_loader() -> void:
	var L := data.length * 0.5
	# rear chassis
	_add_box("paint", Vector3(data.width * 0.8, 1.1, 2.4), Vector3(0, 1.05, 0.75), 0.14)
	# front chassis (articulated)
	_add_box("paint", Vector3(data.width * 0.85, 0.9, 1.7), Vector3(0, 0.95, -1.15), 0.14)
	# cab
	_add_box("glass", Vector3(data.width * 0.62, 1.0, 1.15), Vector3(0, 2.05, 0.55), 0.1)
	_add_box("paint_high", Vector3(data.width * 0.68, 0.12, 1.25), Vector3(0, 2.6, 0.55), 0.05)
	_add_box("dark", Vector3(data.width * 0.58, 0.1, 1.05), Vector3(0, 1.55, 0.55), 0.04)
	for sx in [-1.0, 1.0]:
		_add_box("paint", Vector3(0.18, 0.9, 0.2), Vector3(sx * data.width * 0.42, 0.8, 0.55), 0.05)
	_add_cyl("steel", 0.07, 0.9, Vector3(0, 2.35, 1.5), Vector3.ZERO, 8)
	# arm pivot
	var arm := _node(self, "ArmPivot")
	arm.position = Vector3(0, 1.55, -1.9)
	pivots["arm"] = arm
	for sx in [-1.0, 1.0]:
		var beam := MeshInstance3D.new()
		beam.mesh = MeshGen.rounded_box(Vector3(0.22, 0.3, 2.0), 0.08, 3)
		beam.position = Vector3(sx * data.width * 0.36, 0.0, -0.9)
		beam.rotation_degrees = Vector3(12, 0, 0)
		beam.material_override = paint_mats[0]
		arm.add_child(beam)
	# bucket
	var bucket := _node(self, "BucketPivot")
	bucket.position = Vector3(0, 0.35, -1.95)
	pivots["bucket"] = bucket
	var bm := MeshInstance3D.new()
	bm.mesh = MeshGen.combine([
		MeshGen.rounded_box(Vector3(data.width * 0.95, 0.9, 1.1), 0.14, 4),
		MeshGen.rounded_box(Vector3(data.width * 0.95, 0.16, 1.2), 0.05, 3),
	], [MeshGen.trs(Vector3(0, -0.2, -0.2)), MeshGen.trs(Vector3(0, 0.2, -0.45))])
	bm.material_override = MatLib.steel()
	bucket.add_child(bm)
	var tip := _node(bucket, "Tip")
	tip.position = Vector3(0, -0.55, -0.75)
	mounts["bucket_tip"] = tip
	mounts["bucket"] = bucket


func _build_roller() -> void:
	var L := data.length * 0.5
	# main frame
	_add_box("paint", Vector3(data.width * 0.66, 0.6, 2.2), Vector3(0, 0.95, 0.5), 0.1)
	# front drum
	var drum := _node(self, "Drum")
	drum.position = Vector3(0, data.wheel_radius, -L + data.wheel_radius + 0.2)
	pivots["drum"] = drum
	var dm := MeshInstance3D.new()
	dm.mesh = MeshGen.cylinder(data.wheel_radius, data.wheel_radius, data.width * 0.96, 24, true)
	dm.rotation_degrees = Vector3(0, 0, 90)
	dm.material_override = MatLib.steel()
	drum.add_child(dm)
	# drum frame
	for sx in [-1.0, 1.0]:
		_add_box("paint", Vector3(0.14, 0.5, 1.3), Vector3(sx * data.width * 0.5, data.wheel_radius + 0.3, -L + data.wheel_radius + 0.6), 0.04)
	# cab
	_add_box("glass", Vector3(data.width * 0.6, 0.95, 1.0), Vector3(0, 1.95, 0.6), 0.1)
	_add_box("paint_high", Vector3(data.width * 0.66, 0.12, 1.1), Vector3(0, 2.45, 0.6), 0.05)
	_add_box("dark", Vector3(data.width * 0.56, 0.1, 0.9), Vector3(0, 1.5, 0.6), 0.04)
	# water tank
	_add_cyl("accent", 0.35, 1.5, Vector3(0, 1.6, 1.9), Vector3(0, 0, 90), 14)
	_add_cyl("steel", 0.05, data.width * 0.9, Vector3(0, 1.2, -0.2), Vector3(0, 0, 90), 8)
	_add_beacon(Vector3(0, 2.6, 0.6), Vector3(0.2, 0.14, 0.2), Color(1.0, 0.55, 0.1)))


func _build_trailer() -> void:
	var t := Node3D.new()
	t.name = "Trailer"
	trailer_node = t
	add_child(t)
	var parts: Array = []
	var xfs: Array = []
	var w := data.width * 0.96
	var box_len := 2.8
	parts.append(MeshGen.rounded_box(Vector3(w, 0.9, box_len), 0.1, 4))
	xfs.append(MeshGen.trs(Vector3(0, 1.25, box_len * 0.5)))
	parts.append(MeshGen.rounded_box(Vector3(w * 0.96, 0.1, box_len * 0.96), 0.03, 2))
	for sx in [-1.0, 1.0]:
		parts.append(MeshGen.rounded_box(Vector3(0.1, 0.85, box_len), 0.05, 3))
		xfs.append(MeshGen.trs(Vector3(sx * w * 0.5, 1.2, box_len * 0.5)))
	parts.append(MeshGen.rounded_box(Vector3(w, 0.85, 0.12), 0.05, 3))
	xfs.append(MeshGen.trs(Vector3(0, 1.2, box_len - 0.06)))
	parts.append(MeshGen.rounded_box(Vector3(w * 0.7, 0.16, 2.2), 0.06, 3))
	xfs.append(MeshGen.trs(Vector3(0, 0.75, box_len * 0.5)))
	# drawbar
	parts.append(MeshGen.rounded_box(Vector3(0.16, 0.16, 1.2), 0.05, 3))
	xfs.append(MeshGen.trs(Vector3(0, 0.8, -0.5)))
	var mi := MeshInstance3D.new()
	mi.mesh = MeshGen.combine(parts, xfs)
	mi.material_override = paint_mats[2]
	t.add_child(mi)
	for sx in [-1.0, 1.0]:
		var wheel := make_wheel_node(0.5, 0.4, sx < 0.0)
		wheel.position = Vector3(sx * (w * 0.52), 0.5, box_len * 0.62)
		t.add_child(wheel)
		extra_wheel_visuals.append(wheel)
	cargo_root.position = Vector3(0, 1.35, box_len * 0.5)


# -------------------------------------------------------------- style & state ---
func apply_style(color: Color, accent: Color, rim_c: Color, sticker_index: int) -> void:
	for m in paint_mats:
		m.set_shader_parameter("paint_color", color)
	paint_low_mat.set_shader_parameter("paint_color", color.darkened(0.08))
	paint_high_mat.set_shader_parameter("paint_color", color.lightened(0.04))
	accent_mat.set_shader_parameter("paint_color", accent)
	rim_mat.albedo_color = rim_c
	_set_sticker(sticker_index)


func _set_sticker(index: int) -> void:
	for c in sticker_root.get_children():
		c.queue_free()
	if index <= 0:
		return
	var col: Color = MatLib.STICKER_COLORS[(index - 1) % MatLib.STICKER_COLORS.size()]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.25
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh: Mesh
	if index % 3 == 1:
		mesh = MeshGen.star(0.24, 0.11, 5, 0.06)
	elif index % 3 == 2:
		mesh = MeshGen.heart(0.5, 0.06)
	else:
		mesh = MeshGen.ball(0.2, 6, 10)
	for sx in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(sx * (data.width * 0.5 + 0.02), data.height * 0.5, -data.length * 0.12)
		mi.rotation_degrees = Vector3(0, 90.0 * sx, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sticker_root.add_child(mi)


func set_dirt(value: float) -> void:
	for m in paint_mats:
		m.set_shader_parameter("dirt", clampf(value, 0.0, 1.0))


func set_part_dirt(index: int, value: float) -> void:
	if index >= 0 and index < paint_mats.size():
		paint_mats[index].set_shader_parameter("dirt", clampf(value, 0.0, 1.0))


func get_part_dirt(index: int) -> float:
	if index >= 0 and index < paint_mats.size():
		return float(paint_mats[index].get_shader_parameter("dirt"))
	return 0.0


func get_dirt() -> float:
	var total := 0.0
	for m in paint_mats:
		total += float(m.get_shader_parameter("dirt"))
	return total / maxf(float(paint_mats.size()), 1.0)


func set_wet(v: float) -> void:
	for m in paint_mats:
		m.set_shader_parameter("wet", clampf(v, 0.0, 1.0))


func set_foam(v: float) -> void:
	for m in paint_mats:
		m.set_shader_parameter("foam", clampf(v, 0.0, 1.0))


func set_scratch(v: float) -> void:
	for m in paint_mats:
		m.set_shader_parameter("scratch", clampf(v, 0.0, 1.0))


func set_lights(on: bool) -> void:
	var mat: Material = MatLib.lamp_on() if on else MatLib.lamp_off()
	for c in get_children():
		if c is MeshInstance3D and c.name == "M_lamp":
			c.material_override = mat
	for h in headlights:
		if is_instance_valid(h):
			h.visible = on
	for b in beacon_nodes:
		if is_instance_valid(b) and b.material_override is StandardMaterial3D:
			(b.material_override as StandardMaterial3D).emission_energy_multiplier = 2.2 if on else 0.35


func set_wheel_visible(i: int, vis: bool) -> void:
	if i >= 0 and i < wheel_visuals.size() and is_instance_valid(wheel_visuals[i]):
		wheel_visuals[i].visible = vis


func set_track_offset(v: float) -> void:
	for m in _track_mats:
		m.set_shader_parameter("track_offset", v)
