extends Node
## 音频管理（01 §4、04 §3）：BGM 交叉淡入淡出、胜负短曲、SFX 池（8 个播放器，同名 50 ms 内去重）、环境底噪、总线音量。
## 总线：Master → Music / SFX / UI / Ambient（运行时创建）。音频文件由资源流程放入 assets/audio/，缺失时静默跳过。
## 按钮点击/悬停音效对场景中所有 BaseButton 自动挂接。

const BGM_DIR: String = "res://assets/audio/bgm/"
const SFX_DIR: String = "res://assets/audio/sfx/"
const SFX_EXTENSIONS: Array[String] = [".ogg", ".wav", ".mp3"]
const SFX_POOL_SIZE: int = 16
const FOOTSTEP_MIN_MSEC: int = 90
const FOOTSTEP_VARIANTS: int = 3
const GENERIC_UI: Array[String] = ["ui_click", "ui_hover", "ui_toggle", "ui_select", "ui_value_tick"]
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
var _footstep_region: String = ""
var _last_footstep: int = 0
var _last_specific_msec: int = -100000     ## 最近一次播"具体音"（非通用点击/悬停/选中）的时间


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


## 从 SFX 池播放 assets/audio/sfx/<sfx_name>（可带或不带扩展名）；同名 min_interval_ms（默认 50 ms）内只播一次。
## jitter：音高随机 ±jitter（同屏重复音防"机枪效应"）。
func play_sfx(sfx_name: String, bus: String = "SFX", volume_db: float = 0.0, pitch: float = 1.0,
		jitter: float = 0.0, min_interval_ms: int = DEDUPE_MSEC) -> void:
	if sfx_name == "":
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sfx_name, -min_interval_ms * 2)) < min_interval_ms:
		return
	var stream: AudioStream = _find_sfx(sfx_name)
	if stream == null:
		return
	_last_played[sfx_name] = now
	if not sfx_name in GENERIC_UI:
		_last_specific_msec = now
	var p: AudioStreamPlayer = _pool[_pool_next]
	_pool_next = (_pool_next + 1) % _pool.size()
	p.bus = bus
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-jitter, jitter)))
	p.play()


## UI 总线快捷方式
func play_ui(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	play_sfx(sfx_name, "UI", volume_db, pitch)


## 战斗脚步：按 set_footstep_region 设定的区域随机取 footstep_<区域>_1..3；
## 全局限频（同屏多单位走路时只留稀疏的几声），size > 1 的大体型降调。
func set_footstep_region(region: String) -> void:
	_footstep_region = region


func play_footstep(size: float = 1.0, ally: bool = true) -> void:
	if _footstep_region == "":
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_footstep < FOOTSTEP_MIN_MSEC:
		return
	_last_footstep = now
	var sfx_name: String = "footstep_%s_%d" % [_footstep_region, randi_range(1, FOOTSTEP_VARIANTS)]
	var pitch: float = clampf(1.0 / sqrt(maxf(size, 0.25)), 0.7, 1.3)
	play_sfx(sfx_name, "SFX", -2.0 if ally else -4.0, pitch, 0.06, 0)


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


## 所有按钮：点击（切换类为 ui_toggle）与悬停音效；点 disabled 按钮播 ui_error。
## 按钮可设 meta 覆盖：sfx_press（按下音，"" = 静音，由调用方自己播）、sfx_hover（"" = 不响悬停）。
## 另自动挂接：OptionButton 选中项 → ui_select；Slider / SpinBox 由玩家改值 → ui_value_tick。
func _on_node_added(node: Node) -> void:
	var b: BaseButton = node as BaseButton
	if b != null:
		_hook_button(b)
		return
	var r: Range = node as Range
	if r != null and (r is Slider or r is SpinBox):
		r.gui_input.connect(func(e: InputEvent) -> void:     # FOCUS_NONE 的滑条靠最近一次输入判断
			if e is InputEventMouseButton or e is InputEventMouseMotion or e is InputEventKey:
				r.set_meta("_sfx_input_msec", Time.get_ticks_msec()))
		r.value_changed.connect(func(_v: float) -> void:
			if _user_editing(r):
				play_sfx("ui_value_tick", "UI", 0.0, 1.0, 0.04, 45))


func _hook_button(b: BaseButton) -> void:
	b.pressed.connect(func() -> void:
		var s: String = str(b.get_meta("sfx_press", "ui_toggle" if b.toggle_mode else "ui_click"))
		play_sfx(s, "UI"))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			play_sfx(str(b.get_meta("sfx_hover", "ui_hover")), "UI"))
	b.gui_input.connect(func(e: InputEvent) -> void:
		var mb: InputEventMouseButton = e as InputEventMouseButton
		if b.disabled and mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			play_sfx(str(b.get_meta("sfx_disabled", "ui_error")), "UI"))
	var ob: OptionButton = b as OptionButton
	if ob != null:
		ob.item_selected.connect(func(_i: int) -> void: _play_select.call_deferred())


## 延后到帧末：调用方在自己的 item_selected 里已播了更具体的音（如删除条件 rule_remove）就不再叠 ui_select
func _play_select() -> void:
	if Time.get_ticks_msec() - _last_specific_msec < 30:
		return
	play_sfx("ui_select", "UI")


## 值变化是否来自玩家（有焦点或正被鼠标按住），避免代码赋值时也响
func _user_editing(r: Range) -> bool:
	if not r.is_visible_in_tree():
		return false
	if Time.get_ticks_msec() - int(r.get_meta("_sfx_input_msec", -100000)) < 250:
		return true
	var focus: Control = r.get_viewport().gui_get_focus_owner() if r.get_viewport() != null else null
	if focus == r:
		return true
	var sb: SpinBox = r as SpinBox
	return sb != null and focus == sb.get_line_edit()
