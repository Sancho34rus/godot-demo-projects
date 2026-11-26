extends Node

## Crash-safe save system: JSON file + rotating backup + checksum + autosave.

signal saved
signal loaded

const SAVE_PATH := "user://savegame.json"
const BACKUP_PATH := "user://savegame.backup.json"
const TMP_PATH := "user://savegame.tmp"
const AUTOSAVE_DELAY := 6.0

var _timer: Timer
var _pending := false
var _loaded_once := false


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = AUTOSAVE_DELAY
	_timer.timeout.connect(func() -> void: save_game())
	add_child(_timer)
	GameState.important_change.connect(_schedule_save)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _loaded_once:
			save_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


func _schedule_save() -> void:
	_pending = true
	if _timer != null:
		_timer.start()


func save_game() -> bool:
	var data := {
		"version": 1,
		"game": GameState.to_dict(),
		"quests": QuestSystem.to_dict(),
		"saved_at": Time.get_datetime_string_from_system(),
	}
	var payload := JSON.stringify(data)
	var checksum := str(payload.hash())
	var wrapper := {"checksum": checksum, "data": payload}
	var f := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot write save file")
		return false
	f.store_string(JSON.stringify(wrapper))
	f.close()
	# keep the previous good file as a backup
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_warning("SaveSystem: rename failed (%s)" % err)
		return false
	_pending = false
	_loaded_once = true
	saved.emit()
	return true


func load_game() -> bool:
	if _read(SAVE_PATH):
		_loaded_once = true
		loaded.emit()
		return true
	if _read(BACKUP_PATH):
		push_warning("SaveSystem: restored from backup")
		_loaded_once = true
		loaded.emit()
		return true
	_loaded_once = true
	return false


func _read(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var wrapper: Dictionary = parsed
	if not wrapper.has("data") or not wrapper.has("checksum"):
		return false
	var payload := String(wrapper["data"])
	if str(payload.hash()) != String(wrapper["checksum"]):
		push_warning("SaveSystem: checksum mismatch in " + path)
		return false
	var data = JSON.parse_string(payload)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	if not d.has("game"):
		return false
	GameState.from_dict(d.get("game", {}))
	QuestSystem.from_dict(d.get("quests", {}))
	return true


func wipe() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKUP_PATH))
	GameState.reset_to_defaults()
	QuestSystem.reset()


func save_now() -> void:
	save_game()


## Loads the save once on start-up (main file, then backup if it is damaged).
func ensure_loaded() -> void:
	if not _loaded_once:
		load_game()


## Puts the backup copy back as the main save and reloads it.
func restore_backup() -> bool:
	if not FileAccess.file_exists(BACKUP_PATH):
		return false
	DirAccess.copy_absolute(ProjectSettings.globalize_path(BACKUP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	_loaded_once = false
	return load_game()
