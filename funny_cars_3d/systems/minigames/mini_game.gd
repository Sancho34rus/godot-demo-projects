class_name MiniGame
extends Node3D

## One running minigame. Goals are spawned around the station, the child
## completes them by driving through, parking, or pressing action near the
## target. Nothing ever fails, there is no timer and no penalty.

signal finished(id: String)

var world: WorldBase
var station: Station
var id := ""
var def: Dictionary = {}
var kind := ""
var total := 1
var done := 0
var _finished := false
var _rng := RandomNumberGenerator.new()
var _goals: Array = []        # dictionaries describing each goal node
var _next_gate := 0
var _round_color := Color.WHITE
var _round_cars: Array = []
var _hint_label: Label3D
var _cargo_node: Node3D = null
var _cargo_stage := 0
var _pad_a: Node3D
var _pad_b: Node3D


func setup(w: WorldBase, s: Station, game_id: String) -> void:
	world = w
	station = s
	id = game_id
	def = MiniGameDefs.get_def(id)
	kind = String(def.get("type", "collect"))
	total = MiniGameDefs.scaled_count(id)
	_rng.randomize()
	name = "MiniGame_" + id


func _ready() -> void:
	match kind:
		"collect":
			_start_collect()
		"delivery":
			_start_delivery()
		"parking":
			_start_parking()
		"match":
			_start_match()
		"checkpoints":
			_start_checkpoints()
		"dig":
			_start_dig()
		"water":
			_start_water()
		"help":
			_start_help()
		_:
			_finish()
	_hint(String(def.get("title", "Игра")))
	AudioManager.say("game_start", false)


func _origin() -> Vector3:
	return station.global_position if station != null else Vector3.ZERO


func _spot(min_r: float, max_r: float) -> Vector3:
	for _i in 30:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(min_r, max_r)
		var p := _origin() + Vector3(cos(a) * r, 0, sin(a) * r)
		if not _too_close(p):
			return Vector3(p.x, world.terrain_height(p.x, p.z), p.z)
	var q := _origin() + Vector3(min_r, 0, 0)
	return Vector3(q.x, world.terrain_height(q.x, q.z), q.z)


func _too_close(p: Vector3) -> bool:
	for g in _goals:
		var n: Node3D = g["node"]
		if is_instance_valid(n) and n.global_position.distance_to(p) < 4.5:
			return true
	for s in world.stations():
		if s.global_position.distance_to(p) < 6.0:
			return true
	return false


func _trigger(pos: Vector3, radius: float, cb: Callable) -> Area3D:
	var a := Area3D.new()
	a.position = pos + Vector3(0, 1.2, 0)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = radius
	cs.shape = sh
	a.add_child(cs)
	a.body_entered.connect(cb)
	add_child(a)
	return a


func _hint(text: String) -> void:
	if world != null and world.hud != null and world.hud.has_method("show_bubble"):
		world.hud.call("show_bubble", text, 4.0)
	UIManager.toast(text, String(def.get("icon", "star")), UIKit.ACCENT, 2.4)


func _item_mesh(kind_name: String) -> Node3D:
	var n := Node3D.new()
	match kind_name:
		"fruit":
			Scenery.part(n, MeshGen.ball(0.42, 12, 16), MatLib.plastic(Color(0.95, 0.2, 0.2)), Vector3(0, 0.6, 0))
			Scenery.part(n, Scenery.cyl(0.03, 0.03, 0.3, 5), MatLib.bark(), Vector3(0, 1.1, 0))
			Scenery.part(n, MeshGen.ball(0.16, 8, 10), MatLib.foliage(Color(0.3, 0.7, 0.3), 0.1, 0.4), Vector3(0.14, 1.12, 0))
		"can":
			Scenery.part(n, Scenery.cyl(0.36, 0.36, 0.9, 14), MatLib.plastic(Color(0.95, 0.25, 0.2)), Vector3(0, 0.6, 0))
			Scenery.part(n, Scenery.cyl(0.1, 0.1, 0.22, 8), MatLib.steel(), Vector3(0, 1.17, 0))
			Scenery.part(n, Scenery.rbox(Vector3(0.12, 0.3, 0.12), 0.03), MatLib.plastic(Color(1, 1, 1)), Vector3(0.35, 0.9, 0))
		"gear":
			Scenery.part(n, MeshGen.torus(0.36, 0.12, 16, 8), MatLib.chrome(), Vector3(0, 0.8, 0))
			Scenery.part(n, Scenery.cyl(0.2, 0.2, 0.2, 10), MatLib.steel(), Vector3(0, 0.8, 0), Vector3(90, 0, 0))
		"hidden":
			Scenery.part(n, Scenery.rbox(Vector3(0.9, 0.6, 0.6), 0.1), MatLib.wood(Color(0.8, 0.5, 0.25)), Vector3(0, 0.4, 0))
			Scenery.part(n, MeshGen.ball(0.45, 10, 12), MatLib.emissive(Color(1, 0.9, 0.4), 1.4), Vector3(0, 1.4, 0))
		"fish":
			Scenery.part(n, MeshGen.sphere(Vector3(0.4, 0.26, 0.7), 8, 10), MatLib.plastic(Color(1.0, 0.55, 0.2)), Vector3(0, 0.8, 0))
			Scenery.part(n, MeshGen.cone(0.22, 0.3, 6), MatLib.plastic(Color(1.0, 0.45, 0.15)), Vector3(0, 0.8, 0.6), Vector3(90, 0, 0))
		_:
			Scenery.part(n, MeshGen.star(0.5, 0.22, 5, 0.12), MatLib.emissive(Color(1.0, 0.85, 0.3), 1.2), Vector3(0, 0.9, 0))
	return n


# ---------------------------------------------------------------- collect ---
func _start_collect() -> void:
	var item := String(def.get("item", "star"))
	for i in total:
		var p := _spot(4.0, 14.0)
		var n := _item_mesh(item)
		n.position = p
		add_child(n)
		var rec := {"node": n, "pos": p}
		_goals.append(rec)
		var a := _trigger(p, 2.0, func(body: Node3D) -> void: _collect_one(rec, body))
		rec["area"] = a


func _collect_one(rec: Dictionary, body: Node3D) -> void:
	if _finished or not body is VehicleController:
		return
	if not _goals.has(rec):
		return
	_goals.erase(rec)
	var n: Node3D = rec["node"]
	AudioManager.play_sfx("pop", -6.0, 1.0 + randf() * 0.4)
	_burst(n.global_position + Vector3(0, 0.6, 0), Color(1, 0.9, 0.3))
	if is_instance_valid(n):
		n.queue_free()
	done += 1
	_progress()
	if done >= total:
		_finish()


func _burst(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 18 if SettingsManager.quality() > 0.5 else 8
	p.lifetime = 0.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.22
	var m := SphereMesh.new()
	m.radius = 0.1
	m.height = 0.2
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = mat
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _progress() -> void:
	AudioManager.play_success()
	if _hint_label != null:
		_hint_label.text = "%d / %d" % [done, total]
	UIManager.star_popup(0, "%d / %d" % [done, total])


# --------------------------------------------------------------- delivery ---
func _start_delivery() -> void:
	var color: Color = def.get("pad_color", Color(0.4, 0.8, 1.0))
	_pad_a = _pad(_origin() + Vector3(-7, 0, 0), color, "Груз")
	_pad_b = _pad(_origin() + Vector3(7, 0, 0), Color(0.45, 1.0, 0.55), "Привезти")
	_pad_b.visible = false
	_goals.append({"node": _pad_a, "pos": _pad_a.position})


func _pad(p: Vector3, color: Color, label_text: String) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(p.x, world.terrain_height(p.x, p.z) + 0.05, p.z)
	add_child(root)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.4
	cyl.bottom_radius = 2.4
	cyl.height = 0.12
	disc.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.7)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = mat
	root.add_child(disc)
	var lbl := Label3D.new()
	lbl.text = label_text
	lbl.font_size = 48
	lbl.pixel_size = 0.01
	lbl.position = Vector3(0, 2.6, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	root.add_child(lbl)
	var cb := func(body: Node3D) -> void: _on_pad(root, body)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var cyl_s := CylinderShape3D.new()
	cyl_s.radius = 2.4
	cyl_s.height = 2.0
	cs.shape = cyl_s
	cs.position = Vector3(0, 1.0, 0)
	area.add_child(cs)
	area.body_entered.connect(cb)
	root.add_child(area)
	return root


func _on_pad(root: Node3D, body: Node3D) -> void:
	if _finished or not body is VehicleController:
		return
	if root == _pad_a and _cargo_stage == 0 and _pad_a.visible:
		_cargo_stage = 1
		_pad_a.visible = false
		_pad_b.visible = true
		var pl := body as VehicleController
		_cargo_node = _cargo_mesh()
		pl.model.cargo_root.add_child(_cargo_node)
		pl.cargo = pl.cargo_max if pl.cargo_max > 0.0 else 1.0
		pl.cargo_changed.emit(pl.cargo)
		AudioManager.play_success()
		_hint("Груз в машинке! Вези его к зелёной площадке.")
	elif root == _pad_b and _cargo_stage == 1 and _pad_b.visible:
		_cargo_stage = 0
		var pl2 := body as VehicleController
		if _cargo_node != null and is_instance_valid(_cargo_node):
			_cargo_node.queue_free()
		_cargo_node = null
		pl2.cargo = 0.0
		pl2.cargo_changed.emit(0.0)
		done += 1
		_burst(root.global_position + Vector3(0, 1.5, 0), Color(0.5, 1.0, 0.5))
		AudioManager.play_success()
		if done >= total:
			_finish()
			return
		_progress()
		# next round starts from a new place
		var p := _spot(10.0, 16.0)
		_pad_b.visible = false
		_pad_a.position = Vector3(p.x, p.y + 0.05, p.z)
		_pad_a.visible = true
		var q := _spot(14.0, 22.0)
		_pad_b.position = Vector3(q.x, q.y + 0.05, q.z)
		_pad_b.visible = false
		_pad_a.visible = true


func _cargo_mesh() -> Node3D:
	var n := Node3D.new()
	n.position = Vector3(0, 1.4, 0)
	match String(def.get("cargo", "box")):
		"animal":
			return Scenery.animal(n, "cow", Vector3(0, 0, 0), 0.0)
		"hay":
			Scenery.hay_bale(n, Vector3(0, 0, 0), 0.0)
		"sand":
			Scenery.sand_pile(n, Vector3(0, 0, 0), 0.9)
		_:
			Scenery.part(n, Scenery.rbox(Vector3(1.1, 0.9, 1.0), 0.1), MatLib.wood(Color(0.8, 0.55, 0.3)), Vector3(0, 0.45, 0))
			Scenery.part(n, Scenery.rbox(Vector3(1.14, 0.12, 1.04), 0.03), MatLib.plastic(Color(0.95, 0.85, 0.3)), Vector3(0, 0.9, 0))
	return n


# ---------------------------------------------------------------- parking ---
var _slots: Array = []


func _start_parking() -> void:
	for i in total:
		var p := _spot(10.0, 16.0)
		var yaw := _rng.randf() * TAU
		var root := Node3D.new()
		root.position = Vector3(p.x, world.terrain_height(p.x, p.z) + 0.06, p.z)
		root.rotation.y = yaw
		add_child(root)
		var lines := [Vector3(-1.5, 0.02, 0), Vector3(1.5, 0.02, 0)]
		for l in lines:
			Scenery.part(root, Scenery.rbox(Vector3(0.14, 0.02, 5.2), 0.02), MatLib.road_mark(), l)
		Scenery.part(root, Scenery.rbox(Vector3(3.0, 0.02, 0.14), 0.02), MatLib.road_mark(), Vector3(0, 0.02, -2.6))
		var arrow := Label3D.new()
		arrow.text = "P"
		arrow.font_size = 128
		arrow.pixel_size = 0.01
		arrow.rotation_degrees = Vector3(-90, 0, 0)
		arrow.position = Vector3(0, 0.05, 0.5)
		root.add_child(arrow)
		_slots.append({"root": root, "ok": false, "t": 0.0})


func _process(delta: float) -> void:
	if _finished or world == null or world.player == null or not is_instance_valid(world.player):
		return
	var pl: VehicleController = world.player
	if kind == "parking":
		for s in _slots:
			if s["ok"]:
				continue
			var root: Node3D = s["root"]
			var local := root.global_transform.affine_inverse() * pl.global_position
			var fwd_ok := absf(pl.global_transform.basis.z.dot(root.global_transform.basis.z)) > 0.94
			var inside := absf(local.x) < 1.5 and absf(local.z) < 2.4
			if inside and fwd_ok and absf(pl.speed) < 1.6:
				s["t"] += delta
				if s["t"] > 0.9:
					s["ok"] = true
					_parked(root)
			else:
				s["t"] = 0.0


func _parked(root: Node3D) -> void:
	_burst(root.global_position + Vector3(0, 1.2, 0), Color(0.45, 1.0, 0.55))
	AudioManager.play_success()
	done += 1
	_progress()
	if done >= total:
		_finish()


# ------------------------------------------------------------------ match ---
const MATCH_COLORS := [
	Color(0.93, 0.24, 0.21), Color(0.18, 0.52, 0.95), Color(0.98, 0.8, 0.2),
	Color(0.34, 0.78, 0.36), Color(0.62, 0.36, 0.9), Color(1.0, 0.56, 0.16),
]


func _start_match() -> void:
	var ids := ["car_red", "sport", "suv", "van", "pickup", "police"]
	var n := mini(3 + total, ids.size())
	var palette := MATCH_COLORS.duplicate()
	palette.shuffle()
	for i in n:
		var ang := TAU * float(i) / float(n)
		var p := _origin() + Vector3(cos(ang) * 11.0, 0, sin(ang) * 11.0)
		p.y = world.terrain_height(p.x, p.z)
		var d := VehicleDB.get_vehicle(ids[i % ids.size()])
		if d == null:
			continue
		var c: Color = palette[i % palette.size()]
		var m := VehicleManager.decor(d, self, p, atan2(-(p - _origin()).x, -(p - _origin()).z) + PI, c)
		var a := Area3D.new()
		a.position = Vector3(0, 1.0, 0)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(d.width + 0.6, 2.2, d.length + 0.4)
		cs.shape = bs
		a.add_child(cs)
		m.add_child(a)
		a.body_entered.connect(func(body: Node3D) -> void: _match_hit(m, c, body))
		_round_cars.append({"node": m, "color": c})
	_next_match_round()


func _next_match_round() -> void:
	var pick: Dictionary = _round_cars[_rng.randi() % _round_cars.size()]
	_round_color = pick["color"]
	if _hint_label != null and is_instance_valid(_hint_label):
		_hint_label.queue_free()
	_hint_label = Label3D.new()
	_hint_label.text = "Найди такой же цвет!"
	_hint_label.font_size = 56
	_hint_label.pixel_size = 0.012
	_hint_label.modulate = _round_color
	_hint_label.outline_size = 12
	_hint_label.position = Vector3(0, 5.4, 0)
	_hint_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint_label.no_depth_test = true
	add_child(_hint_label)
	_hint_label.global_position = _origin() + Vector3(0, 5.0, 0)


func _match_hit(m: Node3D, c: Color, body: Node3D) -> void:
	if _finished or not body is VehicleController:
		return
	if c.is_equal_approx(_round_color):
		_burst(m.global_position + Vector3(0, 2.0, 0), c)
		done += 1
		AudioManager.play_success()
		if done >= total:
			_finish()
			return
		_progress()
		_next_match_round()
	else:
		var tw := create_tween()
		tw.tween_property(m, "rotation:z", 0.06, 0.1)
		tw.tween_property(m, "rotation:z", -0.06, 0.1)
		tw.tween_property(m, "rotation:z", 0.0, 0.1)
		AudioManager.play_sfx("click", -6.0, 0.8)
		AudioManager.say("try_again")


# ------------------------------------------------------------ checkpoints ---
var _gates: Array = []


func _start_checkpoints() -> void:
	var prev := _origin()
	for i in total:
		var p := _spot(10.0, 18.0)
		if i > 0:
			# keep the route flowing forward instead of jumping around
			p = prev + (p - prev).normalized() * _rng.randf_range(12.0, 18.0)
			p.y = world.terrain_height(p.x, p.z)
		prev = p
		var g := Node3D.new()
		g.position = p
		add_child(g)
		var ring := MeshInstance3D.new()
		ring.mesh = MeshGen.torus(3.0, 0.22, 24, 8)
		ring.position = Vector3(0, 2.8, 0)
		ring.rotation_degrees = Vector3(90, 0, 0)
		var mat := MatLib.emissive(Color(0.4, 0.9, 1.0), 0.8)
		ring.material_override = mat
		g.add_child(ring)
		var num := Label3D.new()
		num.text = str(i + 1)
		num.font_size = 96
		num.pixel_size = 0.012
		num.position = Vector3(0, 2.8, 0.4)
		num.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		num.no_depth_test = true
		g.add_child(num)
		var rec := {"node": g, "ring": ring, "mat": mat, "idx": i}
		_gates.append(rec)
		var area := Area3D.new()
		area.position = Vector3(0, 2.0, 0)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 3.0
		cs.shape = sh
		area.add_child(cs)
		g.add_child(area)
		area.body_entered.connect(func(body: Node3D) -> void: _gate_hit(rec, body))
	_refresh_gates()


func _refresh_gates() -> void:
	for g in _gates:
		var mat: StandardMaterial3D = g["mat"]
		var ok: bool = int(g["idx"]) < _next_gate
		var active: bool = int(g["idx"]) == _next_gate
		mat.emission = Color(0.5, 1.0, 0.6) if ok else Color(0.4, 0.9, 1.0)
		mat.emission_energy_multiplier = 0.2 if ok else (2.2 if active else 0.5)


func _gate_hit(rec: Dictionary, body: Node3D) -> void:
	if _finished or not body is VehicleController:
		return
	if int(rec["idx"]) != _next_gate:
		return
	_next_gate += 1
	done = _next_gate
	AudioManager.play_success()
	_burst(rec["node"].global_position + Vector3(0, 2.6, 0), Color(0.5, 1.0, 0.6))
	_refresh_gates()
	_progress()
	if done >= total:
		_finish()


# -------------------------------------------------------------------- dig ---
var _spots: Array = []


func _start_dig() -> void:
	for i in total:
		var p := _spot(5.0, 14.0)
		var root := Node3D.new()
		root.position = p
		add_child(root)
		var pile := Scenery.sand_pile(root, Vector3.ZERO, 1.6 + _rng.randf() * 0.8)
		var rec := {"node": root, "pile": pile, "dug": false, "pos": p}
		_spots.append(rec)
		_goals.append(rec)


func _start_water() -> void:
	for i in total:
		var p := _spot(5.0, 14.0)
		var root := Node3D.new()
		root.position = p
		add_child(root)
		Scenery.part(root, Scenery.cyl(0.6, 0.45, 0.6, 12), MatLib.plastic(Color(0.8, 0.45, 0.25)), Vector3(0, 0.3, 0))
		var plant := Scenery.part(root, MeshGen.sphere(Vector3(0.1, 0.1, 0.1), 4, 6), MatLib.foliage(Color(0.3, 0.75, 0.3), 0.15, 0.6), Vector3(0, 1.0, 0))
		var rec := {"node": root, "plant": plant, "done": false, "pos": p}
		_spots.append(rec)
		_goals.append(rec)


func _start_help() -> void:
	var colors := [Color(0.9, 0.5, 0.2), Color(0.5, 0.5, 0.9), Color(0.9, 0.9, 0.3)]
	for i in total:
		var p := _spot(8.0, 16.0)
		var d := VehicleDB.get_vehicle("car_red" if i % 2 == 0 else "pickup")
		if d == null:
			continue
		var m := VehicleManager.decor(d, self, p, _rng.randf() * TAU, colors[i % colors.size()])
		m.rotation.z = -0.22
		var lbl := Label3D.new()
		lbl.text = "Помоги!"
		lbl.font_size = 64
		lbl.pixel_size = 0.012
		lbl.modulate = Color(1, 0.9, 0.5)
		lbl.position = Vector3(0, 3.0, 0)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		m.add_child(lbl)
		var rec := {"node": m, "label": lbl, "done": false, "pos": p}
		_spots.append(rec)
		_goals.append(rec)


## Action button near a target (dig, water, help).
func on_action(player: Node3D) -> bool:
	if _finished or player == null:
		return false
	for rec in _spots:
		var is_done: bool = rec.get("done", rec.get("dug", false))
		if is_done:
			continue
		var n: Node3D = rec["node"]
		if not is_instance_valid(n):
			continue
		if n.global_position.distance_to(player.global_position) > 6.0:
			continue
		match kind:
			"dig":
				_dig(rec)
			"water":
				_water(rec)
			"help":
				_help(rec)
		return true
	return false


func _dig(rec: Dictionary) -> void:
	rec["dug"] = true
	var pile: Node3D = rec["pile"]
	var tw := create_tween()
	tw.tween_property(pile, "scale", Vector3(1.2, 0.2, 1.2), 0.5).set_trans(Tween.TRANS_BACK)
	_burst(rec["pos"] + Vector3(0, 1.0, 0), Color(0.8, 0.65, 0.4))
	AudioManager.play_sfx("dig", -4.0, 1.0)
	_count_done("dig")


func _water(rec: Dictionary) -> void:
	rec["done"] = true
	var plant: Node3D = rec["plant"]
	var tw := create_tween()
	tw.tween_property(plant, "scale", Vector3(9, 9, 9), 1.0).set_trans(Tween.TRANS_BACK)
	var spray := CPUParticles3D.new()
	spray.position = rec["pos"] + Vector3(0, 2.2, 0)
	spray.amount = 30
	spray.lifetime = 0.9
	spray.one_shot = true
	spray.explosiveness = 0.6
	spray.direction = Vector3(0, -1, 0)
	spray.spread = 20.0
	spray.initial_velocity_min = 3.0
	spray.initial_velocity_max = 5.0
	spray.gravity = Vector3(0, -9, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	spray.mesh = sm
	spray.material_override = MatLib.plastic(Color(0.6, 0.85, 1.0))
	add_child(spray)
	spray.emitting = true
	get_tree().create_timer(1.6).timeout.connect(spray.queue_free)
	AudioManager.play_sfx("water", -6.0, 1.0)
	_count_done("water")


func _help(rec: Dictionary) -> void:
	rec["done"] = true
	var lbl: Label3D = rec["label"]
	lbl.text = "Спасибо!"
	lbl.modulate = Color(0.6, 1.0, 0.6)
	var m: Node3D = rec["node"]
	var tw := create_tween()
	tw.tween_property(m, "rotation:z", 0.0, 0.8).set_trans(Tween.TRANS_BOUNCE)
	_burst(m.global_position + Vector3(0, 2.4, 0), Color(1, 0.9, 0.4))
	AudioManager.say("thanks")
	_count_done("help")


func _count_done(_what: String) -> void:
	done += 1
	_progress()
	if done >= total:
		_finish()


# ------------------------------------------------------------------ finish ---
func _finish() -> void:
	if _finished:
		return
	_finished = true
	var stars := int(def.get("reward", 3)) + maxi(total - 3, 0)
	world.reward(stars, "Здорово!")
	QuestSystem.report(String(def.get("event", "deliver")), 1)
	var stat := String(def.get("stat", "minigames"))
	GameState.add_stat(stat)
	GameState.add_stat("minigames")
	AudioManager.play_success()
	AudioManager.say("cheer")
	if station != null:
		station.set_done(true)
	finished.emit(id)
	get_tree().create_timer(1.6).timeout.connect(queue_free)


func abort() -> void:
	_finished = true
	queue_free()
