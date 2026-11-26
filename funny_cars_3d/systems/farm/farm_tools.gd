class_name FarmTools
extends RefCounted

## Farm implements attached to the tractor hitch. Each one is a composite
## model (frame, working parts, wheels) pointing backwards from the hitch.

static func build(kind: String, _d: VehicleData) -> Node3D:
	var root := Node3D.new()
	root.name = "Implement_" + kind
	match kind:
		"plow":
			_plow(root)
		"seeder":
			_seeder(root)
		"sprayer":
			_sprayer(root)
		"harvester":
			_harvester(root)
		"fork":
			_fork(root)
		_:
			root.queue_free()
			return null
	return root


static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return Scenery.part(parent, mesh, mat, pos, rot)


static func _plow(root: Node3D) -> void:
	var steel := MatLib.steel()
	var red := MatLib.plastic(Color(0.9, 0.25, 0.2))
	_mi(root, Scenery.rbox(Vector3(1.8, 0.14, 0.2), 0.04), steel, Vector3(0, 0.0, 0.0))
	_mi(root, Scenery.rbox(Vector3(0.14, 0.9, 0.14), 0.03), steel, Vector3(-0.8, -0.4, 0.0))
	for i in 3:
		var x := -0.6 + i * 0.6
		var disc := MeshGen.torus(0.32, 0.06, 18, 6)
		_mi(root, disc, red, Vector3(x, -0.8, -1.1 - i * 0.15), Vector3(0, 0, 0))
		_mi(root, Scenery.rbox(Vector3(0.12, 0.6, 0.6), 0.04), steel, Vector3(x, -0.4, -0.5), Vector3(0, 0, 0))
		_mi(root, Scenery.rbox(Vector3(0.24, 0.12, 0.6), 0.04), steel, Vector3(x, -0.66, -0.7), Vector3(-16, 0, 0))
	_mi(root, Scenery.cyl(0.05, 0.05, 1.4, 6), steel, Vector3(0, -0.3, -0.7), Vector3(90, 0, 0))


static func _seeder(root: Node3D) -> void:
	var red := MatLib.plastic(Color(0.22, 0.58, 0.95))
	var steel := MatLib.steel()
	_mi(root, Scenery.rbox(Vector3(1.9, 0.9, 1.2), 0.12), red, Vector3(0, 0.45, -0.6))
	_mi(root, Scenery.rbox(Vector3(1.6, 0.2, 1.0), 0.06), MatLib.plastic(Color(0.95, 0.85, 0.2)), Vector3(0, 0.98, -0.6))
	_mi(root, Scenery.cyl(0.06, 0.06, 1.8, 8), steel, Vector3(0, 0.1, 0.0), Vector3(0, 0, 90))
	for i in 5:
		var x := -0.75 + i * 0.375
		_mi(root, Scenery.cyl(0.05, 0.05, 0.8, 6), steel, Vector3(x, -0.2, -1.2))
		_mi(root, Scenery.ball(Vector3(0.1, 0.08, 0.1), 6), MatLib.plastic(Color(0.9, 0.7, 0.3)), Vector3(x, -0.62, -1.2))
	for s in [-1, 1]:
		_mi(root, MeshGen.torus(0.5, 0.07, 14, 6), MatLib.rubber(), Vector3(s * 1.1, 0.25, -0.6), Vector3(0, 0, 90))


static func _sprayer(root: Node3D) -> void:
	var tank := MatLib.plastic(Color(0.4, 0.85, 0.5))
	_mi(root, Scenery.cyl(0.6, 0.6, 2.2, 14), tank, Vector3(0, 0.8, -0.7), Vector3(90, 0, 0))
	_mi(root, Scenery.cyl(0.12, 0.12, 0.2, 8), MatLib.plastic(Color(0.9, 0.9, 0.95)), Vector3(0, 1.45, -0.7))
	_mi(root, Scenery.rbox(Vector3(0.12, 0.12, 4.0), 0.02), MatLib.steel(), Vector3(0, 0.25, -1.5))
	for i in 5:
		_mi(root, Scenery.cyl(0.03, 0.03, 0.4, 5), MatLib.steel(), Vector3(-1.0 + i * 0.5, 0.05, -1.5))
	_mi(root, Scenery.cyl(0.03, 0.03, 1.3, 5), MatLib.steel(), Vector3(0, 0.5, 0.2), Vector3(0, 0, 90))


static func _harvester(root: Node3D) -> void:
	var yellow := MatLib.plastic(Color(0.98, 0.78, 0.2))
	_mi(root, Scenery.rbox(Vector3(3.0, 0.6, 0.9), 0.1), yellow, Vector3(0, 0.25, -0.9))
	_mi(root, Scenery.rbox(Vector3(3.0, 0.2, 0.5), 0.05), MatLib.steel(), Vector3(0, -0.05, -1.4))
	for i in 4:
		_mi(root, Scenery.cyl(0.05, 0.05, 3.0, 6), MatLib.steel(), Vector3(-1.2 + i * 0.8, 0.8, -1.4), Vector3(0, 0, 0))
	_mi(root, MeshGen.torus(0.5, 0.06, 14, 6), yellow, Vector3(0, 1.15, -1.6), Vector3(0, 0, 90))
	_mi(root, Scenery.rbox(Vector3(0.8, 0.8, 0.8), 0.14), MatLib.plastic(Color(0.9, 0.5, 0.15)), Vector3(0, 0.6, 0.0))


static func _fork(root: Node3D) -> void:
	var steel := MatLib.steel()
	_mi(root, Scenery.rbox(Vector3(1.8, 0.14, 0.14), 0.03), steel, Vector3(0, 0.6, 0.0))
	for i in 4:
		_mi(root, Scenery.cyl(0.03, 0.03, 1.4, 5), steel, Vector3(-0.6 + i * 0.4, 0.2, -0.7), Vector3(-90, 0, 0))
	_mi(root, Scenery.rbox(Vector3(0.1, 1.1, 0.1), 0.02), steel, Vector3(0, 0.0, 0.0))
