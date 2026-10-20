extends Control
## 开场动画（2026-10-20，用户《开场.docx》）：长按 Esc 跳过。播放时机（用户 2026-10-20）：
##   · 第一次启动游戏：工作室标志之后、主菜单之前播放一次（存档设置项 opening_seen，「新游戏」清档也保留）；以后启动直接进主菜单；
##   · 主菜单挂机 IDLE_FIRST_SECONDS（1 分钟）无操作 → 播放；挂机触发的这次播完后，再挂机 IDLE_REPEAT_SECONDS（5 分钟）再播；
##     主菜单上任何点按（键盘 / 鼠标 / 手柄按键；只移动鼠标不算；长按 Esc 跳过也算）都把等待时间重置回 1 分钟（GameState.opening_idle_wait，main_menu.gd 计时）。
## 播放中按任何键 / 鼠标键 → 右下角提示「长按 Esc 跳过」；按住 Esc 时提示旁的圆环走满（HOLD_TO_SKIP 秒）即跳过，中途松开归零。
## 风格：Undertale 式「上方一幅画 + 下方逐字打出的旁白（打字音）」，艾尔登法环式的暗色油画质感、镜头缓推、浮尘 / 红烬 / 落灰、胶片噪点。
## 画面是 tools/make_opening_art.py 用游戏正式素材拼贴调色生成的 assets/cg/opening/*.png；分镜、旁白、特效都在 data/opening.json。
## 整段只由时间 _t 推进（step(dt)，单帧最多 MAX_STEP，首帧卡顿不跳字）：
##   每幅画：淡入 → 逐句「打字 → 停留 → 字淡出」→ 画面淡出 → 黑场停顿；句子开始时触发该句的 events（换图 / 闪光 / 震屏 / 碎裂 / 粒子）。
## 播完或长按 Esc（HOLD_TO_SKIP 秒，右下角圆环显示进度）→ 淡到全黑 → SceneRouter.reveal_scene 进主菜单。
## 动效总闸关闭（UiKit.motion_enabled = false）或命令行带 --skip-splash / --skip-opening / --config-editor 时直接进主菜单。

const DATA_PATH: String = "res://data/opening.json"
const ART_DIR: String = "res://assets/cg/opening/"
const NEXT_SCENE: String = SceneRouter.MAIN_MENU_SCENE
const FONT: FontFile = preload("res://assets/fonts/NotoSerifSC-Regular.otf")
const GRAIN_SHADER: Shader = preload("res://assets/shaders/opening_grain.gdshader")
const SHATTER_SHADER: Shader = preload("res://assets/shaders/transition_shatter.gdshader")

const VOID: Color = Color("#08070A")
const BONE: Color = Color("#ECE5D8")
const BONE_DIM: Color = Color("#9C948A")
const BLOOD: Color = Color("#B31A2C")

const ART_ASPECT: float = 1680.0 / 820.0
const FRAME_MAX_W: float = 1440.0
const FRAME_TOP_RATIO: float = 0.1          ## 画框顶边占屏高
const FEATHER_PX: float = 64.0              ## 画框边缘羽化进黑底的宽度
const TEXT_SIZE: int = 38
const TEXT_SPACING: int = 4                 ## 字距（像素）
const TEXT_MAX_W: float = 1300.0

const FADE_IN: float = 1.2                  ## 画面淡入
const FIRST_LINE_AT: float = 0.9            ## 淡入开始后多久开始打第一句
const HOLD_BASE: float = 1.5                ## 打完后停留 = HOLD_BASE + 字数 × HOLD_PER_CHAR
const HOLD_PER_CHAR: float = 0.075
const LINE_FADE: float = 0.35               ## 句与句之间：旧句淡出
const LINE_GAP: float = 0.5
const TAIL: float = 0.4                     ## 最后一句停留结束后画面再停一下
const FADE_OUT: float = 1.1
const BLACK_GAP: float = 0.45               ## 两幅画之间的黑场
const TEXT_ONLY_HOLD: float = 1.6           ## 纯黑只有字的画面额外停留
const END_BLACK: float = 0.8                ## 全部播完后黑场停顿再进主菜单
const SWAP_SECONDS: float = 0.9
const FLASH_SECONDS: float = 0.7
const SHAKE_SECONDS: float = 0.6
const SHAKE_PX: float = 14.0
const SHATTER_SECONDS: float = 1.6
const HOLD_TO_SKIP: float = 1.0             ## 长按 Esc 多久跳过
const SKIP_FADE: float = 0.5
const HINT_SHOW_SECONDS: float = 4.0        ## 每次按键后显示「长按 Esc 跳过」多久
const IDLE_FIRST_SECONDS: float = 60.0      ## 主菜单挂机多久播放
const IDLE_REPEAT_SECONDS: float = 300.0    ## 挂机触发的播放结束后，再挂机多久重播
const SEEN_KEY: String = "opening_seen"     ## 存档 settings 里的「第一次启动已播过」
const MAX_STEP: float = 1.0 / 30.0
const PUNCT: String = "\uFF0C\u3002\u3001\uFF1A\uFF1B\uFF01\uFF1F\u201C\u201D\u2018\u2019\u300C\u300D\u2026\u2014,.!? "   ## 不发打字音的标点（转义写法，界面脚本不放中文字面量）

var cps: float = 11.0                       ## 每秒打出的字数
var panels: Array = []                      ## data/opening.json 的 panels
var bgm: String = ""
var auto_reveal: bool = true                ## 测试置 false：结束时不真的切场景、不写存档
var _played: bool = false                   ## 真的开始播了（被命令行 / 无动效直接跳过时为 false）

var _t: float = 0.0                         ## 当前画面内的时间
var _index: int = 0                         ## 当前画面序号；== panels.size() 表示已播完（结尾黑场）
var _plan: Dictionary = {}                  ## 当前画面的时间表（_plan_panel）
var _fired: Dictionary = {}                 ## 已触发的 events 序号
var _tex_a: Texture2D = null
var _tex_b: Texture2D = null                ## swap 交叉淡入的目标
var _swap_t: float = -1.0
var _flash_t: float = -1.0
var _flash_color: Color = Color.WHITE
var _shake_t: float = -1.0
var _shatter_t: float = -1.0
var _glitch_left: float = 0.0
var _glitch_offsets: PackedFloat32Array = PackedFloat32Array()
var _fx: String = ""
var _particles: Array[Dictionary] = []
var _spawn_acc: float = 0.0
var _rng := RandomNumberGenerator.new()
var _shown_chars: int = 0
var _end_t: float = 0.0

var _esc_down: bool = false
var _esc_held: float = 0.0
var _skipping: bool = false
var _skip_t: float = 0.0
var _hint_t: float = 0.0                    ## 提示剩余显示时间
var _finished: bool = false

var _texture_cache: Dictionary = {}
var _overlay: Control                       ## 画框羽化 / 闪光 / 跳过渐黑
var _shatter: TextureRect
var _text: Label
var _hint: Control
var _hint_label: String = ""
var _blip: AudioStreamPlayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rng.seed = 20261020
	_load_data()
	_build()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not UiKit.motion_enabled or panels.is_empty() or args.has("--skip-splash") or args.has("--skip-opening") \
			or args.has("--config-editor"):
		_finish.call_deferred()
		return
	if bgm != "":
		AudioManager.play_bgm(bgm)
	_played = true
	_enter_panel(0)


func _load_data() -> void:
	if not FileAccess.file_exists(DATA_PATH):
		push_warning("[Opening] missing %s" % DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		push_error("[Opening] invalid json: %s" % DATA_PATH)
		return
	var d: Dictionary = parsed
	panels = d.get("panels", []) as Array
	bgm = str(d.get("bgm", ""))
	cps = maxf(float(d.get("chars_per_second", cps)), 1.0)


func _build() -> void:
	_shatter = TextureRect.new()
	_shatter.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shatter.stretch_mode = TextureRect.STRETCH_SCALE
	_shatter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shatter.visible = false
	var mat := ShaderMaterial.new()
	mat.shader = SHATTER_SHADER
	mat.set_shader_parameter("cells", 16.0)
	mat.set_shader_parameter("spread", 0.6)
	mat.set_shader_parameter("rim", 0.1)
	mat.set_shader_parameter("rim_color", BONE)
	mat.set_shader_parameter("ember_color", BLOOD)
	mat.set_shader_parameter("origin", Vector2(0.5, 0.42))
	_shatter.material = mat
	add_child(_shatter)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_text = Label.new()
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fv := FontVariation.new()                 # 字距
	fv.base_font = FONT
	fv.spacing_glyph = TEXT_SPACING
	var ls := LabelSettings.new()
	ls.font = fv
	ls.font_size = TEXT_SIZE
	ls.font_color = BONE
	ls.line_spacing = 10.0
	ls.shadow_color = Color(0, 0, 0, 0.85)
	ls.shadow_size = 6
	ls.shadow_offset = Vector2.ZERO
	_text.label_settings = ls
	add_child(_text)

	var grain := ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gm := ShaderMaterial.new()
	gm.shader = GRAIN_SHADER
	grain.material = gm
	add_child(grain)

	_hint = Control.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint.draw.connect(_draw_hint)
	add_child(_hint)
	_hint_label = DataRegistry.get_string("ui.opening_skip")

	_blip = AudioStreamPlayer.new()
	_blip.bus = "UI"
	_blip.volume_db = -16.0
	_blip.stream = _make_blip()
	add_child(_blip)


## 打字音：程序合成一声很短的低沉「嗒」（不依赖音效文件）
func _make_blip() -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(rate * 0.045)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i: int in n:
		var x: float = float(i) / rate
		var env: float = exp(-x * 90.0) * minf(1.0, x * 2000.0)
		var v: float = (sin(TAU * 330.0 * x) * 0.7 + sin(TAU * 660.0 * x) * 0.2) * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s


# ---------------------------------------------------------------- 时间轴

func _texture(name: String) -> Texture2D:
	if name == "":
		return null
	if not _texture_cache.has(name):
		var path: String = ART_DIR + name + ".png"
		_texture_cache[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
		if _texture_cache[name] == null:
			push_warning("[Opening] missing art: %s" % path)
	return _texture_cache[name] as Texture2D


## 当前画面的时间表：每句 [开始, 打完, 停留结束]，画面淡出开始 / 结束
static func plan_panel(panel: Dictionary, chars_per_second: float) -> Dictionary:
	var lines: Array = panel.get("lines", []) as Array
	var starts: PackedFloat32Array = PackedFloat32Array()
	var typed: PackedFloat32Array = PackedFloat32Array()
	var ends: PackedFloat32Array = PackedFloat32Array()
	var text_only: bool = str(panel.get("image", "")) == ""
	var t: float = FIRST_LINE_AT
	for i: int in lines.size():
		var n: int = str(lines[i]).length()
		starts.append(t)
		var te: float = t + n / chars_per_second
		typed.append(te)
		var hold: float = HOLD_BASE + n * HOLD_PER_CHAR + (TEXT_ONLY_HOLD if text_only else 0.0)
		ends.append(te + hold)
		t = te + hold + LINE_GAP
	var out_start: float = (ends[ends.size() - 1] if ends.size() > 0 else FADE_IN) + TAIL
	return {
		"starts": starts, "typed": typed, "ends": ends,
		"out_start": out_start, "out_end": out_start + FADE_OUT, "total": out_start + FADE_OUT + BLACK_GAP,
	}


func _panel() -> Dictionary:
	return panels[_index] as Dictionary if _index < panels.size() else {}


func _enter_panel(i: int) -> void:
	_index = i
	_t = 0.0
	_fired = {}
	_shown_chars = 0
	_tex_b = null
	_swap_t = -1.0
	_flash_t = -1.0
	_shake_t = -1.0
	_shatter_t = -1.0
	_shatter.visible = false
	_glitch_left = 0.0
	_text.text = ""
	if _index >= panels.size():
		_end_t = 0.0
		_tex_a = null
		_particles.clear()
		return
	var p: Dictionary = _panel()
	_plan = plan_panel(p, cps)
	_tex_a = _texture(str(p.get("image", "")))
	_fx = str(p.get("fx", ""))
	_particles.clear()
	_spawn_acc = 0.0
	for k: int in 40:                        # 开场先撒一些，不从空画面长出来
		_spawn(_fx, true)


func _process(delta: float) -> void:
	if _esc_down and not Input.is_key_pressed(KEY_ESCAPE):      # 松开事件被别处吃掉时兜底
		set_escape_held(false)
	step(minf(delta, MAX_STEP))


func step(dt: float) -> void:
	if _finished:
		return
	_hint_t = maxf(_hint_t - dt, 0.0)
	if _esc_down and not _skipping:
		_esc_held += dt
		_hint_t = maxf(_hint_t, 0.6)
		if _esc_held >= HOLD_TO_SKIP:
			_skipping = true
			AudioManager.play_ui("ui_skip")
	if _skipping:
		_skip_t += dt
		if _skip_t >= SKIP_FADE:
			_finish()
			return
	if _index >= panels.size():
		_end_t += dt
		if _end_t >= END_BLACK:
			_finish()
			return
	else:
		_t += dt
		_run_events()
		_update_effects(dt)
		_update_text()
		if _t >= float(_plan["total"]):
			_enter_panel(_index + 1)
	queue_redraw()
	_overlay.queue_redraw()
	_hint.queue_redraw()


func _run_events() -> void:
	var p: Dictionary = _panel()
	var starts: PackedFloat32Array = _plan["starts"]
	var events: Array = p.get("events", []) as Array
	for k: int in events.size():
		if _fired.has(k):
			continue
		var ev: Dictionary = events[k] as Dictionary
		var li: int = int(ev.get("line", 0))
		if li < starts.size() and _t >= starts[li]:
			_fired[k] = true
			_fire(ev)


func _fire(ev: Dictionary) -> void:
	match str(ev.get("type", "")):
		"swap":
			_tex_b = _texture(str(ev.get("image", "")))
			_swap_t = 0.0
		"flash":
			_flash_color = Color(str(ev.get("color", "#ffffff")))
			_flash_t = 0.0
			AudioManager.play_sfx("logo_heart", "SFX", -3.0)
		"shake":
			_shake_t = 0.0
			AudioManager.play_sfx("hit_heavy", "SFX", -2.0, 0.8)
		"shatter":
			_start_shatter(_texture(str(ev.get("image", ""))))
			AudioManager.play_sfx("transition_shatter")
		"fx":
			_fx = str(ev.get("fx", _fx))
			for k: int in 90:
				_spawn(_fx, true)


## 碎裂：截下当前画框里的那一块画面盖在上面碎掉，下面立刻换成新图
func _start_shatter(next_tex: Texture2D) -> void:
	if _tex_a == null:
		return
	var img: Image = _tex_a.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var src: Rect2 = _src_rect(_tex_a)
		var shot: Image = img.get_region(Rect2i(src))
		_shatter.texture = ImageTexture.create_from_image(shot)
		_shatter.visible = true
		_shatter_t = 0.0
		(_shatter.material as ShaderMaterial).set_shader_parameter("progress", 0.0)
	if next_tex != null:
		_tex_a = next_tex
		_tex_b = null
		_swap_t = -1.0


func _update_effects(dt: float) -> void:
	if _swap_t >= 0.0:
		_swap_t += dt
		if _swap_t >= SWAP_SECONDS and _tex_b != null:
			_tex_a = _tex_b
			_tex_b = null
			_swap_t = -1.0
	if _flash_t >= 0.0:
		_flash_t += dt
		if _flash_t >= FLASH_SECONDS:
			_flash_t = -1.0
	if _shake_t >= 0.0:
		_shake_t += dt
		if _shake_t >= SHAKE_SECONDS:
			_shake_t = -1.0
	if _shatter_t >= 0.0:
		_shatter_t += dt
		var k: float = clampf(_shatter_t / SHATTER_SECONDS, 0.0, 1.0)
		(_shatter.material as ShaderMaterial).set_shader_parameter("progress", k)
		if k >= 1.0:
			_shatter_t = -1.0
			_shatter.visible = false
			_shatter.texture = null
	if bool(_panel().get("glitch", false)):
		if _glitch_left > 0.0:
			_glitch_left -= dt
		elif _rng.randf() < dt * 0.9:
			_glitch_left = _rng.randf_range(0.06, 0.16)
			_glitch_offsets.resize(9)
			for i: int in 9:
				_glitch_offsets[i] = _rng.randf_range(-0.03, 0.03) if _rng.randf() < 0.5 else 0.0
	_update_particles(dt)


func _update_text() -> void:
	var lines: Array = _panel().get("lines", []) as Array
	var starts: PackedFloat32Array = _plan["starts"]
	var ends: PackedFloat32Array = _plan["ends"]
	var cur: int = -1
	for i: int in starts.size():
		if _t >= starts[i]:
			cur = i
	if cur < 0:
		_text.text = ""
		return
	var line: String = str(lines[cur])
	if _text.text != line:
		_text.text = line
		_shown_chars = 0
	var n: int = mini(int((_t - starts[cur]) * cps), line.length())
	if n > _shown_chars:
		var ch: String = line[n - 1]
		if not PUNCT.contains(ch) and n % 2 == 1 and _blip != null and _blip.is_inside_tree():
			_blip.pitch_scale = _rng.randf_range(0.92, 1.06)
			_blip.play()
		_shown_chars = n
	_text.visible_characters = n
	var a: float = 1.0
	var is_last: bool = cur == starts.size() - 1
	if is_last:
		a = 1.0 - _smooth(clampf((_t - float(_plan["out_start"])) / FADE_OUT, 0.0, 1.0))
	elif _t > ends[cur]:
		a = 1.0 - clampf((_t - ends[cur]) / LINE_FADE, 0.0, 1.0)
	_text.modulate.a = a


## 画面整体可见度（淡入 / 淡出）
func panel_alpha() -> float:
	if _index >= panels.size():
		return 0.0
	var a: float = _smooth(clampf(_t / FADE_IN, 0.0, 1.0))
	var out: float = clampf((_t - float(_plan["out_start"])) / FADE_OUT, 0.0, 1.0)
	return a * (1.0 - _smooth(out))


# ---------------------------------------------------------------- 输入

## 用 _input：鼠标键会被本 Control 的 GUI 吃掉，_unhandled_input 收不到
func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.keycode == KEY_ESCAPE and not key.echo:
		set_escape_held(key.pressed)
		get_viewport().set_input_as_handled()
	elif is_any_press(event):
		if _hint_t <= 0.0 and not _finished:       # 提示「长按 Esc 跳过」刚浮出时轻响一下
			AudioManager.play_ui("ui_hover")
		_hint_t = HINT_SHOW_SECONDS


static func is_any_press(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


## 第一次启动的开场是否已播过
static func is_seen() -> bool:
	return bool(GameState.settings.get(SEEN_KEY, false))


static func mark_seen() -> void:
	if is_seen():
		return
	GameState.settings[SEEN_KEY] = true
	SaveManager.save()


func set_escape_held(down: bool) -> void:
	_esc_down = down
	if not down and not _skipping:
		_esc_held = 0.0


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	_wait_and_reveal()


## 工作室标志 → 本场景的淡入还没结束时不能再切（SceneRouter 正忙会忽略），等它空下来
func _wait_and_reveal() -> void:
	if not auto_reveal:
		return
	if _played:
		mark_seen()
		# 挂机触发且完整播完 → 下次等 5 分钟；跳过（玩家在场）或首次启动 → 1 分钟
		GameState.opening_idle_wait = IDLE_REPEAT_SECONDS if GameState.opening_from_idle and not _skipping else IDLE_FIRST_SECONDS
	GameState.opening_from_idle = false
	while bool(SceneRouter.get("_busy")) and is_inside_tree():
		await get_tree().process_frame
	if is_inside_tree():
		SceneRouter.reveal_scene(NEXT_SCENE, VOID)


# ---------------------------------------------------------------- 粒子（画框内归一化坐标）

func _spawn(kind: String, anywhere: bool) -> void:
	var p: Dictionary = {}
	match kind:
		"dust":
			p = {"pos": Vector2(_rng.randf(), _rng.randf()), "vel": Vector2(_rng.randf_range(-0.006, 0.006), _rng.randf_range(-0.012, 0.002)),
				"size": _rng.randf_range(1.0, 2.6), "color": BONE, "alpha": _rng.randf_range(0.25, 0.6), "life": _rng.randf_range(5.0, 9.0)}
		"embers":
			p = {"pos": Vector2(_rng.randf(), _rng.randf() if anywhere else 1.05), "vel": Vector2(_rng.randf_range(-0.01, 0.01), _rng.randf_range(-0.07, -0.03)),
				"size": _rng.randf_range(1.2, 3.2), "color": Color("#FF5A4A").lerp(Color("#FFB070"), _rng.randf() * 0.5),
				"alpha": _rng.randf_range(0.5, 0.95), "life": _rng.randf_range(3.0, 7.0), "glow": true}
		"ash":
			p = {"pos": Vector2(_rng.randf(), _rng.randf() if anywhere else -0.05), "vel": Vector2(_rng.randf_range(-0.008, 0.012), _rng.randf_range(0.015, 0.04)),
				"size": _rng.randf_range(0.9, 2.2), "color": Color("#B8B0A8"), "alpha": _rng.randf_range(0.25, 0.55), "life": _rng.randf_range(6.0, 12.0)}
		"motes":
			p = {"pos": Vector2(_rng.randf(), _rng.randf()), "vel": Vector2(_rng.randf_range(-0.004, 0.004), _rng.randf_range(-0.01, 0.006)),
				"size": _rng.randf_range(1.0, 2.6), "color": Color("#C8D8F4"), "alpha": _rng.randf_range(0.3, 0.8), "life": _rng.randf_range(4.0, 8.0), "glow": true}
		"shards":
			p = {"pos": Vector2(_rng.randf(), _rng.randf_range(-0.1, 0.6) if anywhere else -0.05), "vel": Vector2(_rng.randf_range(-0.02, 0.02), _rng.randf_range(0.04, 0.12)),
				"size": _rng.randf_range(3.0, 9.0), "color": BONE, "alpha": _rng.randf_range(0.5, 1.0), "life": _rng.randf_range(4.0, 9.0),
				"diamond": true, "spin": _rng.randf_range(-2.0, 2.0)}
		_:
			return
	p["age"] = _rng.randf() * float(p["life"]) * 0.5 if anywhere else 0.0
	p["phase"] = _rng.randf() * TAU
	_particles.append(p)


const SPAWN_RATE: Dictionary = {"dust": 9.0, "embers": 14.0, "ash": 12.0, "motes": 8.0, "shards": 10.0}
const MAX_PARTICLES: int = 220


func _update_particles(dt: float) -> void:
	_spawn_acc += dt * float(SPAWN_RATE.get(_fx, 0.0))
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if _particles.size() < MAX_PARTICLES:
			_spawn(_fx, false)
	var keep: Array[Dictionary] = []
	for p: Dictionary in _particles:
		p["age"] = float(p["age"]) + dt
		var sway: float = sin(float(p["age"]) * 1.3 + float(p["phase"])) * 0.004
		p["pos"] = (p["pos"] as Vector2) + ((p["vel"] as Vector2) + Vector2(sway, 0.0)) * dt
		var pos: Vector2 = p["pos"]
		if float(p["age"]) < float(p["life"]) and pos.y > -0.1 and pos.y < 1.1 and pos.x > -0.1 and pos.x < 1.1:
			keep.append(p)
	_particles = keep


# ---------------------------------------------------------------- 布局与绘制

static func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func frame_rect() -> Rect2:
	var w: float = minf(FRAME_MAX_W, size.x - 120.0)
	var h: float = w / ART_ASPECT
	var top: float = size.y * FRAME_TOP_RATIO
	var r := Rect2((size.x - w) * 0.5, top, w, h)
	if _shake_t >= 0.0:
		var k: float = 1.0 - _shake_t / SHAKE_SECONDS
		r.position += Vector2(sin(_shake_t * 61.0), cos(_shake_t * 47.0)) * SHAKE_PX * k * k
	return r


## 镜头缓推：本画面进度 → 原图上的取景矩形
func _src_rect(tex: Texture2D) -> Rect2:
	var total: float = maxf(float(_plan.get("out_end", 1.0)), 0.01)
	return camera_rect(_panel(), _smooth(clampf(_t / total, 0.0, 1.0)), tex.get_size())


## 起止两个取景各自先夹在原图内，再在两者之间线性插值（u 已缓动）：取景中心沿直线单向移动、缩放单调，
## 不会因为中途碰到图边被夹住而先往一边再折回（2026-10-20 用户反馈第 1 / 14 幕运镜先左后右）
static func camera_rect(panel: Dictionary, u: float, ts: Vector2) -> Rect2:
	var z: Array = panel.get("zoom", [1.0, 1.0]) as Array
	var f: Array = panel.get("focus", [[0.5, 0.5], [0.5, 0.5]]) as Array
	var r0: Rect2 = _framing(ts, float(z[0]), f[0] as Array)
	var r1: Rect2 = _framing(ts, float(z[1]), f[1] as Array)
	return Rect2(r0.position.lerp(r1.position, u), r0.size.lerp(r1.size, u))


static func _framing(ts: Vector2, zoom: float, focus: Array) -> Rect2:
	var sz: Vector2 = ts / maxf(zoom, 1.0)
	var c := Vector2(float(focus[0]), float(focus[1])) * ts
	return Rect2((c - sz * 0.5).clamp(Vector2.ZERO, ts - sz), sz)


func _layout_text() -> void:
	var fr: Rect2 = frame_rect()
	var text_only: bool = _index < panels.size() and str(_panel().get("image", "")) == ""
	var w: float = minf(TEXT_MAX_W, size.x - 120.0)
	if text_only:
		_text.position = Vector2((size.x - w) * 0.5, size.y * 0.5 - 80.0)
		_text.size = Vector2(w, 160.0)
	else:
		var top: float = fr.end.y + 24.0
		_text.position = Vector2((size.x - w) * 0.5, top)
		_text.size = Vector2(w, maxf(size.y - top - 40.0, 80.0))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), VOID)
	_layout_text()
	if _index >= panels.size():
		return
	var fr: Rect2 = frame_rect()
	var a: float = panel_alpha()
	_shatter.position = fr.position
	_shatter.size = fr.size
	_shatter.modulate.a = a
	(_shatter.material as ShaderMaterial).set_shader_parameter("aspect", fr.size.x / maxf(fr.size.y, 1.0))
	if _tex_a != null:
		_draw_image(_tex_a, fr, a)
		if _tex_b != null and _swap_t >= 0.0:
			_draw_image(_tex_b, fr, a * _smooth(clampf(_swap_t / SWAP_SECONDS, 0.0, 1.0)))
	if bool(_panel().get("dim", false)):
		var u: float = clampf(_t / maxf(float(_plan["out_start"]), 0.01), 0.0, 1.0)
		draw_rect(fr, Color(VOID, 0.55 * u * a))
	_draw_particles(fr, a)


func _draw_image(tex: Texture2D, fr: Rect2, a: float) -> void:
	var src: Rect2 = _src_rect(tex)
	if _glitch_left <= 0.0 or _glitch_offsets.is_empty():
		draw_texture_rect_region(tex, fr, src, Color(1, 1, 1, a))
		return
	# 错位：横切成条，每条左右偏一点，外加一层偏红的残影
	var n: int = _glitch_offsets.size()
	for i: int in n:
		var off: float = _glitch_offsets[i]
		var d := Rect2(fr.position.x + off * fr.size.x, fr.position.y + fr.size.y * i / n, fr.size.x, fr.size.y / n)
		var s := Rect2(src.position.x, src.position.y + src.size.y * i / n, src.size.x, src.size.y / n)
		draw_texture_rect_region(tex, d, s, Color(1, 1, 1, a))
	draw_texture_rect_region(tex, Rect2(fr.position + Vector2(9, 0), fr.size), src, Color(1.0, 0.2, 0.25, 0.22 * a))


func _draw_particles(fr: Rect2, a: float) -> void:
	for p: Dictionary in _particles:
		var life: float = float(p["life"])
		var age: float = float(p["age"])
		var k: float = clampf(age / 0.8, 0.0, 1.0) * clampf((life - age) / 1.2, 0.0, 1.0)
		var tw: float = 0.75 + 0.25 * sin(age * 5.0 + float(p["phase"]))
		var pos: Vector2 = fr.position + (p["pos"] as Vector2) * fr.size
		if not fr.grow(-4.0).has_point(pos):
			continue
		var col: Color = p["color"]
		col.a = float(p["alpha"]) * k * tw * a
		var r: float = float(p["size"])
		if p.has("diamond"):
			var ang: float = age * float(p["spin"])
			var pts := PackedVector2Array()
			for v: Vector2 in [Vector2(0, -r), Vector2(r * 0.6, 0), Vector2(0, r), Vector2(-r * 0.6, 0)]:
				pts.append(pos + v.rotated(ang))
			draw_colored_polygon(pts, col)
		else:
			if p.has("glow"):
				draw_circle(pos, r * 3.2, Color(col, col.a * 0.18))
			draw_circle(pos, r, col)


func _draw_overlay() -> void:
	if _index < panels.size() and str(_panel().get("image", "")) != "":
		var fr: Rect2 = frame_rect()
		_draw_feather(fr)
		if _flash_t >= 0.0:
			var k: float = 1.0 - _flash_t / FLASH_SECONDS
			_overlay.draw_rect(fr, Color(_flash_color, 0.85 * k * k * panel_alpha()))
	if _skipping:
		_overlay.draw_rect(Rect2(Vector2.ZERO, _overlay.size), Color(VOID, clampf(_skip_t / SKIP_FADE, 0.0, 1.0)))


## 画框四边羽化进黑底（顶点色渐变），外沿再压一圈纯黑盖住震屏时露出的边
func _draw_feather(fr: Rect2) -> void:
	var o: Control = _overlay
	var f: float = FEATHER_PX
	var solid := Color(VOID, 1.0)
	var clear := Color(VOID, 0.0)
	var tl: Vector2 = fr.position
	var br: Vector2 = fr.end
	var tr := Vector2(br.x, tl.y)
	var bl := Vector2(tl.x, br.y)
	var itl: Vector2 = tl + Vector2(f, f)
	var itr: Vector2 = tr + Vector2(-f, f)
	var ibr: Vector2 = br - Vector2(f, f)
	var ibl: Vector2 = bl + Vector2(f, -f)
	o.draw_polygon(PackedVector2Array([tl, tr, itr, itl]), PackedColorArray([solid, solid, clear, clear]))
	o.draw_polygon(PackedVector2Array([tr, br, ibr, itr]), PackedColorArray([solid, solid, clear, clear]))
	o.draw_polygon(PackedVector2Array([br, bl, ibl, ibr]), PackedColorArray([solid, solid, clear, clear]))
	o.draw_polygon(PackedVector2Array([bl, tl, itl, ibl]), PackedColorArray([solid, solid, clear, clear]))
	var pad: float = SHAKE_PX + 2.0
	o.draw_rect(Rect2(tl.x - pad, tl.y - pad, fr.size.x + pad * 2.0, pad), solid)
	o.draw_rect(Rect2(tl.x - pad, br.y, fr.size.x + pad * 2.0, pad), solid)
	o.draw_rect(Rect2(tl.x - pad, tl.y, pad, fr.size.y), solid)
	o.draw_rect(Rect2(br.x, tl.y, pad, fr.size.y), solid)


## 右下角「长按 Esc 跳过」+ 进度圆环
func _draw_hint() -> void:
	var a: float = clampf(_hint_t / 0.6, 0.0, 1.0)
	if _esc_held > 0.0:
		a = 1.0
	if a <= 0.0 or _hint_label == "":
		return
	var fs: int = 20
	var tw: float = FONT.get_string_size(_hint_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ring_c := Vector2(_hint.size.x - 56.0, _hint.size.y - 52.0)
	var base := Vector2(ring_c.x - 26.0 - tw, ring_c.y + fs * 0.36)
	_hint.draw_string(FONT, base, _hint_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(BONE_DIM, 0.8 * a))
	_hint.draw_arc(ring_c, 12.0, 0.0, TAU, 40, Color(BONE_DIM, 0.35 * a), 2.0, true)
	var k: float = clampf(_esc_held / HOLD_TO_SKIP, 0.0, 1.0)
	if k > 0.0:
		_hint.draw_arc(ring_c, 12.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(BONE, a), 2.6, true)
