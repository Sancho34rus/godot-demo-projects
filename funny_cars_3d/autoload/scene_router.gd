extends Node

## All scene navigation with a soft fade, so the child never gets lost.
## Territories, workshops and the garage are independent scenes that share the
## same vehicle, so any new location only needs a path added here.

const TERRITORY_SCENES := {
	"city": "res://worlds/city.tscn",
	"farm": "res://worlds/farm.tscn",
	"construction": "res://worlds/construction.tscn",
	"autotown": "res://worlds/autotown.tscn",
	"nature": "res://worlds/nature.tscn",
}

const TERRITORY_TITLES := {
	"city": "Город",
	"farm": "Ферма",
	"construction": "Стройка",
	"autotown": "Автогородок",
	"nature": "Секретная поляна",
}

const WORKSHOPS := {
	"car_wash": "res://systems/car_wash/car_wash.tscn",
	"paint": "res://systems/paint/paint_shop.tscn",
	"repair": "res://systems/repair/repair_shop.tscn",
	"garage": "res://ui/garage.tscn",
	"menu": "res://ui/main_menu.tscn",
}

var last_world := "res://worlds/city.tscn"
var current_territory := "city"
var busy := false


func goto_territory(id: String, spawn := "") -> void:
	if not TERRITORY_SCENES.has(id):
		return
	if not is_territory_unlocked(id):
		UIManager.toast("Собери звёздочки, чтобы открыть!", "star", UIKit.ACCENT)
		return
	current_territory = id
	last_world = String(TERRITORY_SCENES[id])
	GameState.set_meta("spawn_point", spawn)
	_load(last_world)


func goto_workshop(id: String) -> void:
	if not WORKSHOPS.has(id):
		return
	if id == "menu":
		goto_menu()
		return
	_load(String(WORKSHOPS[id]))


func back_to_world() -> void:
	_load(last_world)


func goto_menu() -> void:
	_load("res://ui/main_menu.tscn")


func is_territory_unlocked(id: String) -> bool:
	return id in GameState.unlocked_territories


func _load(path: String) -> void:
	if busy:
		return
	busy = true
	get_tree().paused = false
	if UIManager != null:
		UIManager.close_all_modals()
		await UIManager.fade_to_black(0.28)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: cannot load %s (%s)" % [path, err])
		if UIManager != null:
			await UIManager.fade_from_black(0.2)
		busy = false
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if UIManager != null:
		await UIManager.fade_from_black(0.32)
	busy = false
