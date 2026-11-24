class_name FarmSystem
extends Node

## Farm work loop. Plots are tilled, seeded, watered and grown in the open
## world: the tractor drives over a plot with the matching implement attached,
## crops are picked by hand or with the harvester, and the load is carried
## on the trailer to the barn. Animals are fed with hay from the hay store.

const COLS := 4
const ROWS := 3
const SPACING := 9.0
const PLOT := 7.2

var world: WorldBase
var origin := Vector3(-48, 0, -16)
var plots: Array = []
var animals: Array = []
var _pen_area: Area3D
var _feed_cooldown := 0.0


func setup(w: WorldBase) -> void:
	world = w
	for r in ROWS:
		for c in COLS:
			_make_plot(c + r * COLS, origin + Vector3(c * SPACING, 0, r * SPACING))


func _make_plot(idx: int, p: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Plot%d" % idx
	root.position = Vector3(p.x, world.terrain_height(p.x, p.z), p.z)
	world.add_child(root)
	var soil := MeshInstance3D.new()
	soil.mesh = Scenery.rbox(Vector3(PLOT, 0.12, PLOT), 0.04)
	soil.position = Vector3(0, 0.04, 0)
	root.add_child(soil)
	var body := StaticBody3D.new()
	body.set_meta("surface", "soil")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(PLOT, 0.12, PLOT)
	cs.shape = bs
	cs.position = Vector3(0, 0.04, 0)
	body.add_child(cs)
	root.add_child(body)
	var area := Area3D.new()
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(PLOT - 0.4, 2.0, PLOT - 0.4)
	acs.shape = abox
	acs.position = Vector3(0, 1.0, 0)
	area.add_child(acs)
	root.add_child(area)
	var rec := {"root": root, "soil": soil, "state": 0, "crop": null, "furrows": null, "area": area, "idx": idx, "busy": false}
	area.body_entered.connect(func(b: Node3D) -> void: _on_plot_body(rec, b))
	plots.append(rec)
	_set_state(rec, 0)


func _set_state(rec: Dictionary, st: int) -> void:
	rec["state"] = st
	var soil: MeshInstance3D = rec["soil"]
	match st:
		0:
			soil.material_override = MatLib.ground("grass")
			soil.mesh = Scenery.rbox(Vector3(PLOT, 0.12, PLOT), 0.04)
		_:
			soil.material_override = MatLib.ground("plowed")
	if st >= 1 and rec["furrows"] == null:
		var f := Node3D.new()
		var root: Node3D = rec["root"]
		root.add_child(f)
		for i in 5:
			var z := -PLOT * 0.4 + i * PLOT * 0.2
			Scenery.part(f, Scenery.rbox(Vector3(PLOT * 0.9, 0.05, 0.22), 0.02), MatLib.ground("dirt"), Vector3(0, 0.12, z))
		rec["furrows"] = f
	if rec["furrows"] != null:
		(rec["furrows"] as Node3D).visible = st >= 1
	if st >= 2 and rec["crop"] == null:
		var c := Node3D.new()
		var root2: Node3D = rec["root"]
		root2.add_child(c)
		for i in 9:
			var x := -PLOT * 0.36 + (i % 3) * PLOT * 0.36
			var z2 := -PLOT * 0.36 + (i / 3) * PLOT * 0.36
			var stalk := Scenery.part(c, Scenery.cone_mesh(0.14, 0.6), MatLib.foliage(Color(0.35, 0.78, 0.3), 0.2, 0.6), Vector3(x, 0.4, z2))
			stalk.name = "Stalk"
		rec["crop"] = c
	if rec["crop"] != null:
		(rec["crop"] as Node3D).visible = st >= 2
		(rec["crop"] as Node3D).scale = Vector3.ONE * (0.3 if st == 2 else 1.0)


func _on_plot_body(rec: Dictionary, body: Node3D) -> void:
	if not body is VehicleController or rec["busy"]:
		return
	var pl := body as VehicleController
	if pl.speed < -0.2 and absf(pl.speed) > 0.5:
		return
	var st: int = int(rec["state"])
	match pl.tool:
		"plow":
			if st == 0 and absf(pl.speed) > 0.6:
				_plow(rec)
		"seeder":
			if st == 1 and absf(pl.speed) > 0.6:
				_seed(rec)
		"sprayer":
			if st == 2 and absf(pl.speed) > 0.6:
				_water(rec)
		"harvester":
			if st == 4 and absf(pl.speed) > 0.6:
				_harvest(rec, pl)


func _plow(rec: Dictionary) -> void:
	_set_state(rec, 1)
	_dust(rec)
	QuestSystem.report("plow", 1)
	AudioManager.play_sfx("dig", -6.0, 0.9)
	world.reward(1, "Вспахано!")
	GameState.add_stat("plow")


func _seed(rec: Dictionary) -> void:
	_set_state(rec, 2)
	QuestSystem.report("plant", 1)
	GameState.add_stat("plant")
	AudioManager.play_sfx("pop", -8.0, 1.2)
	world.reward(1, "Посажено!")


func _water(rec: Dictionary) -> void:
	rec["busy"] = true
	_spray(rec)
	AudioManager.play_sfx("water", -6.0, 1.0)
	_set_state(rec, 3)
	var crop: Node3D = rec["crop"]
	crop.scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(crop, "scale", Vector3.ONE, 3.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		rec["busy"] = false
		_set_state(rec, 4)
		AudioManager.say("ripe")
	)
	QuestSystem.report("water", 1)
	GameState.add_stat("waters")
	world.reward(1, "Растёт!")


func _harvest(rec: Dictionary, pl: VehicleController) -> void:
	if pl.cargo_kind != "" and pl.cargo_kind != "crop" and pl.cargo > 0.0:
		UIManager.toast("Сначала разгрузи груз!", "farm", UIKit.ACCENT)
		return
	if pl.cargo >= pl.cargo_max and pl.cargo_max > 0.0:
		UIManager.toast("Прицеп полный — отвези урожай в амбар!", "farm", UIKit.ACCENT)
		return
	_pick(rec, pl)


func _pick(rec: Dictionary, pl: VehicleController) -> void:
	_set_state(rec, 1)
	pl.cargo_kind = "crop"
	pl.cargo = minf(pl.cargo + 1.0, maxf(pl.cargo_max, 1.0))
	pl.cargo_changed.emit(pl.cargo)
	_add_cargo_visual(pl)
	QuestSystem.report("harvest", 1)
	GameState.add_stat("harvest")
	AudioManager.play_success()
	world.reward(1, "Урожай!")


func on_action(player: Node3D) -> bool:
	if not player is VehicleController:
		return false
	var pl := player as VehicleController
	for rec in plots:
		var root: Node3D = rec["root"]
		if root.global_position.distance_to(pl.global_position) > 6.0:
			continue
		var st: int = int(rec["state"])
		if st == 4:
			_harvest(rec, pl)
			return true
		if st == 0 and pl.tool == "plow":
			_plow(rec)
			return true
		if st == 1 and pl.tool == "seeder":
			_seed(rec)
			return true
		if st == 2 and pl.tool == "sprayer":
			_water(rec)
			return true
	return false


func _dust(rec: Dictionary) -> void:
	_burst((rec["root"] as Node3D).global_position + Vector3(0, 0.8, 0), Color(0.6, 0.45, 0.3))


func _spray(rec: Dictionary) -> void:
	var root: Node3D = rec["root"]
	var p := CPUParticles3D.new()
	p.position = Vector3(0, 2.0, 0)
	p.amount = 40
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.2
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -8, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	p.mesh = sm
	p.material_override = MatLib.plastic(Color(0.65, 0.88, 1.0))
	root.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.8).timeout.connect(p.queue_free)


func _burst(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 20
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -5, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	p.mesh = sm
	p.material_override = MatLib.plastic(color)
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _add_cargo_visual(pl: VehicleController) -> void:
	var root: Node3D = pl.model.cargo_root
	var n := root.get_child_count()
	var b := Scenery.ball(Vector3(0.28, 0.28, 0.28), 10)
	Scenery.part(root, b, MatLib.plastic(Color(0.95, 0.35, 0.2)), Vector3(-0.5 + (n % 4) * 0.34, 0.3 + (n / 4) * 0.3, 0.0))


# -------------------------------------------------------- stations & pen ---
func on_station(s: Station) -> bool:
	match s.kind:
		"farm_hay":
			return _take_hay(s)
		"farm_store":
			return _store(s)
		"farm_feed":
			return _feed_hint(s)
	return false


func _take_hay(_s: Station) -> bool:
	var pl: VehicleController = world.player
	if pl.cargo_kind == "crop" and pl.cargo > 0.0:
		UIManager.toast("Сначала отвези урожай в амбар!", "farm", UIKit.ACCENT)
		return true
	pl.cargo_kind = "hay"
	pl.cargo = pl.cargo_max
	pl.cargo_changed.emit(pl.cargo)
	AudioManager.play_success()
	UIManager.toast("Сено в кузове! Вези к животным.", "farm", UIKit.ACCENT)
	return true


func _store(_s: Station) -> bool:
	var pl: VehicleController = world.player
	if pl.cargo <= 0.0 or pl.cargo_kind != "crop":
		UIManager.toast("Привези урожай с поля", "farm", UIKit.ACCENT)
		return true
	var n := int(pl.cargo)
	pl.cargo = 0.0
	pl.cargo_kind = ""
	pl.cargo_changed.emit(0.0)
	for c in pl.model.cargo_root.get_children():
		c.queue_free()
	QuestSystem.report("deliver_crop", n)
	GameState.add_stat("deliveries", n)
	world.reward(n * 2, "Урожай в амбаре!")
	AudioManager.say("cheer")
	return true


func _feed_hint(_s: Station) -> bool:
	UIManager.toast("Привези сено и въезжай в загон", "farm", UIKit.ACCENT)
	return true


func setup_pen(center: Vector3) -> void:
	_pen_area = Area3D.new()
	_pen_area.position = center + Vector3(0, 1.0, 0)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(12, 2.0, 12)
	cs.shape = bx
	_pen_area.add_child(cs)
	world.add_child(_pen_area)
	_pen_area.body_entered.connect(_on_pen)
	var kinds := ["cow", "pig", "sheep", "chicken", "horse"]
	for i in kinds.size():
		var a := Vector3(cos(i * 1.3) * 3.5, 0, sin(i * 1.3) * 3.5)
		var p := center + a
		p.y = world.terrain_height(p.x, p.z)
		var n := Scenery.animal(world, kinds[i], p, i * 1.7)
		animals.append(n)


func _on_pen(body: Node3D) -> void:
	if not body is VehicleController:
		return
	var pl := body as VehicleController
	if pl.cargo_kind != "hay" or pl.cargo <= 0.0 or _feed_cooldown > 0.0:
		return
	_feed_cooldown = 1.2
	pl.cargo = maxf(0.0, pl.cargo - 1.0)
	pl.cargo_changed.emit(pl.cargo)
	if pl.cargo <= 0.0:
		pl.cargo_kind = ""
	for n in animals:
		if is_instance_valid(n):
			var base: Vector3 = n.position
			var tw := create_tween()
			tw.tween_property(n, "position:y", base.y + 0.35, 0.18)
			tw.tween_property(n, "position:y", base.y, 0.25)
			_burst(n.global_position + Vector3(0, 1.4, 0), Color(1, 0.4, 0.6))
	AudioManager.play_sfx("animal_moo", -6.0, 1.0)
	QuestSystem.report("feed", 1)
	GameState.add_stat("feed")
	world.reward(1, "Накормили!")


func _process(delta: float) -> void:
	_feed_cooldown = maxf(0.0, _feed_cooldown - delta)
