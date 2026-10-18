extends Node2D
## 战斗场景根（01 §8）：把 BattleController 的世界映射为视图，转发模拟事件到表现，处理快捷键。

const UNIT_VIEW_SCENE: PackedScene = preload("res://scenes/battle/unit_view.tscn")
const STATUS_OVERLAY_SCRIPT: Script = preload("res://scripts/battle/status_overlay.gd")
const UNIT_HIT_RADIUS: float = 0.5        ## 单位点击命中：离身体线段的距离（格）
const UNIT_HIT_BODY_CELLS: float = 0.9    ## 身体线段高度（格，脚底 → 胸口；精灵约 1.2 格高）

var level: LevelDefinition = null
var selected_id: int = -1
var _views: Dictionary = {}     ## unit id -> UnitView

@onready var controller: BattleController = $BattleController
@onready var _map_layer: Node2D = $MapLayer
@onready var _grid: Node2D = $MapLayer/GridOverlay
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
const AMBIENT_BY_BIOME: Dictionary = { "bone_greenhouse": "amb_greenhouse" }   ## 04 §3.2 两种环境底噪
const AMBIENT_DEFAULT: String = "amb_wind"
const DRAG_SOURCE_ALPHA: float = 0.35     ## 第四阶段：部署拖动时原位置单位的透明度

var _placed_count: int = 0
var _last_phase: int = SimTypes.Phase.DEPLOY
## 07 §1.2：玩法矩形（视口像素）与每格像素，每关、每次视口尺寸变化时计算。地图类节点以局部坐标（每格 TILE_SIZE）绘制，
## 统一挂上 位置 = 矩形左上、缩放 = cell_px / TILE_SIZE 的变换；镜头不再缩放地图。
var playfield_rect: Rect2 = Rect2()
var cell_px: int = SimTypes.TILE_SIZE
## 10 §6.4 鼠标触边横向移动：镜头水平偏移（像素，正 = 看向右侧）。Backdrop / 地图 / 各玩法层整体平移 −pan_x；
## 屏幕 → 模拟的换算统一减去偏移（playfield_rect 本身不含偏移）。只碰表现，不碰模拟。
var pan_x: float = 0.0
var _pan_tween: Tween = null
## 第四阶段（用户 2026-10-08）：Ctrl + 滚轮缩放（以鼠标处为中心）、Ctrl + 左键拖动平移（两个方向）。
## 视图变换：未缩放时的屏幕点 p → c + (p − c)·cam_zoom − (pan_x, pan_y)，c = 玩法矩形中心；地图类各层与 Backdrop 同一变换，只碰表现。
var pan_y: float = 0.0
var cam_zoom: float = 1.0
var _drag_source: int = -1               ## 部署拖动中的单位（原位置变淡）
var _status_overlay: Node2D = null       ## 30 关战役：异常状态 / Boss 信号 / 增援区提示（status_overlay.gd）
var tutorial: TutorialDirector = null    ## 第五阶段：强制引导


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
	controller.boss_phase_paused.connect(_on_boss_phase_paused)
	_apply_playfield()
	get_viewport().size_changed.connect(_apply_playfield)
	_hud.call("setup", self)
	controller.setup(level, SaveManager.get_level_config(level.id))
	_placed_count = controller.placements.size()
	EventBus.deployment_changed.connect(_on_deployment_changed)
	AudioManager.play_bgm(level.bgm)
	AudioManager.play_ambient(str(AMBIENT_BY_BIOME.get(level.biome, AMBIENT_DEFAULT)))
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
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_reset"):
		controller.reset()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_toggle_speed"):
		controller.set_speed(1 if controller.speed == 2 else 2)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("battle_pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif controller.phase == SimTypes.Phase.DEPLOY and _digit(event) > 0:
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


func toggle_pause() -> void:
	if controller.phase == SimTypes.Phase.RUNNING:
		controller.pause()
	elif controller.phase == SimTypes.Phase.PAUSED:
		controller.resume()


## 计算玩法矩形并把它应用到全部地图类节点
func _apply_playfield() -> void:
	var pf: Dictionary = Playfield.compute(level, get_viewport_rect().size)
	playfield_rect = pf["rect"] as Rect2
	cell_px = int(pf["cell_px"])
	_apply_pan()


func _panned_layers() -> Array[Node2D]:
	var out: Array[Node2D] = [_map_layer, _target_lines, _unit_layer, _fx, _range, _debug]
	if _status_overlay != null:
		out.append(_status_overlay)
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


## Ctrl + 左键拖动：地图跟手移动（relative = 鼠标位移，屏幕像素）
func pan_by(relative: Vector2) -> void:
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	var lim: Vector2 = pan_limit()
	pan_x = clampf(pan_x - relative.x, -lim.x, lim.x)
	pan_y = clampf(pan_y - relative.y, -lim.y, lim.y)
	_apply_pan()


## Ctrl + 滚轮：以鼠标处为中心缩放一档（dir = +1 放大 / −1 缩小），鼠标下的地图点保持不动
func zoom_at(screen_pos: Vector2, dir: int) -> void:
	var z: float = clampf(cam_zoom * pow(UiKit.ZOOM_STEP, dir), UiKit.ZOOM_MIN, UiKit.ZOOM_MAX)
	if is_equal_approx(z, cam_zoom):
		return
	var c: Vector2 = playfield_rect.get_center()
	var origin: Vector2 = c + (playfield_rect.position - c) * cam_zoom - Vector2(pan_x, pan_y)
	var origin2: Vector2 = screen_pos - (screen_pos - origin) * (z / cam_zoom)
	cam_zoom = z
	var pan: Vector2 = c + (playfield_rect.position - c) * cam_zoom - origin2
	var lim: Vector2 = pan_limit()
	pan_x = clampf(pan.x, -lim.x, lim.x)
	pan_y = clampf(pan.y, -lim.y, lim.y)
	_apply_pan()


## 用户用过 Ctrl 镜头（缩放或纵向平移）时不自动回正
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
	if not pan_enabled() or (_pan_tween != null and _pan_tween.is_running()):
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
	if _pan_tween != null and _pan_tween.is_valid():
		_pan_tween.kill()
	if is_zero_approx(pan_x) or user_camera():
		return
	_pan_tween = create_tween()
	_pan_tween.tween_method(set_pan, pan_x, 0.0, UiKit.PAN_RECENTER_SECONDS)


func _process(delta: float) -> void:
	if level == null or DisplayServer.get_name() == "headless" or not get_window().has_focus():
		return
	var mouse: Vector2 = get_viewport().get_mouse_position()
	if get_viewport_rect().has_point(mouse):
		edge_pan_step(mouse, delta)


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
		v.queue_free()
	_views.clear()
	_fx.call("clear")
	for u: SimUnit in controller.world.units:
		var v: UnitView = UNIT_VIEW_SCENE.instantiate() as UnitView
		_unit_layer.add_child(v)
		v.bind(u, level.height, UnitView.objective_kind_for(level, u))
		v.selected = u.id == selected_id
		_views[u.id] = v
	_range.call("show_for", _view(selected_id))


func _on_ticked() -> void:
	_sync_views()
	var sim_dt: float = SimTypes.SIM_DT * float(controller.speed)
	for v: UnitView in _alive_views():
		v.push_pos(sim_dt)


## 顶栏任务句被点击（07 §6）：特殊目标闪烁
func flash_objectives() -> void:
	for v: UnitView in _alive_views():
		if v.objective_kind != UnitView.OBJ_NONE:
			v.flash()


func _on_phase_changed(phase: int) -> void:
	if phase == SimTypes.Phase.RUNNING and _last_phase == SimTypes.Phase.DEPLOY:
		AudioManager.play_sfx("battle_start")
		recenter_pan()      # 10 §6.4：开始战斗回正
	_last_phase = phase
	_deploy_zone.visible = phase == SimTypes.Phase.DEPLOY
	_floor.set_phase(phase)
	_target_lines.visible = phase != SimTypes.Phase.DEPLOY
	var running: bool = phase == SimTypes.Phase.RUNNING
	for v: UnitView in _alive_views():
		v.interpolate = running
		v.show_state = running or phase == SimTypes.Phase.PAUSED
		if not running:
			v.snap()


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
		_views[u.id] = v


## 多阶段 Boss 到达切换阈值：战斗已暂停。播放该阶段说明（data/stories/<level>_phase<N>.json），提示玩家改指令 / 补增援后「继续」
func _on_boss_phase_paused(next_phase: int) -> void:
	_sync_views()
	_hud.call("_play_and_mark", "%s_phase%d" % [level.id, next_phase])
	_hud.call("show_toast", DataRegistry.get_string("ui.boss_phase_pause").format({ "n": next_phase }))


func _on_deployment_changed() -> void:
	if controller.boss_pending:
		_sync_views()
		return
	var n: int = controller.placements.size()
	AudioManager.play_sfx("deploy_place" if n >= _placed_count else "deploy_remove")
	_placed_count = n
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
				AudioManager.play_sfx(str(src.unit.def.visuals.get("attack_sfx", "")))
				var proj: String = str(src.unit.def.visuals.get("projectile", "none"))
				if proj != "none":
					var c: Color = Palette.BONE if src.unit.faction == SimTypes.Faction.ALLY else Palette.WARN_RED
					_fx.call("spawn_projectile", src.position + Vector2(0.0, -24.0), dst.position + Vector2(0.0, -24.0), c, Art.texture(proj))
		SimTypes.EventType.DAMAGE_APPLIED:
			var hit: UnitView = _view(int(e["target"]))
			if hit != null:
				hit.play_hit()
				AudioManager.play_sfx(str(hit.unit.def.visuals.get("hit_sfx", "")))
		SimTypes.EventType.BLAST_PLACED:
			var at: Vector2 = SimTypes.sim_to_screen(e["pos"] as Vector2, level.height)
			var caster: UnitView = _view(int(e["source"]))
			if caster != null:
				caster.play_attack(at)
				AudioManager.play_sfx(str(caster.unit.def.visuals.get("attack_sfx", "")))
				_fx.call("spawn_projectile", caster.position + Vector2(0.0, -24.0), at, Palette.FLESH_HI, Art.texture(str(caster.unit.def.visuals.get("projectile", "none"))))
			var trait_delay: float = float(e["remaining"])
			_fx.call("spawn_blast_marker", controller.world, int(e["blast_id"]), at, float(e["radius"]), trait_delay)
		SimTypes.EventType.BLAST_DETONATED:
			_fx.call("detonate_marker", int(e["blast_id"]))
			AudioManager.play_sfx("blast_detonate")
		SimTypes.EventType.UNIT_DIED:
			var dead: UnitView = _view(int(e["unit"]))
			if dead != null:
				dead.play_death()
				AudioManager.play_sfx(str(dead.unit.def.visuals.get("death_sfx", "")))
				if int(e["unit"]) == selected_id:
					EventBus.unit_selected.emit(-1)


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
