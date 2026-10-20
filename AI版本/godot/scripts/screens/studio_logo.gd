extends Control
## 开场工作室标志「人偶存续机构」（2026-10-20，标志稿 logo-sheet.html 01 主标志 · 深底）：启动后先播标志，结束后淡入主菜单。
## 标志全部用 _draw 按 120×120 设计坐标逐帧画出，整段动画只由一个时间轴 _t 决定：
##   出现：虚线圆环分四段旋入 → 提线横杆自中心展开、挂钩落下 → 三根提线垂下 → 红菱（灵魂）沿线落下、泛起一圈涟漪 →
##         下端短线与小环 → 「人偶存续机构」逐字由提线吊下（先红后褪成骨白，线随即收回）→ 英文副标解码式定格；
##   停留 HOLD_SECONDS；消失：整体淡出并微微上浮，红菱最后熄灭；然后 SceneRouter.reveal_scene 从同色底淡入下一界面：
##   第一次启动 → 开场动画（2026-10-20，opening.tscn，播完 / 长按 Esc 跳过后进主菜单）；以后启动 → 直接主菜单。
## 左键：出现阶段内 → 立刻完整显示（进入停留）；停留阶段内 → 立刻开始消失；消失动画始终完整播放。
## 动效总闸关闭（UiKit.motion_enabled = false）或命令行带 --skip-splash / --config-editor 时直接进主菜单（连开场动画一起跳过）。

const NEXT_SCENE: String = SceneRouter.OPENING_SCENE
const Opening := preload("res://scripts/screens/opening.gd")
const VOID: Color = Color("#08070A")
const BONE: Color = Color("#ECE5D8")
const BLOOD: Color = Color("#B31A2C")
const BLOOD_DARK: Color = Color("#3A0C12")
const TITLE: String = "人偶存续机构"
const SUBTITLE: String = "PUPPET CONTINUITY AGENCY"
const SCRAMBLE: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/#+-"
const TITLE_FONT: FontFile = preload("res://assets/fonts/NotoSerifSC-Regular.otf")

const MARK_PX: float = 210.0             ## 标志边长（120 设计单位）
const GAP_PX: float = 44.0               ## 标志与文字间距
const TITLE_SIZE: int = 70
const TITLE_SPACING: float = 0.34        ## 字距（em），同标志稿
const SUB_SIZE: int = 17
const SUB_SPACING: float = 0.3
const SUB_GAP_PX: float = 22.0           ## 主名与英文副标间距

## 时间轴（秒）
const INTRO_END: float = 3.6
const HOLD_SECONDS: float = 1.6
const FADE_SECONDS: float = 1.1
const HOLD_END: float = INTRO_END + HOLD_SECONDS
const FADE_END: float = HOLD_END + FADE_SECONDS
const TAIL_SECONDS: float = 0.25         ## 全黑停一下再进主菜单
const MAX_STEP: float = 1.0 / 30.0       ## 单帧最多推进（首帧卡顿不跳动画）

enum Phase { INTRO, HOLD, FADE, DONE }

## 音效时间轴：[时刻, sfx, 音量 dB, 随机音高]（时间轴越过该时刻时播一次；跳过时被越过的不补播）
const CUES: Array = [
	[0.0, "logo_ring", 0.0, false],
	[0.35, "logo_string", -8.0, true],         # 横杆展开
	[0.55, "logo_string", -8.0, true],         # 挂钩落下
	[0.72, "logo_string", -8.0, true],         # 提线垂下
	[1.74, "logo_heart", 0.0, false],          # 红菱落定
	[1.85, "logo_string", -9.0, true], [1.97, "logo_string", -9.0, true], [2.09, "logo_string", -9.0, true],
	[2.21, "logo_string", -9.0, true], [2.33, "logo_string", -9.0, true], [2.45, "logo_string", -9.0, true],
	[2.55, "logo_decode", -2.0, false],        # 英文副标解码
	[HOLD_END, "logo_out", 0.0, false],
]

var _t: float = 0.0
var _cue: int = 0                        ## 下一个待播的 CUES 下标
var _finished: bool = false
var _mono: SystemFont
var _next: String = NEXT_SCENE


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "monospace"])
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not UiKit.motion_enabled or args.has("--skip-splash") or args.has("--config-editor") or Opening.is_seen():
		_next = SceneRouter.MAIN_MENU_SCENE
		_cue = CUES.size()
		_finish.call_deferred()


func phase() -> Phase:
	if _t < INTRO_END:
		return Phase.INTRO
	if _t < HOLD_END:
		return Phase.HOLD
	if _t < FADE_END + TAIL_SECONDS:
		return Phase.FADE
	return Phase.DONE


## 左键跳过：出现中 → 完整显示；停留中 → 开始消失；消失中不打断
func skip() -> void:
	match phase():
		Phase.INTRO:
			_t = INTRO_END
		Phase.HOLD:
			_t = HOLD_END
		_:
			return
	AudioManager.play_ui("ui_skip")
	while _cue < CUES.size() and float(CUES[_cue][0]) < _t:      # 越过的音效不补播（HOLD_END 处的 logo_out 照常播）
		_cue += 1
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		skip()


func _process(delta: float) -> void:
	step(minf(delta, MAX_STEP))


func step(dt: float) -> void:
	if _finished:
		return
	_t += dt
	while _cue < CUES.size() and float(CUES[_cue][0]) <= _t:
		var c: Array = CUES[_cue]
		AudioManager.play_sfx(str(c[1]), "UI", float(c[2]), randf_range(0.9, 1.15) if bool(c[3]) else 1.0, 0.0, 0)
		_cue += 1
	queue_redraw()
	if phase() == Phase.DONE:
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)
	SceneRouter.reveal_scene(_next, VOID)


# ---------------------------------------------------------------- 绘制

## 时间段 [a, b] 内的 0..1 进度
static func _seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


static func _out_back(x: float) -> float:
	var c: float = 1.9
	return 1.0 + (c + 1.0) * pow(x - 1.0, 3.0) + c * pow(x - 1.0, 2.0)


static func _smooth(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)


func _title_advance() -> float:
	return TITLE_FONT.get_string_size("机", HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE).x + TITLE_SIZE * TITLE_SPACING


func _sub_advance() -> float:
	return _mono.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_SIZE).x + SUB_SIZE * SUB_SPACING


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), VOID)
	var t: float = minf(_t, FADE_END)
	var fade: float = _seg(t, HOLD_END, FADE_END)
	var alpha: float = 1.0 - _smooth(_seg(fade, 0.0, 0.8))
	var soul_alpha: float = 1.0 - _smooth(_seg(fade, 0.25, 1.0))      # 红菱最后熄灭
	if soul_alpha <= 0.0:
		return
	var lift: float = -10.0 * _smooth(fade)
	var title_w: float = _title_advance() * TITLE.length() - TITLE_SIZE * TITLE_SPACING
	var sub_w: float = _sub_advance() * SUBTITLE.length() - SUB_SIZE * SUB_SPACING
	var total_w: float = MARK_PX + GAP_PX + maxf(title_w, sub_w)
	var left: float = (size.x - total_w) * 0.5
	var mid_y: float = size.y * 0.5 + lift
	_draw_mark(Vector2(left, mid_y - MARK_PX * 0.5), MARK_PX / 120.0, t, alpha, soul_alpha)
	var words_x: float = left + MARK_PX + GAP_PX
	var title_h: float = TITLE_FONT.get_ascent(TITLE_SIZE)
	var block_h: float = title_h * 0.86 + SUB_GAP_PX + SUB_SIZE
	var title_base: float = mid_y - block_h * 0.5 + title_h * 0.86
	_draw_title(Vector2(words_x, title_base), t, alpha)
	_draw_subtitle(Vector2(words_x, title_base + SUB_GAP_PX + SUB_SIZE), t, alpha)


## 标志本体；o = 左上角，s = 每设计单位的像素
func _draw_mark(o: Vector2, s: float, t: float, a: float, soul_a: float) -> void:
	var c: Vector2 = o + Vector2(60, 60) * s
	var bone: Color = Color(BONE, a)
	var thread: Color = Color(BONE, 0.72 * a)
	# 虚线圆环：4 段（68 / 13.675，周长 2π·52 ≈ 326.7），自 3 点钟顺时针；整体自 -70° 旋入，各段依次画出
	var spin: float = deg_to_rad(-70.0) * (1.0 - _out_cubic(_seg(t, 0.0, 1.1)))
	var dash: float = 68.0 / 52.0
	var period: float = dash + 13.675 / 52.0
	for i: int in 4:
		var p: float = _out_cubic(_seg(t, 0.08 * i, 0.08 * i + 0.7))
		if p <= 0.0:
			continue
		var a0: float = spin + period * i
		draw_arc(c, 52.0 * s, a0, a0 + dash * p, 48, bone, 1.8 * s, true)
	# 横杆：自中心向两侧展开；挂钩：自上落下
	var bar: float = _out_cubic(_seg(t, 0.35, 0.85))
	if bar > 0.0:
		var hw: float = 36.2 * bar
		draw_rect(Rect2(o + Vector2(60.0 - hw, 22.8) * s, Vector2(hw * 2.0, 4.4) * s), bone)
	var hook: float = _out_cubic(_seg(t, 0.55, 0.9))
	if hook > 0.0:
		var top: float = lerpf(-6.0, 9.8, hook)
		draw_rect(Rect2(o + Vector2(57.8, top) * s, Vector2(4.4, 27.2 - top) * s), Color(BONE, a * hook))
	# 三根提线（中线先、两侧稍后）
	var strings: Array = [
		[Vector2(34, 25), Vector2(34, 38), Vector2(46, 46), Vector2(58, 56), 0.78],
		[Vector2(60, 25), Vector2(60, 34), Vector2(60, 44), Vector2(60, 54), 0.72],
		[Vector2(86, 25), Vector2(86, 38), Vector2(74, 46), Vector2(62, 56), 0.84],
	]
	for st: Array in strings:
		var p: float = _out_cubic(_seg(t, float(st[4]), float(st[4]) + 0.55))
		if p > 0.0:
			_draw_bezier(o, s, st[0] as Vector2, st[1] as Vector2, st[2] as Vector2, st[3] as Vector2, p, thread, 1.2 * s)
	# 红菱：沿中线落下（回弹），落定时泛起一圈涟漪并闪亮
	var drop: float = _seg(t, 1.3, 1.78)
	if drop > 0.0:
		var dy: float = -34.0 * (1.0 - _out_back(drop))
		var da: float = soul_a * _seg(drop, 0.0, 0.35)
		var flash: float = 1.0 - _seg(t, 1.78, 2.3)
		var fill: Color = Color(BLOOD.lerp(Color("#FF5A66"), (0.55 * flash if t >= 1.78 else 0.0)), da)
		var dia: PackedVector2Array = _diamond(o, s, Vector2(60, 68 + dy), 1.0)
		draw_colored_polygon(dia, fill)
		draw_line(o + Vector2(60, 56 + dy) * s, o + Vector2(60, 80 + dy) * s, Color(BLOOD_DARK, 0.3 * da), 1.0 * s, true)
		var rip: float = _seg(t, 1.74, 2.55)
		if rip > 0.0 and rip < 1.0:
			var ring: PackedVector2Array = _diamond(o, s, Vector2(60, 68), 1.0 + 1.6 * _out_cubic(rip))
			ring.append(ring[0])
			draw_polyline(ring, Color(BLOOD, 0.7 * (1.0 - rip) * soul_a), 1.4 * s, true)
	# 下端短线与小环
	var tail: float = _out_cubic(_seg(t, 1.75, 2.1))
	if tail > 0.0:
		draw_line(o + Vector2(60, 84) * s, o + Vector2(60, 84 + 6.0 * tail) * s, thread, 1.2 * s, true)
		var ring_p: float = _seg(t, 1.9, 2.2)
		if ring_p > 0.0:
			draw_arc(o + Vector2(60, 94) * s, 3.3 * s, -PI * 0.5, -PI * 0.5 + TAU * ring_p, 24, bone, 1.4 * s, true)


## 三次贝塞尔前 p 段
func _draw_bezier(o: Vector2, s: float, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, p: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	var n: int = maxi(2, int(24.0 * p))
	for i: int in n + 1:
		var u: float = p * float(i) / float(n)
		pts.append(o + p0.bezier_interpolate(p1, p2, p3, u) * s)
	draw_polyline(pts, col, w, true)


func _diamond(o: Vector2, s: float, center: Vector2, k: float) -> PackedVector2Array:
	return PackedVector2Array([
		o + (center + Vector2(0, -16) * k) * s, o + (center + Vector2(14, 0) * k) * s,
		o + (center + Vector2(0, 16) * k) * s, o + (center + Vector2(-14, 0) * k) * s,
	])


## 主名：每个字由一根提线吊下来——线先垂到字顶，字带回弹落位、由血红褪成骨白，线随即向上收回
func _draw_title(base: Vector2, t: float, a: float) -> void:
	var adv: float = _title_advance()
	var ascent: float = TITLE_FONT.get_ascent(TITLE_SIZE)
	for i: int in TITLE.length():
		var t0: float = 1.85 + 0.12 * i
		var p: float = _seg(t, t0, t0 + 0.75)
		if p <= 0.0:
			continue
		var x: float = base.x + adv * i
		var cx: float = x + (adv - TITLE_SIZE * TITLE_SPACING) * 0.5
		var char_top: float = base.y - ascent * 0.86
		var down: float = _out_cubic(_seg(p, 0.0, 0.35))
		var up: float = _out_cubic(_seg(p, 0.55, 1.0))
		if up < 1.0:
			var y_top: float = lerpf(char_top - 150.0, char_top - 4.0, up)
			var y_end: float = lerpf(char_top - 150.0, char_top - 4.0, down)
			draw_line(Vector2(cx, y_top), Vector2(cx, y_end), Color(BONE, 0.55 * a * (1.0 - up)), 1.2, true)
		var q: float = _seg(p, 0.25, 0.8)
		if q <= 0.0:
			continue
		var dy: float = -26.0 * (1.0 - _out_back(q))
		var col: Color = BLOOD.lerp(BONE, _smooth(_seg(p, 0.45, 1.0)))
		col.a = a * _seg(q, 0.0, 0.5)
		draw_string(TITLE_FONT, Vector2(x, base.y + dy), TITLE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, TITLE_SIZE, col)


## 英文副标：逐字乱码解码后定格
func _draw_subtitle(base: Vector2, t: float, a: float) -> void:
	var adv: float = _sub_advance()
	var tick: int = int(t / 0.045)
	for i: int in SUBTITLE.length():
		var ch: String = SUBTITLE[i]
		if ch == " ":
			continue
		var t0: float = 2.55 + 0.028 * i
		var p: float = _seg(t, t0, t0 + 0.35)
		if p <= 0.0:
			continue
		var settled: bool = p >= 1.0
		if not settled:
			ch = SCRAMBLE[absi(hash(Vector2i(i, tick))) % SCRAMBLE.length()]
		var col: Color = Color(BONE, 0.62 * a) if settled else Color(BLOOD.lerp(BONE, 0.35), 0.8 * a * _seg(p, 0.0, 0.3))
		draw_string(_mono, Vector2(base.x + adv * i, base.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, SUB_SIZE, col)
