class_name MeshGen
extends RefCounted

## Procedural mesh toolkit.
## Everything in the game (vehicles, buildings, trees, animals, UI icons in 3D)
## is generated from these primitives, so the project needs no external art
## assets and every model still has real volume, bevels and smoothing.

class Buf:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	func v(p: Vector3, n: Vector3, t: Vector2 = Vector2.ZERO) -> int:
		var i := pos.size()
		pos.append(p)
		nrm.append(n)
		uv.append(t)
		return i

	func tri(a: int, b: int, c: int) -> void:
		var gn := (pos[b] - pos[a]).cross(pos[c] - pos[a])
		if gn.length_squared() < 0.000000000001:
			return
		var an := nrm[a] + nrm[b] + nrm[c]
		if gn.dot(an) < 0.0:
			var t := b
			b = c
			c = t
		idx.append(a)
		idx.append(b)
		idx.append(c)

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static func empty() -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arr[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array()
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


## Box with smoothly rounded edges and corners (real bevels, not a cube).
static func rounded_box(size: Vector3, radius: float = 0.1, seg: int = 3) -> ArrayMesh:
	var h := size * 0.5
	var r: float = clampf(radius, 0.001, minf(minf(h.x, h.y), h.z) * 0.999)
	var inner := h - Vector3(r, r, r)
	var b := Buf.new()
	var s: int = maxi(seg, 2)

	# --- six flat faces ---
	for a in 3:
		for sgn in [-1.0, 1.0]:
			var e0: int = (a + 1) % 3
			var e1: int = (a + 2) % 3
			var n := Vector3.ZERO
			n[a] = sgn
			var rows: Array = []
			for i in s + 1:
				var row: Array = []
				var u: float = lerpf(-inner[e0], inner[e0], float(i) / float(s))
				for j in s + 1:
					var w: float = lerpf(-inner[e1], inner[e1], float(j) / float(s))
					var p := Vector3.ZERO
					p[a] = sgn * h[a]
					p[e0] = u
					p[e1] = w
					row.append(b.v(p, n))
				rows.append(row)
			for i in s:
				for j in s:
					b.quad(rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1])

	# --- twelve rounded edges ---
	for ai in 3:
		for bi in range(ai + 1, 3):
			var ci: int = 3 - ai - bi
			for sa in [-1.0, 1.0]:
				for sb in [-1.0, 1.0]:
					var arc: int = maxi(seg, 3)
					var rows2: Array = []
					for k in 2:
						var row2: Array = []
						var cpos: float = lerpf(-inner[ci], inner[ci], float(k))
						for t in arc + 1:
							var ang: float = float(t) / float(arc) * PI * 0.5
							var ca: float = cos(ang) * sa
							var cb: float = sin(ang) * sb
							var p := Vector3.ZERO
							p[ai] = sa * inner[ai] + ca * r
							p[bi] = sb * inner[bi] + cb * r
							p[ci] = cpos
							var nn := Vector3.ZERO
							nn[ai] = ca
							nn[bi] = cb
							row2.append(b.v(p, nn.normalized()))
						rows2.append(row2)
					for t in arc:
						b.quad(rows2[0][t], rows2[1][t], rows2[1][t + 1], rows2[0][t + 1])

	# --- eight corner spheres ---
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var c := Vector3(sx * inner.x, sy * inner.y, sz * inner.z)
				var cs: int = maxi(seg, 3)
				var rows3: Array = []
				for i in cs + 1:
					var row3: Array = []
					var phi: float = float(i) / float(cs) * PI * 0.5
					for j in cs + 1:
						var th: float = float(j) / float(cs) * PI * 0.5
						var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
						var nd := Vector3(d.x * sx, d.y * sy, d.z * sz)
						row3.append(b.v(c + nd * r, nd))
					rows3.append(row3)
				for i in cs:
					for j in cs:
						b.quad(rows3[i][j], rows3[i + 1][j], rows3[i + 1][j + 1], rows3[i][j + 1])

	return b.mesh()


static func sphere(radius: Vector3, rings: int = 10, segments: int = 16) -> ArrayMesh:
	var b := Buf.new()
	var rg: int = maxi(rings, 3)
	var sg: int = maxi(segments, 4)
	var grid: Array = []
	for i in rg + 1:
		var row: Array = []
		var phi: float = PI * float(i) / float(rg)
		for j in sg + 1:
			var th: float = TAU * float(j) / float(sg)
			var d := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			row.append(b.v(Vector3(d.x * radius.x, d.y * radius.y, d.z * radius.z), d))
		grid.append(row)
	for i in rg:
		for j in sg:
			b.quad(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])
	return b.mesh()


static func ball(radius: float, rings: int = 10, segments: int = 16) -> ArrayMesh:
	return sphere(Vector3(radius, radius, radius), rings, segments)


## Cylinder along +Y with optional caps.
static func cylinder(r_top: float, r_bottom: float, height: float, segments: int = 16, caps: bool = true) -> ArrayMesh:
	var b := Buf.new()
	var seg: int = maxi(segments, 3)
	var hy := height * 0.5
	var slope := 0.0
	if height > 0.0001:
		slope = (r_bottom - r_top) / height
	var rows: Array = []
	for i in 2:
		var row: Array = []
		var y: float = lerpf(-hy, hy, float(i))
		var rr: float = lerpf(r_bottom, r_top, float(i))
		for j in seg + 1:
			var th: float = TAU * float(j) / float(seg)
			var c := cos(th)
			var sn := sin(th)
			row.append(b.v(Vector3(c * rr, y, sn * rr), Vector3(c, slope, sn).normalized()))
		rows.append(row)
	for j in seg:
		b.quad(rows[0][j], rows[0][j + 1], rows[1][j + 1], rows[1][j])
	if caps:
		for j in seg:
			var th0: float = TAU * float(j) / float(seg)
			var th1: float = TAU * float(j + 1) / float(seg)
			var a := b.v(Vector3(cos(th0) * r_top, hy, sin(th0) * r_top), Vector3.UP)
			var bb := b.v(Vector3(cos(th1) * r_top, hy, sin(th1) * r_top), Vector3.UP)
			var cc := b.v(Vector3(0, hy, 0), Vector3.UP)
			b.tri(a, bb, cc)
			var d := b.v(Vector3(cos(th0) * r_bottom, -hy, sin(th0) * r_bottom), Vector3.DOWN)
			var e := b.v(Vector3(cos(th1) * r_bottom, -hy, sin(th1) * r_bottom), Vector3.DOWN)
			var f := b.v(Vector3(0, -hy, 0), Vector3.DOWN)
			b.tri(d, e, f)
	return b.mesh()


static func cone(radius: float, height: float, segments: int = 16) -> ArrayMesh:
	return cylinder(0.001, radius, height, segments, true)


static func torus(major: float, minor: float, seg: int = 18, ring: int = 9) -> ArrayMesh:
	var b := Buf.new()
	var grid: Array = []
	for i in ring + 1:
		var row: Array = []
		var a: float = TAU * float(i) / float(ring)
		for j in seg + 1:
			var bb: float = TAU * float(j) / float(seg)
			var n := Vector3(cos(a) * cos(bb), sin(bb), sin(a) * cos(bb)).normalized()
			var rr: float = major + minor * cos(bb)
			row.append(b.v(Vector3(cos(a) * rr, minor * sin(bb), sin(a) * rr), n))
		grid.append(row)
	for i in ring:
		for j in seg:
			b.quad(grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j])
	return b.mesh()


## Extrude a closed 2D profile (x = length, y = height) along Z with rounded sides.
## Produces smooth, beveled volumes — the base of every vehicle shell.
static func extrude_profile(profile: PackedVector2Array, width: float, rings: int = 5, cap_scale: float = 0.93) -> ArrayMesh:
	var n := profile.size()
	if n < 3:
		return empty()
	# keep counter-clockwise winding so outward normals are well defined
	var area := 0.0
	for i in n:
		var a: Vector2 = profile[i]
		var b2: Vector2 = profile[(i + 1) % n]
		area += a.x * b2.y - b2.x * a.y
	var prof := profile
	if area < 0.0:
		prof = PackedVector2Array()
		for i in range(n - 1, -1, -1):
			prof.append(profile[i])
	var normals2: Array = []
	for i in n:
		var p_prev: Vector2 = prof[(i - 1 + n) % n]
		var p_next: Vector2 = prof[(i + 1) % n]
		var e: Vector2 = p_next - p_prev
		normals2.append(Vector2(e.y, -e.x).normalized())

	var buf := Buf.new()
	var rg: int = maxi(rings, 2)
	var hw := width * 0.5
	var layers: Array = []
	for k in rg + 1:
		var tt: float = float(k) / float(rg) * 2.0 - 1.0
		var sc: float = cap_scale + (1.0 - cap_scale) * sqrt(maxf(0.0, 1.0 - tt * tt))
		var zz: float = tt * hw
		var lat: float = tt * 1.7
		var row: Array = []
		for i in n:
			var p: Vector2 = prof[i]
			var n2: Vector2 = normals2[i]
			var n3 := Vector3(n2.x, n2.y, lat).normalized()
			row.append(buf.v(Vector3(p.x * sc, p.y * sc, zz), n3))
		layers.append(row)
	for k in rg:
		for i in n:
			var i2: int = (i + 1) % n
			buf.quad(layers[k][i], layers[k][i2], layers[k + 1][i2], layers[k + 1][i])

	# gently domed end caps keep the shell watertight
	for side in [-1, 1]:
		var li: int = 0 if side < 0 else rg
		var z: float = -hw if side < 0 else hw
		var nz := Vector3(0, 0, side)
		var poly := PackedVector2Array()
		for i in n:
			var p3: Vector3 = buf.pos[layers[li][i]]
			poly.append(Vector2(p3.x, p3.y))
		var tris := Geometry2D.triangulate_polygon(poly)
		if tris.size() >= 3:
			var capv: Array = []
			for i in n:
				var p3: Vector3 = buf.pos[layers[li][i]]
				capv.append(buf.v(Vector3(p3.x, p3.y, z), nz))
			for i in range(0, tris.size(), 3):
				buf.tri(capv[tris[i]], capv[tris[i + 1]], capv[tris[i + 2]])
	return buf.mesh()


static func plane(size: Vector2, subdiv: int = 1, uv_scale: float = 1.0) -> ArrayMesh:
	var b := Buf.new()
	var s: int = maxi(subdiv, 1)
	var rows: Array = []
	for i in s + 1:
		var row: Array = []
		var z: float = lerpf(-size.y * 0.5, size.y * 0.5, float(i) / float(s))
		for j in s + 1:
			var x: float = lerpf(-size.x * 0.5, size.x * 0.5, float(j) / float(s))
			row.append(b.v(Vector3(x, 0, z), Vector3.UP, Vector2(float(j) / float(s), float(i) / float(s)) * uv_scale))
		rows.append(row)
	for i in s:
		for j in s:
			b.quad(rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j])
	return b.mesh()


## Heightfield terrain patch centred on origin, size in X/Z.
static func heightfield(size: Vector2, res: int, height_fn: Callable, uv_scale: float = 6.0) -> ArrayMesh:
	var b := Buf.new()
	var s: int = maxi(res, 2)
	var rows: Array = []
	var step: float = 0.5
	for i in s + 1:
		var row: Array = []
		var z: float = lerpf(-size.y * 0.5, size.y * 0.5, float(i) / float(s))
		for j in s + 1:
			var x: float = lerpf(-size.x * 0.5, size.x * 0.5, float(j) / float(s))
			var y: float = height_fn.call(x, z)
			var hx: float = height_fn.call(x + step, z) - height_fn.call(x - step, z)
			var hz: float = height_fn.call(x, z + step) - height_fn.call(x, z - step)
			var nrm := Vector3(-hx, 2.0 * step, -hz).normalized()
			row.append(b.v(Vector3(x, y, z), nrm, Vector2(float(j) / float(s), float(i) / float(s)) * uv_scale))
		rows.append(row)
	for i in s:
		for j in s:
			b.quad(rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j])
	return b.mesh()


static func star(outer: float, inner: float, points: int = 5, depth: float = 0.12) -> ArrayMesh:
	var b := Buf.new()
	var front: Array = []
	var back: Array = []
	for i in points * 2:
		var ang: float = -PI * 0.5 + TAU * float(i) / float(points * 2)
		var r: float = outer if i % 2 == 0 else inner
		var p := Vector3(cos(ang) * r, sin(ang) * r, 0)
		front.append(b.v(p + Vector3(0, 0, depth * 0.5), Vector3(0, 0, 1)))
		back.append(b.v(p - Vector3(0, 0, depth * 0.5), Vector3(0, 0, -1)))
	var fc := b.v(Vector3(0, 0, depth * 0.5 + 0.03), Vector3(0, 0, 1))
	var bc := b.v(Vector3(0, 0, -depth * 0.5 - 0.03), Vector3(0, 0, -1))
	var n: int = front.size()
	for i in n:
		var j: int = (i + 1) % n
		b.tri(fc, front[i], front[j])
		b.tri(bc, back[j], back[i])
		b.quad(front[i], back[i], back[j], front[j])
	return b.mesh()


static func heart(size: float, depth: float = 0.12) -> ArrayMesh:
	var b := Buf.new()
	var pts := 48
	var front: Array = []
	for i in pts:
		var t: float = TAU * float(i) / float(pts)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		front.append(Vector2(x, y) * (size / 34.0))
	for i in pts:
		var j: int = (i + 1) % pts
		var a := b.v(Vector3(front[i].x, front[i].y, depth * 0.5), Vector3(0, 0, 1))
		var bb := b.v(Vector3(front[j].x, front[j].y, depth * 0.5), Vector3(0, 0, 1))
		var c := b.v(Vector3(0, 0, depth * 0.5 + 0.02), Vector3(0, 0, 1))
		b.tri(a, bb, c)
		var d := b.v(Vector3(front[i].x, front[i].y, -depth * 0.5), Vector3(0, 0, -1))
		var e := b.v(Vector3(front[j].x, front[j].y, -depth * 0.5), Vector3(0, 0, -1))
		var f := b.v(Vector3(0, 0, -depth * 0.5 - 0.02), Vector3(0, 0, -1))
		b.tri(d, e, f)
		var a2 := b.v(Vector3(front[i].x, front[i].y, depth * 0.5), Vector3(front[i].normalized()))
		var b2 := b.v(Vector3(front[j].x, front[j].y, depth * 0.5), Vector3(front[j].normalized()))
		var c2 := b.v(Vector3(front[i].x, front[i].y, -depth * 0.5), Vector3(front[i].normalized()))
		var d2 := b.v(Vector3(front[j].x, front[j].y, -depth * 0.5), Vector3(front[j].normalized()))
		b.quad(a2, b2, d2, c2)
	return b.mesh()


## Merge meshes into a single ArrayMesh (one draw call per material group).
static func combine(meshes: Array, xforms: Array = []) -> ArrayMesh:
	var out_pos := PackedVector3Array()
	var out_nrm := PackedVector3Array()
	var out_uv := PackedVector2Array()
	var out_idx := PackedInt32Array()
	for i in meshes.size():
		var m: Mesh = meshes[i]
		if m == null:
			continue
		var xf := Transform3D.IDENTITY
		if i < xforms.size() and xforms[i] != null:
			xf = xforms[i]
		var nxf := xf.basis.inverse().transposed()
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			if arr.size() == 0:
				continue
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var us := PackedVector2Array()
			if arr[Mesh.ARRAY_TEX_UV] != null:
				us = arr[Mesh.ARRAY_TEX_UV]
			var base := out_pos.size()
			for k in vs.size():
				out_pos.append(xf * vs[k])
				if k < ns.size():
					out_nrm.append((nxf * ns[k]).normalized())
				else:
					out_nrm.append(Vector3.UP)
				if k < us.size():
					out_uv.append(us[k])
				else:
					out_uv.append(Vector2.ZERO)
			var idxs = arr[Mesh.ARRAY_INDEX]
			if idxs == null or idxs.size() == 0:
				for k in vs.size():
					out_idx.append(base + k)
			else:
				for k in idxs.size():
					out_idx.append(base + int(idxs[k]))
	var arr2 := []
	arr2.resize(Mesh.ARRAY_MAX)
	arr2[Mesh.ARRAY_VERTEX] = out_pos
	arr2[Mesh.ARRAY_NORMAL] = out_nrm
	arr2[Mesh.ARRAY_TEX_UV] = out_uv
	arr2[Mesh.ARRAY_INDEX] = out_idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr2)
	return out


static func t(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(x, y, z))


static func trs(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	b = b.scaled(scale)
	return Transform3D(b, pos)


## Cylinder stretched between two points (cables, branches, railings).
static func between(a: Vector3, b: Vector3, radius: float, segments: int = 8) -> ArrayMesh:
	var d := b - a
	var dist := d.length()
	if dist < 0.0001:
		return empty()
	var m := cylinder(radius, radius, dist, segments, true)
	var up := Vector3.UP
	var axis := d.normalized()
	var basis := Basis()
	if absf(axis.dot(up)) > 0.999:
		basis = Basis.IDENTITY if axis.y > 0.0 else Basis(Vector3.RIGHT, PI)
	else:
		var right := up.cross(axis).normalized()
		var fwd := right.cross(axis).normalized()
		basis = Basis(right, axis, fwd)
	var xf := Transform3D(basis, (a + b) * 0.5)
	return combine([m], [xf])


## Tube following a polyline (used for hoses, ropes, branches).
static func tube(points: Array, radius: float, segments: int = 8) -> ArrayMesh:
	var parts: Array = []
	for i in points.size() - 1:
		parts.append(between(points[i], points[i + 1], radius, segments))
	if parts.is_empty():
		return empty()
	return combine(parts)
