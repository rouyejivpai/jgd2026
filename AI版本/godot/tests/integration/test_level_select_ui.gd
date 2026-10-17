extends GutTest
## 10 §3.2 章节地图交互：左侧地图视口横向拖动（左键拖 / 滚轮，范围 clamp，6 px 点击阈值）；点击节点只选中、不进关；
## 「进入」按钮触发进关、锁定时禁用并说明前置关卡；「回放剧情」只列 stories_seen 已含的 _intro / _win / _lose，播放不改 seen；
## 默认选中最新可挑战节点并滚到视口中央；地图宽于视口时能滚到第 25 节点。

const SELECT_SCENE: PackedScene = preload("res://scenes/screens/level_select.tscn")
const SELECT_SCRIPT: GDScript = preload("res://scripts/screens/level_select.gd")
## 本文件测第一章（25 节点宽图、不分区域）的地图交互；2026-10-18 起主线为分区域的七区战役，这里显式指定第一章

var _saved_data: Dictionary
var _saved_progress: Dictionary
var _entered: Array[String] = []


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_progress = GameState.progress
	SaveManager.data["stories_seen"] = {}      # 不依赖本机存档里已看过的剧情（after_each 恢复）
	_entered.clear()
	SELECT_SCRIPT.set("chapter_index", DataRegistry.get_chapters().find(DataRegistry.get_chapter("chapter_01")))


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.sync_from_save()
	GameState.progress = _saved_progress
	SELECT_SCRIPT.set("chapter_index", -1)


func _open(completed: Array) -> Control:
	GameState.progress = { "completed": completed, "unlocked_levels": [] }
	var sel: Control = SELECT_SCENE.instantiate() as Control
	add_child_autofree(sel)
	sel.set("navigate", false)
	sel.connect("enter_requested", func(lid: String) -> void: _entered.append(lid))
	await wait_process_frames(2)
	return sel


func _press(sel: Control, at: Vector2, pressed: bool) -> void:
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = pressed
	mb.position = at
	(sel.find_child("MapViewport", true, false) as Control).gui_input.emit(mb)


func _move(sel: Control, at: Vector2) -> void:
	var mm := InputEventMouseMotion.new()
	mm.position = at
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	(sel.find_child("MapViewport", true, false) as Control).gui_input.emit(mm)


func _scroll(sel: Control) -> float:
	return float(sel.get("scroll_x"))


func test_layout_viewport_and_detail_panel() -> void:
	var sel: Control = await _open([])
	var viewport: Control = sel.find_child("MapViewport", true, false) as Control
	var detail: Control = sel.find_child("DetailPanel", true, false) as Control
	var vp: Vector2 = sel.get_viewport_rect().size
	assert_almost_eq(viewport.size.x, vp.x, 1.0, "P6：地图铺满窗口（批准整图 ui_22），详情面板浮在右侧")
	assert_true(viewport.clip_contents)
	assert_almost_eq(float(sel.call("visible_width")), UiKit.layout_rect("chapter", "panel_top", vp).position.x, 1.0, "可见宽 = 详情面板左缘")
	assert_true(detail.find_child("Skin_panel_top", true, false) != null, "详情上框")
	assert_gt(float(sel.call("max_scroll")), 0.0, "宽图宽于可见区")


func test_drag_and_wheel_clamped() -> void:
	var sel: Control = await _open([])
	sel.call("set_scroll", 0.0)
	_press(sel, Vector2(600.0, 500.0), true)
	_move(sel, Vector2(596.0, 500.0))
	assert_false(bool(sel.call("is_dragging")), "≤ 6 px 视为点击，不拖动")
	assert_eq(_scroll(sel), 0.0)
	_move(sel, Vector2(400.0, 500.0))
	assert_true(bool(sel.call("is_dragging")))
	assert_almost_eq(_scroll(sel), 200.0, 0.01, "左键按住向左拖 200 px → 地图右移 200")
	_move(sel, Vector2(2000.0, 500.0))
	assert_eq(_scroll(sel), 0.0, "不越过左端（clamp 到 0）")
	_move(sel, Vector2(-20000.0, 500.0))
	assert_almost_eq(_scroll(sel), float(sel.call("max_scroll")), 0.01, "不越过右端（clamp 到 地图宽 − 视口宽）")
	_press(sel, Vector2(-20000.0, 500.0), false)
	assert_false(bool(sel.call("is_dragging")), "松开结束拖动，无惯性")
	var before: float = _scroll(sel)
	_move(sel, Vector2(0.0, 500.0))
	assert_eq(_scroll(sel), before, "松开后移动不再拖")
	sel.call("set_scroll", 0.0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	(sel.find_child("MapViewport", true, false) as Control).gui_input.emit(wheel)
	assert_almost_eq(_scroll(sel), UiKit.CHAPTER_WHEEL_STEP, 0.01, "滚轮横移")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	(sel.find_child("MapViewport", true, false) as Control).gui_input.emit(wheel)
	(sel.find_child("MapViewport", true, false) as Control).gui_input.emit(wheel)
	assert_eq(_scroll(sel), 0.0, "滚轮同样 clamp")


func test_can_scroll_to_node_25() -> void:
	var sel: Control = await _open([])
	var viewport: Control = sel.find_child("MapViewport", true, false) as Control
	var vr := Rect2(0.0, 0.0, float(sel.call("visible_width")), viewport.size.y)
	sel.call("set_scroll", 0.0)
	assert_false(vr.encloses(sel.call("node_rect_in_viewport", "node_25") as Rect2), "起始时第 25 节点在视口外")
	sel.call("set_scroll", float(sel.call("max_scroll")))
	assert_true(vr.encloses(sel.call("node_rect_in_viewport", "node_25") as Rect2), "滚到最右能看到第 25 节点")


func test_default_selects_latest_playable_and_centers() -> void:
	var sel: Control = await _open(["level_01", "level_02", "level_03", "level_04", "level_05", "level_06"])
	assert_eq(str(sel.get("selected_id")), "level_07", "默认选中最新可挑战节点")
	var viewport: Control = sel.find_child("MapViewport", true, false) as Control
	var r: Rect2 = sel.call("node_rect_in_viewport", "level_07") as Rect2
	var expected: float = float(sel.call("visible_width")) * 0.5
	if _scroll(sel) > 0.0 and _scroll(sel) < float(sel.call("max_scroll")):
		assert_almost_eq(r.get_center().x, expected, 1.0, "滚到视口中央")
	else:
		assert_true(Rect2(0.0, 0.0, float(sel.call("visible_width")), viewport.size.y).encloses(r), "受范围限制时至少在可见区内")
	var sel2: Control = await _open([])
	assert_eq(str(sel2.get("selected_id")), "level_01", "新存档默认第一关")


func test_click_node_selects_without_entering() -> void:
	var sel: Control = await _open(["level_01"])
	var buttons: Dictionary = sel.get("node_buttons") as Dictionary
	(buttons["level_01"] as Button).pressed.emit()
	assert_eq(str(sel.get("selected_id")), "level_01", "点击节点 = 选中")
	assert_eq(_entered.size(), 0, "点击节点不进关")
	var title: Label = sel.find_child("DetailTitle", true, false) as Label
	assert_string_contains(title.text, DataRegistry.get_level("level_01").title, "详情面板显示关卡名")
	var summary: Label = sel.find_child("DetailSummary", true, false) as Label
	assert_eq(summary.text, DataRegistry.get_level("level_01").subtitle, "summary 为空回退 subtitle")
	var objective: Label = sel.find_child("DetailObjective", true, false) as Label
	assert_string_contains(objective.text, DataRegistry.get_level("level_01").objective_text, "任务一句话")
	var plate: Label = (buttons["level_01"] as Button).get_node("Nameplate") as Label
	assert_eq(plate.get_theme_color("font_color"), Palette.ALCHEMY_GOLD, "选中名牌高亮")
	var enter: Button = sel.find_child("EnterButton", true, false) as Button
	assert_false(enter.disabled, "已完成的关卡可再进")
	enter.pressed.emit()
	assert_eq(_entered, ["level_01"] as Array[String], "「进入」触发进关")


func test_locked_node_disables_enter_and_names_prerequisite() -> void:
	var sel: Control = await _open(["level_01"])
	var buttons: Dictionary = sel.get("node_buttons") as Dictionary
	(buttons["level_03"] as Button).pressed.emit()
	var enter: Button = sel.find_child("EnterButton", true, false) as Button
	var locked_by: Label = sel.find_child("DetailLockedBy", true, false) as Label
	assert_true(enter.disabled, "锁定时禁用")
	assert_true(locked_by.visible)
	assert_string_contains(locked_by.text, DataRegistry.get_level("level_02").title, "说明前置关卡")
	enter.pressed.emit()
	assert_eq(_entered.size(), 0)
	(buttons["node_14"] as Button).pressed.emit()
	assert_eq(str(sel.get("selected_id")), "node_14", "占位节点可选中查看")
	assert_true(enter.disabled, "占位节点不可进入")
	assert_string_contains((sel.find_child("DetailTitle", true, false) as Label).text, "未开放")


func test_replay_lists_only_seen_stories_and_does_not_mark() -> void:
	SaveManager.mark_story_seen("level_01_intro")
	SaveManager.mark_story_seen("level_01_lose")
	var sel: Control = await _open(["level_01"])
	var buttons: Dictionary = sel.get("node_buttons") as Dictionary
	(buttons["level_01"] as Button).pressed.emit()
	var replay: Button = sel.find_child("ReplayButton", true, false) as Button
	var pick: OptionButton = sel.find_child("ReplayPick", true, false) as OptionButton
	assert_eq(sel.call("replay_ids"), ["level_01_intro", "level_01_lose"] as Array[String], "只列已看过的条目，顺序 开场 / 胜利 / 失败")
	assert_false(replay.disabled)
	assert_eq(pick.get_item_text(1), DataRegistry.get_string("ui.replay_lose"), "「开场剧情」下拉列出已看条目（批准整图 ui_22）")
	var seen_before: Dictionary = (SaveManager.data.get("stories_seen", {}) as Dictionary).duplicate()
	pick.select(0)
	replay.pressed.emit()
	var player: StoryPlayer = sel.find_children("*", "StoryPlayer", true, false)[0] as StoryPlayer
	assert_true(player.visible, "用 StoryPlayer 播放")
	assert_eq(player.current_story, "level_01_intro")
	assert_eq_deep(SaveManager.data.get("stories_seen", {}), seen_before)
	(buttons["level_02"] as Button).pressed.emit()
	assert_true(replay.disabled, "一条都没看过则禁用")


## P6 章节节点切片：徽章按状态换图（已完成 / 可挑战 / 锁定 / 选中 / 首领），锁 / 勾角标只在对应状态显示；占位节点选中时换紧凑版式
func test_node_badges_follow_state() -> void:
	var sel: Control = await _open(["level_01"])
	var buttons: Dictionary = sel.get("node_buttons") as Dictionary
	var tex := func(nid: String) -> String:
		var t: Texture2D = ((buttons[nid] as Button).get_node("Disc") as TextureRect).texture
		return t.resource_path if t != null else ""
	var file := func(id: String) -> String: return str(UiKit.layout_element("chapter", id).get("file", ""))
	(buttons["level_03"] as Button).pressed.emit()
	assert_eq(tex.call("level_01"), file.call("node_tex_done"), "已完成徽章")
	assert_eq(tex.call("level_02"), file.call("node_tex_open"), "可挑战徽章")
	assert_eq(tex.call("level_03"), file.call("node_tex_selected"), "选中徽章")
	assert_eq(tex.call("level_04"), file.call("node_tex_locked"), "锁定徽章")
	assert_eq(tex.call("level_08"), file.call("node_tex_boss"), "首领恒用青底徽章")
	assert_true(((buttons["level_01"] as Button).get_node("Check") as Control).visible, "已完成显示勾")
	assert_false(((buttons["level_01"] as Button).get_node("Lock") as Control).visible)
	assert_true(((buttons["level_04"] as Button).get_node("Lock") as Control).visible, "锁定显示锁")
	assert_not_null((buttons["level_01"] as Button).icon, "区域图标（node_art）")
	(buttons["node_09"] as Button).pressed.emit()
	assert_true((sel.find_child("Skin_ph_enter", true, false) as Control).visible, "占位节点：紧凑版式的「进入」")
	assert_false((sel.find_child("EnterButton", true, false) as Control).visible, "占位节点：隐藏普通「进入」")
	assert_false((sel.find_child("Skin_moon_orn", true, false) as Control).visible, "占位节点：隐藏框体纹饰")
