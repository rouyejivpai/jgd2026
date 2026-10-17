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
	assert_true(t.has_tutorial(LEVEL))
	assert_true(t.is_test(LEVEL), "开发期测试内容")
	var steps: Array[Dictionary] = t.tutorial_steps(LEVEL)
	assert_eq(str(steps[0]["advance"]), "event")
	assert_true(bool(steps[0]["block"]), "有高亮且不是「下一步」：默认只放行高亮处")
	assert_false(bool(steps[2]["block"]), "「下一步」步骤默认不拦截")
	var c05: LevelDefinition = DataRegistry.get_level("level_c05")
	assert_true(c05.allowed_selectors.has(SimTypes.Selector.MOST_DAMAGE), "teaching.json 覆盖 allowed.selectors（测试内容）")
	assert_string_contains(str(DataRegistry.get_level("level_c03").briefing["mechanic_hint"]), "【测试】", "覆盖 mechanic_hint")


func test_invalid_steps_reported() -> void:
	var was: bool = DataReader.silent
	DataReader.silent = true
	var before: int = DataReader.error_count
	TeachingDef.normalize_step({ "text": "x", "advance": "event", "event": "nope", "targets": [{ "kind": "ufo" }] }, "t")
	TeachingDef.from_dict({ "levels": { "level_07": { "hints": ["a", "b", "c", "d"] } } }, "t")
	DataReader.silent = was
	assert_eq(DataReader.error_count - before, 3, "未知事件 / 未知目标类型 / 第七关覆盖都报错")


func test_overlay_blocks_outside_holes_only() -> void:
	var ov := TutorialOverlay.new()
	add_child_autofree(ov)
	ov.show_step("t", "x", 1, 1, false, true, "auto", "auto")
	ov.set_targets([Rect2(100, 100, 50, 50)] as Array[Rect2])
	assert_false(ov._has_point(Vector2(120, 120)), "高亮处放行")
	assert_true(ov._has_point(Vector2(400, 400)), "高亮外吞掉")
	ov.show_step("t", "x", 1, 1, true, false, "auto", "auto")
	assert_false(ov._has_point(Vector2(400, 400)), "block = false：整层放行")


func test_steps_advance_by_events_and_next() -> void:
	var root: Node2D = _battle(LEVEL)
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	assert_true(d.active(), "首次进入本关：引导开始")
	assert_true(d.overlay.visible)
	assert_eq(d.index, 0)
	var rects: Array[Rect2] = d.target_rects(d.current())
	assert_eq(rects.size(), 2, "出场卡 + 部署区两处高亮")
	var c: BattleController = root.get_node("BattleController") as BattleController
	var lv: LevelDefinition = root.get("level") as LevelDefinition
	assert_false(d.overlay._has_point(rects[1].get_center()), "部署区可点（可拖放）")
	var uid: String = c.add_unit("striker", lv.deploy_cells[0])
	assert_ne(uid, "")
	await wait_process_frames(2)
	assert_eq(d.index, 1, "放下单位 → 下一步")
	EventBus.unit_selected.emit(c.unit_id_of_slot(uid))
	await wait_process_frames(2)
	assert_eq(d.index, 2, "选中己方 → 下一步")
	assert_true((d.overlay.find_child("NextButton", true, false) as Button).visible, "「下一步」步骤显示按钮")
	(d.overlay.find_child("NextButton", true, false) as Button).pressed.emit()
	await wait_process_frames(2)
	assert_eq(d.index, 3)
	root.get_node("UI/HUD").call("enter_beacon_mode", uid)
	await wait_process_frames(2)
	assert_eq(d.index, 4, "进入信标模式 → 下一步")
	c.add_beacon(uid, Vector2i(5, 3))
	await wait_process_frames(2)
	assert_eq(d.index, 5, "放置信标 → 下一步")
	root.get_node("UI/HUD").call("exit_beacon_mode")
	assert_true(c.start())
	await wait_process_frames(2)
	assert_false(d.active(), "开始战斗 → 引导完成")
	assert_true(SaveManager.is_tutorial_seen(LEVEL), "完成后记入存档")


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
	GameState.tutorial_preview = { "level_id": "level_01", "test": true, "steps": [{ "title": "预览", "text": "开始", "targets": [{ "kind": "ui", "node": "StartButton" }], "advance": "click" }] }
	var root: Node2D = _battle("level_01")
	await wait_process_frames(3)
	var d: TutorialDirector = _director(root)
	assert_true(d.preview)
	assert_true(d.active())
	assert_true((d.overlay.find_child("BackButton", true, false) as Button).visible, "预览显示「返回配置器」")
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
