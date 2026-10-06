extends Node2D
## 玩法场景：把「地图 + 单位 + 时钟 + 会话 + HUD」接成一个**能真的玩**的关卡。
##
## 【它做什么】选关后进入本场景 → 装配 `LevelSession` → 编制期放信标、写指令
## → 点「开始」进推演期 → 结算 → 回主菜单。
##
## 【它不做什么】不实现规则编辑的细节（那是指令面板的事）、不算分（系统 08）。
## 本文件是**接线**，把已经过测试的系统连起来。
##
## 【相机】2D 正交，直接把逻辑坐标（格）× TILE_PX 当世界坐标；
## 地图居中显示。不做跟随 —— 地图最大 20×20，一屏能看全。

# 【阵营常量】用专门的纯数据脚本（`types.gd`），不要写死 0/1，
# 也不要 preload `unit_actor.gd`（会成环，本轮在 statistics.gd 上踩过）。
const TeamScript := preload("res://src/core/types.gd")
const GameClockScript := preload("res://src/core/time/game_clock.gd")
const BattleMapScript := preload("res://src/core/map/battle_map.gd")
const BeaconLayerScript := preload("res://src/core/map/beacon_layer.gd")
const UnitActorScript := preload("res://src/core/unit/unit_actor.gd")
const LevelLoaderScript := preload("res://src/core/level/level_loader.gd")
const LevelSessionScript := preload("res://src/core/level/level_session.gd")
const DataLoaderScript := preload("res://src/core/data/data_loader.gd")
const ToolbarScript := preload("res://src/ui/hud_toolbar.gd")
const RulePanelScript := preload("res://src/ui/rule_panel.gd")
const RendererScript := preload("res://src/play/battle_renderer.gd")
const ResultScreenScript := preload("res://src/ui/result_screen.gd")
const IntroDialogScript := preload("res://src/ui/dialogs/intro_dialog.gd")
const HelpPanelScript := preload("res://src/ui/help_panel.gd")
const StatisticsScript := preload("res://src/core/score/statistics.gd")
## FR-EDIT-01：运行时 F1 打开编辑器
const EDITOR_SCENE := "res://src/editor/editor_scene.tscn"
const ScorerScript := preload("res://src/core/score/scorer.gd")

## 要载入的关卡 id（由主菜单 / 选关界面通过 `load_level_id()` 设置，
## 或直接在编辑器里指定）
var level_id := "tutorial_01"

var clock: Node = null
var session: RefCounted = null
var beacon_layer: RefCounted = null
var toolbar: Control = null
var rule_panel: Control = null
var camera: Camera2D = null
## 相机基准位置（地图中心）；抽屉展开时在它基础上做横向偏移
var _cam_base := Vector2.ZERO
## 战场绘制层（网格 / 墙 / 终点 / 信标）
var renderer: Node2D = null
## 结算界面与关卡介绍弹窗
var result_screen: Control = null
var intro_dialog: Control = null
## 机制说明面板与暂停菜单
var help_panel: Control = null
var pause_menu: CanvasLayer = null
## 本局结算数据（ResultData）
var result_data = null
var world: Node2D = null

var _data: RefCounted = null
var _loader: RefCounted = null
var _paused := false
var _banner: Label = null


func _ready() -> void:
	_build_nodes()
	if not _start_level(level_id):
		_show_banner("关卡载入失败：%s" % level_id, Color(1, 0.4, 0.4))


## 供外部在 add_child 之前调用
func load_level_id(id: String) -> void:
	level_id = id


func _build_nodes() -> void:
	# 世界根：地图与单位都挂在这里
	world = Node2D.new()
	world.name = "World"
	add_child(world)

	camera = Camera2D.new()
	camera.name = "Camera"
	camera.enabled = true
	add_child(camera)

	# 时钟：只推进逻辑 tick，不受倍速影响
	clock = GameClockScript.new()
	clock.name = "GameClock"
	add_child(clock)

	# HUD 层。
	# 【布局约定】一律用锚点 + 容器，不用绝对像素坐标 ——
	# 之前把提示条钉在 (760, 90)、选关页钉在 y=960，窗口一变小就溢出被裁。
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	add_child(canvas)

	# 顶部工具条：贴顶、横向铺满
	toolbar = ToolbarScript.new()
	toolbar.name = "Toolbar"
	toolbar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	canvas.add_child(toolbar)
	toolbar.connect("button_pressed", _on_toolbar_button)
	toolbar.connect("speed_changed", _on_speed_changed)
	toolbar.connect("vision_toggled", _on_vision_toggled)
	if toolbar != null and renderer != null:
		renderer.call("set_show_vision", bool(toolbar.call("is_vision_visible")))

	# 提示条：全宽容器 + 居中。
	#
	# 【不能套 HBoxContainer】原来是 MarginContainer > HBoxContainer > Label，
	# 而 HBox 会把子节点压到**最小宽度**，于是开了 autowrap 的 Label 变成
	# **逐字竖排**（截图里能看到竖着的「信标 2」）。直接让 Label 铺满
	# MarginContainer 的宽度即可：短文本一行放下，真超长时才按词换行。
	var banner_layer := MarginContainer.new()
	banner_layer.name = "BannerLayer"
	banner_layer.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_layer.add_theme_constant_override("margin_top", 96)
	canvas.add_child(banner_layer)

	_banner = Label.new()
	_banner.name = "Banner"
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.visible = false
	banner_layer.add_child(_banner)

	# 指令面板（左侧抽屉，占屏宽 1/3），默认收起
	rule_panel = RulePanelScript.new()
	rule_panel.name = "RulePanel"
	canvas.add_child(rule_panel)
	rule_panel.connect("closed", _on_rule_panel_closed)
	rule_panel.connect("rules_changed", _on_rules_changed)
	rule_panel.connect("rule_copied", _on_rule_copied)

	# 关卡介绍弹窗与结算界面：都盖在 HUD 之上
	intro_dialog = IntroDialogScript.new()
	intro_dialog.name = "IntroDialog"
	canvas.add_child(intro_dialog)

	help_panel = HelpPanelScript.new()
	help_panel.name = "HelpPanel"
	canvas.add_child(help_panel)

	result_screen = ResultScreenScript.new()
	result_screen.name = "ResultScreen"
	canvas.add_child(result_screen)
	result_screen.connect("action_selected", _on_result_action)

	# 暂停菜单：**必须实例化在场景里**，否则 ESC 只是冻结、没有任何界面。
	# 它自己会把 process_mode 设为 ALWAYS，所以暂停后仍能响应 ESC。
	var pm: PackedScene = load("res://scenes/ui/pause_menu.tscn")
	if pm != null:
		pause_menu = pm.instantiate()
		pause_menu.name = "PauseMenu"
		add_child(pause_menu)
		pause_menu.connect("restart_requested", _on_pause_restart_requested)
		pause_menu.connect("main_menu_requested", _on_pause_main_menu_requested)
	# 让抽屉从工具条下方开始（否则会盖住工具栏左侧的"退出/关卡介绍/机制说明"）。
	# 工具条尺寸要等一帧布局才有值，所以延后设置。
	_sync_panel_top.call_deferred()


func _sync_panel_top() -> void:
	if rule_panel != null and toolbar != null:
		rule_panel.call("set_top_offset", toolbar.size.y + 4.0)


## 抽屉展开时把**地图**右移，让正在编辑的单位不被抽屉挡住。
##
## 【注意是"地图右移"，不是"相机右移"】相机 position 是"出现在屏幕中心的那个世界点"，
## 所以地图要右移、相机就得**左移**（详见函数内的验算）。
## 我原来把这两者搞反了，于是地图反而被推到抽屉底下 —— 用户第 8 轮报的
## "抽屉挡住正在编辑的单位"根因就在这里。
func _apply_camera_offset() -> void:
	if camera == null:
		return
	if rule_panel != null and bool(rule_panel.call("is_open")):
		var drawer_w: float = float(rule_panel.call("drawer_width"))
		var zoom: float = maxf(camera.zoom.x, 0.001)
		# 把地图中心挪到「可见区域（屏宽 − 抽屉宽）」的中心。
		#
		# 【符号是负的】相机 position 是"**出现在屏幕中心**的那个世界点"。
		# 想让地图在屏幕上**向右**让开抽屉，相机就必须**向左**移。
		# 原来写的是 `+drawer_w * 0.5 / zoom`（相机右移 → 地图在屏幕上左移），
		# 结果地图被推到抽屉底下、**正在编辑的那个单位被挡住** ——
		# 这正是用户第 8 轮报的问题，当时只修了"关抽屉后相机不复位"，
		# 没看出方向本来就反了。
		#
		# 验算（1920 宽、7×7 地图、缩放 2.054、抽屉 806）：
		#   shift = -806*0.5/2.054 = -196.2 → 相机 x = 224-196.2 = 27.8
		#   地图中心屏幕 x = (224-27.8)*2.054 + 960 = 1363 = 可见区中心 ✓
		var shift := -drawer_w * 0.5 / zoom
		camera.position = _cam_base + Vector2(shift, 0.0)
		return
	camera.position = _cam_base


func _start_level(id: String) -> bool:
	_data = DataLoaderScript.new()
	var derrs: Array = _data.call("load_all")
	if not derrs.is_empty():
		push_error("数据载入失败：" + str(derrs))
		return false

	_loader = LevelLoaderScript.new()
	var known: Array = _data.call("unit_type_ids")
	var res: Dictionary = _loader.call("load_level", id, known)
	if not bool(res.get("ok", false)):
		push_error("关卡载入失败：" + str(res.get("errors", [])))
		return false

	var lv = res["level"]
	# 会话装配进世界节点，地图与单位都成为 world 的子节点
	session = LevelSessionScript.new()
	var errs: Array = session.call("setup", world, lv, clock, _build_stats_table())
	if not errs.is_empty():
		push_error("会话装配失败：" + str(errs))
		return false

	# 信标层：编制期让玩家放信标
	beacon_layer = BeaconLayerScript.new()
	beacon_layer.call("setup", session.get("map"), int(lv.beacon_quota))
	beacon_layer.connect("changed", _on_beacons_changed)
	_on_beacons_changed(beacon_layer.call("count"), int(lv.beacon_quota))

	# 绘制层：网格 / 墙 / 终点区 / **信标**（信标以前是隐形的，用户反馈过）
	renderer = RendererScript.new()
	renderer.name = "Renderer"
	renderer.z_index = -10                     # 压在地图与单位之下
	world.add_child(renderer)
	renderer.call("setup", session.get("map"), beacon_layer)
	renderer.set("session", session)

	session.connect("state_changed", _on_state_changed)
	session.connect("finished", _on_finished)

	_fit_camera(lv)
	if rule_panel != null:
		rule_panel.call("set_max_beacons", int(lv.beacon_quota))
	_refresh_toolbar()
	# 进关卡自动弹一次介绍（FR-TUT-03）
	_refresh_invalid_badge()
	_show_level_intro()
	return true


## 从 DataLoader 取每种单位的数值（含可选字段默认值）
func _build_stats_table() -> Dictionary:
	var out: Dictionary = {}
	for t in _data.call("unit_type_ids"):
		var r: Dictionary = _data.call("get_unit_stats", str(t), {})
		out[str(t)] = r.get("stats", {})
	return out


## 让地图**铺满视野**：算出合适的缩放，并把相机对准地图中心。
##
## 【为什么不能保持 1:1】7×7 的地图只有 448×448 px，而虚拟分辨率是 1920×1080 ——
## 1:1 画出来就是屏幕正中一小块，四周全是空白。玩家会在空白处点击，
## 于是不断收到「这里不能放信标」（用户实测反馈）。
##
## 【尺寸从哪来】不能问 viewport：`get_visible_rect()` 拿到的是**窗口**尺寸
## （headless 下实测是 1920×1920，高度完全不对）。游戏逻辑坐标系由
## `display/window/size/viewport_*` 决定，所以要读**项目设置**。
func _fit_camera(lv) -> void:
	var size: Vector2i = lv.call("map_size")
	var px := float(BattleMapScript.TILE_PX)
	var map_px := Vector2(float(size.x), float(size.y)) * px

	var vw := float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))
	var vh := float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	if map_px.x > 0.0 and map_px.y > 0.0 and vw > 0.0 and vh > 0.0:
		# 顶部工具条约 60px，再留 8% 边距
		var usable := Vector2(vw * 0.92, (vh - 80.0) * 0.92)
		var scale_fit: float = minf(usable.x / map_px.x, usable.y / map_px.y)
		# 限制在合理区间：太小看不清、太大看不出全貌
		camera.zoom = Vector2.ONE * clampf(scale_fit, 0.5, 4.0)
	# 地图整体中心 = (w, h) * TILE_PX * 0.5（与 BattleRenderer 的坐标约定一致）
	_cam_base = map_px * 0.5
	camera.position = _cam_base
	camera.make_current()


# ---------------------------------------------------------------------------
# 交互
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var world_pos := get_global_mouse_position()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			# 信标模式下点格子放信标；否则点单位打开指令面板（详设 10 的 4.2）
			var in_mode: bool = toolbar != null and bool(toolbar.get("beacon_mode"))
			if in_mode:
				var r: int = int(try_place_beacon_at(world_pos))
				if r == 0:
					_show_banner("这里不能放信标", Color(1, 0.7, 0.4), 0.8)
			else:
				_click_at(world_pos)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_undo_last_beacon()
		return
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		var k := event as InputEventKey
		# FR-EDIT-01（P0）：运行时按 F1 **快速开关编辑器**。
		# 编辑器是独立场景，所以"开"=带着当前关卡 id 切过去；
		# "关"（在编辑器里按 F1 / ESC）由编辑器自己负责回玩法场景。
		if k.keycode == KEY_F1 and not k.ctrl_pressed:
			get_viewport().set_input_as_handled()
			_open_editor_for_current_level()
			return
	if event.is_action_pressed("pause"):
		_toggle_pause()
	elif event.is_action_pressed("restart"):
		_do_reset()


## 普通点击（非信标模式）：点单位打开指令面板，点空地关闭面板。
func _click_at(world_pos: Vector2) -> void:
	var u = _unit_at_world(world_pos)
	if u != null:
		if rule_panel != null:
			# 打开前刷新候选项：信标数、信号数都可能已经变了
			rule_panel.call("set_context", int(beacon_layer.call("count")), _signal_count())
			rule_panel.call("set_sibling_units", _ally_units())
			session.call("refresh_invalid_reasons")     # 打开时先算一遍，别让旧标记留着
			rule_panel.call("open_for", u)
			# 【D-22】打开后按"这个单位自己的信标数"刷新候选（open_for 之后才知道是谁）
			rule_panel.call("set_context",
				int(beacon_layer.call("count_of", int(u.get("entity_id")))), _signal_count())
			_apply_camera_offset()
		return
	# 点空地：关掉抽屉（详设 09 的 4.1「点地图空白关闭」）
	if rule_panel != null and bool(rule_panel.call("is_open")):
		rule_panel.call("close")
		_apply_camera_offset()


## 找出世界坐标下的单位（用逻辑格判定，不依赖碰撞体是否已注册）
func _unit_at_world(world_pos: Vector2) -> Node2D:
	if session == null:
		return null
	var mp = session.get("map")
	var tile: Vector2i = mp.call("world_to_tile", world_pos)
	for u in (session.get("units") as Array):
		# 【必须走 map.logic_to_tile（floor）】不能用 round：逻辑坐标是瓦片中心
		# （瓦片 1 → 1.5），round(1.5)=2 会算到邻格，于是**点不中单位**
		# （冒烟测试抓到："点单位后抽屉打开"失败）。这与 _check_reach_position
		# 曾经的 round 误用是同一类错误。
		var p: Vector2 = u.get("position_logic")
		if mp.call("logic_to_tile", p) == tile:
			return u
	return null


## 在世界坐标处放一个信标。
##
## 【为什么把坐标当参数】原来的写法内部直接读 `get_global_mouse_position()`，
## 于是 headless 测试无法构造「点在合法格上」的场景 —— 只能测到「点无效位置被拒」
## 这一半。坐标作为参数传入后，放置逻辑可以被完整验证（M5 实测）。
## 【D-22】放下的信标该归谁：
## · 指令面板开着 → 归正在编辑的那个单位（"先选单位再放它自己的信标"）
## · 否则只有 1 个存活我方 → 归它（没有歧义，省一步点击）
## · 否则 → -1，拒绝放置并提示（不可公用，猜错归属比拒绝更糟）
func _beacon_owner() -> int:
	if rule_panel != null and bool(rule_panel.call("is_open")):
		var u = rule_panel.call("current_unit")
		if u != null:
			return int(u.get("entity_id"))
	if session == null:
		return -1
	var allies: Array = []
	for u2 in (session.get("units") as Array):
		if u2 == null:
			continue
		if int(u2.get("team")) == TeamScript.TEAM_ALLY and not bool(u2.get("is_dead")):
			allies.append(u2)
	if allies.size() == 1:
		return int((allies[0] as Node).get("entity_id"))
	return -1


## 指令面板的"可选信标数"：**该单位自己的**信标（D-22），没有归属时退回全局
func _beacon_count_for_owner() -> int:
	var owner := _beacon_owner()
	if owner > 0:
		return int(beacon_layer.call("count_of", owner))
	return int(beacon_layer.call("count"))


func try_place_beacon_at(world_pos: Vector2) -> int:
	# 只有编制期能放信标（推演期信标不可改）
	if session == null or bool(session.call("is_running")):
		return 0
	var owner := _beacon_owner()
	if owner < 0:
		_show_banner("先点一个单位，再放它自己的信标", Color(1.0, 0.85, 0.5), 1.2)
		return 0
	var tile: Vector2i = session.get("map").call("world_to_tile", world_pos)
	if not bool(beacon_layer.call("can_place", tile)):
		return 0
	var idx: int = int(beacon_layer.call("add_beacon", tile, owner))
	if idx > 0:
		var ordinal: int = int(beacon_layer.call("owner_ordinal", idx))
		_show_banner("信标 %d" % ordinal, Color(0.6, 0.9, 1.0), 0.7)
	return idx


func _undo_last_beacon() -> void:
	if session != null and bool(session.call("is_running")):
		return
	# 【D-22】右键撤回"当前归属单位自己的最后一个信标"；没有归属时退回全局最后一个
	var owner := _beacon_owner()
	if owner > 0:
		var gi: int = int(beacon_layer.call("last_index_of", owner))
		if gi > 0:
			beacon_layer.call("remove_at", gi)
			return
	var n: int = int(beacon_layer.call("count"))
	if n <= 0:
		return
	# 【下标是 1 起的】`remove_at(i)` 的 i 是**信标序号**（1..n），
	# 所以"最后一个"的序号就是 `n`，不是 `n-1`。
	# 原来写成 `n-1`：n==1 时是 remove_at(0) 越界 → **右键什么也没撤回**；
	# n>=2 时撤掉的是**第一个**信标（撤回撤错了对象）。
	# 这个 bug 是被"撤回后指令应立刻变无效"的用例逼出来的。
	beacon_layer.call("remove_at", n)


func _process(_delta: float) -> void:
	# 信标模式下给鼠标悬停格一个「能不能放」的即时反馈。
	# 玩家之前只能靠「点了没反应」猜，体验很差（用户实测反馈）。
	if renderer == null or session == null:
		return
	var in_mode: bool = toolbar != null and bool(toolbar.get("beacon_mode"))
	var allow: bool = in_mode and not bool(session.call("is_running"))
	var tile: Vector2i = session.get("map").call("world_to_tile", get_global_mouse_position())
	var valid := bool(beacon_layer.call("can_place", tile)) if allow else false
	renderer.call("set_hover", tile, valid, allow)


## 「视野」辅助显示开关（FR-TUT-04）：我方与敌方的可见范围都画。
## 纯表现，不影响任何判定。
func _on_vision_toggled(on: bool) -> void:
	if renderer != null:
		renderer.call("set_show_vision", on)


## 热重载单位数值（FR-UNIT-04）：不重启引擎即可应用新的 units.json。
##
## 【两条路径】① 编辑器改完点「一键试玩」会**新建**玩法场景 → 天然拿到最新数据；
## ② 已经在玩的时候想让新数值生效，就调这个函数。
##
## 血量按**比例**折算：上限被调小时不至于瞬间变成超血。
func reload_unit_data() -> Array[String]:
	var errs: Array[String] = []
	if _data == null:
		return errs
	errs.append_array(_data.call("reload_all"))
	if not errs.is_empty():
		return errs
	if session == null:
		return errs
	for u in (session.get("units") as Array):
		var tid := str(u.get("type_id"))
		if tid.is_empty():
			continue
		var res: Dictionary = _data.call("get_unit_stats", tid, u.get("overrides"))
		var fresh: Dictionary = res.get("stats", {})
		if fresh.is_empty():
			continue
		var old_max := float((u.get("stats") as Dictionary).get("max_hp", 0.0))
		var new_max := float(fresh.get("max_hp", 0.0))
		var ratio := 1.0
		if old_max > 0.0 and new_max > 0.0:
			ratio = new_max / old_max
		u.set("stats", fresh)
		u.set("max_hp", new_max)
		u.set("hp", minf(float(u.get("hp")) * ratio, new_max))
	if renderer != null:
		renderer.call("refresh")
	return errs


func _on_beacons_changed(used, quota) -> void:
	if toolbar != null:
		toolbar.call("set_beacon_count", int(used), int(quota))
	if renderer != null:
		renderer.call("refresh")
	# 【信标数变了要同步给指令面板】条件里的「信标」下拉是按实际放置数生成的，
	# 信标是玩家动态放的（详设 09 的 3.2 明确要求每次重建候选项）。
	if rule_panel != null:
		# 【D-22】候选列表按"当前编辑单位自己的信标"给，不是全局总数
		rule_panel.call("set_context", _beacon_count_for_owner(), _signal_count())
	# 信标数变了 → 引用了不存在信标的指令要立刻标黄（详设 09 的 4.5：
	# 编制期信标变动时主动重算，而不是等推演期求值才发现）
	_refresh_invalid_badge()
	if rule_panel != null:
		rule_panel.call("refresh")


## 重算无效指令并刷新角标（详设 09 的 4.5 + 详设 10 的 1.3）。
## 信标变动、指令增删改、复制之后都要走这里 —— 统一一处，避免漏掉某个入口。
func _refresh_invalid_badge() -> void:
	if session == null:
		return
	if not bool(session.call("is_running")):
		session.call("refresh_invalid_reasons")
	if toolbar != null:
		toolbar.call("set_invalid_count", int(session.call("invalid_rule_count")))


## 本关全部我方单位（指令复制用）
func _ally_units() -> Array:
	var out: Array = []
	if session == null:
		return out
	for u in (session.get("units") as Array):
		if u != null and int(u.get("team")) == 0:
			out.append(u)
	return out


## 复制完指令后：重算目标单位的无效标记并刷新面板
func _on_rule_copied(_target) -> void:
	_refresh_invalid_badge()
	if rule_panel != null:
		rule_panel.call("refresh")


func _signal_count() -> int:
	if session == null:
		return 1
	var lv = session.get("level")
	if lv == null:
		return 1
	return maxi(1, int(lv.signal_count))


func _on_toolbar_button(id: String) -> void:
	match id:
		ToolbarScript.BTN_EXIT:
			_exit_to_menu()
		ToolbarScript.BTN_INTRO:
			# 玩家显式点的「关卡介绍」：**强制打开**（不受"首次"限制）
			_show_level_intro(true)
			# 【D-29】策划案 v2 3.2 的「提示」按钮：多次点击后会转成「推荐阵型 → 一键过关」。
			# 本阶段只做**点击计数**，到阈值时如实告诉玩家该功能还没做 ——
			# 比"什么都不做"诚实，也比"假装有"强。
			_hint_clicks += 1
			if _hint_clicks >= HINT_TO_RECOMMEND:
				_show_banner("已点提示 %d 次：「推荐阵型 / 一键过关」尚未实现（策划案 v2 3.2）"
					% _hint_clicks, Color(0.95, 0.85, 0.55), 2.5)
		ToolbarScript.BTN_HELP:
			_show_help()
		ToolbarScript.BTN_BEACON:
			# 模式开关本身由工具条负责；这里只给玩家反馈
			var on: bool = toolbar != null and bool(toolbar.get("beacon_mode"))
			_show_banner("信标模式：开（左键放 / 右键撤）" if on else "信标模式：关",
				Color(0.6, 0.9, 1.0), 1.0)
		ToolbarScript.BTN_START:
			_do_start()
		ToolbarScript.BTN_RESET:
			_do_reset()
		ToolbarScript.BTN_CLEAR:
			_do_clear()
		ToolbarScript.BTN_SPEED:
			pass    # 速度变化由 speed_changed 信号处理


func _on_rule_panel_closed() -> void:
	# 【必须在这里复位相机】抽屉有三种关闭方式：点它的「关闭」按钮、点地图空白、
	# 进推演期自动收起。前两种都走 close() → 发 closed 信号，所以复位逻辑
	# 必须挂在信号上；只在 _click_at 里复位的话，用「关闭」按钮关掉后
	# 相机会一直偏着（实测截图里 05/06 仍偏移 156px）。
	_apply_camera_offset()


func _on_rules_changed() -> void:
	# 【原来是 pass】规则改动后只在推演期求值时才会重算 invalid_reason，
	# 所以刚写错引用的指令**不会立刻标黄**。现在改动即重算并刷新角标。
	_refresh_invalid_badge()


func _do_start() -> void:
	if session == null:
		return
	if bool(session.call("start")):
		_show_banner("推演开始", Color(0.7, 1.0, 0.7), 1.0)


## 「提示」按钮的点击次数（D-29：策划案说多次点击后会变成「推荐阵型」）
var _hint_clicks := 0
## 点到这个次数就该出现「推荐阵型」了（策划案没给具体次数，取 3）
const HINT_TO_RECOMMEND := 3


## 「清空」（D-33，策划案 v2 3.2）：「清除所有我方单位，回到关卡开始」。
##
## 【实现 = 重置 + 让我方单位退场】先走「重置」回到开局（时钟、位置、血量、信号都回初始），
## 再让每个我方单位走**真实的退场路径** `die()`（它会从战斗状态里注销、关掉受击盒、换外观）。
## 这样不需要另写一套"移除单位"，也不会留下半死不活的对象。
##
## 【为什么横幅要写"按重置可恢复"】预置单位模型下清空后场上没有我方单位，
## 玩家如果不知道能恢复，会以为关卡坏了（`LevelSession.reset()` 会复活单位，确实能恢复）。
func _do_clear() -> void:
	if session == null:
		return
	session.call("reset")
	var removed := 0
	for u in (session.get("units") as Array):
		if u == null:
			continue
		if int(u.get("team")) != TeamScript.TEAM_ALLY:
			continue
		if bool(u.get("is_dead")):
			continue
		u.call("die")
		removed += 1
	_show_banner("已清空我方单位 %d 个（按「重置」可恢复）" % removed,
		Color(1.0, 0.78, 0.55), 2.5)
	_refresh_invalid_badge()


## 场上还活着的我方单位数（清空用例与 HUD 都用它，避免各自写一套口径）
func ally_alive_count() -> int:
	if session == null:
		return 0
	var n := 0
	for u in (session.get("units") as Array):
		if u == null:
			continue
		if int(u.get("team")) == TeamScript.TEAM_ALLY and not bool(u.get("is_dead")):
			n += 1
	return n


func _do_reset() -> void:
	if session == null:
		return
	session.call("reset")
	_show_banner("已重置（指令与信标保留）", Color(0.9, 0.9, 0.6), 1.0)


func _exit_to_menu() -> void:
	_goto_scene("res://scenes/ui/main_menu.tscn")


## 弹机制说明面板（读 res://data/help/机制说明.md，按二级标题分节）
func _show_help() -> void:
	if help_panel == null:
		return
	help_panel.call("load_document")
	help_panel.call("open_panel")


## 弹关卡介绍。内容取自关卡数据的 `intro` 字段（title + tips）。
## 显示关卡介绍弹窗。
##
## 【`force = false` 表示"自动弹"】FR-TUT-03 的原话是「每关**首次**进入时弹出介绍与 tips」，
## 所以进关时只在**没看过**的情况下自动弹；看过之后玩家仍可从工具条的
## 「关卡介绍」按钮随时再看（那时走 `force = true`）。
## 我原来是无条件弹 —— 每次进关都弹一遍，与"首次"不符。
func _show_level_intro(force: bool = false) -> void:
	if intro_dialog == null or session == null:
		return
	var lv = session.get("level")
	var intro: Dictionary = {}
	if lv != null and (lv.get("intro") is Dictionary):
		intro = lv.get("intro")
	if not force:
		var lid := str(lv.get("id")) if lv != null else ""
		if Save.has_seen_intro(lid):
			return
		Save.mark_intro_seen(lid)
	intro_dialog.call("show_intro", intro)


func _toggle_pause() -> void:
	# 【ESC 现在打开真正的暂停菜单】原来只是 get_tree().paused = true，
	# 冻结了却没有任何界面，玩家看不到能做什么（详设 10 的 4.5）。
	if pause_menu != null:
		if bool(pause_menu.call("is_open")):
			pause_menu.call("close")
		else:
			pause_menu.call("open")
		_paused = bool(pause_menu.call("is_open"))
		return
	# 兜底：没有菜单时保持原来的纯冻结行为
	_paused = not _paused
	get_tree().paused = _paused
	_show_banner("已暂停" if _paused else "继续", Color(0.9, 0.9, 0.6), 1.0)


func _on_pause_restart_requested() -> void:
	# 与工具条「重置」同义：保留玩家的指令与信标（而不是重载场景）。
	# 重载会丢掉关卡 id —— 玩法场景是带 id 实例化出来的。
	_do_reset()


func _on_pause_main_menu_requested() -> void:
	_goto_scene("res://scenes/ui/main_menu.tscn")


func _on_speed_changed(speed: float) -> void:
	if clock != null:
		clock.call("set_speed_multiplier", speed)


func _on_state_changed(state: int) -> void:
	_refresh_toolbar()
	# 进入推演期就收起抽屉：观战时不该被面板挡住地图（详设 09 的 4.6）
	if state != LevelSessionScript.State.BUILD and rule_panel != null:
		if bool(rule_panel.call("is_open")):
			rule_panel.call("close")
			_apply_camera_offset()
	if state == LevelSessionScript.State.RUN:
		_show_banner("推演中", Color(0.7, 1.0, 0.7), 0.8)


func _on_finished(verdict: int) -> void:
	var win: bool = verdict == LevelSessionScript.Verdict.WIN
	_show_banner("胜利！" if win else "失败",
		Color(0.6, 1.0, 0.6) if win else Color(1, 0.5, 0.5), 2.5)
	_build_and_show_result(verdict)


## 结算：采集统计 → 算分 → 读写最佳记录 → 交给结算界面渲染。
##
## 【为什么在玩法场景里算，而不是在 LevelSession 里】
## 统计要用到**信标数**（属于信标层）与**游戏内时间**（属于时钟），
## 而 LevelSession 不持有信标层（那由本场景创建）。详设 08 的 2.3 也说
## 统计量"由会话在结算时一次性快照传入"。放在这里能同时看到三方，且不让
## 逻辑层耦合 UI 侧的对象。
func _build_and_show_result(verdict: int) -> void:
	if session == null:
		return
	var lv = session.get("level")
	var level_id := str(lv.id) if lv != null else ""
	var coef: Dictionary = {}
	if _data != null:
		coef = _data.call("scoring_coefficients")
	var beacon_n: int = int(beacon_layer.call("count")) if beacon_layer != null else 0
	var elapsed: float = float(clock.get("game_time")) if clock != null else 0.0

	var stats = StatisticsScript.snapshot(session.get("units") as Array, beacon_n, elapsed)

	# 先读历史最佳（约定：**分越低越好**），再算分，最后写回内存存档。
	var save_node := get_node_or_null("/root/Save")
	var save_dict: Variant = null
	if save_node != null:
		save_dict = save_node.get("data")
	var best_before := ScorerScript.best_of(save_dict, level_id)
	result_data = ScorerScript.compute(level_id, verdict, stats, coef, best_before)
	if save_dict != null:
		ScorerScript.apply_best(save_dict, level_id, result_data)

	if result_screen != null:
		result_screen.set("has_next", not _next_level_id().is_empty())
		result_screen.call("show_result", result_data)


## 取清单里的下一关 id；没有则返回空串（结算界面据此隐藏"下一关"）
func _next_level_id() -> String:
	if _loader == null or session == null:
		return ""
	var lv = session.get("level")
	if lv == null:
		return ""
	var ids: Array = _loader.call("list_level_ids")
	var cur := str(lv.id)
	var idx := ids.find(cur)
	if idx < 0 or idx + 1 >= ids.size():
		return ""
	return str(ids[idx + 1])


## FR-EDIT-01：从玩法中按 F1 打开关卡编辑器，**带着当前关卡 id**，
## 这样改完能直接试玩回同一关（详情 07 的 1.2「独立场景，运行时 F1 可开关」）。
func _open_editor_for_current_level() -> void:
	var packed: PackedScene = load(EDITOR_SCENE)
	if packed == null:
		_show_banner("找不到编辑器场景", Color(1, 0.7, 0.4), 1.0)
		return
	var ed = packed.instantiate()
	# 编辑器用 load_level_id 接收要打开哪一关
	ed.call("load_level_id", str(session.get("level").get("id")) if session != null else "tutorial_01")
	var root := get_tree().root
	var old := get_tree().current_scene
	root.add_child(ed)
	get_tree().current_scene = ed
	if old != null and old != ed:
		old.queue_free()


## 结算界面的出口
func _on_result_action(id: String) -> void:
	match id:
		ResultScreenScript.ACTION_RETRY:
			if result_screen != null:
				result_screen.call("hide_result")
			if session != null:
				session.call("reset")      # 保留玩家的指令与信标
		ResultScreenScript.ACTION_NEXT:
			var nid := _next_level_id()
			if not nid.is_empty():
				_goto_level(nid)
		ResultScreenScript.ACTION_SELECT:
			_goto_scene("res://src/ui/level_select.tscn")
		ResultScreenScript.ACTION_EXIT:
			_goto_scene("res://scenes/ui/main_menu.tscn")


## 换关卡：重建一个玩法场景并替换当前场景，避免残留状态
func _goto_level(id: String) -> void:
	var packed: PackedScene = load("res://src/play/play_scene.tscn")
	if packed == null:
		return
	var ps = packed.instantiate()
	ps.call("load_level_id", id)
	var root := get_tree().root
	var old := get_tree().current_scene
	root.add_child(ps)
	get_tree().current_scene = ps
	if old != null and old != ps:
		old.queue_free()


func _goto_scene(path: String) -> void:
	if has_node("/root/SceneLoader"):
		get_node("/root/SceneLoader").call("goto", path)


func _refresh_toolbar() -> void:
	if toolbar != null and session != null:
		toolbar.call("apply_state", int(session.get("state")))


# ---------------------------------------------------------------------------
# 提示条
# ---------------------------------------------------------------------------

func _show_banner(text: String, color: Color, seconds: float = 1.5) -> void:
	if _banner == null:
		return
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.visible = true
	if seconds <= 0.0:
		return
	# 用一次性定时器隐藏；重复调用时先杀掉旧的，避免闪烁
	var old := get_node_or_null("BannerTimer")
	if old != null:
		old.queue_free()
	var t := Timer.new()
	t.name = "BannerTimer"
	t.one_shot = true
	t.wait_time = seconds
	t.timeout.connect(func() -> void:
		if _banner != null:
			_banner.visible = false)
	add_child(t)
	t.start()
