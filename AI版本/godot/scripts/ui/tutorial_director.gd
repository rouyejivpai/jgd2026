class_name TutorialDirector
extends Node
## 第五阶段（2026-10-17 会议）统一强制引导：按 data/teaching.json 的步骤逐步显示 TutorialOverlay（遮罩 + 高亮 + 箭头 + 说明），
## 等待「下一步」/ 点击高亮处 / 指定事件后进入下一步。所有关卡复用这一套。
## - 每关只自动出现一次（完成或跳过记入存档 tutorials_seen）；配置器预览（GameState.tutorial_preview）不受此限、不写存档。
## - 部署阶段的步骤在开战后自动跳过；战斗中的步骤（phase = running）到时出现并暂停战斗，推进后恢复。
## - 剧情 / 设置 / 结算显示时引导暂时隐藏。
## - 拾取模式（GameState.tutorial_pick，配置器「拾取目标」）：点击界面元素或地块 → 结果写入 GameState.tutorial_pick_result 并返回配置器。

signal finished(skipped: bool)

const OVERLAY_LAYER: int = 3              ## 高于 HUD（UI 层 2），低于设置浮窗（100）
const AUTO_NAME_PREFIX: String = "@"
const UNIT_HOLE_UP: float = 1.35          ## 单位高亮框：脚底以上的格数（盖住精灵头顶）
const UNIT_HOLE_DOWN: float = 0.5         ## 单位高亮框：脚底以下的格数（底座）

var root: Node2D = null                   ## BattleRoot
var hud: Control = null
var controller: BattleController = null
var level: LevelDefinition = null
var overlay: TutorialOverlay = null
var steps: Array[Dictionary] = []
var index: int = -1
var preview: bool = false
var pick_mode: bool = false
var is_test: bool = false
var _paused_by_us: bool = false
var _placed: int = 0
var _beacons: Dictionary = {}             ## unit id -> 信标数
var _layer: CanvasLayer = null
var _zoomed: Dictionary = {}              ## 被 zoom 放大的界面元素 Control -> 原 scale（换步时还原）
var back_button: Button = null            ## 从配置器进入（预览 / 拾取 / 试玩本关）时的「返回配置器」


func setup(p_root: Node2D, p_hud: Control) -> void:
	root = p_root
	hud = p_hud
	controller = root.get("controller") as BattleController
	level = root.get("level") as LevelDefinition
	var teaching: TeachingDef = DataRegistry.get_teaching()
	if not GameState.config_editor_state.is_empty():
		_add_back_button()
	var pv: Dictionary = GameState.tutorial_preview
	pick_mode = bool(GameState.tutorial_pick.get("active", false)) and str(GameState.tutorial_pick.get("level_id", "")) == level.id
	if str(pv.get("level_id", "")) == level.id:
		preview = true
		var was: bool = DataReader.silent
		DataReader.silent = true
		for i: int in (pv.get("steps", []) as Array).size():
			steps.append(TeachingDef.normalize_step((pv["steps"] as Array)[i] as Dictionary, "preview"))
		DataReader.silent = was
		is_test = bool(pv.get("test", false))
	elif GameState.tutorials_enabled:      # 2026-10-18：每次进关都从头播放新手教程（不再因「已看过」跳过；存档仍记录看过）
		steps = teaching.tutorial_steps(level.id)
		is_test = teaching.is_test(level.id)
	if steps.is_empty() and not pick_mode:
		return
	_layer = CanvasLayer.new()
	_layer.name = "TutorialLayer"
	_layer.layer = OVERLAY_LAYER
	root.add_child(_layer)
	overlay = TutorialOverlay.new()
	_layer.add_child(overlay)
	overlay.set_style(teaching.style)
	overlay.next_pressed.connect(_on_next)
	overlay.skip_pressed.connect(skip)
	overlay.back_pressed.connect(_back_to_editor)
	overlay.set_back_visible(false)               # 「返回配置器」统一用独立按钮（_add_back_button）
	_placed = controller.placements.size()
	EventBus.deployment_changed.connect(_on_deployment_changed)
	EventBus.unit_selected.connect(_on_unit_selected)
	EventBus.beacons_changed.connect(_on_beacons_changed)
	EventBus.rules_changed.connect(func(_id: int) -> void: _fire("rules_changed"))
	EventBus.battle_phase_changed.connect(_on_phase_changed)
	if pick_mode:
		overlay.show_step(DataRegistry.get_string("ui.tutorial_pick_title"), DataRegistry.get_string("ui.tutorial_pick_hint"), 1, 1, false, false, "none", "top")
		overlay.set_targets([] as Array[Rect2])
		return
	index = 0


func active() -> bool:
	return overlay != null and (pick_mode or (index >= 0 and index < steps.size()))


func current() -> Dictionary:
	return steps[index] if index >= 0 and index < steps.size() else {}


func _exit_tree() -> void:
	_restore_zoom()
	if _paused_by_us and controller != null and controller.phase == SimTypes.Phase.PAUSED:
		controller.resume()


func _process(_delta: float) -> void:
	if not active() or pick_mode:
		return
	if _blocked_by_other_ui():
		overlay.hide_overlay()
		return
	var step: Dictionary = current()
	var running: bool = controller.phase == SimTypes.Phase.RUNNING or (controller.phase == SimTypes.Phase.PAUSED and _paused_by_us)
	if str(step["phase"]) == "deploy" and controller.phase != SimTypes.Phase.DEPLOY:
		_advance()                          # 已经开战：部署阶段的步骤作废
		return
	if str(step["phase"]) == "running":
		if not running or (controller.world != null and controller.world.clock.time + SimTypes.TIME_EPS < float(step["after"]) and not _paused_by_us):
			overlay.hide_overlay()
			return
		if controller.phase == SimTypes.Phase.RUNNING:
			controller.pause()
			_paused_by_us = true
	if controller.phase == SimTypes.Phase.ENDED:
		finish(false)
		return
	if not overlay.visible:
		_show(step)
	overlay.set_targets(target_rects(step))
	if str(step["advance"]) == "event":
		# 信标模式 / 侧栏按状态推进：已在信标模式（或已退出）、侧栏已收起时直接成立
		var on: bool = str(hud.call("beacon_mode_slot")) != ""
		if str(step["event"]) == "beacon_mode" and on:
			_fire("beacon_mode")
		elif str(step["event"]) == "beacon_mode_exit" and not on:
			_fire("beacon_mode_exit")
		elif str(step["event"]) == "panel_closed" and not bool(hud.call("side_visible")):
			_fire("panel_closed")


func _show(step: Dictionary) -> void:
	var title: String = str(step["title"])
	if is_test:
		title = DataRegistry.get_string("ui.tutorial_test_tag") + title
	if bool(step["deselect"]):
		EventBus.unit_selected.emit(-1)
	overlay.show_step(title, str(step["text"]), index + 1, steps.size(), str(step["advance"]) == "next", bool(step["block"]), str(step["arrow"]), str(step["panel"]),
		str(step["advance"]) == "tap")
	_apply_zoom(step)


## ui 目标的 zoom：以中心为轴放大（出场卡等），换步 / 结束时还原
func _apply_zoom(step: Dictionary) -> void:
	_restore_zoom()
	for t: Dictionary in step["targets"] as Array[Dictionary]:
		if str(t["kind"]) != "ui" or is_equal_approx(float(t.get("zoom", 1.0)), 1.0):
			continue
		var c: Control = find_ui(str(t["node"]))
		if c == null:
			continue
		_zoomed[c] = c.scale
		c.pivot_offset = c.size * 0.5
		var to := Vector2.ONE * float(t["zoom"])
		if UiKit.motion_enabled:
			c.create_tween().tween_property(c, "scale", to, float(overlay.style["zoom_seconds"])).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			c.scale = to


func _restore_zoom() -> void:
	for c: Variant in _zoomed.keys():
		if is_instance_valid(c):
			(c as Control).scale = _zoomed[c] as Vector2
	_zoomed.clear()


## 剧情、设置、结算等浮层显示时让路
func _blocked_by_other_ui() -> bool:
	if SceneRouter.is_settings_open():
		return true
	var dlg: Node = hud.get_node_or_null("DialogueOverlay")
	if dlg is CanvasItem and (dlg as CanvasItem).visible:
		return true
	var res: Node = hud.get_node_or_null("ResultPanel")
	return res is CanvasItem and (res as CanvasItem).visible


## 某步全部目标的屏幕矩形（第一个为箭头目标；找不到的目标略过；blocked 一个目标可有多处）
func target_rects(step: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for t: Dictionary in step["targets"] as Array[Dictionary]:
		if str(t["kind"]) == "blocked":
			for group: Array in blocked_groups(level.blocked):
				out.append(_cells_rect(group))
			continue
		var r: Rect2 = target_rect(t)
		if r.size != Vector2.ZERO:
			out.append(r)
	return out


func target_rect(t: Dictionary) -> Rect2:
	match str(t["kind"]):
		"ui":
			var c: Control = find_ui(str(t["node"]))
			return c.get_global_rect() if c != null and c.is_visible_in_tree() else Rect2()
		"cell", "cells":
			return _cells_rect(t["cells"] as Array)
		"deploy_zone":
			return _cells_rect(level.deploy_cells)
		"unit":
			var u: SimUnit = controller.world.get_spawn(str(t["spawn"])) if controller.world != null else null
			return _unit_rect(u)
		"ally":
			return _unit_rect(_first_ally())
		"ring":
			var owner_unit: SimUnit = _first_ally() if str(t["spawn"]) == "" else (controller.world.get_spawn(str(t["spawn"])) if controller.world != null else null)
			return _ring_rect(owner_unit, str(t["ring"]))
	return Rect2()


func _first_ally() -> SimUnit:
	for uid: String in controller.uids():
		if controller.placements.has(uid):
			return controller.world.get_unit(controller.unit_id_of_slot(uid))
	return null


## 障碍格按四邻接分组（每组合成一处高亮）
static func blocked_groups(cells: Array[Vector2i]) -> Array[Array]:
	var left: Dictionary = {}
	for c: Vector2i in cells:
		left[c] = true
	var out: Array[Array] = []
	for start: Vector2i in cells:
		if not left.has(start):
			continue
		var group: Array[Vector2i] = []
		var todo: Array[Vector2i] = [start]
		left.erase(start)
		while not todo.is_empty():
			var c: Vector2i = todo.pop_back() as Vector2i
			group.append(c)
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if left.has(c + d):
					left.erase(c + d)
					todo.append(c + d)
		out.append(group)
	return out


## HUD 中的节点："名字" 或 "名字/子路径"（名字按递归查找，子路径相对该节点；子路径找不到时按名字在该节点下递归查找，
## 如 Group_attack/RuleSelector = 攻击组第一条指令的目标选择下拉）
func find_ui(spec: String) -> Control:
	var parts: PackedStringArray = spec.split("/", false, 1)
	if parts.is_empty():
		return null
	var base: Node = hud if parts[0] == hud.name else hud.find_child(parts[0], true, false)
	if base == null:
		return null
	if parts.size() > 1:
		var sub: Node = base.get_node_or_null(NodePath(parts[1]))
		if sub == null and not parts[1].contains("/"):
			sub = base.find_child(parts[1], true, false)
		base = sub
	return base as Control


func _cells_rect(cells: Array) -> Rect2:
	var r := Rect2()
	var first: bool = true
	for c: Vector2i in cells:
		var cr: Rect2 = root.call("cell_screen_rect", c) as Rect2
		r = cr if first else r.merge(cr)
		first = false
	return r


## 单位高亮框：脚底锚点往上盖住整个精灵（约 1.2 格高），点在身体任何位置都能穿过遮罩点中（用户 2026-10-18）
func _unit_rect(u: SimUnit) -> Rect2:
	if u == null or not u.alive:
		return Rect2()
	var cr: Rect2 = root.call("cell_screen_rect", u.cell()) as Rect2
	var center: Variant = root.call("unit_screen_pos", u.id)
	var c: Vector2 = center as Vector2 if center != null else cr.get_center()
	var top_left := Vector2(c.x - cr.size.x * 0.6, c.y - cr.size.y * UNIT_HOLE_UP)
	return Rect2(top_left, Vector2(cr.size.x * 1.2, cr.size.y * (UNIT_HOLE_UP + UNIT_HOLE_DOWN)))


## 单位视野圈 / 射程圈的外接矩形（半径按格 × 屏幕上的格宽，与 RangeLayer 同口径）
func _ring_rect(u: SimUnit, ring: String) -> Rect2:
	if u == null or not u.alive:
		return Rect2()
	var radius_cells: float = u.vision if ring == "vision" else u.attack_range
	if radius_cells <= 0.0:
		return Rect2()
	var cr: Rect2 = root.call("cell_screen_rect", u.cell()) as Rect2
	var center: Variant = root.call("unit_screen_pos", u.id)
	var c: Vector2 = center as Vector2 if center != null else cr.get_center()
	var r: float = radius_cells * cr.size.x
	return Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)


# ---- 推进 ----
func _on_next() -> void:
	if active() and str(current().get("advance", "")) == "next":
		_advance()


func _fire(event: String) -> void:
	if not active() or pick_mode:
		return
	var step: Dictionary = current()
	if str(step["advance"]) != "event" or str(step["event"]) != event or not overlay.visible:
		return
	if _counted(event) < int(step["count"]):
		return
	_advance_from.call_deferred(index)


## count 对应的累计数量：已部署单位数 / 全场信标数 / 本步高亮地块内的信标数；其他事件恒为 1
func _counted(event: String) -> int:
	match event:
		"deployed":
			return controller.placements.size()
		"beacon_placed":
			return controller.beacon_total()
		"beacon_in_area":
			return beacons_in_area(current())
	return 1


## 某步高亮地块（cell / cells 目标）内的信标数（全部己方单位合计）
func beacons_in_area(step: Dictionary) -> int:
	var area: Dictionary = {}
	for t: Dictionary in step.get("targets", []) as Array[Dictionary]:
		for c: Vector2i in t.get("cells", []) as Array:
			area[c] = true
	var n: int = 0
	for uid: String in controller.uids():
		for b: Dictionary in controller.get_beacons(uid):
			if area.has(b["cell"] as Vector2i):
				n += 1
	return n


## 只推进第 i 步（同一帧内多次触发只推进一次）
func _advance_from(i: int) -> void:
	if index == i:
		_advance()


func _advance() -> void:
	if not active():
		return
	index += 1
	_restore_zoom()
	overlay.hide_overlay()
	if _paused_by_us and (index >= steps.size() or str(steps[index]["phase"]) != "running" or controller.world.clock.time + SimTypes.TIME_EPS < float(steps[index]["after"])):
		_paused_by_us = false
		if controller.phase == SimTypes.Phase.PAUSED:
			controller.resume()
	if index >= steps.size():
		finish(false)


func skip() -> void:
	finish(true)


func finish(skipped: bool) -> void:
	if overlay == null:
		return
	index = steps.size()
	_restore_zoom()
	overlay.hide_overlay()
	if _paused_by_us and controller.phase == SimTypes.Phase.PAUSED:
		controller.resume()
	_paused_by_us = false
	if not preview and not pick_mode:
		SaveManager.mark_tutorial_seen(level.id)
	finished.emit(skipped)


## 屏幕顶部居中的「返回配置器」（层级高于引导遮罩，不受遮罩拦截）
func _add_back_button() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ConfigBackLayer"
	layer.layer = OVERLAY_LAYER + 1
	root.add_child(layer)
	back_button = Button.new()
	back_button.name = "ConfigBackButton"
	back_button.text = DataRegistry.get_string("ui.tutorial_back")
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.position = Vector2(root.get_viewport_rect().size.x * 0.5 - 90.0, 140.0)
	back_button.custom_minimum_size = Vector2(180.0, 44.0)
	back_button.pressed.connect(_back_to_editor)
	layer.add_child(back_button)


func _back_to_editor() -> void:
	GameState.tutorial_pick = {}
	SceneRouter.goto_config_editor()


# ---- 事件 ----
func _on_deployment_changed() -> void:
	var n: int = controller.placements.size()
	if n > _placed:
		_fire("deployed")
	_placed = n


func _on_unit_selected(unit_id: int) -> void:
	if unit_id < 0 or controller.world == null:
		return
	var u: SimUnit = controller.world.get_unit(unit_id)
	if u != null:
		_fire("ally_selected" if u.faction == SimTypes.Faction.ALLY else "enemy_selected")


func _on_beacons_changed(unit_id: int) -> void:
	var n: int = controller.get_beacons(controller.slot_of_unit(unit_id)).size()
	if n > int(_beacons.get(unit_id, 0)):
		_fire("beacon_placed")
	_beacons[unit_id] = n
	_fire("beacon_in_area")                 # 拖动信标进区域也算；数量按本步区域内的信标数判断


func _on_phase_changed(phase: int) -> void:
	if phase == SimTypes.Phase.RUNNING and not _paused_by_us:
		_fire("battle_started")


## 开始拖动出场卡（free 关 { form }，fixed 关未上场的槽位卡 { slot_id, from_map: false }）
func _notification(what: int) -> void:
	if what != NOTIFICATION_DRAG_BEGIN or overlay == null or not is_inside_tree():
		return
	var data: Variant = get_viewport().gui_get_drag_data()
	if data is Dictionary and ((data as Dictionary).has("form") or ((data as Dictionary).has("slot_id") and not bool((data as Dictionary).get("from_map", false)))):
		_fire("drag_started")


# ---- 输入：advance = click 时点高亮处推进；拾取模式（配置器）----
## 在 GUI 之前处理（不吞掉点击：高亮处的界面照常响应）
func _input(event: InputEvent) -> void:
	if overlay == null:
		return
	if not pick_mode:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT or not active() or not overlay.visible:
			return
		var adv: String = str(current()["advance"])
		if adv == "click" and not overlay.holes.is_empty() and overlay.holes[0].has_point(click.position):
			_advance_from.call_deferred(index)
		elif adv == "tap" and not overlay.panel_rect().has_point(click.position):
			get_viewport().set_input_as_handled()     # 点任意处继续：这一下只用来推进，不传给下面的界面
			_advance_from.call_deferred(index)
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back_to_editor()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if overlay.panel_rect().has_point(mb.position) or (back_button != null and back_button.get_global_rect().has_point(mb.position)):
		return                              # 说明框里的按钮、返回按钮照常
	var picked: Dictionary = pick_at(mb.position, get_viewport().gui_get_hovered_control())
	if picked.is_empty():
		return
	get_viewport().set_input_as_handled()
	GameState.tutorial_pick_result = picked
	_back_to_editor()


## 拾取结果：界面元素 { kind: ui, node } 优先，否则玩法矩形内的地块 { kind: cell, cell }；都不是返回 {}
func pick_at(screen_pos: Vector2, hovered: Control) -> Dictionary:
	var name_of: String = stable_name(hovered)
	if name_of != "":
		return { "kind": "ui", "node": name_of }
	if bool(root.call("in_playfield", screen_pos)):
		var c: Vector2i = root.call("screen_to_cell", screen_pos) as Vector2i
		if level.in_bounds(c):
			return { "kind": "cell", "cell": [c.x, c.y] }
	return {}


## 控件自身或最近的、名字不是自动生成（@…）的祖先名；HUD 本身、地图输入层与引导层返回 ""
func stable_name(c: Control) -> String:
	var n: Node = c
	while n != null and n != hud:
		if n == overlay or (overlay != null and overlay.is_ancestor_of(n)):
			return ""
		if n.name == &"MapInput":
			return ""
		if not str(n.name).begins_with(AUTO_NAME_PREFIX) and hud.find_child(str(n.name), true, false) == n:
			return str(n.name)
		n = n.get_parent()
	return ""
