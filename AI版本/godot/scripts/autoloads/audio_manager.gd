extends Node
## 音频管理（01 §4、04 §3）：BGM 交叉淡入淡出、胜负短曲、SFX 池（8 个播放器，同名 50 ms 内去重）、环境底噪、总线音量。
## 总线：Master → Music / SFX / UI / Ambient（运行时创建）。音频文件由资源流程放入 assets/audio/，缺失时静默跳过。
## 按钮点击/悬停音效对场景中所有 BaseButton 自动挂接。

const BGM_DIR: String = "res://assets/audio/bgm/"
const SFX_DIR: String = "res://assets/audio/sfx/"
const SFX_EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]
const SFX_POOL_SIZE: int = 8
const DEDUPE_MSEC: int = 50
const CROSSFADE_SECONDS: float = 1.0
const STING_DUCK_DB: float = -14.0
const SILENT_DB: float = -60.0
const BUSES: Array[String] = ["Music", "SFX", "UI", "Ambient"]

var _bgm_players: Array[AudioStreamPlayer] = []
var _bgm_active: int = 0
var _bgm_name: String = ""
var _sting: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _ambient_name: String = ""
var _pool: Array[AudioStreamPlayer] = []
var _pool_next: int = 0
var _last_played: Dictionary = {}      ## sfx 名 -> Time.get_ticks_msec()（表现层去重，与模拟无关）
var _stream_cache: Dictionary = {}     ## 路径 -> AudioStream 或 null
var _bgm_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	for i: int in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = SILENT_DB
		add_child(p)
		_bgm_players.append(p)
	_sting = AudioStreamPlayer.new()
	_sting.bus = "Music"
	_sting.finished.connect(_unduck)
	add_child(_sting)
	_ambient = AudioStreamPlayer.new()
	_ambient.bus = "Ambient"
	add_child(_ambient)
	for i: int in SFX_POOL_SIZE:
		var s := AudioStreamPlayer.new()
		s.bus = "SFX"
		add_child(s)
		_pool.append(s)
	apply_volumes()
	get_tree().node_added.connect(_on_node_added)
	EventBus.battle_ended.connect(_on_battle_ended)
	EventBus.validation_failed.connect(func(_p: Array) -> void: play_sfx("ui_error", "UI"))
	EventBus.hint_requested.connect(func(_t: int) -> void: play_sfx("hint_open", "UI"))


func _ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


## 设置项（GameState.settings 的 master / music / sfx，0..1 线性）→ 总线音量
func apply_volumes() -> void:
	var settings: Dictionary = GameState.settings
	_set_bus("Master", float(settings.get("master", 1.0)))
	_set_bus("Music", float(settings.get("music", 1.0)))
	_set_bus("SFX", float(settings.get("sfx", 1.0)))
	_set_bus("UI", float(settings.get("sfx", 1.0)))
	_set_bus("Ambient", float(settings.get("sfx", 1.0)))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


## 按名称交叉淡入播放 assets/audio/bgm/<bgm_name>.mp3（循环）；同名正在播放则不变
func play_bgm(bgm_name: String) -> void:
	if bgm_name == _bgm_name:
		return
	var stream: AudioStream = _load(BGM_DIR + bgm_name + ".mp3")
	_bgm_name = bgm_name
	var old: AudioStreamPlayer = _bgm_players[_bgm_active]
	_bgm_active = 1 - _bgm_active
	var new: AudioStreamPlayer = _bgm_players[_bgm_active]
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween().set_parallel(true)
	_bgm_tween.tween_property(old, "volume_db", SILENT_DB, CROSSFADE_SECONDS)
	if stream != null:
		_set_loop(stream, true)
		new.stream = stream
		new.volume_db = SILENT_DB
		new.play()
		_bgm_tween.tween_property(new, "volume_db", 0.0, CROSSFADE_SECONDS)


## 胜负短曲：压低 BGM，播完恢复
func play_sting(sting_name: String) -> void:
	var stream: AudioStream = _load(BGM_DIR + sting_name + ".mp3")
	if stream == null:
		return
	_set_loop(stream, false)
	_sting.stream = stream
	_sting.play()
	for p: AudioStreamPlayer in _bgm_players:
		if p.playing and p.volume_db > SILENT_DB + 1.0:
			p.volume_db = STING_DUCK_DB


func _unduck() -> void:
	var p: AudioStreamPlayer = _bgm_players[_bgm_active]
	if p.playing:
		create_tween().tween_property(p, "volume_db", 0.0, CROSSFADE_SECONDS)


func play_ambient(ambient_name: String) -> void:
	if ambient_name == _ambient_name:
		return
	_ambient_name = ambient_name
	var stream: AudioStream = _find_sfx(ambient_name)
	_ambient.stop()
	if stream != null:
		_set_loop(stream, true)
		_ambient.stream = stream
		_ambient.play()


func stop_ambient() -> void:
	_ambient_name = ""
	_ambient.stop()


## 从 SFX 池播放 assets/audio/sfx/<sfx_name>（可带或不带扩展名）；同名 50 ms 内只播一次
func play_sfx(sfx_name: String, bus: String = "SFX") -> void:
	if sfx_name == "":
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -DEDUPE_MSEC * 2)) < DEDUPE_MSEC:
		return
	var stream: AudioStream = _find_sfx(sfx_name)
	if stream == null:
		return
	_last_played[sfx_name] = now
	var p: AudioStreamPlayer = _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.bus = bus
	p.stream = stream
	p.play()


func _find_sfx(sfx_name: String) -> AudioStream:
	var base: String = sfx_name.get_basename() if sfx_name.get_extension() != "" else sfx_name
	if sfx_name.get_extension() != "":
		var exact: AudioStream = _load(SFX_DIR + sfx_name)
		if exact != null:
			return exact
	for ext: String in SFX_EXTENSIONS:
		var s: AudioStream = _load(SFX_DIR + base + ext)
		if s != null:
			return s
	return null


func _load(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path] as AudioStream
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path) as AudioStream
	else:
		print_verbose("[AudioManager] missing audio: %s" % path)
	_stream_cache[path] = s
	return s


func _set_loop(stream: AudioStream, on: bool) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = on
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = on
	elif stream is AudioStreamWAV:
		var wav: AudioStreamWAV = stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if on else AudioStreamWAV.LOOP_DISABLED
		if on:      # 导入时 loop_end 未设置：循环整段
			wav.loop_begin = 0
			wav.loop_end = roundi(wav.get_length() * float(wav.mix_rate))


func _on_battle_ended(result: int, _reason: int) -> void:
	play_sting("sting_victory" if result == SimTypes.BattleResult.WIN else "sting_defeat")


## 所有按钮：点击（切换类为 ui_toggle）与悬停音效
func _on_node_added(node: Node) -> void:
	var b: BaseButton = node as BaseButton
	if b == null:
		return
	b.pressed.connect(func() -> void: play_sfx("ui_toggle" if b.toggle_mode else "ui_click", "UI"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			play_sfx("ui_hover", "UI"))
