extends GutTest
## 10 §3.2 章节地图交互：左侧地图视口横向拖动（左键拖 / 滚轮，范围 clamp，6 px 点击阈值）；点击节点只选中、不进关；
## 「进入」按钮触发进关、锁定时禁用并说明前置关卡；「开头剧情」「结尾剧情」按钮只在 stories_seen 含 _intro / _win 时显示，播放不改 seen；
## 默认选中最新可挑战节点并滚到视口中央；地图宽于视口时能滚到第 25 节点。
## 2026-10-20：拖出框（橡皮筋，最多视口宽 1/8）松手弹回；点空白处收起详情面板、点节点展开；未解锁名牌空白压锁、新解锁播解锁动画。
## 2026-10-20：进入时详情面板收起、默认节点不高亮；点节点展开并把节点滚到可见区横向正中（可出框），收起时弹回范围。

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
	SaveManager.autosave = false               # 揭开记录不写盘
	_entered.clear()
	SELECT_SCRIPT.set("chapter_index", DataRegistry.get_chapters().find(DataRegistry.get_chapter("chapter_01")))


func after_each() -> void:
	SaveManager.data = _saved_data
	SaveManager.autosave = true
	GameState.sync_from_save()
	GameState.progress = _saved_progress
	SELECT_SCRIPT.set("chapter_index", -1)


## revealed = null：所有关卡都已揭开（不播解锁动画）；否则为揭开记录
func _open(completed: Array, revealed: Variant = null) -> Control:
	GameState.progress = { "completed": completed, "unlocked_levels": [] }
	SaveManager.data["levels_revealed"] = DataRegistry.get_level_list() if revealed == null else revealed
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


## 点节点展开详情面板并等动画结束
func _open_panel(sel: Control, nid: String) -> void:
	((sel.get("node_buttons") as Dictionary)[nid] as Button).pressed.emit()
	await wait_seconds(0.6)


func test_layout_viewport_and_detail_panel() -> void:
	var sel: Control = await _open([])
	var viewport: Control = sel.find_child("MapViewport", true, false) as Control
	var detail: Control = sel.find_child("DetailPanel", true, false) as Control
	var vp: Vector2 = sel.get_viewport_rect().size
	assert_almost_eq(viewport.size.x, vp.x, 1.0, "P6：地图铺满窗口（批准整图 ui_22），详情面板浮在右侧")
	assert_true(viewport.clip_contents)
	assert_false(bool(sel.get("panel_open")), "进入时不显示详情面板")
	assert_almost_eq(float(sel.call("visible_width")), vp.x, 1.0, "面板收起：地图可见宽铺满窗口")
	assert_gt(detail.position.x, vp.x - UiKit.layout_rect("chapter", "panel_top", vp).position.x, "面板在窗口外")
	await _open_panel(sel, "level_01")
	var view_end: float = UiKit.layout_rect("chapter", "map_view", vp).end.x if not UiKit.layout_element("chapter", "map_view").is_empty() else UiKit.layout_rect("chapter", "panel_top", vp).position.x
	assert_almost_eq(float(sel.call("visible_width")), view_end, 1.0, "可见宽 = 详情面板不透明处的左缘（哥特换皮：布局 map_view）")
	assert_true(detail.find_child("Skin_panel_top", true, false) != null, "详情上框")
	assert_gt(float(sel.call("max_scroll")), 0.0, "宽图宽于可见区")


func test_drag_rubber_band_and_spring_back() -> void:
	var sel: Control = await _open([])
	var lim: float = sel.get_viewport_rect().size.x / 8.0
	await _open_panel(sel, "level_01")
	sel.call("set_scroll", 0.0)
	_press(sel, Vector2(600.0, 500.0), true)
	_move(sel, Vector2(596.0, 500.0))
	assert_false(bool(sel.call("is_dragging")), "≤ 6 px 视为点击，不拖动")
	assert_eq(_scroll(sel), 0.0)
	_move(sel, Vector2(400.0, 500.0))
	assert_true(bool(sel.call("is_dragging")))
	assert_almost_eq(_scroll(sel), 200.0, 0.01, "范围内一比一：左键按住向左拖 200 px → 地图右移 200")
	_move(sel, Vector2(700.0, 500.0))
	var over: float = -_scroll(sel)
	assert_gt(over, 0.0, "可以拖出左端")
	assert_lt(over, 100.0, "出框部分越拉越紧（拉出 100 px，实际不到 100）")
	_move(sel, Vector2(20000.0, 500.0))
	assert_true(-_scroll(sel) <= lim + 0.01, "最多拖出视口宽的 1/8")
	assert_gt(-_scroll(sel), lim * 0.9, "拉得越远越接近上限，不硬卡")
	_press(sel, Vector2(20000.0, 500.0), false)
	assert_false(bool(sel.call("is_dragging")), "松开结束拖动")
	await wait_seconds(0.7)
	assert_almost_eq(_scroll(sel), 0.0, 0.5, "松手后弹回左端")
	assert_true(bool(sel.get("panel_open")), "拖动不算点击，面板不收起")
	_press(sel, Vector2(600.0, 500.0), true)
	_move(sel, Vector2(-20000.0, 500.0))
	var mx: float = float(sel.call("max_scroll"))
	assert_between(_scroll(sel), mx, mx + lim, "右端同样最多拖出 1/8")
	_press(sel, Vector2(-20000.0, 500.0), false)
	await wait_seconds(0.7)
	assert_almost_eq(_scroll(sel), mx, 0.5, "松手后弹回右端")
	sel.call("set_scroll", 0.0)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	(sel.find_child("MapViewport", true, false) as Control).gui_input.emit(wheel)
	assert_almost_eq(_scroll(sel), UiKit.CHAPTER_WHEEL_STEP, 0.01, "滚轮横移")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	(sel.find_child("MapViewport", true, false) as Control).gui_input.emit(wheel)
	(sel.find_child("MapViewport", true, false) as Control).gui_input.emit(wheel)
	assert_eq(_scroll(sel), 0.0, "滚轮不出框")


func test_click_empty_collapses_panel_and_node_reopens() -> void:
	var sel: Control = await _open(["level_01"])
	var vp: Vector2 = sel.get_viewport_rect().size
	await _open_panel(sel, "level_01")
	var open_w: float = float(sel.call("visible_width"))
	_press(sel, Vector2(300.0, 60.0), true)
	_press(sel, Vector2(300.0, 60.0), false)
	assert_false(bool(sel.get("panel_open")), "点地图空白处收起详情面板")
	await wait_seconds(0.6)
	assert_almost_eq(float(sel.call("visible_width")), vp.x, 1.0, "收起后地图可见宽铺满窗口")
	var detail: Control = sel.find_child("DetailPanel", true, false) as Control
	assert_gt(detail.position.x, vp.x - UiKit.layout_rect("chapter", "panel_top", vp).position.x, "面板滑出窗口")
	((sel.get("node_buttons") as Dictionary)["level_02"] as Button).pressed.emit()
	assert_true(bool(sel.get("panel_open")), "点节点展开")
	assert_eq(str(sel.get("selected_id")), "level_02")
	await wait_seconds(0.6)
	assert_almost_eq(float(sel.call("visible_width")), open_w, 1.0)
	assert_almost_eq(detail.position.x, 0.0, 0.5, "面板回到原位")
	var r: Rect2 = sel.call("node_rect_in_viewport", "level_02") as Rect2
	assert_almost_eq(r.get_center().x, open_w * 0.5, 1.0, "选中节点滚到可见区横向正中")


## 选中首尾节点也强制居中（出框）；收起面板时立刻弹回可滚范围
func test_select_centers_even_out_of_bounds_and_collapse_springs_back() -> void:
	var sel: Control = await _open(["level_01"])
	await _open_panel(sel, "level_01")
	var open_w: float = float(sel.call("visible_width"))
	assert_almost_eq((sel.call("node_rect_in_viewport", "level_01") as Rect2).get_center().x, open_w * 0.5, 1.0, "第一关也居中")
	assert_lt(_scroll(sel), float(sel.call("min_scroll")), "为居中出了左框")
	((sel.get("node_buttons") as Dictionary)["node_25"] as Button).pressed.emit()
	await wait_seconds(0.6)
	assert_almost_eq((sel.call("node_rect_in_viewport", "node_25") as Rect2).get_center().x, open_w * 0.5, 1.0, "面板已展开时点别的节点同样居中")
	assert_gt(_scroll(sel), float(sel.call("max_scroll")), "为居中出了右框")
	_press(sel, Vector2(300.0, 60.0), true)
	_press(sel, Vector2(300.0, 60.0), false)
	await wait_seconds(0.6)
	assert_false(bool(sel.get("panel_open")))
	assert_between(_scroll(sel), float(sel.call("min_scroll")) - 0.5, float(sel.call("max_scroll")) + 0.5, "收起后弹回范围内")


## 新解锁的关卡：进场先按锁住显示（空名牌 + 锁），揭开记录随即写入；动画结束后名牌写上名字
func test_newly_unlocked_level_reveals() -> void:
	var sel: Control = await _open(["level_01"], ["level_01"])
	var b2: Button = (sel.get("node_buttons") as Dictionary)["level_02"] as Button
	assert_true((SaveManager.revealed("levels_revealed") as Array).has("level_02"), "揭开记录在动画开始时写入")
	if UiKit.motion_enabled:
		assert_eq(sel.get("revealing") as Array, ["level_02"] as Array[String])
		assert_eq((b2.get_node("Nameplate") as Label).text, "", "动画前仍是空名牌")
		assert_true((b2.get_node("PlateBg/Lock") as Control).visible)
		sel.call("skip_reveals")
	assert_eq((b2.get_node("Nameplate") as Label).text, "02 · " + DataRegistry.get_level("level_02").title)
	assert_false((b2.get_node("PlateBg/Lock") as Control).visible)
	var sel2: Control = await _open(["level_01", "level_02"], null)
	SaveManager.data.erase("levels_revealed")
	assert_eq(sel2.call("pending_reveals") as Array, ["level_03"] as Array[String], "旧存档没有揭开记录：可挑战未通关的补播一次")


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
	assert_false(bool(sel.get("panel_open")), "进入时不显示详情面板")
	var b07: Button = (sel.get("node_buttons") as Dictionary)["level_07"] as Button
	assert_false((b07.get_node("Nameplate") as Label).has_theme_color_override("font_color"), "进入时默认关卡不画选中样式（名牌不提亮）")
	assert_almost_eq(b07.scale.x, 1.0, 0.001, "进入时默认关卡不放大")
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
	assert_eq(((buttons["level_03"] as Button).get_node("Nameplate") as Label).text, "", "未解锁看不见名字")
	assert_eq((sel.find_child("DetailTitle", true, false) as Label).text, DataRegistry.get_string("ui.node_unknown"), "详情标题也不显示名字")
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
	SaveManager.mark_story_seen("level_02_intro")
	SaveManager.mark_story_seen("level_02_win")
	var sel: Control = await _open(["level_01", "level_02"])
	var buttons: Dictionary = sel.get("node_buttons") as Dictionary
	var replay: Button = sel.find_child("ReplayButton", true, false) as Button
	var picker: StorySelect = sel.get("story_select") as StorySelect
	(buttons["level_01"] as Button).pressed.emit()
	assert_eq(sel.call("replay_ids"), ["level_01_intro"] as Array[String], "只看过开头（失败剧情不回放）")
	assert_true(replay.visible, "看过任一段就显示「剧情回放」")
	replay.pressed.emit()
	assert_true(picker.visible, "点「剧情回放」打开剧情选择")
	assert_eq(picker.cards().size(), 2, "开头 / 结尾两卡")
	assert_false(picker.cards()[0].disabled, "看过的开头可选")
	assert_true(picker.cards()[1].disabled, "没看过的结尾锁定")
	picker.close()
	(buttons["level_02"] as Button).pressed.emit()
	assert_eq(sel.call("replay_ids"), ["level_02_intro", "level_02_win"] as Array[String])
	var seen_before: Dictionary = (SaveManager.data.get("stories_seen", {}) as Dictionary).duplicate()
	replay.pressed.emit()
	picker.cards()[1].pressed.emit()
	var player: StoryPlayer = sel.find_children("*", "StoryPlayer", true, false)[0] as StoryPlayer
	assert_true(player.visible, "用 StoryPlayer 播放")
	assert_false(picker.visible, "播放时剧情选择暂隐")
	assert_eq(player.current_story, "level_02_win")
	assert_eq(player.size, sel.size, "剧情层铺满界面（尺寸为 0 时收不到点击，会卡在第一句）")
	assert_eq_deep(SaveManager.data.get("stories_seen", {}), seen_before)
	player.close()
	assert_true(picker.visible, "播完回到剧情选择")
	picker.back_page()
	assert_false(picker.visible, "返回关闭剧情选择")
	(buttons["level_03"] as Button).pressed.emit()
	assert_false(replay.visible, "一条都没看过则不显示")


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
	assert_false(((buttons["level_01"] as Button).get_node("PlateBg/Lock") as Control).visible)
	assert_true(((buttons["level_04"] as Button).get_node("PlateBg/Lock") as Control).visible, "锁定：锁压在名牌上")
	assert_not_null((buttons["level_01"] as Button).icon, "区域图标（node_art）")
	(buttons["node_09"] as Button).pressed.emit()
	assert_true((sel.find_child("Skin_ph_enter", true, false) as Control).visible, "占位节点：紧凑版式的「进入」")
	assert_false((sel.find_child("EnterButton", true, false) as Control).visible, "占位节点：隐藏普通「进入」")
	assert_false((sel.find_child("Skin_moon_orn", true, false) as Control).visible, "占位节点：隐藏框体纹饰")


## 2026-10-21 用户：地图横向不够长，底部横向滚动条（滑轨 + 旋钮）删掉；拖动 / 滚轮横移照旧
func test_no_horizontal_scroll_bar() -> void:
	var sel: Control = await _open([])
	assert_null(sel.find_child("Skin_scroll_line", true, false), "无滑轨")
	assert_null(sel.find_child("Skin_scroll_thumb", true, false), "无旋钮")
	await _open_panel(sel, "level_01")
	assert_null(sel.find_child("Skin_scroll_thumb", true, false), "展开面板后也没有")
