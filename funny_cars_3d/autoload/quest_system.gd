extends Node

## Endless, kind quests. Every activity in the world reports events,
## quests listen for them, reward stars and then choose a new variation.
## Variation (activity x machine x amount x territory) gives hundreds of
## combinations without ever blocking free play.

signal quest_changed
signal quest_completed(quest: Dictionary)

const TEMPLATES := [
	{"id": "wash", "event": "wash_done", "title": "Помой машинку", "icon": "water", "base": 1, "where": "autotown"},
	{"id": "paint", "event": "paint_done", "title": "Покрась машинку", "icon": "paint", "base": 1, "where": "autotown"},
	{"id": "repair", "event": "repair_done", "title": "Почини машинку", "icon": "wrench", "base": 1, "where": "autotown"},
	{"id": "plow", "event": "plow", "title": "Вспаши поле", "icon": "tractor", "base": 4, "where": "farm"},
	{"id": "plant", "event": "plant", "title": "Посади семена", "icon": "seed", "base": 4, "where": "farm"},
	{"id": "water", "event": "water", "title": "Полей грядки", "icon": "water", "base": 3, "where": "farm"},
	{"id": "harvest", "event": "harvest", "title": "Собери урожай", "icon": "farm", "base": 4, "where": "farm"},
	{"id": "feed", "event": "feed", "title": "Покорми животных", "icon": "animal", "base": 3, "where": "farm"},
	{"id": "dig", "event": "dig", "title": "Покопай песок", "icon": "bucket", "base": 4, "where": "construction"},
	{"id": "load", "event": "load", "title": "Загрузи самосвал", "icon": "dump", "base": 3, "where": "construction"},
	{"id": "deliver", "event": "deliver", "title": "Привези материалы", "icon": "build", "base": 2, "where": "construction"},
	{"id": "compact", "event": "compact", "title": "Укатай дорожку", "icon": "build", "base": 4, "where": "construction"},
	{"id": "parking", "event": "parking", "title": "Припаркуйся", "icon": "car", "base": 2, "where": "city"},
	{"id": "gift", "event": "gift", "title": "Найди подарки", "icon": "gift", "base": 2, "where": "any"},
	{"id": "crane", "event": "crane_pick", "title": "Подними груз краном", "icon": "crane", "base": 2, "where": "construction"},
	{"id": "deliver_crop", "event": "deliver_crop", "title": "Отвези урожай", "icon": "farm", "base": 2, "where": "farm"},
	{"id": "explore", "event": "secret", "title": "Найди секретное место", "icon": "map", "base": 1, "where": "nature"},
]

var active: Dictionary = {}
var completed := 0
var template_index := 0
var _last_id := ""
var _changing := false


func _ready() -> void:
	if active.is_empty():
		call_deferred("start_next")


func start_next() -> void:
	if _changing:
		return
	_changing = true
	var tpl: Dictionary = _pick_template()
	_last_id = String(tpl["id"])
	var target: int = int(tpl["base"]) + int(completed / 4)
	target = clampi(target, 1, 12)
	active = {
		"id": tpl["id"],
		"event": tpl["event"],
		"title": tpl["title"],
		"icon": tpl["icon"],
		"where": tpl["where"],
		"target": target,
		"progress": 0,
		"reward": 1 + int(target / 4),
	}
	_changing = false
	quest_changed.emit()


func _pick_template() -> Dictionary:
	var pool: Array = []
	for t in TEMPLATES:
		if String(t["id"]) != _last_id:
			pool.append(t)
	if pool.is_empty():
		pool = TEMPLATES.duplicate()
	# rotate through the pool so the order stays varied but never random-hard
	template_index = (template_index + 1 + int(completed / 3)) % pool.size()
	return pool[template_index]


func report(event: String, amount: int = 1) -> void:
	if active.is_empty():
		return
	if String(active.get("event", "")) != event:
		return
	active["progress"] = int(active.get("progress", 0)) + amount
	if int(active["progress"]) >= int(active["target"]):
		_finish()


func _finish() -> void:
	var done: Dictionary = active.duplicate()
	completed += 1
	GameState.add_stat("quests")
	GameState.add_stars(int(done.get("reward", 1)))
	quest_completed.emit(done)
	if UIManager != null:
		UIManager.toast("Задание выполнено! Молодец!", "check", Color(0.55, 1.0, 0.6), 2.4)
		UIManager.star_popup(int(done.get("reward", 1)))
	AudioManager.play_success()
	active = {}
	quest_changed.emit()
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if active.is_empty():
			start_next())


func progress_ratio() -> float:
	if active.is_empty():
		return 0.0
	return clampf(float(active.get("progress", 0)) / maxf(float(active.get("target", 1)), 1.0), 0.0, 1.0)


func current_hint() -> String:
	if active.is_empty():
		return ""
	return String(active.get("title", ""))


func to_dict() -> Dictionary:
	return {"active": active, "completed": completed, "template_index": template_index, "last_id": _last_id}


func from_dict(d: Dictionary) -> void:
	if d == null or d.is_empty():
		return
	active = d.get("active", {})
	completed = int(d.get("completed", 0))
	template_index = int(d.get("template_index", 0))
	_last_id = String(d.get("last_id", ""))
	quest_changed.emit()


func reset() -> void:
	active = {}
	completed = 0
	template_index = 0
	_last_id = ""
	start_next()
