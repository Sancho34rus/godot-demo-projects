class_name Living
extends Node3D

## Living world: wandering animals that hop away from the machine, birds that
## circle overhead, butterflies over the flowers and fish in the lake.
## Everything is cheap (no physics) and capped by the graphics profile.

var world: WorldBase
var _items: Array = []
var _max_items := 60


func setup(w: WorldBase) -> void:
	world = w
	_max_items = 30 if SettingsManager.quality() < 0.5 else 60


func add_animal(kind: String, center: Vector3, radius: float = 6.0) -> void:
	if _items.size() >= _max_items:
		return
	var node := Scenery.animal(self, kind, center, randf() * TAU)
	_items.append({"node": node, "type": "walk", "home": center, "radius": radius, "target": center,
		"speed": 1.3 if kind != "chicken" else 1.6, "t": randf() * 4.0, "wait": randf() * 3.0, "fear": 0.0})


func add_bird(center: Vector3, radius: float = 14.0, height: float = 12.0) -> void:
	if _items.size() >= _max_items:
		return
	var node := Node3D.new()
	add_child(node)
	node.add_child(_bird_mesh())
	_items.append({"node": node, "type": "bird", "home": center, "radius": radius, "h": height, "t": randf() * TAU, "speed": 0.5})


func add_butterfly(center: Vector3, radius: float = 3.0) -> void:
	if _items.size() >= _max_items:
		return
	var node := Node3D.new()
	add_child(node)
	var col := Color.from_hsv(randf(), 0.6, 1.0)
	var wing_l := Scenery.part(node, MeshGen.sphere(Vector3(0.22, 0.02, 0.18), 6, 8), MatLib.plastic(col), Vector3(-0.12, 0, 0))
	var wing_r := Scenery.part(node, MeshGen.sphere(Vector3(0.22, 0.02, 0.18), 6, 8), MatLib.plastic(col), Vector3(0.12, 0, 0))
	_items.append({"node": node, "type": "bfly", "home": center, "radius": radius, "t": randf() * TAU, "wl": wing_l, "wr": wing_r})


func add_fish(center: Vector3, radius: float, depth_y: float) -> void:
	var node := Node3D.new()
	add_child(node)
	var body := Scenery.part(node, MeshGen.sphere(Vector3(0.22, 0.14, 0.45), 8, 10), MatLib.plastic(Color(1.0, 0.55, 0.2)), Vector3.ZERO)
	Scenery.part(node, MeshGen.cone(0.14, 0.2, 6), MatLib.plastic(Color(1.0, 0.45, 0.15)), Vector3(0, 0, 0.45), Vector3(90, 0, 0))
	_items.append({"node": node, "type": "fish", "home": center, "radius": radius, "h": depth_y, "t": randf() * TAU, "body": body})


func _bird_mesh() -> Node3D:
	var n := Node3D.new()
	Scenery.part(n, MeshGen.sphere(Vector3(0.16, 0.14, 0.28), 6, 8), MatLib.plastic(Color(0.35, 0.6, 0.95)), Vector3.ZERO)
	Scenery.part(n, MeshGen.sphere(Vector3(0.36, 0.02, 0.14), 4, 6), MatLib.plastic(Color(0.25, 0.45, 0.85)), Vector3(0, 0, 0))
	return n


func _process(delta: float) -> void:
	if world == null:
		return
	var pp := world.player_position()
	for it in _items:
		var node: Node3D = it["node"]
		if not is_instance_valid(node):
			continue
		match it["type"]:
			"walk":
				_walk(it, node, delta, pp)
			"bird":
				it["t"] += delta * it["speed"]
				var c: Vector3 = it["home"]
				var r: float = it["radius"]
				node.position = Vector3(c.x + cos(it["t"]) * r, c.y + it["h"] + sin(it["t"] * 2.0) * 0.6, c.z + sin(it["t"]) * r)
				node.rotation.y = -it["t"] + PI * 0.5
			"bfly":
				it["t"] += delta * 3.0
				var c2: Vector3 = it["home"]
				var r2: float = it["radius"]
				var ty := world.terrain_height(c2.x, c2.z) + 1.2 + sin(it["t"] * 0.7) * 0.5
				node.position = Vector3(c2.x + cos(it["t"] * 0.6) * r2, ty, c2.z + sin(it["t"] * 0.6) * r2)
				node.rotation.y = it["t"] * 0.6
				var flap := sin(it["t"] * 9.0) * 0.9
				it["wl"].rotation.z = flap
				it["wr"].rotation.z = -flap
			"fish":
				it["t"] += delta * 0.6
				var c3: Vector3 = it["home"]
				var r3: float = it["radius"]
				node.position = Vector3(c3.x + cos(it["t"]) * r3, it["h"], c3.z + sin(it["t"]) * r3)
				node.rotation.y = -it["t"] + PI * 0.5
				it["body"].rotation.y = sin(it["t"] * 12.0) * 0.25


func _walk(it: Dictionary, node: Node3D, delta: float, pp: Vector3) -> void:
	var pos := node.global_position
	var flee := pp.distance_to(pos) < 5.5
	if flee:
		var away := (pos - pp)
		away.y = 0.0
		if away.length() > 0.01:
			it["target"] = pos + away.normalized() * 8.0
		it["wait"] = 0.0
	if it["wait"] > 0.0:
		it["wait"] -= delta
		node.position.y = world.terrain_height(node.position.x, node.position.z)
		return
	var target: Vector3 = it["target"]
	var to := target - pos
	to.y = 0.0
	if to.length() < 0.3:
		var a := randf() * TAU
		var r: float = it["radius"] * sqrt(randf())
		var h: Vector3 = it["home"]
		it["target"] = Vector3(h.x + cos(a) * r, 0, h.z + sin(a) * r)
		it["wait"] = 1.5 + randf() * 3.0
		return
	var sp: float = float(it["speed"]) * (2.8 if flee else 1.0)
	var step := to.normalized() * sp * delta
	var np := pos + step
	node.global_position = Vector3(np.x, world.terrain_height(np.x, np.z), np.z)
	var target_yaw := atan2(-to.x, -to.z)
	node.rotation.y = lerp_angle(node.rotation.y, target_yaw, clampf(delta * 6.0, 0.0, 1.0))
	it["t"] += delta * 10.0
	node.rotation.z = sin(it["t"]) * 0.03
