class_name CreditsRoll
extends Node2D
## 片尾开发者名单（2026-10-20 用户定稿 D 方案）：第 30 关胜利剧情播完 → SceneRouter.goto_credits() 淡到全黑进入本场景。
## ① 全黑。主角人偶（同战斗己方：金色光芒 / 金色光点 / 金色脚印，但无脚底光圈、无纹章环绕、无信标线）从画面最左边走出，向右走；
## ② 人偶走到画面正中后镜头开始跟随（人偶保持在正中，世界向左滚动）；
## ③ 右边路旁依次站着开发者（各自选的 Q 版形象，头部盖圆形头像；站位比人偶的路靠后、略小，像站在路边看她走过），人偶走近时该开发者亮起、头顶弹出对话框：职位 + 名字 + 想对玩家说的话；
##    人偶走过后开发者转身目送；
## ④ 走过最后一人后镜头停下，人偶加速甩开众人，从右边走出画面；
## ⑤ 画面再次全黑，渐显结束卡（CreditsCard：左栏致玩家的短信、右栏群二维码，与对话框同一套装饰）；右下角「点击任意按键以继续」，
##    玩家按下任意键 / 鼠标键才回主菜单，否则一直停在这页方便扫码（2026-10-21 用户定）。
## Esc：名单途中直接跳到 ⑤。名单、头像、留言、二维码、音乐都在 data/credits.json；界面文字在 strings.json 的 ui.credits_*。
## 金色光效靠 HDR 2D + 辉光（SceneRouter 对本场景开启 HDR，本场景自带 WorldEnvironment）。

const DATA_PATH: String = "res://data/credits.json"
const GROUND_FX_SCRIPT: Script = preload("res://scripts/battle/ground_fx.gd")
const FONT: FontFile = preload("res://assets/fonts/NotoSerifSC-Regular.otf")

const GROUND_Y_RATIO: float = 0.74       ## 地面（脚底）高度占屏高
const HERO_SCALE: float = 1.0            ## 精灵缩放（战斗中 0.5）
const CREW_SCALE: float = 0.84
const ROADSIDE_PX: float = 110.0         ## 开发者站在路边：脚底比人偶的路高出这么多（画面更靠后）
const WALK_SPEED: float = 165.0          ## 像素 / 秒
const RUN_SPEED: float = 420.0           ## 甩开众人时的速度
const RUN_ACCEL: float = 300.0
const START_X: float = -140.0            ## 主角起点（画面左外）
const FIRST_CREW_RATIO: float = 0.64     ## 第一位开发者的横坐标占屏宽
const CREW_SPACING: float = 540.0
const TALK_AHEAD: float = 330.0          ## 主角离开发者还差这么远时，开发者亮起说话
const TURN_BEHIND: float = 80.0          ## 主角走过这么远后，开发者转身目送
const RELEASE_AFTER: float = 320.0       ## 走过最后一人这么远后镜头停下
const BUBBLE_GAP: float = 26.0           ## 对话框尾巴尖离头顶的距离
const BUBBLE_STAGGER: float = 64.0       ## 相邻对话框高低错开
const BUBBLE_FADE_RATIO: float = 0.06    ## 开发者滚到画面左侧这个比例以内时收起对话框
const EXIT_MARGIN: float = 160.0         ## 主角走出右边界这么远后转黑
const BLACKOUT_SECONDS: float = 1.4
const SKIP_BLACKOUT_SECONDS: float = 0.6
const BLACK_HOLD: float = 0.6
const CARD_STEP_SECONDS: float = 0.7     ## 结束卡各块依次淡入
const RETURN_MARGIN: Vector2 = Vector2(56.0, 44.0)   ## 「点击任意按键以继续」离右下角的距离
const RETURN_DELAY: float = 2.0          ## 结束卡出完后多久显示「返回」提示并接受点击
const HINT_SIZE: int = 22

enum Stage { WALK, EXIT, BLACK, CARD, DONE }

var stage: Stage = Stage.WALK
var data: Dictionary = {}

var _view: Vector2 = Vector2(1920.0, 1080.0)
var _ground_y: float = 0.0
var _hero: CreditsFigure = null
var _crew: Array[CreditsFigure] = []
var _bubbles: Array[CreditsBubble] = []
var _talked: Array[bool] = []
var _turned: Array[bool] = []
var _release_x: float = 0.0
var _camera: Camera2D
var _ground_fx: Node2D
var _bubble_layer: CanvasLayer
var _cover: ColorRect
var _card: Control
var _card_items: Array[Control] = []
var _return_hint: Label
var _skip_hint: Label
var _can_leave: bool = false


## 第 level_id 关胜利剧情之后是否接片尾名单
static func plays_after(level_id: String) -> bool:
	return str(load_data().get("trigger_level", "")) == level_id


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _ready() -> void:
	data = load_data()
	_view = get_viewport_rect().size
	_ground_y = _view.y * GROUND_Y_RATIO
	_build_stage()
	_build_cast()
	_build_overlays()
	var bgm: String = str(data.get("bgm", ""))
	if bgm != "":
		AudioManager.play_bgm(bgm)
	if not UiKit.motion_enabled:          # 截图 / 无动效：直接给结束卡
		_show_card(true)


func _build_stage() -> void:
	var back := CanvasLayer.new()
	back.name = "Backdrop"
	back.layer = -10
	add_child(back)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(black)
	var env := Environment.new()             # 同战斗场景：画布背景 + 辉光（金色光效的 HDR 部分发光）
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	_ground_fx = Node2D.new()
	_ground_fx.name = "GroundFX"
	_ground_fx.set_script(GROUND_FX_SCRIPT)
	add_child(_ground_fx)
	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position = _view * 0.5
	add_child(_camera)
	_camera.make_current()


func _build_cast() -> void:
	var tex: Texture2D = Art.unit_texture(str(data.get("hero_form", "striker")))
	var members: Array = data.get("members", []) as Array
	var crew_root := Node2D.new()
	crew_root.name = "Crew"
	add_child(crew_root)
	_bubble_layer = CanvasLayer.new()
	_bubble_layer.name = "Bubbles"
	_bubble_layer.layer = 1
	_bubble_layer.follow_viewport_enabled = true      # 对话框按世界坐标摆放，随镜头平移
	add_child(_bubble_layer)
	var x: float = _view.x * FIRST_CREW_RATIO
	for i: int in members.size():
		var m: Dictionary = members[i] as Dictionary
		var f := CreditsFigure.new()
		f.name = "Crew%d" % i
		f.position = Vector2(x, _ground_y - ROADSIDE_PX)
		crew_root.add_child(f)
		var crew_tex: Texture2D = Art.texture(str(m.get("sprite", "")))
		f.setup(crew_tex if crew_tex != null else tex, false, CREW_SCALE, float(i * 7 % 17) / 17.0, true, m, FONT)
		_crew.append(f)
		var b := CreditsBubble.new()
		b.name = "Bubble%d" % i
		_bubble_layer.add_child(b)
		b.setup(m, FONT)
		b.position = f.position + f.head_top() - Vector2(0.0, BUBBLE_GAP + (BUBBLE_STAGGER if i % 2 == 1 else 0.0))
		_bubbles.append(b)
		_talked.append(false)
		_turned.append(false)
		x += CREW_SPACING
	var last_x: float = _crew[-1].position.x if not _crew.is_empty() else _view.x * 0.5
	_release_x = maxf(last_x + RELEASE_AFTER, _view.x * 0.5)
	_hero = CreditsFigure.new()
	_hero.name = "Hero"
	_hero.position = Vector2(START_X, _ground_y)
	add_child(_hero)
	_hero.setup(tex, true, HERO_SCALE, 0.31, false)
	_hero.speed = WALK_SPEED
	AudioManager.set_footstep_region("bone_greenhouse")      # 片尾接在最终战之后，沿用骨花温室的石地脚步
	_hero.footstep.connect(func(p: Vector2) -> void:
		_ground_fx.call("add_footprint", p, true, _hero.print_size())
		AudioManager.play_footstep(1.0))


func _build_overlays() -> void:
	var top := CanvasLayer.new()
	top.name = "Overlay"
	top.layer = 10
	add_child(top)
	_skip_hint = _text(DataRegistry.get_string("ui.credits_skip"), HINT_SIZE, Palette.BONE_DIM)
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 36)
	_skip_hint.modulate.a = 0.55
	top.add_child(_skip_hint)
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.modulate.a = 0.0
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.add_child(_cover)
	_card = CreditsCard.new()
	_card.name = "EndCard"
	_card.visible = false
	top.add_child(_card)
	(_card as CreditsCard).build({
		"title": DataRegistry.get_string("ui.credits_thanks"),
		"title_en": DataRegistry.get_string("ui.credits_thanks_en"),
		"body": DataRegistry.get_string("ui.credits_letter"),
		"farewell": DataRegistry.get_string("ui.credits_farewell"),
		"join": DataRegistry.get_string("ui.credits_join"),
	}, Art.texture(str(data.get("qr", ""))))
	_card_items = (_card as CreditsCard).items()
	for c: Control in _card_items:
		c.modulate.a = 0.0
	_return_hint = _text(DataRegistry.get_string("ui.credits_return"), HINT_SIZE, Palette.BONE_DIM)
	_return_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)      # 右下角，离边 RETURN_MARGIN；向左上生长
	_return_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_return_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_return_hint.offset_right = -RETURN_MARGIN.x
	_return_hint.offset_bottom = -RETURN_MARGIN.y
	_return_hint.offset_left = _return_hint.offset_right
	_return_hint.offset_top = _return_hint.offset_bottom
	_return_hint.modulate.a = 0.0
	_card.add_child(_return_hint)


func _text(t: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _process(delta: float) -> void:
	match stage:
		Stage.WALK, Stage.EXIT:
			_update_walk(delta)
		Stage.CARD:
			if _can_leave:
				_return_hint.modulate.a = 0.55 + 0.35 * sin(Time.get_ticks_msec() / 1000.0 * 2.4)


func _update_walk(delta: float) -> void:
	var hx: float = _hero.position.x
	_camera.position.x = clampf(hx, _view.x * 0.5, _release_x)
	var left_edge: float = _camera.position.x - _view.x * 0.5
	for i: int in _crew.size():
		var cx: float = _crew[i].position.x
		if not _talked[i] and hx >= cx - TALK_AHEAD:
			_talked[i] = true
			_crew[i].light_up()
			_bubbles[i].pop()
			AudioManager.play_ui("tip_card", -4.0)
		if not _turned[i] and hx >= cx + TURN_BEHIND:
			_turned[i] = true
			_crew[i].face(false)
		if _talked[i] and _bubbles[i].is_shown() and _bubbles[i].modulate.a > 0.99 and cx - left_edge < _view.x * BUBBLE_FADE_RATIO:
			_bubbles[i].fade()
	if stage == Stage.WALK and hx >= _release_x:
		stage = Stage.EXIT                 # 镜头停下，人偶加速甩开众人
		AudioManager.play_sfx("retreat_swish", "SFX", -2.0)
	if stage == Stage.EXIT:
		_hero.speed = move_toward(_hero.speed, RUN_SPEED, RUN_ACCEL * delta)
		if hx > _camera.position.x + _view.x * 0.5 + EXIT_MARGIN:
			_blackout(BLACKOUT_SECONDS)


## 转黑 → 结束卡
func _blackout(seconds: float) -> void:
	if stage == Stage.BLACK or stage == Stage.CARD or stage == Stage.DONE:
		return
	stage = Stage.BLACK
	var t: Tween = create_tween()
	t.tween_property(_skip_hint, "modulate:a", 0.0, seconds * 0.5)
	t.parallel().tween_property(_cover, "modulate:a", 1.0, seconds)
	t.tween_interval(BLACK_HOLD)
	t.tween_callback(_show_card.bind(false))


func _show_card(instant: bool) -> void:
	stage = Stage.CARD
	_cover.modulate.a = 1.0
	_skip_hint.visible = false
	_card.visible = true
	set_process(true)
	if _hero != null:
		_hero.speed = 0.0
	if instant:
		for c: Control in _card_items:
			c.modulate.a = 1.0
		_return_hint.modulate.a = 0.8
		_can_leave = true
		return
	AudioManager.play_ui("unlock_reveal")
	var t: Tween = create_tween()
	for c: Control in _card_items:
		t.tween_property(c, "modulate:a", 1.0, CARD_STEP_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_interval(RETURN_DELAY)
	t.tween_callback(func() -> void: _can_leave = true)


func _unhandled_input(event: InputEvent) -> void:
	if stage == Stage.WALK or stage == Stage.EXIT:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			AudioManager.play_ui("ui_skip")
			_blackout(SKIP_BLACKOUT_SECONDS)
		return
	if stage != Stage.CARD or not _can_leave:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	var key: InputEventKey = event as InputEventKey
	if (mb != null and mb.pressed) or (key != null and key.pressed and not key.echo):    # 任意按键 / 鼠标键
		get_viewport().set_input_as_handled()
		stage = Stage.DONE
		AudioManager.play_ui("ui_confirm_major")
		SceneRouter.goto_main_menu()
