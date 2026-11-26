class_name VehicleData
extends Resource

## Data description of one drivable machine.
## Adding a new vehicle = one entry in VehicleDB + one optional build_* function.

var id := "car"
var title := "Машинка"
var kind := "car"
var category := "car"          # car / work / emergency / big

var length := 4.0              # along -Z (forward)
var width := 1.8
var height := 1.45

var mass := 1200.0
var max_speed := 24.0
var power := 12.0
var brake_force := 16.0
var steer_deg := 32.0

var wheel_radius := 0.34
var wheel_width := 0.24
var wheel_x := 0.8
var wheel_z_front := 1.25
var wheel_z_rear := -1.25
var wheel_z_extra := 0.0       # decorative third axle (0 = none)
var tracked := false

var color := Color(0.93, 0.24, 0.21)
var unlock_stars := 0
var engine_sound := "engine_car"
var engine_pitch := 1.0
var special := ""              # excavator / bulldozer / loader / crane / dump / tractor / roller / fire / police / tow / garbage
var attachment := ""           # plow / seeder / water / harvester / trailer
var description := ""


func wheel_positions() -> Array:
	var h := wheel_radius
	return [
		Vector3(wheel_x, h, wheel_z_front),
		Vector3(-wheel_x, h, wheel_z_front),
		Vector3(wheel_x, h, wheel_z_rear),
		Vector3(-wheel_x, h, wheel_z_rear),
	]


func front_axle() -> float:
	return wheel_z_front


func rear_axle() -> float:
	return wheel_z_rear
