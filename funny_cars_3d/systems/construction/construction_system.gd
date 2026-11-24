class_name ConstructionSystem
extends Node

## Стройка: экскаватор копает песок в котловане, самосвал везёт его на свалку
## и разгружает — горка растёт. Бульдозер сдвигает кучи, каток уплотняет гравий
## и делает асфальт, кран поднимает кубики и строит башню на площадке.

const PIT_RECT := Rect2(Vector2(-46, -30), Vector2(26, 16))
const DUMP_POS := Vector3(34, 0, 20)
const ROAD_A := Vector3(-8, 0, 44)
const ROAD_B := Vector3(56, 0, 44)
const BUILD_POS := Vector3(-18, 0, -62)

var world: WorldBase
var sand_in_pit := 9.0
var pit_pile: Node3D
var dump_piles: Array = []
var dump_total := 0.0
var road_strip: MeshInstance3D
var road_progress := 0.0
var road_area: Area3D
var crane_tower: Node3D
var crates: Array = []
var build_blocks := 0
var _roller_inside := false
var _road_done := false
var _sand_cd := 0.0


func setup(w: WorldBase) -> void:
	world = w
	_build_pit()
	_build_dump()
	_build_road()
	_build_crane_site()
	_build_warehouses()


# -------------------------------------------------------------------- pit ---
func _build_pit() -> void:
	var c := PIT_RECT.get_center()
	var root := Node3D.new()
	root.name = "Pit"
	world.add_child(root)
	pit_pile = Scenery.sand_pile(root, Vector3(c.x, -2.0, c.y), 4.5)
	# hazard sign
	Scenery.sign(root, Vector3(PIT_RECT.position.x - 2.0, 0, PIT_RECT.end.y + 2.0), 0.0, "bump")
	_update_pit()


func _update_pit() -> void:
	var s := clampf(sand_in_pit / 9.0, 0.15, 1.0)
	pit_pile.scale = Vector3(s, maxf(0.2, s * 0.8), s)


# ------------------------------------------------------------------- dump ---
func _build_dump() -> void:
	Scenery.solid(world, Vector3(18, 0.05, 14), DUMP_POS + Vector3(0, 0.03, 0), MatLib.ground("gravel"), "gravel")
	var lbl := Label3D.new()
	lbl.text = "Свалка песка"
	lbl.font_size = 56
	lbl.pixel_size = 0.012
	lbl.position = DUMP_POS + Vector3(0, 3.0, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	world.add_child(lbl)


func _add_dump_pile(amount: float) -> void:
	dump_total += amount
	var idx := dump_piles.size()
	if dump_piles.is_empty() or dump_piles[-1]["count"] >= 3:
		var root := Scenery.root(world, "DumpPile%d" % idx, DUMP_POS + Vector3(-5.0 + idx * 3.2, 0, randf_range(-2, 2)))
		dump_piles.append({"root": root, "count": 0})
	var rec: Dictionary = dump_piles[-1]
	rec["count"] += 1
	var r: Node3D = rec["root"]
	for c in r.get_children():
		c.queue_free()
	Scenery.sand_pile(r, Vector3.ZERO, 1.2 + 0.4 * rec["count"])


# ------------------------------------------------------------------- road ---
func _build_road() -> void:
	var d := ROAD_B - ROAD_A
	var yaw := atan2(-d.x, -d.z)
	var r := Scenery.root(world, "RoadSite", (ROAD_A + ROAD_B) * 0.5 + Vector3(0, 0.05, 0), yaw)
	road_strip = Scenery.part(r, Scenery.rbox(Vector3(7.0, 0.1, d.length()), 0.02), MatLib.ground("gravel"), Vector3.ZERO)
	var body := Scenery.collider_only(r, Vector3(7.0, 0.12, d.length()), Vector3.ZERO, "gravel")
	body.name = "RoadBody"
	road_area = Area3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(7.0, 2.0, d.length())
	cs.shape = bs
	cs.position = Vector3(0, 1.0, 0)
	road_area.add_child(cs)
	r.add_child(road_area)
	road_area.name = "RollArea"


func _update_road(delta: float) -> void:
	if _road_done:
		return
	for b in road_area.get_overlapping_bodies():
		if b is VehicleController and (b as VehicleController).data.kind == "roller":
			road_progress = minf(1.0, road_progress + delta * 0.18)
			if not _roller_inside:
				_roller_inside = true
			_flatten_mark()
			break
	if road_progress >= 1.0 and not _road_done:
		_road_done = true
		road_strip.material_override = MatLib.ground("asphalt")
		QuestSystem.report("compact", 1)
		GameState.add_stat("compact")
		world.reward(4, "Дорога готова!")
		AudioManager.say("road_done")


func _flatten_mark() -> void:
	# compaction changes the surface colour a bit at a time
	var t := road_progress
	var mat := road_strip.material_override as ShaderMaterial
	if mat == null:
		road_strip.material_override = MatLib.ground("gravel")
	road_strip.scale = Vector3(1.0, 1.0 - 0.15 * t, 1.0)


# ------------------------------------------------------------- crane site ---
func _build_crane_site() -> void:
	crane_tower = Scenery.crane_tower(world, Vector3(-50, 0, 40), 20.0, 0.0)
	# building under construction: a low frame of steel and crates waiting
	for i in 3:
		crates.append(Scenery.crate(world, BUILD_POS + Vector3(-6.0 + i * 2.2, 0, 4.0), Color(0.82, 0.55, 0.3), 0.0, 1.6))
	Scenery.part(world, Scenery.rbox(Vector3(10.0, 0.2, 10.0), 0.05), MatLib.ground("concrete"), BUILD_POS + Vector3(0, 0.1, 0))


func _update_crane(delta: float) -> void:
	if crane_tower == null:
		return
	var jib: Node3D = crane_tower.get_meta("jib")
	jib.rotation.y += delta * 0.12


# -------------------------------------------------------------- warehouses ---
func _build_warehouses() -> void:
	Scenery.warehouse(world, Vector3(54, 0, -48), -PI * 0.5, Color(0.9, 0.7, 0.45))
	Scenery.warehouse(world, Vector3(72, 0, 6), -PI * 0.5, Color(0.7, 0.8, 0.95))
	for i in 4:
		Scenery.barrel(world, Vector3(44 + i * 1.2, 0, -20), Color(0.95, 0.4, 0.2) if i % 2 == 0 else Color(0.3, 0.6, 0.95))
	Scenery.hay_bale(world, Vector3(30, 0, -54), 0.0)
	Scenery.hay_bale(world, Vector3(32, 0, -54), 0.0)


# ------------------------------------------------------------------ actions ---
func on_action(player: Node3D) -> bool:
	if not player is VehicleController:
		return false
	var pl := player as VehicleController
	var kind := pl.data.kind
	var pos := pl.global_position
	# 1) dig with an excavator or loader next to the pit
	if (kind == "excavator" or kind == "loader") and _in_pit_zone(pos, 9.0):
		if pl.cargo_kind == "sand" and pl.cargo >= pl.cargo_max:
			UIManager.toast("Ковш полный — отвези песок на свалку", "bucket", UIKit.ACCENT)
			return true
		if sand_in_pit <= 0.2:
			UIManager.toast("Котлован пуст. Молодец!", "check", UIKit.ACCENT)
			return true
		var take := minf(1.0, sand_in_pit)
		sand_in_pit -= take
		pl.cargo_kind = "sand"
		pl.cargo = minf(pl.cargo + take, pl.cargo_max)
		pl.cargo_changed.emit(pl.cargo)
		_update_pit()
		AudioManager.play_sfx("dig", -4.0, 1.0)
		QuestSystem.report("dig", 1)
		GameState.add_stat("dig")
		world.reward(1, "Копаем!")
		return true
	# 2) unload sand from a dump truck (or any vehicle carrying sand) at the dump
	if pl.cargo_kind == "sand" and pl.cargo > 0.0 and pos.distance_to(DUMP_POS) < 12.0:
		var n := pl.cargo
		pl.cargo = 0.0
		pl.cargo_kind = ""
		pl.cargo_changed.emit(0.0)
		_add_dump_pile(n)
		QuestSystem.report("load", int(n))
		GameState.add_stat("loads", int(n))
		AudioManager.play_success()
		world.reward(int(n) * 2, "Песок выгружен!")
		return true
	# 3) crane hook: pick up or set down a crate
	if kind == "crane" and pl.get_mount("hook") != null:
		return _crane_action(pl)
	# 4) bulldozer: push a sand pile flat
	if kind == "bulldozer":
		for pile in dump_piles:
			var root: Node3D = pile["root"]
			if root.global_position.distance_to(pos) < 6.0 and pile["count"] > 0:
				pile["count"] = 0
				var tw := create_tween()
				tw.tween_property(root, "scale", Vector3(1.6, 0.25, 1.6), 0.6)
				AudioManager.play_sfx("tool", -6.0, 0.7)
				world.reward(1, "Разровняли!")
				return true
	return false


func _in_pit_zone(p: Vector3, margin: float) -> bool:
	var c := PIT_RECT.get_center()
	return absf(p.x - c.x) < PIT_RECT.size.x * 0.5 + margin and absf(p.z - c.y) < PIT_RECT.size.y * 0.5 + margin


func _crane_action(pl: VehicleController) -> bool:
	var hook: Node3D = pl.get_mount("hook")
	var hook_pos := hook.global_position
	if held_crate != null and is_instance_valid(held_crate):
		# set down the crate: it becomes part of the building
		var drop := held_crate.global_position
		held_crate.reparent(world)
		held_crate.global_position = Vector3(drop.x, world.terrain_height(drop.x, drop.z), drop.z)
		crates.append(held_crate)
		held_crate = null
		build_blocks += 1
		QuestSystem.report("crane_pick", 1)
		GameState.add_stat("cranes")
		world.reward(2, "Кубик на месте!")
		AudioManager.play_success()
		return true
	for c in crates:
		if is_instance_valid(c) and c.global_position.distance_to(hook_pos) < 4.0:
			crates.erase(c)
			c.reparent(hook)
			c.position = Vector3(0, -0.6, 0)
			held_crate = c
			AudioManager.play_sfx("click", -4.0, 1.2)
			UIManager.toast("Кран зацепил кубик!", "crane", UIKit.ACCENT)
			return true
	return false


var held_crate: Node3D = null


# ---------------------------------------------------------------- process ---
func _process(delta: float) -> void:
	_update_road(delta)
	_update_crane(delta)
	_sand_cd -= delta
	if world.player != null and is_instance_valid(world.player):
		var pl: VehicleController = world.player
		# a bulldozer flattening a pile: any touching bulldozer slowly levels it
		_roller_inside = false
		if pl.data.kind == "bulldozer" and absf(pl.speed) > 1.0:
			for pile in dump_piles:
				var root: Node3D = pile["root"]
				if root.global_position.distance_to(pl.global_position) < 3.0 and pile["count"] > 0:
					root.scale = root.scale.lerp(Vector3(1.0, 0.7, 1.0), delta * 0.4)
