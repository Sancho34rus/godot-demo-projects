class_name Station
extends Node3D

## A glowing, friendly hotspot in a territory. Drive or walk close and press
## the action button: workshops, minigames, gifts and farm/construction jobs
## are all started from stations, so every zone is built the same way.

@export var kind := "minigame"       # carwash, paint, repair, garage, minigame, gift, farm, construction, npc
@export var game_id := ""
@export var title := "Место"
@export var icon := "star"
@export var color := Color(1.0, 0.8, 0.25)
@export var radius := 6.0

var _ring: MeshInstance3D
var _label: Label3D
var _t := 0.0
var done := false


func _ready() -> void:
	add_to_group("station")
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.5
	tor.outer_radius = 1.9
	ring.mesh = tor
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(0, 0.12, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.75)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = mat
	add_child(ring)
	_ring = ring
	var lbl := Label3D.new()
	lbl.text = title
	lbl.font_size = 56
	lbl.pixel_size = 0.01
	lbl.outline_size = 10
	lbl.position = Vector3(0, 3.2, 0)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	add_child(lbl)
	_label = lbl


func _process(delta: float) -> void:
	_t += delta
	if _ring != null:
		_ring.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.06)
		_ring.rotation_degrees.y += delta * 40.0
	if _label != null:
		_label.position.y = 3.2 + sin(_t * 2.0) * 0.12


func set_done(v: bool) -> void:
	done = v
	if _label != null:
		_label.modulate = Color(0.7, 1.0, 0.7) if v else Color(1, 1, 1)
