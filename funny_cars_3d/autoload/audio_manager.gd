extends Node

## Music, sound effects, engine loops and Russian character voices.

signal voice_started(key: String)

const AUDIO_DIR := "res://assets/audio/"
const VOICE_DIR := "res://assets/voices/"

var _cache: Dictionary = {}
var _music: AudioStreamPlayer
var _music2: AudioStreamPlayer
var _sfx_pool: Array = []
var _voice: AudioStreamPlayer
var _current_music := ""
var _music_tween: Tween


func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_ensure_bus("Engine")
	_ensure_bus("Voice")
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_music2 = AudioStreamPlayer.new()
	_music2.bus = "Music"
	add_child(_music2)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	apply_settings()


func _ensure_bus(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
	return idx


func apply_settings() -> void:
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	var ei := AudioServer.get_bus_index("Engine")
	var vi := AudioServer.get_bus_index("Voice")
	if mi != -1:
		AudioServer.set_bus_mute(mi, not SettingsManager.music_on)
		AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(SettingsManager.music_volume, 0.001)))
	if si != -1:
		AudioServer.set_bus_mute(si, not SettingsManager.sfx_on)
		AudioServer.set_bus_volume_db(si, linear_to_db(maxf(SettingsManager.sfx_volume, 0.001)))
	if ei != -1:
		AudioServer.set_bus_mute(ei, not SettingsManager.sfx_on)
		AudioServer.set_bus_volume_db(ei, linear_to_db(maxf(SettingsManager.sfx_volume, 0.001)))
	if vi != -1:
		AudioServer.set_bus_mute(vi, not SettingsManager.voice_on)
		AudioServer.set_bus_volume_db(vi, linear_to_db(0.95))


# ------------------------------------------------------------------- loading ---
func stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := AUDIO_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		path = AUDIO_DIR + name + ".mp3"
	if not ResourceLoader.exists(path):
		_cache[name] = null
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV and (name.begins_with("engine") or name.begins_with("music") or name.begins_with("amb_")):
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = w.data.size() / 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else w.data.size()
	_cache[name] = s
	return s


func voice_stream(key: String) -> AudioStream:
	var ck := "voice_" + key
	if _cache.has(ck):
		return _cache[ck]
	var path := VOICE_DIR + key + ".mp3"
	if not ResourceLoader.exists(path):
		_cache[ck] = null
		return null
	var s: AudioStream = load(path)
	_cache[ck] = s
	return s


# --------------------------------------------------------------------- music ---
func play_music(name: String = "music_main", fade: float = 0.8) -> void:
	if _current_music == name and _music.playing:
		return
	var s := stream(name)
	if s == null:
		return
	_current_music = name
	_music.stream = s
	_music.volume_db = -40.0
	_music.play()
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", 0.0, maxf(fade, 0.01))


func stop_music(fade: float = 0.5) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -42.0, maxf(fade, 0.01))
	_music_tween.tween_callback(func() -> void:
		_music.stop()
		_current_music = "")


# -------------------------------------------------------------------- sounds ---
func play_sfx(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not SettingsManager.sfx_on:
		return
	var s := stream(name)
	if s == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.pitch_scale = clampf(pitch, 0.4, 2.5)
			p.play()
			return
	# all busy: reuse the first one
	var first: AudioStreamPlayer = _sfx_pool[0]
	first.stream = s
	first.volume_db = volume_db
	first.pitch_scale = pitch
	first.play()


func play_click() -> void:
	play_sfx("click", -6.0, randf_range(0.95, 1.1))


func play_star() -> void:
	play_sfx("star", -4.0, randf_range(0.98, 1.06))


func play_success() -> void:
	play_sfx("success", -2.0)


func play_unlock() -> void:
	play_sfx("unlock", -2.0)


# -------------------------------------------------------------------- voices ---
func say(key: String, force: bool = false) -> void:
	if not SettingsManager.voice_on:
		return
	if _voice.playing and not force:
		return
	var s := voice_stream(key)
	if s == null:
		return
	_voice.stream = s
	_voice.play()
	voice_started.emit(key)


func stop_voice() -> void:
	_voice.stop()


# -------------------------------------------------------------------- engines ---
func make_engine_player(kind: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var s := stream(kind)
	p.bus = "Engine"
	if s != null:
		p.stream = s
	p.unit_size = 12.0
	p.max_distance = 60.0
	p.volume_db = -18.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	return p


func make_loop_player(name: String, bus: String = "SFX") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(name)
	p.bus = bus
	p.unit_size = 8.0
	p.max_distance = 40.0
	p.volume_db = -12.0
	if p.stream is AudioStreamWAV:
		var w := p.stream as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = w.data.size() / 2
	return p
