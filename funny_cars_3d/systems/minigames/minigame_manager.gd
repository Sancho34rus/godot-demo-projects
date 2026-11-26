class_name MiniGameManager
extends Node

## Starts minigames from stations and routes action presses to the running one.
## Free play is never blocked: stations can be ignored and replayed any time.

signal game_started(id: String)
signal game_finished(id: String)

var world: WorldBase
var active: MiniGame = null


func _ready() -> void:
	world = get_parent() as WorldBase


func on_station(s: Station) -> bool:
	if s.kind != "minigame":
		return false
	if active != null and is_instance_valid(active):
		UIManager.toast("Сначала закончим это задание!", "star", UIKit.ACCENT)
		return true
	start(s.game_id, s)
	return true


func start(id: String, s: Station) -> void:
	if MiniGameDefs.get_def(id).is_empty():
		UIManager.toast("Скоро!", "star", UIKit.ACCENT)
		return
	var mg := MiniGame.new()
	mg.setup(world, s, id)
	world.add_child(mg)
	active = mg
	mg.finished.connect(_on_finished)
	game_started.emit(id)


func on_action(player: Node3D) -> bool:
	if active == null or not is_instance_valid(active):
		return false
	return active.on_action(player)


func _on_finished(id: String) -> void:
	game_finished.emit(id)
	active = null
