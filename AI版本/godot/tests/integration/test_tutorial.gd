extends GutTest
## 第五阶段（2026-10-17 会议）统一强制引导：teaching.json 解析与覆盖、遮罩只放行高亮处、按事件 / 下一步推进、
## 开战后跳过部署步骤、战斗中步骤暂停战斗、跳过 / 完成后不再出现、配置器预览与拾取。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const LEVEL: String = "level_c01"

var _saved_data: Dictionary
var _saved_level_id: String
var _saved_unlocks: Dictionary


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = DataRegistry.get_initial_unlocks()
	(GameState.unlocks["forms"] as Array).append_array(["bulwark", "swift"])
	# 第 1–4 关通关奖励（沿信标、最远），与玩家按顺序打到第 5 关时一致
	(GameState.unlocks["actions"] as Array).append("follow_beacons")
	(GameState.unlocks["selectors"] as Array).append("farthest")
	(GameState.unlocks["presets"] as Array).append_array(["preset.follow_route", "preset.attack_farthest_in_range"])
	(SaveManager.data.get("tutorials_seen", {}) as Dictionary).clear()
	GameState.tutorial_preview = {}
	GameState.tutorial_pick = {}
	GameState.tutorial_pick_result = {}


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	GameState.unlocks = _saved_unlocks
	GameState.tutorial_preview = {}
	GameState.tutorial_pick = {}
	GameState.config_editor_state = {}


func _battle(level_id: String) -> Node2D:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	return root


func _director(root: Node2D) -> TutorialDirector:
	return root.get("tutorial") as TutorialDirector


func test_teaching_data_parsed_and_overrides_applied() -> void:
	var t: TeachingDef = DataRegistry.get_teaching()
	assert_false(DataRegistry.has_errors)
	for i: int in range(1, 7):
		var lid: String = "level_c0%d" % i
		assert_true(t.has_tutorial(lid), "教程关引导 PPT：第 %d 关有引导" % i)
		assert_false(t.is_test(lid), "已替换开发期测试内容")
	var steps: Array[Dictionary] = t.tutorial_steps(LEVEL)
	assert_eq(str(steps[0]["advance"]), "tap", "第 1 关第 1 步：点击屏幕继续")
	assert_true(bool(steps[1]["block"]), "有高亮且不是「下一步」：默认只放行高亮处")
	assert_eq(float((steps[1]["targets"] as Array[Dictionary])[0]["zoom"]), 1.15, "单位卡放大")
	var c02: Array[Dictionary] = t.tutorial_steps("level_c02")
	assert_false(bool(c02[2]["block"]), "「下一步」步骤默认不拦截")
	assert_eq(int(c02[5]["count"]), 3, "第三个信标")
	var c05: LevelDefinition = DataRegistry.get_level("level_c05")
	assert_true(c05.allowed_selectors.has(SimTypes.Selector.FARTHEST))
	assert_false(c05.allowed_selectors.has(SimTypes.Selector.MOST_DAMAGE), "测试用的 allowed 覆盖已移除")


func test_invalid_steps_reported() -> void:
	var was: bool = DataReader.silent
	DataReader.silent = true
	var before: int = DataReader.error_count
	TeachingDef.normalize_step({ "text": "x", "advance": "event", "event": "nope", "targets": [{ "kind": "ufo" }] }, "t")
	TeachingDef.from_dict({ "levels": { "level_07": { "hints": ["a", "b", "c", "d"] } } }, "t")
	TeachingDef.normalize_step({ "text": "x", "advance": "event", "event": "ally_selected", "count": 2, "targets": [{ "kind": "ring", "ring": "aura" }] }, "t")
	DataReader.silent = was
	assert_eq(DataReader.error_count - before, 5, "未知事件 / 未知目标类型 / 第七关覆盖 / count 用在不计数的事件 / 未知圆环都报错")


func test_blocked_groups_merge_adjacent_cells() -> void:
	var cells: Array[Vector2i] = [Vector2i(4, 3), Vector2i(4, 4), Vector2i(6, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0)]
	var groups: Array[Array] = TutorialDirector.blocked_groups(cells)
	assert_eq(groups.size(), 3)
	assert_eq(groups.map(func(g: Array) -> int: return g.size()), [2, 1, 3])


func test_overlay_blocks_outside_holes_only() -> void:
	var ov := TutorialOverlay.new()
	add_child_autofree(ov)
	ov.show_step("t", "x", 1, 1, false, true, "auto", "auto")
	ov.set_targets([Rect2(100, 100, 50, 50)] as Array[Rect2])
	assert_false(ov._has_point(Vector2(120, 120)), "高亮处放行")
	assert_true(ov._has_point(Vector2(400, 400)), "高亮外吞掉")
	ov.show_step("t", "x", 1, 1, true, false, "auto", "auto")
	assert_false(ov._has_point(Vector2(400, 400)), "block = false：整层放行")


func _click(d: TutorialDirector, pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	d._input(e)


## 当前步骤的高亮全部找得到（每个目标至少一处矩形）
func _assert_targets_found(d: TutorialDirector) -> void:
	await wait_process_frames(2)
	var step: Dictionary = d.current()
	var rects: Array[Rect2] = d.target_rects(step)
	var want: int = (step["targets"] as Array[Dictionary]).filter(func(t: Dictionary) -> bool: return str(t["kind"]) != "none").size()
	assert_true(rects.size() >= want, "第 %d 步「%s」的 %d 个高亮都找得到（找到 %d）" % [d.index + 1, str(step["title"]), want, rects.size()])
	assert_true(d.overlay.visible, "第 %d 步显示" % (d.index + 1))


func _next(d: TutorialDirector) -> void:
	(d.overlay.find_child("NextButton", true, false) as Button).pressed.emit()
	await wait_process_frames(2)


func test_c01_budget_card_zone_start() -> void:
	var root: Node2D = _battle(LEVEL)
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	assert_true(d.active(), "首次进入本关：引导开始")
	await _assert_targets_found(d)
	assert_eq(d.index, 0)
	assert_false((d.overlay.find_child("NextButton", true, false) as Button).visible, "点击任意处继续：不显示「下一步」")
	_click(d, Vector2(5, 5))
	await wait_process_frames(2)
	assert_eq(d.index, 1, "点屏幕 → 单位卡")
	await _assert_targets_found(d)
	var card: Control = d.find_ui("Card_striker")
	await wait_seconds(0.4)
	assert_gt(card.scale.x, 1.1, "单位卡放大")
	d._fire("drag_started")
	await wait_process_frames(2)
	assert_eq(d.index, 2, "开始拖动 → 可部署区")
	assert_eq(card.scale, Vector2.ONE, "换步后还原")
	await _assert_targets_found(d)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_false(d.overlay._has_point(d.overlay.holes[0].get_center()), "部署区可点（可拖放）")
	assert_ne(c.add_unit("striker", Vector2i(1, 3)), "")
	await wait_process_frames(2)
	assert_eq(d.index, 3, "放下单位 → 开始")
	await _assert_targets_found(d)
	assert_true(c.start())
	await wait_process_frames(2)
	assert_false(d.active(), "开始战斗 → 引导完成")
	assert_true(SaveManager.is_tutorial_seen(LEVEL), "完成后记入存档")


func test_c02_beacon_purchase_obstacles_and_route() -> void:
	var root: Node2D = _battle("level_c02")
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var hud: Control = root.get_node("UI/HUD") as Control
	await _assert_targets_found(d)
	var uid: String = c.add_unit("striker", Vector2i(1, 5))
	assert_ne(uid, "")
	EventBus.unit_selected.emit(c.unit_id_of_slot(uid))         # 与 MapInput 放下后一致：自动选中
	await wait_process_frames(2)
	assert_eq(d.index, 1, "放下单位 → 购买信标")
	await _assert_targets_found(d)
	hud.call("enter_beacon_mode", uid)
	await wait_process_frames(2)
	assert_eq(d.index, 2, "进入信标模式 → 障碍物")
	await _assert_targets_found(d)
	assert_eq(d.target_rects(d.current()).size(), 3, "三组障碍格三处高亮")
	await _next(d)
	for i: int in 3:
		assert_eq(d.index, 3 + i)
		await _assert_targets_found(d)
		var cell: Vector2i = ((d.current()["targets"] as Array[Dictionary])[0]["cells"] as Array)[0] as Vector2i
		assert_ne(c.add_beacon(uid, cell), "")
		await wait_process_frames(2)
	assert_eq(c.beacon_total(), 3)
	assert_eq(d.index, 6, "放满三个 → 完成")
	await _assert_targets_found(d)
	hud.call("exit_beacon_mode")
	await wait_process_frames(2)
	assert_eq(d.index, 7, "退出信标模式 → 点击人偶")
	await _assert_targets_found(d)
	EventBus.unit_selected.emit(c.unit_id_of_slot(uid))
	await wait_process_frames(2)
	assert_eq(d.index, 8, "选中 → 移动策略")
	await _assert_targets_found(d)
	await _next(d)
	await _assert_targets_found(d)
	assert_true(c.start(), str(c.last_problems))
	await wait_process_frames(2)
	assert_false(d.active())
	for i: int in 3000:
		if c.phase == SimTypes.Phase.ENDED:
			break
		c.advance_tick()
	assert_eq(c.world.result, SimTypes.BattleResult.WIN, "照引导放的三个信标能走到物资箱")


func test_c03_enemy_info_and_rings() -> void:
	var root: Node2D = _battle("level_c03")
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var hud: Control = root.get_node("UI/HUD") as Control
	await _assert_targets_found(d)
	var uid: String = c.add_unit("bulwark", Vector2i(1, 7))
	assert_ne(uid, "")
	EventBus.unit_selected.emit(c.unit_id_of_slot(uid))
	await wait_process_frames(2)
	await _assert_targets_found(d)
	hud.call("enter_beacon_mode", uid)
	await wait_process_frames(2)
	assert_eq(d.index, 2)
	await _assert_targets_found(d)
	assert_false(d.overlay._has_point(Vector2(5, 5)), "放信标步骤不拦截")
	c.add_beacon(uid, Vector2i(8, 3))
	await wait_process_frames(2)
	assert_eq(d.index, 3)
	await _assert_targets_found(d)
	hud.call("exit_beacon_mode")
	await wait_process_frames(2)
	assert_eq(d.index, 4, "完成 → 敌人信息")
	await _assert_targets_found(d)
	EventBus.unit_selected.emit(c.world.get_spawn("T1").id)
	await wait_process_frames(2)
	assert_eq(d.index, 5, "选中敌人 → 敌人的策略")
	await _assert_targets_found(d)
	await _next(d)
	EventBus.unit_selected.emit(c.unit_id_of_slot(uid))
	await wait_process_frames(2)
	assert_eq(d.index, 7, "选中己方 → 圆环")
	await _assert_targets_found(d)
	var rings: Array[Rect2] = d.target_rects(d.current())
	assert_gt(rings[0].size.x, rings[1].size.x, "视野圈大于射程圈")
	await _next(d)
	await _assert_targets_found(d)
	await _next(d)
	await _assert_targets_found(d)
	assert_true(c.start())
	await wait_process_frames(2)
	assert_false(d.active())


func test_c05_rule_parts_and_farthest() -> void:
	var root: Node2D = _battle("level_c05")
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	var c: BattleController = root.get_node("BattleController") as BattleController
	await _assert_targets_found(d)
	var uid: String = c.add_unit("striker", Vector2i(1, 8))
	EventBus.unit_selected.emit(c.unit_id_of_slot(uid))
	await wait_process_frames(2)
	assert_eq(d.index, 1, "放下 → 点击人偶")
	await _assert_targets_found(d)
	EventBus.unit_selected.emit(c.unit_id_of_slot(uid))
	await wait_process_frames(2)
	for i: int in 4:
		assert_eq(d.index, 2 + i)
		await _assert_targets_found(d)
		await _next(d)
	assert_eq(d.index, 6, "改成最远")
	await _assert_targets_found(d)
	var sel: OptionButton = d.find_ui("Group_attack/RuleSelector") as OptionButton
	assert_not_null(sel)
	for i: int in sel.item_count:
		if str(sel.get_item_metadata(i)) == "farthest":
			sel.select(i)
			sel.item_selected.emit(i)
	await wait_process_frames(2)
	assert_eq(d.index, 7, "改了指令 → 开始")
	assert_eq(c.get_rules(uid)[0].target.selector, SimTypes.Selector.FARTHEST)


func test_c04_and_c06_steps_show() -> void:
	var root: Node2D = _battle("level_c04")
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	var c: BattleController = root.get_node("BattleController") as BattleController
	await _assert_targets_found(d)
	c.add_unit("striker", (root.get("level") as LevelDefinition).deploy_cells[0])
	await wait_process_frames(2)
	assert_eq(d.index, 1)
	await _assert_targets_found(d)
	root.queue_free()
	await wait_process_frames(2)
	var root6: Node2D = _battle("level_c06")
	await wait_process_frames(3)
	var d6: TutorialDirector = _director(root6)
	assert_true(d6.overlay.visible, "综合测试说明")
	await _next(d6)
	assert_false(d6.active())


func test_skip_marks_seen_and_does_not_repeat() -> void:
	var root: Node2D = _battle(LEVEL)
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	(d.overlay.find_child("SkipButton", true, false) as Button).pressed.emit()
	assert_false(d.active())
	assert_true(SaveManager.is_tutorial_seen(LEVEL))
	root.queue_free()
	await wait_process_frames(2)
	var root2: Node2D = _battle(LEVEL)
	await wait_process_frames(3)
	assert_null(_director(root2).overlay, "看过的引导不再出现（不建遮罩）")


func test_deploy_steps_dropped_after_battle_starts_and_running_step_pauses() -> void:
	GameState.tutorial_preview = { "level_id": "level_c03", "steps": [
		{ "title": "部署", "text": "部署", "targets": [{ "kind": "deploy_zone" }], "advance": "event", "event": "deployed" },
		{ "title": "射程", "text": "射程", "targets": [{ "kind": "unit", "spawn": "T1" }], "advance": "next", "phase": "running", "after": 1.5, "block": false }] }
	var root: Node2D = _battle("level_c03")
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var lv: LevelDefinition = root.get("level") as LevelDefinition
	var uid: String = c.add_unit("striker", lv.deploy_cells[0])
	assert_true(c.start(), "预填的沿信标没放信标只提醒，不阻止开始")
	await wait_process_frames(3)
	assert_eq(str(d.current()["phase"]), "running", "开战后部署阶段的步骤作废，跳到战斗中的步骤")
	assert_false(d.overlay.visible, "未到 after 秒：不显示")
	for i: int in 60:
		c.advance_tick()
	await wait_process_frames(2)
	assert_true(d.overlay.visible, "到点出现")
	assert_eq(c.phase, SimTypes.Phase.PAUSED, "战斗中的步骤暂停战斗")
	(d.overlay.find_child("NextButton", true, false) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_eq(c.phase, SimTypes.Phase.RUNNING, "推进后恢复")
	assert_false(d.active())
	assert_ne(uid, "")


func test_preview_uses_given_steps_and_does_not_mark_seen() -> void:
	GameState.config_editor_state = { "level": "level_01" }          # 从配置器进入
	GameState.tutorial_preview = { "level_id": "level_01", "test": true, "steps": [{ "title": "预览", "text": "开始", "targets": [{ "kind": "ui", "node": "StartButton" }], "advance": "click" }] }
	var root: Node2D = _battle("level_01")
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	assert_true(d.preview)
	assert_true(d.active())
	assert_not_null(d.back_button, "从配置器进入：显示「返回配置器」")
	assert_string_contains((d.overlay.find_child("Title", true, false) as Label).text, DataRegistry.get_string("ui.tutorial_test_tag"))
	var r: Rect2 = d.overlay.holes[0]
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = r.get_center()
	d._input(e)
	await wait_process_frames(2)
	assert_false(d.active(), "点高亮处推进")
	assert_false(SaveManager.is_tutorial_seen("level_01"), "预览不写存档")


func test_pick_mode_returns_ui_or_cell() -> void:
	GameState.tutorial_pick = { "active": true, "level_id": "level_01" }
	var root: Node2D = _battle("level_01")
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	assert_true(d.pick_mode)
	var hud: Control = root.get_node("UI/HUD") as Control
	var start: Control = hud.find_child("StartButton", true, false) as Control
	assert_eq(d.pick_at(start.get_global_rect().get_center(), start), { "kind": "ui", "node": "StartButton" })
	var cell_pos: Vector2 = (root.call("cell_screen_rect", Vector2i(3, 3)) as Rect2).get_center()
	assert_eq(d.pick_at(cell_pos, null), { "kind": "cell", "cell": [3, 3] }, "地图上点地块")
