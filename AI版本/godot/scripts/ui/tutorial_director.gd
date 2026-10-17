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
var _in_beacon_mode: bool = false
var _layer: CanvasLayer = null


func setup(p_root: Node2D, p_hud: Control) -> void:
	root = p_root
	hud = p_hud
	controller = root.get("controller") as BattleController
	level = root.get("level") as LevelDefinition
	var teaching: TeachingDef = DataRegistry.get_teaching()
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
	elif not SaveManager.is_tutorial_seen(level.id) and GameState.tutorials_enabled:
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
	overlay.set_back_visible(preview or pick_mode)
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
	if str(step["advance"]) == "event" and str(step["event"]) == "beacon_mode":
		var on: bool = str(hud.call("beacon_mode_slot")) != ""
		if on and not _in_beacon_mode:
			_in_beacon_mode = true
			_fire("beacon_mode")
		_in_beacon_mode = on


func _show(step: Dictionary) -> void:
	var title: String = str(step["title"])
	if is_test:
		title = DataRegistry.get_string("ui.tutorial_test_tag") + title
	overlay.show_step(title, str(step["text"]), index + 1, steps.size(), str(step["advance"]) == "next", bool(step["block"]), str(step["arrow"]), str(step["panel"]))


## 剧情、设置、结算等浮层显示时让路
func _blocked_by_other_ui() -> bool:
	if SceneRouter.is_settings_open():
		return true
	var dlg: Node = hud.get_node_or_null("DialogueOverlay")
	if dlg is CanvasItem and (dlg as CanvasItem).visible:
		return true
	var res: Node = hud.get_node_or_null("ResultPanel")
	return res is CanvasItem and (res as CanvasItem).visible


## 某步全部目标的屏幕矩形（第一个为箭头目标；找不到的目标略过）
func target_rects(step: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for t: Dictionary in step["targets"] as Array[Dictionary]:
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
			for uid: String in controller.uids():
				if controller.placements.has(uid):
					return _unit_rect(controller.world.get_unit(controller.unit_id_of_slot(uid)))
	return Rect2()


## HUD 中的节点："名字" 或 "名字/子路径"（名字按递归查找，子路径相对该节点）
func find_ui(spec: String) -> Control:
	var parts: PackedStringArray = spec.split("/", false, 1)
	if parts.is_empty():
		return null
	var base: Node = hud if parts[0] == hud.name else hud.find_child(parts[0], true, false)
	if base == null:
		return null
	if parts.size() > 1:
		base = base.get_node_or_null(NodePath(parts[1]))
	return base as Control


func _cells_rect(cells: Array) -> Rect2:
	var r := Rect2()
	var first: bool = true
	for c: Vector2i in cells:
		var cr: Rect2 = root.call("cell_screen_rect", c) as Rect2
		r = cr if first else r.merge(cr)
		first = false
	return r


func _unit_rect(u: SimUnit) -> Rect2:
	if u == null or not u.alive:
		return Rect2()
	var cr: Rect2 = root.call("cell_screen_rect", u.cell()) as Rect2
	var center: Variant = root.call("unit_screen_pos", u.id)
	var c: Vector2 = center as Vector2 if center != null else cr.get_center()
	return Rect2(c - cr.size * 0.6, cr.size * 1.2)


# ---- 推进 ----
func _on_next() -> void:
	if active() and str(current().get("advance", "")) == "next":
		_advance()


func _fire(event: String) -> void:
	if not active() or pick_mode:
		return
	var step: Dictionary = current()
	if str(step["advance"]) == "event" and str(step["event"]) == event and overlay.visible:
		_advance.call_deferred()


func _advance() -> void:
	if not active():
		return
	index += 1
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
	overlay.hide_overlay()
	if _paused_by_us and controller.phase == SimTypes.Phase.PAUSED:
		controller.resume()
	_paused_by_us = false
	if not preview and not pick_mode:
		SaveManager.mark_tutorial_seen(level.id)
	finished.emit(skipped)


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


func _on_phase_changed(phase: int) -> void:
	if phase == SimTypes.Phase.RUNNING and not _paused_by_us:
		_fire("battle_started")


# ---- 输入：advance = click 时点高亮处推进；拾取模式（配置器）----
## 在 GUI 之前处理（不吞掉点击：高亮处的界面照常响应）
func _input(event: InputEvent) -> void:
	if overlay == null:
		return
	if not pick_mode:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT and active() and overlay.visible 				and str(current()["advance"]) == "click" and not overlay.holes.is_empty() and overlay.holes[0].has_point(click.position):
			_advance.call_deferred()
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back_to_editor()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if overlay.panel_rect().has_point(mb.position):
		return                              # 说明框里的按钮照常
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
