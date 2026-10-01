extends Node
## 音效池 + 音乐。autoload 名：Audio
##
## 用法：
##   Audio.play(preload("res://assets/audio/jump.wav"))
##   Audio.play_music(preload("res://assets/audio/bgm.ogg"))
##   Audio.set_bus_volume("Master", 0.8)
##
## 依赖 default_bus_layout.tres 里的 Master / SFX / Music 三条总线。

const POOL_SIZE := 12

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	_music.volume_db = -6.0
	add_child(_music)

	# 启动就套用已保存的音量，不必先打开设置菜单才生效
	Save.load_settings()
	set_bus_volume("Master", float(Save.get_setting("master", 0.8)))
	set_bus_volume("SFX", float(Save.get_setting("sfx", 0.8)))
	set_bus_volume("Music", float(Save.get_setting("music", 0.6)))

## 播一次性音效。pitch_jitter 让连打时听感不单调，是廉价的手感提升。
func play(stream: AudioStream, volume_db := 0.0, pitch_jitter := 0.05) -> void:
	if stream == null:
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()

## 循环音乐，带淡入
func play_music(stream: AudioStream, fade := 0.5) -> void:
	if stream == null:
		return
	if _music.stream == stream and _music.playing:
		return
	_music.stream = stream
	_music.volume_db = -60.0
	_music.play()
	var t := create_tween()
	t.tween_property(_music, "volume_db", -6.0, fade)

func stop_music(fade := 0.3) -> void:
	if not _music.playing:
		return
	var t := create_tween()
	t.tween_property(_music, "volume_db", -60.0, fade)
	await t.finished
	_music.stop()

## 0..1 的线性音量。设置菜单调用这个。
func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		push_warning("Audio: 找不到 bus " + bus_name)
		return
	var v := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(v))
	AudioServer.set_bus_mute(idx, v <= 0.001)

func get_bus_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))

## 程序化生成一段 8bit 方波。没有音效素材时用，能立刻验证音频链路是通的。
static func make_beep(freq := 660.0, duration := 0.08, amp := 0.35) -> AudioStreamWAV:
	const RATE := 22050
	var count := maxi(int(RATE * duration), 1)
	var bytes := PackedByteArray()
	bytes.resize(count)
	for i in count:
		var t := float(i) / RATE
		var env := 1.0 - float(i) / count
		var sample := sin(TAU * freq * t) * amp * env
		bytes[i] = clampi(int((sample + 0.5) * 255.0), 0, 255)
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s
