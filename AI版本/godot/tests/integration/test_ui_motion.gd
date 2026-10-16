extends GutTest
## 10 §1.5 UI 动效（P8）：按钮动效 ButtonMotion。总闸关闭时不挂动效、静止态 = 布局值；状态切换 ≤ 0.25 s 收敛；
## disabled 不播放；连续快速切换无残留；静止的普通态与原样式逐项一致（文字内边距不变）；参数全部来自 data/ui_motion.json。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const MAX_TRANSITION: float = 0.25      ## 10 §1.5 约束 2
const MENU_PROFILE: String = "button_menu"

var _saved_enabled: bool = true


func before_each() -> void:
	_saved_enabled = UiKit.motion_enabled
	UiKit.motion_enabled = true


func after_each() -> void:
	UiKit.motion_enabled = _saved_enabled


func _menu() -> Control:
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	add_child_autofree(menu)
	return menu


func _button(menu: Control, id: String) -> Button:
	return (menu.get("nodes") as Dictionary)[id] as Button


func _motion(b: Button) -> ButtonMotion:
	var m: ButtonMotion = b.get_node_or_null(ButtonMotion.NODE_NAME) as ButtonMotion
	if m != null:
		m.set_process(false)        # 测试里手动驱动状态，不让每帧求值覆盖
	return m


## 推进当前状态过渡 dt 秒
func _step(m: ButtonMotion, dt: float) -> void:
	if m.tween != null and m.tween.is_valid():
		m.tween.custom_step(dt)


func test_params_are_data_and_transitions_within_limit() -> void:
	for profile: String in ["button", MENU_PROFILE]:
		var p: Dictionary = UiKit.motion_params(profile)
		assert_false(p.is_empty(), "%s 档在 data/ui_motion.json" % profile)
		for key: String in ["hover_in", "hover_out", "press", "release"]:
			var d: float = float((p[key] as Dictionary)["duration"])
			assert_true(d > 0.0 and d <= MAX_TRANSITION, "%s.%s 时长 %.2f ≤ 0.25 s" % [profile, key, d])
			assert_true(UiKit.MOTION_TRANS.has(str((p[key] as Dictionary)["trans"])), "%s.%s 曲线名合法" % [profile, key])
			assert_true(UiKit.MOTION_EASE.has(str((p[key] as Dictionary)["ease"])), "%s.%s 缓动名合法" % [profile, key])
	var menu: Dictionary = UiKit.motion_params(MENU_PROFILE)
	assert_false(menu.has("extends"), "合并后不留 extends")
	assert_eq_deep(menu["gold_mask"], UiKit.motion_params("button")["gold_mask"])
	assert_true(float(menu["hover_nudge_px"]) > 0.0 and bool(menu["focus_follows_mouse"]), "菜单档：选中让位 + 焦点跟随鼠标（Q-072）")


func test_disabled_switch_attaches_nothing() -> void:
	UiKit.motion_enabled = false
	var menu: Control = _menu()
	await wait_process_frames(2)
	for id: String in ["btn_start", "btn_settings", "btn_quit"]:
		var b: Button = _button(menu, id)
		assert_null(b.get_node_or_null(ButtonMotion.NODE_NAME), "%s 总闸关闭时不挂动效节点（不会创建 Tween）" % id)
		assert_false(b.has_meta(ButtonMotion.META))
		assert_eq(b.get_rect(), UiKit.layout_rect("main_menu", id, menu.size), "%s 静止态位置 / 尺寸 = 布局" % id)
		assert_eq(b.scale, Vector2.ONE)
	var start: Button = _button(menu, "btn_start")
	assert_eq(start.get_theme_stylebox("normal"), start.get_theme_stylebox("hover"), "无动效时仍按 P5 约定：焦点复用 hover 贴图")
	assert_null(UiKit.attach_button_motion(start), "总闸关闭时 attach 返回 null")


func test_rest_state_matches_original_styles() -> void:
	var menu: Control = _menu()
	await wait_process_frames(2)
	var b: Button = _button(menu, "btn_quit")
	var m: ButtonMotion = _motion(b)
	assert_not_null(m, "主界面按钮挂了动效")
	assert_eq(m.visual, ButtonMotion.Visual.NORMAL, "未悬停、无焦点 = 普通态")
	assert_null(m.tween, "静止时没有进行中的 Tween")
	assert_eq(b.scale, Vector2.ONE)
	assert_eq(b.get_rect(), UiKit.layout_rect("main_menu", "btn_quit", menu.size), "动效不改布局")
	assert_false(b.has_theme_color_override("font_color"), "静止态不覆盖文字颜色")
	var theme_sb: StyleBox = (menu.theme as Theme).get_stylebox("normal", b.theme_type_variation)
	assert_eq((m.get_node("Base") as Panel).get_theme_stylebox("panel"), theme_sb, "底层画的就是原 normal 样式")
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(b.get_theme_stylebox("normal").get_margin(side), theme_sb.get_margin(side), "空样式保留内边距（文字位置不变）")
	assert_false((m.get_node("Hover") as Panel).visible)
	assert_false((m.get_node("Pressed") as Panel).visible)
	assert_true(m.show_behind_parent, "动效层画在按钮文字之下")


func test_focus_shows_hover_and_follows_mouse() -> void:
	var menu: Control = _menu()
	await wait_process_frames(3)
	var start: Button = _button(menu, "btn_start")
	var settings: Button = _button(menu, "btn_settings")
	var ms: ButtonMotion = start.get_node(ButtonMotion.NODE_NAME) as ButtonMotion
	assert_eq(ms.visual, ButtonMotion.Visual.HOVER, "默认焦点的「开始」呈 hover 态（首帧直接落位）")
	assert_eq(ms.hover_w, 1.0)
	settings.mouse_entered.emit()
	assert_true(settings.has_focus(), "悬停即取焦点")
	assert_eq(ms.target_visual(), ButtonMotion.Visual.NORMAL, "「开始」失焦后回普通态，同一时刻只有一个按钮亮")
	var mset: ButtonMotion = settings.get_node(ButtonMotion.NODE_NAME) as ButtonMotion
	settings.mouse_exited.emit()
	assert_false(settings.has_focus(), "鼠标离开即交还焦点")
	assert_eq(mset.target_visual(), ButtonMotion.Visual.NORMAL, "离开后回到普通态，不会一直亮着")
	assert_null(menu.get_viewport().gui_get_focus_owner(), "此时没有按钮有焦点")
	var down := InputEventAction.new()
	down.action = "ui_down"
	down.pressed = true
	menu.call("_unhandled_input", down)
	assert_true(start.has_focus(), "无焦点时按方向键回到第一个可用按钮（键盘仍可用）")


func test_transitions_converge_within_limit() -> void:
	var menu: Control = _menu()
	await wait_process_frames(2)
	var b: Button = _button(menu, "btn_settings")
	var m: ButtonMotion = _motion(b)
	var p: Dictionary = UiKit.motion_params(MENU_PROFILE)
	m.go(ButtonMotion.Visual.HOVER)
	assert_not_null(m.sweep_tween, "从普通态进入 hover 时光带扫过")
	_step(m, MAX_TRANSITION)
	assert_almost_eq(m.hover_w, 1.0, 0.001, "hover ≤ 0.25 s 收敛")
	assert_false((m.get_node("Base") as Panel).visible, "hover 满权重时底层隐藏（= hover 切片本身）")
	var base_col: Color = (menu.theme as Theme).get_color("font_color", b.theme_type_variation)
	assert_eq(b.get_theme_color("font_color"), base_col.lightened(float(p["text_hover_lighten"])), "hover 文字微亮（幅度来自数据）")
	m.go(ButtonMotion.Visual.PRESSED)
	assert_null(m.sweep_tween, "离开 hover 即停光带")
	_step(m, MAX_TRANSITION)
	assert_almost_eq(m.press_w, 1.0, 0.001, "pressed ≤ 0.25 s 收敛")
	assert_almost_eq(b.scale.x, float(p["press_scale"]), 0.0001, "按下微缩（幅度来自数据）")
	m.go(ButtonMotion.Visual.HOVER)
	_step(m, MAX_TRANSITION)
	assert_almost_eq(m.press_w, 0.0, 0.001, "松开回弹 ≤ 0.25 s 收敛")
	assert_almost_eq(b.scale.x, 1.0, 0.0001)
	m.go(ButtonMotion.Visual.NORMAL)
	_step(m, MAX_TRANSITION)
	assert_almost_eq(m.hover_w, 0.0, 0.001, "移出 ≤ 0.25 s 收敛")
	assert_eq(b.scale, Vector2.ONE)
	assert_false(b.has_theme_color_override("font_color"), "回到普通态去掉文字颜色覆盖")


func test_disabled_plays_nothing() -> void:
	var menu: Control = _menu()
	await wait_process_frames(2)
	var b: Button = _button(menu, "btn_quit")
	var m: ButtonMotion = _motion(b)
	m.go(ButtonMotion.Visual.HOVER)
	b.disabled = true
	m.go(m.target_visual())
	assert_eq(m.visual, ButtonMotion.Visual.DISABLED)
	assert_null(m.tween, "disabled 立即切换，不创建 Tween")
	assert_null(m.sweep_tween, "disabled 不播放光带")
	assert_eq(m.hover_w, 0.0)
	assert_eq(b.scale, Vector2.ONE)
	var theme_sb: StyleBox = (menu.theme as Theme).get_stylebox("disabled", b.theme_type_variation)
	assert_eq((m.get_node("Base") as Panel).get_theme_stylebox("panel"), theme_sb, "底层换成 disabled 样式")
	assert_false(b.has_theme_color_override("font_color"), "disabled 文字颜色用主题的 font_disabled_color")
	b.disabled = false
	m.go(m.target_visual())
	assert_null(m.tween, "从 disabled 恢复也立即落位")
	assert_eq((m.get_node("Base") as Panel).get_theme_stylebox("panel"), (menu.theme as Theme).get_stylebox("normal", b.theme_type_variation))


func test_rapid_switching_leaves_no_residue() -> void:
	var menu: Control = _menu()
	await wait_process_frames(2)
	var b: Button = _button(menu, "btn_settings")
	var m: ButtonMotion = _motion(b)
	var seq: Array[int] = [ButtonMotion.Visual.HOVER, ButtonMotion.Visual.PRESSED, ButtonMotion.Visual.NORMAL,
		ButtonMotion.Visual.HOVER, ButtonMotion.Visual.PRESSED, ButtonMotion.Visual.HOVER, ButtonMotion.Visual.NORMAL]
	for v: int in seq:
		m.go(v)
		_step(m, 0.02)
	_step(m, MAX_TRANSITION)
	assert_almost_eq(m.hover_w, 0.0, 0.001)
	assert_almost_eq(m.press_w, 0.0, 0.001)
	assert_eq(b.scale, Vector2.ONE, "无残留缩放")
	assert_null(m.sweep_tween, "无残留光带")
	assert_false((m.get_node("Hover") as Panel).visible)
	assert_false((m.get_node("Pressed") as Panel).visible)
	assert_true((m.get_node("Base") as Panel).visible)
	assert_false(b.has_theme_color_override("font_color"), "无残留文字颜色")


func test_motion_off_at_runtime_snaps_without_tween() -> void:
	var menu: Control = _menu()
	await wait_process_frames(2)
	var m: ButtonMotion = _motion(_button(menu, "btn_quit"))
	UiKit.motion_enabled = false
	m.go(ButtonMotion.Visual.HOVER)
	assert_null(m.tween, "运行中关闭总闸：状态立即落位，不创建 Tween")
	assert_null(m.sweep_tween)
	assert_eq(m.hover_w, 1.0)


func test_menu_hover_nudges_background_and_text() -> void:
	var menu: Control = _menu()
	await wait_process_frames(2)
	var b: Button = _button(menu, "btn_quit")
	var m: ButtonMotion = _motion(b)
	var nudge: float = float(UiKit.motion_params(MENU_PROFILE)["hover_nudge_px"])
	var theme_sb: StyleBox = (menu.theme as Theme).get_stylebox("normal", b.theme_type_variation)
	m.go(ButtonMotion.Visual.HOVER)
	_step(m, MAX_TRANSITION)
	assert_eq(m.position.x, nudge, "背景层右移 hover_nudge_px")
	assert_eq(b.get_theme_stylebox("normal").get_margin(SIDE_LEFT), theme_sb.get_margin(SIDE_LEFT) + nudge, "文字同步右移")
	assert_eq(b.get_theme_stylebox("normal").get_margin(SIDE_RIGHT), theme_sb.get_margin(SIDE_RIGHT) - nudge, "左右内边距和不变（最小尺寸不变）")
	m.go(ButtonMotion.Visual.NORMAL)
	_step(m, MAX_TRANSITION)
	assert_eq(m.position.x, 0.0, "回到普通态不让位")
	assert_eq(b.get_theme_stylebox("normal").get_margin(SIDE_LEFT), theme_sb.get_margin(SIDE_LEFT))


## 第 4 条通用化：任何进入场景树的普通按钮自动挂通用档；flat / 复选框 / no_motion 不挂；总闸关闭不挂
func test_every_button_gets_motion_automatically() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var plain := UiKit.button("x")
	var flat := Button.new()
	flat.flat = true
	var check := CheckBox.new()
	var opted := Button.new()
	opted.set_meta(&"no_motion", true)
	for c: Control in [plain, flat, check, opted]:
		root.add_child(c)
	await wait_process_frames(2)
	assert_not_null(plain.get_node_or_null(ButtonMotion.NODE_NAME), "程序化按钮自动挂动效")
	assert_eq((plain.get_node(ButtonMotion.NODE_NAME) as ButtonMotion).params, UiKit.motion_params("button"), "通用档")
	for c: Button in [flat, check, opted]:
		assert_null(c.get_node_or_null(ButtonMotion.NODE_NAME), "%s 不挂" % c.get_class())
	UiKit.motion_enabled = false
	var late := Button.new()
	root.add_child(late)
	await wait_process_frames(2)
	assert_null(late.get_node_or_null(ButtonMotion.NODE_NAME), "总闸关闭时新按钮不挂")
	var gone := Button.new()
	UiKit.motion_enabled = true
	root.add_child(gone)
	gone.free()                    # 本帧就释放：帧末的延迟挂载不报错
	await wait_process_frames(2)
	assert_true(true)


## 外部代码改按钮样式（章节地图节点按选中重设）：下一帧重新接管；外部文字颜色在动效结束后恢复
func test_external_restyle_is_recaptured() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var b := UiKit.button("node")
	root.add_child(b)
	await wait_process_frames(2)
	var m: ButtonMotion = b.get_node(ButtonMotion.NODE_NAME) as ButtonMotion
	var restyled: StyleBoxFlat = UiKit.panel_style(Color.BLACK, Color.GOLD, 6)
	b.add_theme_stylebox_override("normal", restyled)
	b.add_theme_color_override("font_color", Color.GOLD)
	m._process(0.0)
	assert_eq((m.get_node("Base") as Panel).get_theme_stylebox("panel"), restyled, "底层改画外部的新样式")
	assert_true(b.get_theme_stylebox("normal") is StyleBoxEmpty, "按钮自身又换回空样式，不会重复绘制")
	m.set_process(false)
	m.go(ButtonMotion.Visual.HOVER)
	_step(m, MAX_TRANSITION)
	assert_ne(b.get_theme_color("font_color"), Color.GOLD, "hover 时文字提亮")
	m.go(ButtonMotion.Visual.NORMAL)
	_step(m, MAX_TRANSITION)
	assert_eq(b.get_theme_color("font_color"), Color.GOLD, "回到普通态恢复外部设的文字颜色")


func test_toggle_buttons_do_not_stay_shrunk() -> void:
	var root := Control.new()
	add_child_autofree(root)
	var b := UiKit.button("2x")
	b.toggle_mode = true
	root.add_child(b)
	await wait_process_frames(2)
	var m: ButtonMotion = _motion(b)
	b.button_pressed = true
	m.go(m.target_visual())
	_step(m, MAX_TRANSITION)
	assert_eq(m.visual, ButtonMotion.Visual.PRESSED, "切换按钮按下常态 = pressed 样式")
	assert_eq(b.scale, Vector2.ONE, "但不缩放")
	assert_false(b.has_theme_color_override("font_color"), "也不压暗文字（与无动效时相同）")
