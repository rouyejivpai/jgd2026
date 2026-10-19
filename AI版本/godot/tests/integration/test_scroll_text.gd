extends GutTest
## P6 文字溢出（用户 2026-10-05）：超出框体的文字遮罩 + 滚动（ScrollText）。
## 名字类自动往返滚动、长文本滚轮 / 拖动滚动；单行左右、多行上下；不超出时不动。
## 以及局内 HUD 的堆叠内容检验：全部文字槽填入超长内容后，框体与文字区不变、内容不出框。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const LONG_TEXT: String = "超长文字检验用的一段很长很长的内容甲乙丙丁戊己庚辛壬癸子丑寅卯辰巳午未申酉戌亥"

var _saved_motion: bool = true


var _saved_data: Dictionary


func before_each() -> void:
	_saved_motion = UiKit.motion_enabled
	UiKit.motion_enabled = true
	_saved_data = SaveManager.data.duplicate(true)      # 本机存档里已看提示层数会改变提示按钮文字：测试内清零，结束恢复


func after_each() -> void:
	UiKit.motion_enabled = _saved_motion
	SaveManager.data = _saved_data


func _wrapped(text: String, box: Vector2, mode: int, wrap_lines: bool = false) -> ScrollText:
	var host := Control.new()
	add_child_autofree(host)
	var l := Label.new()
	l.text = text
	l.position = Vector2(10, 10)
	l.size = box
	if wrap_lines:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(l)
	var s: ScrollText = ScrollText.wrap(l, mode, Rect2(Vector2(10, 10), box))
	s.set_process(false)
	return s


func test_params_are_data() -> void:
	var p: Dictionary = UiKit.motion_params("scroll_text")
	for k: String in ["auto_speed_px", "auto_pause_s", "wheel_step_px", "drag_threshold_px", "edge_fade_px"]:
		assert_true(p.has(k), "scroll_text.%s 在 data/ui_motion.json" % k)


func test_short_text_does_not_scroll() -> void:
	var s: ScrollText = _wrapped("短", Vector2(200, 30), ScrollText.Mode.AUTO)
	await wait_process_frames(1)
	assert_eq(s.overflow(), 0.0)
	assert_eq(s.position, Vector2(10, 10), "包裹节点占据原 Label 的位置")
	assert_eq(s.size, Vector2(200, 30))
	assert_true(s.clip_contents, "遮罩")
	s.call("_process", 5.0)
	assert_eq(s.offset, 0.0, "不超出时不滚动")
	assert_null(s.label.material, "不超出时不渐隐")


func test_auto_scrolls_horizontally_and_back() -> void:
	var s: ScrollText = _wrapped(LONG_TEXT, Vector2(120, 30), ScrollText.Mode.AUTO)
	await wait_process_frames(1)
	var over: float = s.overflow()
	assert_gt(over, 0.0, "单行超出")
	assert_eq(s.size, Vector2(120, 30), "遮罩区不变")
	var p: Dictionary = UiKit.motion_params("scroll_text")
	s.call("_process", float(p["auto_pause_s"]) * 0.5)
	assert_eq(s.offset, 0.0, "起点先停顿")
	for i: int in 4000:
		s.call("_process", 0.05)
		if s.offset >= over:
			break
	assert_almost_eq(s.offset, over, 0.01, "匀速滚到末端")
	assert_almost_eq(s.label.position.x, -over, 0.01, "左右滚动（单行）")
	assert_not_null(s.label.material, "超出时两端渐隐")
	for i: int in 4000:
		s.call("_process", 0.05)
		if s.offset <= 0.0:
			break
	assert_eq(s.offset, 0.0, "停顿后滚回起点（往返）")


func test_auto_respects_motion_switch() -> void:
	UiKit.motion_enabled = false
	var s: ScrollText = _wrapped(LONG_TEXT, Vector2(120, 30), ScrollText.Mode.AUTO)
	await wait_process_frames(1)
	for i: int in 100:
		s.call("_process", 0.1)
	assert_eq(s.offset, 0.0, "总闸关闭（截图 --no-motion）时停在起点")


func test_manual_wheel_drag_and_click() -> void:
	var s: ScrollText = _wrapped(LONG_TEXT, Vector2(120, 30), ScrollText.Mode.MANUAL)
	await wait_process_frames(1)
	watch_signals(s)
	assert_eq(s.mouse_filter, Control.MOUSE_FILTER_STOP, "长文本接收滚轮与拖动")
	s.call("_process", 10.0)
	assert_eq(s.offset, 0.0, "手动模式不自动滚动")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	s.call("_gui_input", wheel)
	assert_eq(s.offset, float(UiKit.motion_params("scroll_text")["wheel_step_px"]), "滚轮滚动一步")
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	s.call("_gui_input", wheel)
	assert_eq(s.offset, 0.0)
	# 点击（不移动）= clicked
	s.call("_gui_input", _btn(true, Vector2(50, 10)))
	s.call("_gui_input", _btn(false, Vector2(50, 10)))
	assert_signal_emit_count(s, "clicked", 1, "按下后不移动视为点击")
	# 拖动：向左拖 = 内容向左走，不算点击
	s.call("_gui_input", _btn(true, Vector2(100, 10)))
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(40, 10)
	s.call("_gui_input", mm)
	assert_almost_eq(s.offset, minf(60.0, s.overflow()), 0.01, "拖动滚动")
	s.call("_gui_input", _btn(false, Vector2(40, 10)))
	assert_signal_emit_count(s, "clicked", 1, "拖动不算点击")


func test_multiline_scrolls_vertically() -> void:
	var s: ScrollText = _wrapped(LONG_TEXT + LONG_TEXT + LONG_TEXT, Vector2(120, 40), ScrollText.Mode.MANUAL, true)
	await wait_process_frames(1)
	assert_gt(s.overflow(), 0.0, "多行超出")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	s.call("_gui_input", wheel)
	assert_gt(s.offset, 0.0)
	assert_eq(s.label.position.x, 0.0, "多行不左右动")
	assert_lt(s.label.position.y, 0.0, "上下滚动（多行）")
	assert_eq(s.label.size.x, 120.0, "多行按遮罩宽换行")


func _btn(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var b := InputEventMouseButton.new()
	b.button_index = MOUSE_BUTTON_LEFT
	b.pressed = pressed
	b.position = pos
	return b


## 堆叠内容检验：HUD 全部文字槽换成超长内容，框体与文字区（遮罩）不变，文字不出遮罩
func test_hud_text_slots_contain_overlong_content() -> void:
	SaveManager.set_level_config("level_08", {})
	SaveManager.set_hints_seen("level_08", 0)
	GameState.current_level_id = "level_08"
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	await wait_process_frames(3)
	var vp: Vector2 = root.get_viewport_rect().size
	var hud: Node = root.find_child("HUD", true, false)
	var nodes: Dictionary = hud.get("_skin_nodes") as Dictionary
	for n: String in ["TitleLabel", "ObjectiveLabel", "PhaseLabel", "BudgetTitle", "BudgetLabel", "BudgetFixedLabel"]:      # 计时每帧刷新，只查框体
		(root.find_child(n, true, false) as Label).text = LONG_TEXT
	# 提示按钮（用户 2026-10-06）：只显示「提示」或「推荐阵型」，不滚动；「推荐阵型」完整放得进放宽后的文字区
	var hint: Button = root.find_child("HintButton", true, false) as Button
	assert_eq(hint.text, DataRegistry.get_string("ui.hint"), "提示按钮不显示已看层数")
	var hint_area: Rect2 = UiKit.layout_text_rect("battle_hud", "btn_hint", vp)
	var font: Font = hint.get_theme_font("font")
	var w: float = font.get_string_size(DataRegistry.get_string("ui.recommend_formation"), HORIZONTAL_ALIGNMENT_LEFT, -1, hint.get_theme_font_size("font_size")).x
	assert_lte(w, hint_area.size.x, "「推荐阵型」不出框、不需要滚动")
	assert_false(hint.has_meta(UiKit.TEXT_PROXY_META), "提示按钮不设滚动")
	for n: String in ["RetryButton", "PauseButton", "ObjectivesButton", "MechanicsButton", "ClearButton", "StartButton", "SettingsButton", "ExitButton"]:
		(root.find_child(n, true, false) as Button).text = LONG_TEXT
	await wait_process_frames(2)
	for id: String in nodes.keys():
		var e: Dictionary = UiKit.layout_element("battle_hud", id)
		var c: Control = nodes[id] as Control
		var expect: Rect2 = UiKit.layout_text_rect("battle_hud", id, vp) if str(e["kind"]) == "text_style" else UiKit.layout_rect("battle_hud", id, vp)
		assert_eq(c.get_global_rect(), expect, "%s 超长内容下框体 / 文字区不变" % id)
		if str(e.get("kind", "")) == "text_style":
			assert_true(c is ScrollText and (c as ScrollText).clip_contents, "%s 文字遮罩" % id)
			if id != "timer_value" and id != "timer_value2":
				assert_gt((c as ScrollText).overflow(), 0.0, "%s 超出 → 可滚动" % id)
		elif c is Button and str(e.get("overflow", "")) != "":
			var proxy: ScrollText = null
			for ch: Node in c.get_children(true):
				if ch is ScrollText:
					proxy = ch as ScrollText
			assert_not_null(proxy, "%s 按钮文字在文字区内遮罩滚动" % id)
			assert_true(proxy.clip_contents)
			assert_true(c.get_global_rect().encloses(proxy.get_global_rect()), "%s 文字区在按钮框内（页边距）" % id)
	for card: Node in root.find_children("*", "RosterCard", true, false):
		var scrolls: Array[ScrollText] = []
		for ch: Node in card.get_children(true):
			if ch is ScrollText:
				scrolls.append(ch as ScrollText)
		var expect: int = 3
		if RosterCard.gothic():                  # 哥特卡：名称、「COST n」各一行，按布局 data.hidden 隐藏的不算（卡名进悬停提示）
			expect = 0
			for gid: String in ["card_g_name", "card_g_cost"]:
				if not bool((UiKit.layout_element("battle_hud", gid).get("data", {}) as Dictionary).get("hidden", false)):
					expect += 1
		assert_eq(scrolls.size(), expect, "卡名 / COST / 费用都遮罩 + 自动滚动")
		for st: ScrollText in scrolls:
			assert_true((card as Control).get_global_rect().encloses(st.get_global_rect()), "卡面文字区在卡面内")
