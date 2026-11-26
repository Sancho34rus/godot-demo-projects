class_name VehicleManager
extends RefCounted

## Spawns playable and parked machines. Every vehicle is built from its data
## entry, so adding a machine to VehicleDB is all that is needed.

static func spawn(d: VehicleData, parent: Node3D, pos: Vector3, yaw: float) -> VehicleController:
	var v := VehicleController.new()
	v.name = "Vehicle_" + d.id
	v.position = pos
	v.rotation.y = yaw
	parent.add_child(v)
	v.setup(d)
	return v


## Static decorative vehicle (parked car, stopped truck). No physics.
static func decor(d: VehicleData, parent: Node3D, pos: Vector3, yaw: float, style_color: Color = Color(-1, 0, 0)) -> VehicleModel:
	var m := VehicleModel.new()
	m.name = "Decor_" + d.id
	m.position = pos
	m.rotation.y = yaw
	parent.add_child(m)
	m.build(d)
	var st := GameState.style(d.id)
	var c := style_color if style_color.r >= 0.0 else Color(String(st.get("color", d.color.to_html(false))))
	m.apply_style(c, Color(String(st.get("accent", "f2f6ff"))), Color(String(st.get("rim", "ccd3dc"))), int(st.get("sticker", 0)))
	return m
