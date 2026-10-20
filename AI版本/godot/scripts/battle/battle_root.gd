extends Node2D
## 战斗场景根（01 §8）：把 BattleController 的世界映射为视图，转发模拟事件到表现，处理快捷键。

const UNIT_VIEW_SCENE: PackedScene = preload("res://scenes/battle/unit_view.tscn")
const STATUS_OVERLAY_SCRIPT: Script = preload("res://scripts/battle/status_overlay.gd")
const RELIC_LAYER_SCRIPT: Script = preload("res://scripts/battle/relic_layer.gd")
const GROUND_FX_SCRIPT: Script = preload("res://scripts/battle/ground_fx.gd")
## 2026-10-19 战斗打击感：击败震屏（整个战场画布平移，HUD 不动）
const SHAKE_PX: float = 9.0
const SHAKE_SECONDS: float = 0.32
const SHAKE_HZ: float = 38.0
const BLAST_SHAKE_SECONDS: float = 0.24          ## 延迟爆炸到期：短一些的震屏
const MELEE_FX_CELLS: float = 1.6                 ## 普通攻击出手时敌我距离（格）不超过此值用斩击，否则用射弹
const VOLLEY_SHOTS: Vector2i = Vector2i(1, 3)     ## 普通攻击每次打出的发数范围（只是动画，伤害一次结算）
const VOLLEY_INTERVAL: float = 0.08               ## 齐射每发间隔（秒）
const VOLLEY_SIZE: float = 0.5                    ## 多发时每发大小（相对常规；只有 1 发时为常规大小）
const KNOCK_MARGIN: Vector2 = Vector2(0.45, 0.2)   ## 击飞落点离战场 / 可视区边缘的余量（格）：左右、下
const KNOCK_TOP_MARGIN: float = 1.25               ## 击飞落点离上边缘的余量（格，人物约 1.2 格高）
const UNIT_HIT_RADIUS: float = 0.5        ## 单位点击命中：离身体线段的距离（格）
const UNIT_HIT_BODY_CELLS: float = 0.9    ## 身体线段高度（格，脚底 → 胸口；精灵约 1.2 格高）
## 2026-10-20 战斗音效：攻击 / 受击音高随机（防"机枪效应"）、齐射后续每发压低、保护对象受伤警报限频、麻痹空挥间隔
const SFX_JITTER: float = 0.05
const VOLLEY_SFX_DB: float = -6.0
const PROTECT_ALERT_MSEC: int = 1500
const FIZZLE_MIN_MSEC: int = 400
## 脚步音色区域（footstep_<区域>_1..3）：30 关战役取章节地图的区域；旧关卡只有 biome，按此表映射
const FOOTSTEP_REGION_BY_BIOME: Dictionary = { "bone_farm": "withered_farm", "wailing_wall": "holy_bell", "hound_den": "flesh_swamp",
	"transit_node": "warped_corridor", "bone_greenhouse": "bone_greenhouse" }

var level: LevelDefinition = null
var selected_id: int = -1
var _views: Dictionary = {}     ## unit id -> UnitView

@onready var controller: BattleController = $BattleController
@onready var _map_layer: Node2D = $MapLayer
@onready var _grid: GridOverlay = $MapLayer/GridOverlay
@onready var _backdrop: Sprite2D = $BackdropLayer
@onready var _ground: Node2D = $MapLayer/GroundLayer
@onready var _floor: FloorHighlight = $MapLayer/FloorHighlight
@onready var _beacon_layer: Node2D = $MapLayer/BeaconLayer
@onready var _canvas_modulate: CanvasModulate = $LightLayer/CanvasModulate
@onready var _deploy_zone: Node2D = $MapLayer/DeployZone
@onready var _unit_layer: Node2D = $UnitLayer
@onready var _fx: Node2D = $FXLayer
@onready var _range: Node2D = $RangeLayer
@onready var _hud: Control = $UI/HUD
@onready var _target_lines: Node2D = $TargetLines
@onready var _debug: Node2D = $DebugLayer

## 第二关首次失败后目标连线强制高亮（关卡册 3.2；03 §3 "HUD 逻辑：level_02 且 fail_count == 1"）
const FIRST_FAIL_HIGHLIGHT_LEVEL: String = "level_02"
const FIRST_FAIL_HIGHLIGHT_SECONDS: float = 2.0
const DRAG_SOURCE_ALPHA: float = 0.35     ## 第四阶段：部署拖动时原位置单位的透明度
const CAM_OVERSCROLL_FRAC: float = 0.125  ## 拖动镜头最多拖出平移范围 = 视口宽 / 高 × 1/8（同选关 OVERSCROLL_FRAC）
const CAM_SPRING_TIME: float = 0.45       ## 拖出范围松手后弹回的时长（同选关 SPRING_TIME）
const DMG_NUMBER_FS: int = 44              ## 普通伤害飘字字号（遗物飘字为 64）；易伤 / 重击加大到 DMG_NUMBER_FS_HEAVY
const DMG_NUMBER_FS_HEAVY: int = 56
const DMG_NUMBER_JITTER: Vector2 = Vector2(22.0, 10.0)   ## 飘字随机偏移（像素），连击时不完全叠在一起

var _last_phase: int = SimTypes.Phase.DEPLOY
## 07 §1.2：玩法矩形（视口像素）与每格像素，每关、每次视口尺寸变化时计算。地图类节点以局部坐标（每格 TILE_SIZE）绘制，
## 统一挂上 位置 = 矩形左上、缩放 = cell_px / TILE_SIZE 的变换；镜头不再缩放地图。
var playfield_rect: Rect2 = Rect2()
var cell_px: int = SimTypes.TILE_SIZE
## 10 §6.4 鼠标触边横向移动：镜头水平偏移（像素，正 = 看向右侧）。Backdrop / 地图 / 各玩法层整体平移 −pan_x；
## 屏幕 → 模拟的换算统一减去偏移（playfield_rect 本身不含偏移）。只碰表现，不碰模拟。
var pan_x: float = 0.0
var _pan_tween: Tween = null
## 用户 2026-10-21：滚轮缩放（以鼠标处为中心）；按住中键或左键拖动空地平移（两个方向），拖出平移范围时橡皮筋、松手弹回（同选关）。
## 视图变换：未缩放时的屏幕点 p → c + (p − c)·cam_zoom − (pan_x, pan_y)，c = 玩法矩形中心；地图类各层与 Backdrop 同一变换，只碰表现。
var pan_y: float = 0.0
var cam_zoom: float = 1.0
var _cam_dragging: bool = false
var _cam_press_pos: Vector2 = Vector2.ZERO   ## 拖动镜头的按下点（屏幕）与当时的偏移，橡皮筋按总位移算
var _cam_press_pan: Vector2 = Vector2.ZERO
var _drag_source: int = -1               ## 部署拖动中的单位（原位置变淡）
var _status_overlay: Node2D = null       ## 30 关战役：异常状态 / Boss 信号 / 增援区提示（status_overlay.gd）
var _relic_ground: Node2D = null         ## 遗物地块 / 放置预览（单位之下，relic_layer.gd GROUND）
var _obstacle_props: ObstacleProps = null ## 用户 2026-10-20：地块立体物件，挂在 UnitLayer 下与角色一起按脚底 y 排序
var _relic_top: Node2D = null            ## 遗物点选目标圈 / 生效特效（单位之上，relic_layer.gd TOP）
var tutorial: TutorialDirector = null    ## 第五阶段：强制引导
var _ground_fx: Node2D = null            ## 脚印 / 落地碎屑（ground_fx.gd，地图之上、目标连线之下）
## 本 tick 内发出、尚未命中的攻击："源>目标" → { src_pos, events, done, gen }。同 tick 的受击 / 倒下事件挂到记录上，
## 等射弹命中或斩击命中时刻再播放受击表现（模拟结果不等待）
var _pending_hits: Dictionary = {}
var _fx_gen: int = 0                     ## 世界重建时递增，作废尚未播放的受击表现
var _blast_from: Dictionary = {}         ## 本 tick 被爆炸波及的单位 id → 爆心（本层坐标）：碎屑 / 击飞背离爆心
var _shake_left: float = 0.0
var _shake_seed: float = 0.0
var _last_placements: Dictionary = {}    ## 上一次的部署（槽位 → 格），用于找出新落位的单位
var _boss_resume_armed: bool = false     ## Boss 换阶段暂停中：下一次 PAUSED → RUNNING 播 battle_resume
var _fizzle_at: Dictionary = {}          ## unit id -> 下次允许播放麻痹空挥音的 Time.get_ticks_msec()（只读模拟原因码）


func _ready() -> void:
	var level_id: String = GameState.current_level_id
	if level_id == "" or DataRegistry.get_level(level_id) == null:
		var ids: Array[String] = DataRegistry.get_level_list()
		level_id = ids[0] if not ids.is_empty() else ""
	level = DataRegistry.get_level(level_id)
	if level == null:
		push_error("[BattleRoot] no level to load")
		return
	GameState.current_level_id = level.id
	controller.persist = true
	controller.world_rebuilt.connect(_on_world_rebuilt)
	controller.ticked.connect(_on_ticked)
	EventBus.sim_event.connect(_on_sim_event)
	EventBus.battle_phase_changed.connect(_on_phase_changed)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.battle_ended.connect(_on_battle_ended)
	SceneRouter.settings_opened.connect(_on_settings_opened)
	_backdrop.call("setup", level)
	_map_layer.call("setup", level)
	_ground.call("setup", level)
	_obstacle_props = ObstacleProps.new()
	_obstacle_props.name = "ObstacleProps"
	_unit_layer.add_child(_obstacle_props)
	_obstacle_props.setup(level)
	_grid.draw_tile_objects = not ObstacleProps.has_objects(level)
	_grid.call("setup", level)
	_floor.setup(level)
	_beacon_layer.call("setup", level, controller, self)
	_canvas_modulate.color = Palette.CANVAS_MODULATE
	_deploy_zone.call("setup", level)
	_target_lines.set("views", _views)
	_target_lines.set("grid_height", level.height)
	_target_lines.set("enabled", GameState.setting_bool("target_lines"))
	_debug.set("views", _views)
	_debug.set("grid_height", level.height)
	_debug.visible = false
	_status_overlay = Node2D.new()
	_status_overlay.name = "StatusOverlay"
	_status_overlay.set_script(STATUS_OVERLAY_SCRIPT)
	add_child(_status_overlay)
	move_child(_status_overlay, _unit_layer.get_index() + 1)
	_status_overlay.set("controller", controller)
	_status_overlay.set("grid_height", level.height)
	_ground_fx = Node2D.new()
	_ground_fx.name = "GroundFx"
	_ground_fx.set_script(GROUND_FX_SCRIPT)
	add_child(_ground_fx)
	move_child(_ground_fx, _target_lines.get_index())
	_fx.set("ground", _ground_fx)
	_relic_ground = _make_relic_layer("RelicGround", 0)
	move_child(_relic_ground, _unit_layer.get_index())
	_relic_top = _make_relic_layer("RelicTop", 1)
	move_child(_relic_top, _status_overlay.get_index() + 1)
	controller.boss_phase_paused.connect(_on_boss_phase_paused)
	_apply_playfield()
	get_viewport().size_changed.connect(_apply_playfield)
	_hud.call("setup", self)
	controller.setup(level, SaveManager.get_level_config(level.id))
	_last_placements = controller.placements.duplicate()
	EventBus.deployment_changed.connect(_on_deployment_changed)
	AudioManager.play_bgm(level.bgm)
	AudioManager.set_footstep_region(footstep_region(level))
	AudioManager.stop_ambient()          # 用户 2026-10-20：所有区域关闭环境底噪
	_hud.call("begin")
	tutorial = TutorialDirector.new()          # 第五阶段：统一强制引导（本关有引导且未看过 / 配置器预览 / 拾取模式时才建遮罩）
	tutorial.name = "TutorialDirector"
	add_child(tutorial)
	tutorial.setup(self, _hud)


## 战斗快捷键在 GUI 之前处理（A02）：否则空格（开始，也是 ui_accept）会先按下当前有焦点的按钮，
## 例如刚点过的提示按钮会再揭示一层。文本输入框有焦点时让给输入框。
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or SceneRouter.is_settings_open():   # 设置浮窗打开时快捷键全部让给浮窗
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if event.is_action_pressed("ui_debug_overlay"):
		_debug.visible = not _debug.visible
		_hud.call("set_debug", _debug.visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_start"):
		if controller.phase == SimTypes.Phase.DEPLOY:
			controller.start()
		elif controller.boss_pending:          # Boss 换阶段暂停：同「继续战斗」按钮
			controller.resume()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_reset"):
		if controller.phase != SimTypes.Phase.DEPLOY:
			AudioManager.play_ui("battle_reset")
		controller.reset()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_toggle_speed"):
		controller.set_speed(1 if controller.speed == 2 else 2)
		AudioManager.play_ui("ui_toggle")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif (controller.phase == SimTypes.Phase.DEPLOY or controller.boss_pending) and _digit(event) > 0:
		AudioManager.play_ui("ui_click" if _digit(event) <= controller.deployed_uids().size() else "ui_error")
		_hud.call("enter_beacon_mode_number", _digit(event))     # 第四阶段：按单位编号数字键进入该单位的信标模式
		get_viewport().set_input_as_handled()


## 数字键 1–9（主键盘或小键盘）按下 → 1–9，其他 0
static func _digit(event: InputEvent) -> int:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo or k.ctrl_pressed or k.alt_pressed:
		return 0
	var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_0
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return code - KEY_KP_0
	return 0


## 决策 ⑦：局内打开设置浮窗时，运行中自动暂停；关闭后保持暂停，由玩家点「继续」
func _on_settings_opened() -> void:
	controller.pause()


## 玩家的暂停 / 继续（P 键与 HUD 暂停按钮都走这里）：播 game_pause / game_unpause。
## 设置浮窗自动暂停、引导暂停直接调 controller，不出声；Boss 换阶段暂停中的继续由 _on_phase_changed 播 battle_resume
func toggle_pause() -> void:
	if controller.phase == SimTypes.Phase.RUNNING:
		AudioManager.play_ui("game_pause")
		controller.pause()
	elif controller.phase == SimTypes.Phase.PAUSED:
		if not controller.boss_pending:
			AudioManager.play_ui("game_unpause")
		controller.resume()


## 脚步音色区域：世界章节地图里的区域 id 优先，否则 biome；旧区域 / biome 名按 FOOTSTEP_REGION_BY_BIOME 映射
static func footstep_region(lv: LevelDefinition) -> String:
	var wc: ChapterDef = DataRegistry.world_chapter()
	var region: String = wc.region_of_level(lv.id) if wc != null and wc.has_level(lv.id) else ""
	if region == "":
		region = lv.biome
	return str(FOOTSTEP_REGION_BY_BIOME.get(region, region))


## 计算玩法矩形并把它应用到全部地图类节点
func _apply_playfield() -> void:
	var pf: Dictionary = Playfield.compute(level, get_viewport_rect().size)
	playfield_rect = pf["rect"] as Rect2
	cell_px = int(pf["cell_px"])
	_apply_pan()


func _panned_layers() -> Array[Node2D]:
	var out: Array[Node2D] = [_map_layer, _target_lines, _unit_layer, _fx, _range, _debug]
	for n: Node2D in [_status_overlay, _relic_ground, _relic_top, _ground_fx]:
		if n != null:
			out.append(n)
	return out


func _apply_pan() -> void:
	var k: float = float(cell_px) / float(SimTypes.TILE_SIZE) * cam_zoom
	var c: Vector2 = playfield_rect.get_center()
	var origin: Vector2 = c + (playfield_rect.position - c) * cam_zoom - Vector2(pan_x, pan_y)
	for n: Node2D in _panned_layers():
		n.scale = Vector2(k, k)
		n.position = origin
	_backdrop.call("set_view", c, cam_zoom, Vector2(pan_x, pan_y))


## 平移上限：未缩放时横向 ±PAN_MAX（不露底，10 §6.4）、纵向 ±PAN_MAX/2；放大后再加上放大多出的半幅
func pan_limit() -> Vector2:
	var extra: Vector2 = playfield_rect.size * (maxf(cam_zoom, 1.0) - 1.0) * 0.5
	return Vector2(UiKit.PAN_MAX, UiKit.PAN_MAX * 0.5) + extra


## 设置镜头横向偏移（clamp 到上限）
func set_pan(x: float) -> void:
	pan_x = clampf(x, -pan_limit().x, pan_limit().x)
	_apply_pan()


## 直接平移（relative = 鼠标位移，屏幕像素；clamp 到上限，不回弹）
func pan_by(relative: Vector2) -> void:
	_kill_pan_tween()
	var lim: Vector2 = pan_limit()
	pan_x = clampf(pan_x - relative.x, -lim.x, lim.x)
	pan_y = clampf(pan_y - relative.y, -lim.y, lim.y)
	_apply_pan()


## 拖动镜头开始（中键 / 左键拖空地）：打断回弹 / 回正，记下按下点
func begin_cam_drag(screen_pos: Vector2) -> void:
	_kill_pan_tween()
	_cam_dragging = true
	_cam_press_pos = screen_pos
	_cam_press_pan = Vector2(pan_x, pan_y)


## 拖动中：地图跟手；超出平移范围的部分走橡皮筋（同选关 _rubber）
func cam_drag_to(screen_pos: Vector2) -> void:
	if not _cam_dragging:
		return
	var raw: Vector2 = _cam_press_pan - (screen_pos - _cam_press_pos)
	var lim: Vector2 = pan_limit()
	var over: Vector2 = get_viewport_rect().size * CAM_OVERSCROLL_FRAC
	pan_x = _rubber(raw.x, -lim.x, lim.x, _cam_press_pan.x, over.x)
	pan_y = _rubber(raw.y, -lim.y, lim.y, _cam_press_pan.y, over.y)
	_apply_pan()


## 松手：出框则弹回范围内（TRANS_BACK，同选关 _spring_back）
func end_cam_drag() -> void:
	if not _cam_dragging:
		return
	_cam_dragging = false
	var lim: Vector2 = pan_limit()
	var to := Vector2(clampf(pan_x, -lim.x, lim.x), clampf(pan_y, -lim.y, lim.y))
	if to.distance_to(Vector2(pan_x, pan_y)) <= 0.01:
		return
	_kill_pan_tween()
	if not UiKit.motion_enabled or not is_inside_tree():
		_set_pan_vec(to)
		return
	_pan_tween = create_tween()
	_pan_tween.tween_method(_set_pan_vec, Vector2(pan_x, pan_y), to, CAM_SPRING_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func cam_dragging() -> bool:
	return _cam_dragging


## 橡皮筋：[lo, hi] 内一比一，出框部分越拉越紧、渐近 lim；按下时已出框则范围扩到按下位置，起步不跳
static func _rubber(x: float, lo: float, hi: float, press: float, lim: float) -> float:
	lo = minf(lo, press)
	hi = maxf(hi, press)
	if lim <= 0.0:
		return clampf(x, lo, hi)
	if x < lo:
		return lo - lim * (1.0 - exp(-(lo - x) / lim))
	if x > hi:
		return hi + lim * (1.0 - exp(-(x - hi) / lim))
	return x


## 不限制范围地摆放（橡皮筋 / 回弹动画用）
func _set_pan_vec(v: Vector2) -> void:
	pan_x = v.x
	pan_y = v.y
	_apply_pan()


func _kill_pan_tween() -> void:
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	_pan_tween = null


## 滚轮：以鼠标处为中心缩放一档（dir = +1 放大 / −1 缩小），鼠标下的地图点保持不动
func zoom_at(screen_pos: Vector2, dir: int) -> void:
	var z: float = clampf(cam_zoom * pow(UiKit.ZOOM_STEP, dir), UiKit.ZOOM_MIN, UiKit.ZOOM_MAX)
	if is_equal_approx(z, cam_zoom):
		return
	_kill_pan_tween()
	var c: Vector2 = playfield_rect.get_center()
	var origin: Vector2 = c + (playfield_rect.position - c) * cam_zoom - Vector2(pan_x, pan_y)
	var origin2: Vector2 = screen_pos - (screen_pos - origin) * (z / cam_zoom)
	cam_zoom = z
	var pan: Vector2 = c + (playfield_rect.position - c) * cam_zoom - origin2
	var lim: Vector2 = pan_limit()
	pan_x = clampf(pan.x, -lim.x, lim.x)
	pan_y = clampf(pan.y, -lim.y, lim.y)
	_apply_pan()
	if _cam_dragging:                      # 拖动中缩放：以当前位置重新起算，地图不跳
		_cam_press_pos = screen_pos
		_cam_press_pan = Vector2(pan_x, pan_y)


## 用户动过镜头（缩放或纵向平移）时不自动回正
func user_camera() -> bool:
	return not is_equal_approx(cam_zoom, 1.0) or not is_zero_approx(pan_y)


## 当前每格屏幕像素（含缩放），拖拽虚影等用
func cell_screen_px() -> float:
	return float(cell_px) * cam_zoom


## 触边横移可用：有选中单位且侧栏可见
func pan_enabled() -> bool:
	return selected_id >= 0 and bool(_hud.call("side_visible"))


## 一帧的触边横移：鼠标 x < PAN_EDGE_PX → 向左，> 窗口宽 − PAN_EDGE_PX → 向右，速度 PAN_SPEED；只有横向
func edge_pan_step(mouse_pos: Vector2, delta: float) -> void:
	if not pan_enabled() or _cam_dragging or (_pan_tween != null and _pan_tween.is_running()):
		return
	if bool(_hud.call("mouse_over_side", mouse_pos)):      # 第四阶段：鼠标在侧栏上不触边平移
		return
	var w: float = get_viewport_rect().size.x
	var dir: float = 0.0
	if mouse_pos.x < UiKit.PAN_EDGE_PX:
		dir = -1.0
	elif mouse_pos.x > w - UiKit.PAN_EDGE_PX:
		dir = 1.0
	if dir != 0.0:
		set_pan(pan_x + dir * UiKit.PAN_SPEED * delta)


## 取消选中或开始战斗时 PAN_RECENTER_SECONDS 内回正
func recenter_pan() -> void:
	if _cam_dragging:
		return
	_kill_pan_tween()
	if is_zero_approx(pan_x) or user_camera():
		return
	_pan_tween = create_tween()
	_pan_tween.tween_method(set_pan, pan_x, 0.0, UiKit.PAN_RECENTER_SECONDS)


func _process(delta: float) -> void:
	if level == null:
		return
	_update_shake(delta)
	_grid.set_line_state(controller.phase == SimTypes.Phase.DEPLOY, grid_focus())
	if DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if get_viewport_rect().has_point(mouse):
		edge_pan_step(mouse, delta)


## 底格线回到原不透明度的情形（2026-10-19）：拖动单位、选中单位看详情、信标模式
func grid_focus() -> bool:
	return selected_id >= 0 or _drag_source >= 0 or _floor.dragging or _floor.beacon_drag \
		or str(_hud.call("beacon_mode_slot")) != ""


## 去掉镜头偏移与缩放后的屏幕坐标（= 未平移、未缩放时的同一世界点）
func unpan(screen_pos: Vector2) -> Vector2:
	var c: Vector2 = playfield_rect.get_center()
	return c + (screen_pos + Vector2(pan_x, pan_y) - c) / cam_zoom


## 屏幕坐标是否落在玩法矩形内（矩形外的点击一律视为点击空地）；矩形随镜头平移
func in_playfield(screen_pos: Vector2) -> bool:
	return playfield_rect.has_point(unpan(screen_pos))


## 屏幕坐标（HUD 中的鼠标位置）→ 模拟坐标
func screen_to_sim(screen_pos: Vector2) -> Vector2:
	var local_px: Vector2 = _map_layer.get_global_transform_with_canvas().affine_inverse() * screen_pos
	return SimTypes.screen_to_sim(local_px, level.height)


func screen_to_cell(screen_pos: Vector2) -> Vector2i:
	return SimTypes.pos_to_cell(screen_to_sim(screen_pos))


## 格子上沿中点的屏幕坐标（P6：不可放置气泡的指向点）
func cell_top_screen(cell: Vector2i) -> Vector2:
	var local: Vector2 = Vector2((cell.x + 0.5) * SimTypes.TILE_SIZE, (level.height - 1 - cell.y) * SimTypes.TILE_SIZE)
	return _map_layer.get_global_transform_with_canvas() * local


## 第五阶段（强制引导）：某格在屏幕上的矩形（随镜头平移 / 缩放）
func cell_screen_rect(cell: Vector2i) -> Rect2:
	var t: Transform2D = _map_layer.get_global_transform_with_canvas()
	var a: Vector2 = t * Vector2(cell.x * SimTypes.TILE_SIZE, (level.height - 1 - cell.y) * SimTypes.TILE_SIZE)
	var b: Vector2 = t * Vector2((cell.x + 1) * SimTypes.TILE_SIZE, (level.height - cell.y) * SimTypes.TILE_SIZE)
	return Rect2(a, Vector2.ZERO).expand(b)


## 屏幕坐标处的存活单位 id，无则 -1；玩法矩形外恒为 -1。
## 命中区 = 脚底到头顶的竖直线段（UNIT_HIT_BODY_CELLS 高）外扩 UNIT_HIT_RADIUS 格：精灵站在格中心往上约 1.2 格，
## 点在身体上也算点中（用户 2026-10-18「点击试作人偶无反应」）；多名重叠取离线段最近者。
func unit_at_screen(screen_pos: Vector2) -> int:
	if not in_playfield(screen_pos):
		return -1
	var p: Vector2 = screen_to_sim(screen_pos)
	var best: int = -1
	var best_d: float = UNIT_HIT_RADIUS
	for u: SimUnit in controller.world.units:
		if not u.alive:
			continue
		var head: Vector2 = u.pos + Vector2(0.0, UNIT_HIT_BODY_CELLS)
		var d: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, u.pos, head))
		if d <= best_d:
			best_d = d
			best = u.id
	return best


## 单位视图在视口中的位置（07 §5 侧栏切侧用），无视图返回 null
func unit_screen_pos(unit_id: int) -> Variant:
	var v: UnitView = _view(unit_id)
	if v == null:
		return null
	return v.get_global_transform_with_canvas().origin


## 当前选中的己方槽位（未选中或选中敌人为 ""）
func selected_slot() -> String:
	return controller.slot_of_unit(selected_id)


## 屏幕坐标处选中单位的信标字母（07 §3.1），无则 ""
func beacon_at_screen(slot_id: String, screen_pos: Vector2) -> String:
	if slot_id == "" or not in_playfield(screen_pos):
		return ""
	var cell: Vector2i = screen_to_cell(screen_pos)
	for b: Dictionary in controller.get_beacons(slot_id):
		if b["cell"] as Vector2i == cell:
			return str(b["id"])
	return ""


## 布信标 / 拖信标的规划态：地板高亮（10 §7）+ 落点提示
func set_beacon_drag(beacon_id: String, cell: Vector2i, legal: bool) -> void:
	_floor.set_beacon_drag(true)
	_beacon_layer.call("set_drag", beacon_id, cell, legal)


func clear_beacon_drag() -> void:
	_beacon_layer.call("clear_drag")
	_floor.set_beacon_drag(false)


## 10 §4：放下到非法格时该格红闪
func flash_illegal(cell: Vector2i) -> void:
	_deploy_zone.call("flash", cell)


func set_drag_hover(cell: Vector2i, legal: bool, form: String = "") -> void:
	_deploy_zone.call("set_hover", cell, legal, Art.unit_texture(form) if form != "" else null)


## 部署拖动的来源单位：原位置变淡（-1 = 恢复）
func set_drag_source(unit_id: int) -> void:
	var prev: UnitView = _view(_drag_source)
	if prev != null:
		prev.modulate.a = 1.0
	_drag_source = unit_id
	var v: UnitView = _view(unit_id)
	if v != null:
		v.modulate.a = DRAG_SOURCE_ALPHA


func clear_drag_hover() -> void:
	_deploy_zone.call("clear_hover")


func _on_world_rebuilt() -> void:
	for v: Node in _unit_layer.get_children():
		if v != _obstacle_props:
			v.queue_free()
	_views.clear()
	_fx.call("clear")
	_ground_fx.call("clear")
	_pending_hits.clear()
	_fizzle_at.clear()
	_fx_gen += 1
	for u: SimUnit in controller.world.units:
		var v: UnitView = UNIT_VIEW_SCENE.instantiate() as UnitView
		_unit_layer.add_child(v)
		v.bind(u, level.height, UnitView.objective_kind_for(level, u))
		v.selected = u.id == selected_id
		v.footstep.connect(_on_footstep)
		_views[u.id] = v
	_range.call("show_for", _view(selected_id))


func _on_ticked() -> void:
	_sync_views()
	var sim_dt: float = SimTypes.SIM_DT * float(controller.speed)
	for v: UnitView in _alive_views():
		v.push_pos(sim_dt)
	_pending_hits.clear()      # 同 tick 的受击 / 倒下事件已挂到各自的攻击记录上
	_blast_from.clear()
	_fizzle_sfx()


## 麻痹空挥（模拟不发事件）：读攻击原因码 PARALYZED（目标在射程内但被麻痹封住出手），按攻速间隔播 attack_fizzle。只读模拟
func _fizzle_sfx() -> void:
	if controller.world == null:
		return
	var now: int = Time.get_ticks_msec()
	for u: SimUnit in controller.world.units:
		var r: int = u.attack_reason if u.dual_rules else u.reason
		if not u.alive or r != SimTypes.ReasonCode.PARALYZED:
			_fizzle_at.erase(u.id)
			continue
		if now >= int(_fizzle_at.get(u.id, 0)):
			_fizzle_at[u.id] = now + maxi(FIZZLE_MIN_MSEC, roundi(1000.0 / maxf(u.attack_speed, 0.1)))
			AudioManager.play_sfx("attack_fizzle", "SFX", -5.0, 1.0, 0.08, 120)


func _on_footstep(pos: Vector2, ally: bool, size: float) -> void:
	_ground_fx.call("add_footprint", pos, ally, size)
	AudioManager.play_footstep(size, ally)


## 顶栏任务句被点击（07 §6）：特殊目标闪烁
func flash_objectives() -> void:
	for v: UnitView in _alive_views():
		if v.objective_kind != UnitView.OBJ_NONE:
			v.flash()


func _on_phase_changed(phase: int) -> void:
	if phase == SimTypes.Phase.RUNNING and _last_phase == SimTypes.Phase.DEPLOY:
		AudioManager.play_sfx("battle_start")
		recenter_pan()      # 10 §6.4：开始战斗回正
	elif phase == SimTypes.Phase.RUNNING and _last_phase == SimTypes.Phase.PAUSED and _boss_resume_armed:
		AudioManager.play_sfx("battle_resume")       # Boss 换阶段后「继续战斗」（按钮 / 空格 / 引导，统一在状态切换处播）
	if phase != SimTypes.Phase.PAUSED:
		_boss_resume_armed = false
	_last_phase = phase
	_deploy_zone.visible = phase == SimTypes.Phase.DEPLOY
	_floor.set_phase(phase)
	_target_lines.visible = phase != SimTypes.Phase.DEPLOY
	var running: bool = phase == SimTypes.Phase.RUNNING
	for v: UnitView in _alive_views():
		v.interpolate = running
		v.show_state = running or phase == SimTypes.Phase.PAUSED
		if phase == SimTypes.Phase.DEPLOY:
			v.snap()
		elif not running:
			v.settle()         # 暂停 / 结束：显示位置平滑停到模拟位置


## 战斗中途加入的单位（Boss 召唤、换阶段增援）补建视图；部署阶段由 world_rebuilt 整体重建
func _sync_views() -> void:
	if controller.world == null:
		return
	for u: SimUnit in controller.world.units:
		if _views.has(u.id):
			continue
		var v: UnitView = UNIT_VIEW_SCENE.instantiate() as UnitView
		_unit_layer.add_child(v)
		v.bind(u, level.height, UnitView.objective_kind_for(level, u))
		v.show_state = controller.phase != SimTypes.Phase.DEPLOY
		v.interpolate = controller.phase == SimTypes.Phase.RUNNING
		v.footstep.connect(_on_footstep)
		_views[u.id] = v
		if controller.phase != SimTypes.Phase.DEPLOY:     # 增援 / 召唤出场：阵营色光柱
			_fx.call("spawn_pillar", v.position, u.faction == SimTypes.Faction.ALLY, v.view_scale(), "spawn")
			if not controller.boss_pending:               # 战斗中出场（Boss 召唤）；换阶段暂停中放下的增援由部署输入播放落位音
				AudioManager.play_sfx("unit_summon", "SFX", 0.0, 1.0, 0.04)


## Boss 换阶段暂停中增援变化（同部署阶段）：收回的增援删视图，挪位的增援对齐新格并播落位光柱；选中的增援被收回则收起侧栏
func _sync_boss_views() -> void:
	for id: Variant in _views.keys():
		if controller.world.get_unit(int(id)) == null:
			var gone: UnitView = _view(int(id))
			if gone != null:
				gone.queue_free()
			_views.erase(id)
	for uid: String in controller.reinforce_uids:
		var v: UnitView = _view(controller.unit_id_of_slot(uid))
		if v != null and v.cur_pos != v.unit.pos:
			v.snap()
			_fx.call("spawn_pillar", v.position, true, 1.0, "place")
	_sync_views()
	if selected_id >= 0 and controller.world.get_unit(selected_id) == null:
		EventBus.unit_selected.emit(-1)


## 多阶段 Boss 到达切换阈值：战斗已暂停。播放该阶段说明（data/stories/<level>_phase<N>.json），提示玩家改指令 / 补增援后「继续」
func _on_boss_phase_paused(next_phase: int) -> void:
	_sync_views()
	_boss_resume_armed = true
	AudioManager.play_sfx("boss_phase")
	_hud.call("_play_and_mark", "%s_phase%d" % [level.id, next_phase])
	_hud.call("show_toast", DataRegistry.get_string("ui.boss_phase_pause").format({ "n": next_phase }))


func _on_deployment_changed() -> void:
	if controller.boss_pending:
		_sync_boss_views()
		return
	# 音效由各玩家操作处自己播（放置 / 移除 / 清空 / 推荐阵容 / 遗物 / 信标）；引导开场的自动清空、读档恢复不出声
	# 部署落位（新放下或挪到新格）：金色小光柱
	for slot: Variant in controller.placements.keys():
		var cell: Variant = controller.placements[slot]
		if cell is Vector2i and _last_placements.get(slot, null) != cell:
			_fx.call("spawn_pillar", SimTypes.sim_to_screen(SimTypes.cell_center(cell as Vector2i), level.height), true, 1.0, "place")
	_last_placements = controller.placements.duplicate()
	# 10 §4：选中的己方单位被移除（移除按钮 / 拖出战场 / 清空）→ 收起侧栏
	if selected_id >= 0 and controller.world.get_unit(selected_id) == null:
		EventBus.unit_selected.emit(-1)


func _on_battle_ended(result: int, _reason: int) -> void:
	var delay: float = 0.0
	if result == SimTypes.BattleResult.LOSE and level.id == FIRST_FAIL_HIGHLIGHT_LEVEL and int(GameState.fail_counts.get(level.id, 0)) == 1:
		_target_lines.set("world", controller.world)
		_target_lines.call("highlight", FIRST_FAIL_HIGHLIGHT_SECONDS)
		delay = FIRST_FAIL_HIGHLIGHT_SECONDS   # 先看连线，再弹结算
	_hud.call("show_result", result, delay)


func _on_unit_selected(unit_id: int) -> void:
	selected_id = unit_id
	if unit_id < 0:
		recenter_pan()      # 10 §6.4：取消选中回正
	_floor.set_selected(controller.slot_of_unit(unit_id) != "")
	for v: UnitView in _alive_views():
		v.selected = v.unit.id == unit_id
	_range.call("show_for", _view(unit_id))


func _on_sim_event(e: Dictionary) -> void:
	match int(e["type"]):
		SimTypes.EventType.ATTACK_FIRED:
			var src: UnitView = _view(int(e["source"]))
			var dst: UnitView = _view(int(e["target"]))
			if src != null and dst != null:
				src.play_attack(dst.position)
				AudioManager.play_sfx(str(src.unit.def.visuals.get("attack_sfx", "")), "SFX", 0.0, 1.0, SFX_JITTER)
				_spawn_attack_fx(src, dst, float(e.get("damage", -1.0)))
		SimTypes.EventType.DAMAGE_APPLIED:
			var key: String = "%d>%d" % [int(e.get("source", -1)), int(e["target"])]
			if _pending_hits.has(key):
				((_pending_hits[key] as Dictionary)["events"] as Array).append(e)
			elif _blast_from.has(int(e["target"])):
				_show_hit(e, _blast_from[int(e["target"])])
			else:
				_show_hit(e, _source_pos(int(e.get("source", -1))))
		SimTypes.EventType.BLAST_PLACED:
			var at: Vector2 = SimTypes.sim_to_screen(e["pos"] as Vector2, level.height)
			var caster: UnitView = _view(int(e["source"]))
			if caster != null:
				caster.play_attack(at)
				AudioManager.play_sfx(str(caster.unit.def.visuals.get("attack_sfx", "")), "SFX", 0.0, 1.0, SFX_JITTER)
				var land: Callable = func() -> void: AudioManager.play_sfx("blast_land", "SFX", -3.0, 1.0, SFX_JITTER)
				_fx.call("spawn_projectile", caster.chest_pos(), at, caster.unit.faction == SimTypes.Faction.ALLY,
					CombatFx.shape_for(caster.unit.def), caster.view_scale(), land, 0.0, _skill_tint(caster.unit))
			var trait_delay: float = float(e["remaining"])
			var src_unit: SimUnit = controller.world.get_unit(int(e["source"]))
			var ally_blast: bool = src_unit != null and src_unit.faction == SimTypes.Faction.ALLY
			_fx.call("spawn_blast_marker", controller.world, int(e["blast_id"]), at, float(e["radius"]), trait_delay, ally_blast, _skill_tint(src_unit))
		SimTypes.EventType.BLAST_DETONATED:
			_fx.call("detonate_marker", int(e["blast_id"]))
			AudioManager.play_sfx("blast_detonate")
			shake(BLAST_SHAKE_SECONDS)
			var center: Vector2 = SimTypes.sim_to_screen(e["pos"] as Vector2, level.height)
			for hid: int in e.get("hits", []) as Array:
				_blast_from[hid] = center
		SimTypes.EventType.BOSS_SKILL:
			_on_boss_skill(e)
		SimTypes.EventType.RELIC_USED:
			_on_relic_used(e)
		SimTypes.EventType.UNIT_DIED:
			if int(e["unit"]) == selected_id:
				EventBus.unit_selected.emit(-1)
			var key: String = "%d>%d" % [int(e.get("killer", -1)), int(e["unit"])]
			if _pending_hits.has(key):
				((_pending_hits[key] as Dictionary)["events"] as Array).append(e)
			elif _blast_from.has(int(e["unit"])):
				_show_death(e, _blast_from[int(e["unit"])])
			else:
				_show_death(e, _source_pos(int(e.get("killer", -1))))


## 2026-10-21 Boss 放招：不论范围内有没有目标，都播施法动作 + 招式特效（信号色，见 CombatFx.BossWave）+ 震屏 + 女鬼尖啸。
## 命中的伤害 / 状态另有各自的受击表现；放招的低频冲击（core_pulse）由 StatusOverlay 在信号放招时播放
func _on_boss_skill(e: Dictionary) -> void:
	var center: Vector2 = SimTypes.sim_to_screen(e["pos"] as Vector2, level.height)
	var caster: UnitView = _view(int(e["source"]))
	if caster != null:
		caster.play_attack(caster.position + Vector2(0.0, -1.0))     # 向上一扬（不转向）
	var consts: Dictionary = STATUS_OVERLAY_SCRIPT.get_script_constant_map()
	var sig: String = str(e.get("signal", ""))
	var col: Color = (consts.get("SIGNAL_COLOR", {}) as Dictionary).get(sig, Color(1.0, 0.36, 0.66)) as Color
	AudioManager.play_sfx("boss_scream", "SFX", 0.0, float((consts.get("SIGNAL_PITCH", {}) as Dictionary).get(sig, 1.0)), 0.03)   # 女鬼尖啸，音高随信号色
	var inside: bool = str(e.get("side", "inside")) == "inside"
	_fx.call("spawn_boss_wave", center, float(e.get("radius", 0.0)) * float(SimTypes.TILE_SIZE), inside, col, str(e.get("effect", "")))
	shake(BLAST_SHAKE_SECONDS)


## 普通攻击特效按出手时的敌我距离决定（用户 2026-10-19：取决于位置关系，而非角色本身）：
## 距离 ≤ MELEE_FX_CELLS = 斩击，否则 = 射弹（形状仍按角色）。
## 每次出手随机打出 1–3 发（只是动画）：只有 1 发时为常规大小；多发时每发间隔 VOLLEY_INTERVAL、弹道 / 斩向各不相同、
## 大小为常规的 VOLLEY_SIZE。每一发命中都播放受击表现（白闪、后挫、碎屑）；最后一发才结算本次伤害（模拟伤害照常一次结算，
## 倒下表现也在最后一发播放）。
## 特殊攻击（延迟爆炸的炮击，BLAST_PLACED）不走这里，始终是单发常规大小的射弹 + 落点预警。
## damage = 本次出手面值（ATTACK_FIRED），命中结算的伤害大于它 = 吃到易伤加成 → 叠一声重击。第 2 发起每发补一声压低的出手音
func _spawn_attack_fx(src: UnitView, dst: UnitView, damage: float = -1.0) -> void:
	var ally: bool = src.unit.faction == SimTypes.Faction.ALLY
	var rec: Dictionary = { "src_pos": src.position, "events": [], "done": false, "gen": _fx_gen, "damage": damage }
	var sfx: String = str(src.unit.def.visuals.get("attack_sfx", ""))
	_pending_hits["%d>%d" % [src.unit.id, dst.unit.id]] = rec
	var melee: bool = src.unit.pos.distance_to(dst.unit.pos) <= MELEE_FX_CELLS
	var shots: int = randi_range(VOLLEY_SHOTS.x, VOLLEY_SHOTS.y)
	var kinds: Array = [0, 1, 2]
	kinds.shuffle()
	var side: float = 1.0 if randf() < 0.5 else -1.0
	var shape: int = CombatFx.shape_for(src.unit.def)
	var info: Dictionary = { "from": src.chest_pos(), "to": dst.chest_pos(), "toward": dst.position - src.position,
		"src_size": src.view_scale(), "dst_size": dst.view_scale(), "ally": ally, "src": src.unit.id, "dst": dst.unit.id,
		"size": 1.0 if shots == 1 else VOLLEY_SIZE, "tint": _skill_tint(src.unit) }
	for i: int in shots:
		var last: bool = i == shots - 1
		var shot: Callable = _volley_shot.bind(rec, info, melee, shape, int(kinds[i % 3]), side * (1.0 if i % 2 == 0 else -1.0), last)
		if i == 0:
			shot.call()
		else:
			get_tree().create_timer(VOLLEY_INTERVAL * float(i)).timeout.connect(_volley_followup.bind(rec, sfx, shot))


## 齐射的第 2 发起：补一声压低的出手音，再打出这一发
func _volley_followup(rec: Dictionary, sfx: String, shot: Callable) -> void:
	if int(rec["gen"]) != _fx_gen:
		return
	AudioManager.play_sfx(sfx, "SFX", VOLLEY_SFX_DB, 1.0, SFX_JITTER * 1.6, 40)
	shot.call()


## 齐射中的一发。攻击者 / 目标的视图可能已释放（倒下、重置）：取不到时用出手时记下的位置
func _volley_shot(rec: Dictionary, info: Dictionary, melee: bool, shape: int, kind: int, side: float, last: bool) -> void:
	if int(rec["gen"]) != _fx_gen:
		return
	var ally: bool = bool(info["ally"])
	var src: UnitView = _view(int(info["src"]))
	var dst: UnitView = _view(int(info["dst"]))
	var from: Vector2 = src.chest_pos() if src != null and not src.is_dying else info["from"] as Vector2
	var to: Vector2 = dst.chest_pos() if dst != null else info["to"] as Vector2
	var hit: Callable = _flush_hit.bind(rec) if last else _volley_hit.bind(rec, info)
	var k: float = float(info["size"])
	var spread: float = 0.0 if is_equal_approx(k, 1.0) else 1.0     # 单发不加抖动
	if melee:
		var jitter := Vector2(randf_range(-10.0, 10.0), randf_range(-12.0, 8.0)) * float(info["dst_size"]) * spread
		_fx.call("spawn_slash", to + jitter, ally, float(info["dst_size"]) * k, info["toward"], kind if spread > 0.0 else -1)
		get_tree().create_timer(CombatFx.SLASH_HIT_AT).timeout.connect(hit)
	else:
		var jitter := Vector2(randf_range(-6.0, 6.0), randf_range(-8.0, 8.0)) * float(info["src_size"]) * spread
		_fx.call("spawn_projectile", from + jitter, to, ally, shape, float(info["src_size"]) * k, hit, side, info["tint"] as Color)


## 非最后一发命中：只播放受击表现（白闪、后挫、少量碎屑、受击音效），不结算伤害、不播放倒下
func _volley_hit(rec: Dictionary, info: Dictionary) -> void:
	if int(rec["gen"]) != _fx_gen:
		return
	var hit: UnitView = _view(int(info["dst"]))
	if hit == null or hit.is_dying:
		return
	var dir: Vector2 = hit.position - (rec["src_pos"] as Vector2)
	hit.play_hit(dir)
	AudioManager.play_sfx(str(hit.unit.def.visuals.get("hit_sfx", "")), "SFX", -2.0, 1.0, SFX_JITTER)
	_fx.call("spawn_debris", hit.position, -hit.chest_offset().y, dir, 4, 0.8)


func _flush_hit(rec: Dictionary) -> void:
	if bool(rec["done"]) or int(rec["gen"]) != _fx_gen:
		return
	rec["done"] = true
	for e: Dictionary in rec["events"] as Array:
		if int(e["type"]) == SimTypes.EventType.UNIT_DIED:
			_show_death(e, rec["src_pos"])
		else:
			_show_hit(e, rec["src_pos"], float(rec.get("damage", -1.0)))


## 攻击者当前位置；没有（遗物、已移除）为 null
## 2026-10-20 敌人技能色（visuals.skill_color）：延迟爆炸的射弹与落点按施放者的技能色着色；未配置 = 透明（用阵营色）
func _skill_tint(u: SimUnit) -> Color:
	if u == null or u.def == null:
		return Color(0, 0, 0, 0)
	return Art.color_from_hex(str(u.def.visuals.get("skill_color", "")), Color(0, 0, 0, 0))


func _source_pos(unit_id: int) -> Variant:
	var v: UnitView = _view(unit_id)
	return v.position if v != null else null


## 受击：白闪后挫 + 背离攻击者抛飞灰黑碎屑。base = 普通攻击的出手面值（其他来源 −1），见 _hit_sfx
func _show_hit(e: Dictionary, from_pos: Variant, base: float = -1.0) -> void:
	var hit: UnitView = _view(int(e["target"]))
	if hit == null or hit.is_dying:
		return
	var dir: Vector2 = Vector2(randf_range(-0.4, 0.4), -1.0)
	if from_pos != null:
		dir = hit.position - (from_pos as Vector2)
	hit.play_hit(dir)
	_hit_sfx(hit, e, base)
	var amount: float = float(e.get("amount", 0.0))
	_damage_number(hit, e, base)
	var count: int = clampi(5 + int(amount / 12.0), 5, 11)
	_fx.call("spawn_debris", hit.position, -hit.chest_offset().y, dir, count, 1.0)


## 伤害飘字（沿用遗物飘字 RelicLayer.spawn_fx，不画扩散圈）：打敌人 = 金色、打己方 = 红色；易伤加成 / Boss 招式字号加大。
## 遗物骨刃（source = −1）已由 _on_relic_used 飘过字，这里跳过
func _damage_number(hit: UnitView, e: Dictionary, base: float) -> void:
	var src: int = int(e.get("source", -1))
	var amount: int = roundi(float(e.get("amount", 0.0)))
	if src < 0 or amount <= 0:
		return
	var heavy: bool = float(amount) > base * 1.01 + 0.01 if base > 0.0 else (_is_boss(src) or hit.unit.has_status("vulnerable"))
	var col: Color = Palette.WARN_RED if hit.unit.faction == SimTypes.Faction.ALLY else Palette.ALCHEMY_GOLD
	var shift := Vector2(randf_range(-1.0, 1.0) * DMG_NUMBER_JITTER.x, randf_range(-1.0, 1.0) * DMG_NUMBER_JITTER.y)
	_relic_top.call("spawn_fx", hit.unit.pos, col, "-%d" % amount, false, DMG_NUMBER_FS_HEAVY if heavy else DMG_NUMBER_FS, shift, true)


## 受击音：目标的 hit_sfx；遗物骨刃（source = −1）只播重击。另叠一声重击：普通攻击伤害大于出手面值（易伤加成）、
## Boss 范围招式（Boss 造成但不是普通攻击）、其他来源（爆炸）命中时目标带易伤。保护对象受伤 = 警报（限频）
func _hit_sfx(hit: UnitView, e: Dictionary, base: float) -> void:
	var src: int = int(e.get("source", -1))
	var amount: float = float(e.get("amount", 0.0))
	if src < 0:
		AudioManager.play_sfx("hit_heavy", "SFX", 0.0, 1.0, SFX_JITTER)
	else:
		AudioManager.play_sfx(str(hit.unit.def.visuals.get("hit_sfx", "")), "SFX", 0.0, 1.0, SFX_JITTER)
		var heavy: bool = amount > base * 1.01 + 0.01 if base > 0.0 else (_is_boss(src) or hit.unit.has_status("vulnerable"))
		if heavy:
			AudioManager.play_sfx("hit_heavy", "SFX", -2.0, 1.0, SFX_JITTER)
	if hit.objective_kind == UnitView.OBJ_PROTECT and amount > 0.0:
		AudioManager.play_sfx("protect_alert", "SFX", 0.0, 1.0, 0.0, PROTECT_ALERT_MSEC)


func _is_boss(unit_id: int) -> bool:
	var w: SimWorld = controller.world
	if w == null or w.boss.is_empty():
		return false
	var b: SimUnit = w.get_spawn(str(w.boss.get("unit", "")))
	return b != null and b.id == unit_id


## 击败：震屏 → 爆散 → 击飞（不出战场 / 可视区）→ 灰化 → 自上而下化为灰烬
func _show_death(e: Dictionary, from_pos: Variant) -> void:
	var dead: UnitView = _view(int(e["unit"]))
	if dead == null or dead.is_dying:
		return
	var dir: Vector2 = Vector2(-1.0 if dead.position.x > float(level.width * SimTypes.TILE_SIZE) * 0.5 else 1.0, 0.0)
	if from_pos != null and dead.position.distance_to(from_pos as Vector2) > 1.0:
		dir = (dead.position - (from_pos as Vector2)).normalized()
	shake()
	_fx.call("spawn_death_burst", dead.position, -dead.chest_offset().y, dir, dead.unit.faction == SimTypes.Faction.ALLY, dead.view_scale())
	dead.play_death(dir, knock_bounds(dead.view_scale()))
	AudioManager.play_sfx(str(dead.unit.def.visuals.get("death_sfx", "")), "SFX", 0.0, 1.0, 0.03)


## 击飞落点范围（单位层坐标，脚底）：战场矩形 ∩ 当前可视区（扣掉 HUD 上下带），再留出人物身高 / 半宽的余量
func knock_bounds(size: float = 1.0) -> Rect2:
	var tile: float = float(SimTypes.TILE_SIZE)
	var field := Rect2(Vector2.ZERO, Vector2(level.width, level.height) * tile)
	var inv: Transform2D = _unit_layer.get_global_transform_with_canvas().affine_inverse()
	var vp: Vector2 = get_viewport_rect().size
	var b: Vector2 = Playfield.bands()
	var a: Vector2 = inv * Vector2(0.0, b.x)
	var c: Vector2 = inv * Vector2(vp.x, vp.y - b.y)
	var visible_rect := Rect2(a, Vector2.ZERO).expand(c)
	var r: Rect2 = field.intersection(visible_rect) if field.intersects(visible_rect) else field
	var left: float = r.position.x + KNOCK_MARGIN.x * tile * size
	var right: float = r.end.x - KNOCK_MARGIN.x * tile * size
	var top: float = r.position.y + KNOCK_TOP_MARGIN * tile * size
	var bottom: float = r.end.y - KNOCK_MARGIN.y * tile
	if right <= left or bottom <= top:
		return Rect2(r.get_center(), Vector2(0.001, 0.001))
	return Rect2(left, top, right - left, bottom - top)


## 震屏：整个战场画布（第 0 层）抖动，HUD 不动；衰减到 0 时复位
func shake(seconds: float = SHAKE_SECONDS) -> void:
	if not UiKit.motion_enabled:
		return
	_shake_left = maxf(_shake_left, seconds)
	_shake_seed = randf() * 100.0


func _update_shake(delta: float) -> void:
	if _shake_left <= 0.0:
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	var k: float = _shake_left / SHAKE_SECONDS
	var tt: float = (SHAKE_SECONDS - _shake_left) * SHAKE_HZ + _shake_seed
	var off := Vector2(sin(tt * 1.7) + 0.5 * sin(tt * 3.1), cos(tt * 1.3) + 0.5 * sin(tt * 2.7)) * SHAKE_PX * k * k / 1.5
	get_viewport().canvas_transform = Transform2D(0.0, off.round() if _shake_left > 0.0 else Vector2.ZERO)


func _exit_tree() -> void:
	if is_inside_tree() and get_viewport() != null:
		get_viewport().canvas_transform = Transform2D.IDENTITY


func _view(unit_id: int) -> UnitView:
	var raw: Variant = _views.get(unit_id, null)
	if raw == null or not is_instance_valid(raw):
		return null
	return raw as UnitView


func _alive_views() -> Array[UnitView]:
	var out: Array[UnitView] = []
	for id: int in _views.keys():
		var v: UnitView = _view(id)
		if v != null and not v.is_dying:
			out.append(v)
	return out


# ---- 遗物（relic_layer.gd；HUD 遗物栏与 MapInput 调用）----
func _make_relic_layer(node_name: String, mode: int) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	n.set_script(RELIC_LAYER_SCRIPT)
	add_child(n)
	n.set("mode", mode)
	n.set("controller", controller)
	n.set("grid_height", level.height)
	return n


## 遗物进入 / 退出点选（"" = 退出）：清掉放置预览与目标悬停
func set_relic_armed(relic_id: String) -> void:
	_relic_top.call("set_armed", relic_id, -1)
	_relic_ground.call("clear_hover")


## 地块遗物落点预览（拖动或点选中），吸附到 cell
func set_relic_hover(relic_id: String, cell: Vector2i, legal: bool) -> void:
	_relic_ground.call("set_hover", relic_id, cell, legal)


func clear_relic_hover() -> void:
	if _relic_ground != null:
		_relic_ground.call("clear_hover")


## 点选目标时悬停的单位（-1 = 无）
func set_relic_target_hover(relic_id: String, unit_id: int) -> void:
	_relic_top.call("set_armed", relic_id, unit_id)


## 屏幕坐标处的遗物地块（部署阶段拖动挪位 / 右键撤回用），无则 ""
func relic_tile_at_screen(screen_pos: Vector2) -> String:
	if controller.relic_tile.is_empty() or not in_playfield(screen_pos):
		return ""
	var rid: String = str(controller.relic_tile["relic"])
	return rid if controller.relic_tile_cells(rid, controller.relic_tile["cell"] as Vector2i).has(screen_to_cell(screen_pos)) else ""


func _on_relic_used(e: Dictionary) -> void:
	var rid: String = str(e.get("relic", ""))
	var target: SimUnit = controller.world.get_unit(int(e.get("target", -1)))
	if target == null:
		return
	var heal: bool = str(e.get("kind", "")) == "heal"
	var amount: int = roundi(float(e.get("amount", 0.0)))
	# 遗物由玩家施放：一律金色。骨刃 = 自上劈落的光柱 + 竖斩；徽章 = 上浮的治疗光柱
	var tv: UnitView = _view(target.id)
	var feet: Vector2 = tv.position if tv != null else SimTypes.sim_to_screen(target.pos, level.height)
	var sz: float = tv.view_scale() if tv != null else 1.0
	_fx.call("spawn_pillar", feet, true, sz, "heal" if heal else "strike")
	if not heal:
		_fx.add_child(CombatFx.Slash.make(feet + Vector2(0.0, UnitView.CHEST_Y * sz), true, sz, Vector2.DOWN, 1))
	_relic_top.call("spawn_fx", target.pos, RelicLayer.relic_color(rid), ("+%d" if heal else "-%d") % amount)
	AudioManager.play_sfx("heal" if heal else "attack_swift")     # 骨刃的重击由随后的 DAMAGE_APPLIED（source = −1）播放
	var v: UnitView = _view(target.id)
	if v != null and heal:
		v.flash()
	_hud.call("show_toast", DataRegistry.get_string("ui.relic_used_heal" if heal else "ui.relic_used_strike").format({
		"name": str(DataRegistry.get_relic(rid).get("name", "")), "target": target.display_name, "n": amount }))
