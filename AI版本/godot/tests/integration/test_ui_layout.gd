extends GutTest
## 10 §1.3 美术管线（P5）：manifest → data/ui_layout + 主题；UiKit.layout_rect 是唯一的设计 → 屏幕换算（设计画布居中，铺满画布的元素 cover）；
## 主界面与设置浮窗按布局建出（位置 = 设计坐标）、文字取 strings key、错误态元素只在数据错误时出现；滑条填充 / 把手随数值。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/screens/main_menu.tscn")


func _manifest(screen: String, file: String = "manifest.json") -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/%s/%s" % [screen, file])) as Dictionary


func test_layout_generated_from_manifest() -> void:
	for screen: String in ["main_menu", "settings_overlay"]:
		var layout: Dictionary = UiKit.ui_layout(screen)
		assert_false(layout.is_empty(), "%s 布局存在（apply_ui_manifest.py 生成）" % screen)
		var man: Dictionary = _manifest(screen)
		var ids: Array = []
		for e: Variant in man["elements"] as Array:
			ids.append(str((e as Dictionary)["id"]))
			var le: Dictionary = UiKit.layout_element(screen, str((e as Dictionary)["id"]))
			assert_eq_deep(le["rect"], (e as Dictionary)["rect"])
		assert_eq(UiKit.layout_elements(screen).filter(func(le: Dictionary) -> bool: return not bool(le.get("error_only", false))).size(), ids.size(),
			"%s 元素与 manifest 一一对应、同序" % screen)
		var theme: Theme = UiKit.ui_theme(screen)
		assert_not_null(theme)
		for le: Dictionary in UiKit.layout_elements(screen):
			if le.has("theme_type"):
				assert_true(theme.get_type_variation_list(theme.get_type_variation_base(StringName(str(le["theme_type"])))).has(StringName(str(le["theme_type"]))),
					"主题含变体 %s" % le["theme_type"])
	assert_true(bool(UiKit.layout_element("main_menu", "error_bar").get("error_only", false)), "错误条来自 error_manifest，标为 error_only")


func test_layout_rect_centers_design_canvas() -> void:
	var r: Rect2 = UiKit.layout_rect("main_menu", "btn_start", Vector2(1920, 1080))
	assert_eq(r, Rect2(148, 560, 500, 116), "1920×1080 = 设计坐标")
	assert_eq(UiKit.layout_rect("main_menu", "btn_start", Vector2(2560, 1080)), Rect2(468, 560, 500, 116), "21:9 水平居中")
	assert_eq(UiKit.layout_rect("main_menu", "btn_start", Vector2(1920, 1200)), Rect2(148, 620, 500, 116), "16:10 垂直居中")
	assert_eq(UiKit.layout_rect("main_menu", "bg", Vector2(2560, 1200)), Rect2(0, 0, 2560, 1200), "铺满设计画布的背景 cover 整个视口")
	assert_eq(UiKit.layout_text_rect("main_menu", "btn_start", Vector2(1920, 1080)), Rect2(148 + 64, 560 + 22, 372, 72), "按钮文字区 = text_rect")


func test_main_menu_built_from_layout() -> void:
	var saved_motion: bool = UiKit.motion_enabled
	UiKit.motion_enabled = false          # 静止态（P8 动效另见 test_ui_motion.gd）
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	add_child_autofree(menu)
	await wait_process_frames(2)
	UiKit.motion_enabled = saved_motion
	var vp: Vector2 = menu.size
	var start: Button = menu.find_child("StartButton", true, false) as Button
	assert_eq(start.get_rect(), UiKit.layout_rect("main_menu", "btn_start", vp), "按钮位置 = 布局")
	assert_eq(start.text, DataRegistry.get_string("ui.menu_start"), "文字取 strings key（切片不含文字）")
	assert_eq(String(start.theme_type_variation), "main_menu__btn_start")
	assert_eq((menu.find_child("Subtitle", true, false) as Label).text, DataRegistry.get_string("ui.game_subtitle"))
	assert_not_null(menu.find_child("Title", true, false), "游戏名艺术字切片")
	assert_eq(menu.find_child("ErrorBar", true, false) != null, DataRegistry.has_errors, "错误条只在数据错误时出现")
	assert_true(start.has_focus(), "首项默认焦点")
	assert_eq(start.get_theme_stylebox("normal"), start.get_theme_stylebox("hover"), "焦点复用 hover 贴图")


func test_settings_slider_fill_and_grabber_follow_value() -> void:
	var overlay: SettingsOverlay = SceneRouter.settings_overlay()
	var saved: float = GameState.setting_float("music", 1.0)
	SceneRouter.open_settings()
	var s: HSlider = overlay.find_child("Volume_music", true, false) as HSlider
	s.value = 0.8
	var vp: Vector2 = overlay.size
	var fill: Control = overlay.nodes["slider_music_fill"] as Control
	var grab: Control = overlay.nodes["slider_music_grabber"] as Control
	assert_eq(fill.size.x, UiKit.layout_rect("settings_overlay", "slider_music_fill", vp).size.x, "80% 时填充宽 = 设计样例（304）")
	assert_eq(grab.position.x, UiKit.layout_rect("settings_overlay", "slider_music_grabber", vp).position.x, "把手位置 = 设计样例")
	assert_eq((overlay.nodes["pct_music"] as Label).text, "80%")
	s.value = 0.0
	assert_false(fill.visible, "0% 时无填充")
	overlay.visible = false        # 不经 close()，不写存档
	GameState.settings["music"] = saved
