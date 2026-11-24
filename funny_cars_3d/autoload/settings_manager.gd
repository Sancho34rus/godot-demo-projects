extends Node

## Player settings: sound, graphics profile, control mode.
## Stored separately from the save game so it survives a progress reset.

signal changed

const PATH := "user://settings.json"

var music_on := true
var sfx_on := true
var voice_on := true
var music_volume := 0.65
var sfx_volume := 0.85
var graphics := "medium"          # low / medium / high
var controls := "simple"          # simple (one big gas pedal) / full
var camera_invert := false
var show_fps := false
var haptics := true


func _ready() -> void:
	load_settings()
	apply_graphics()


func quality() -> float:
	match graphics:
		"low": return 0.55
		"high": return 1.0
		_: return 0.8


func shadows_enabled() -> bool:
	return graphics != "low"


func particles_amount() -> int:
	match graphics:
		"low": return 6
		"high": return 24
		_: return 14


func view_distance() -> float:
	match graphics:
		"low": return 140.0
		"high": return 320.0
		_: return 220.0


func apply_graphics() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	match graphics:
		"low":
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.scaling_3d_scale = 0.8
		"high":
			vp.msaa_3d = Viewport.MSAA_4X
			vp.scaling_3d_scale = 1.0
		_:
			vp.msaa_3d = Viewport.MSAA_2X
			vp.scaling_3d_scale = 0.95


const SETTING_KEYS := ["music_on", "sfx_on", "voice_on", "music_volume", "sfx_volume",
	"graphics", "controls", "camera_invert", "show_fps", "haptics"]


func set_value(key: String, value) -> void:
	if not (key in SETTING_KEYS):
		return
	set(key, value)
	if key == "graphics":
		apply_graphics()
	changed.emit()
	save_settings()


func save_settings() -> void:
	var d := {
		"music_on": music_on, "sfx_on": sfx_on, "voice_on": voice_on,
		"music_volume": music_volume, "sfx_volume": sfx_volume,
		"graphics": graphics, "controls": controls,
		"camera_invert": camera_invert, "show_fps": show_fps, "haptics": haptics,
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d, "  "))
	f.close()


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	music_on = d.get("music_on", music_on)
	sfx_on = d.get("sfx_on", sfx_on)
	voice_on = d.get("voice_on", voice_on)
	music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	graphics = String(d.get("graphics", graphics))
	controls = String(d.get("controls", controls))
	camera_invert = bool(d.get("camera_invert", camera_invert))
	show_fps = bool(d.get("show_fps", show_fps))
	haptics = bool(d.get("haptics", haptics))


func vibrate(ms: int = 30) -> void:
	if not haptics:
		return
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
