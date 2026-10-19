extends GutTest
## 主菜单「继续游戏 / 新游戏」：无进度时「继续游戏」禁用、默认焦点在「新游戏」；有进度时「新游戏」先弹确认框，
## 取消不动存档，确认后清空全部存档（保留设置）、GameState 指向新存档、章节与当前区域回到默认（随后进入一级地图）。
## 测试期间改用临时存档路径并拦住场景切换（SceneRouter._busy），结束后恢复真实存档内容。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const LevelSelectScript := preload("res://scripts/screens/level_select.gd")
const TEST_PATH: String = "user://test_tmp/save_new_game.json"

var _saved_data: Dictionary
var _saved_invalid: Dictionary
var _saved_chapter: int
var _saved_region: String
var _saved_busy: bool


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_invalid = SaveManager.invalid_configs.duplicate(true)
	_saved_chapter = LevelSelectScript.chapter_index
	_saved_region = GameState.current_region_id
	_saved_busy = bool(SceneRouter.get("_busy"))
	SceneRouter.set("_busy", true)          # 不真的切到一级地图
	_cleanup()


func after_each() -> void:
	SaveManager.data = _saved_data
	SaveManager.invalid_configs = _saved_invalid
	GameState.sync_from_save()
	LevelSelectScript.chapter_index = _saved_chapter
	GameState.current_region_id = _saved_region
	SceneRouter.set("_busy", _saved_busy)
	_cleanup()


func _cleanup() -> void:
	for p: String in [TEST_PATH, TEST_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _menu() -> Control:
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	menu.set("save_path", TEST_PATH)
	add_child_autofree(menu)
	return menu


func _btn(menu: Control, id: String) -> Button:
	return (menu.get("nodes") as Dictionary)[id] as Button


func _fresh() -> Dictionary:
	return SaveManager.new_save(DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels())


func _with_progress() -> void:
	var d: Dictionary = _fresh()
	SaveManager.apply_rewards(d, "level_01", DataRegistry.get_level("level_01").rewards)
	(d["stories_seen"] as Dictionary)["story_intro"] = true
	d["settings"] = (_saved_data.get("settings", {}) as Dictionary).duplicate(true)
	(d["settings"] as Dictionary)["music"] = 0.35
	SaveManager.data = d
	GameState.sync_from_save()


func test_no_progress_disables_continue() -> void:
	SaveManager.data = _fresh()
	GameState.sync_from_save()
	var menu: Control = _menu()
	await wait_process_frames(2)
	assert_true(_btn(menu, "btn_continue").disabled, "无进度时「继续游戏」禁用")
	assert_eq(_btn(menu, "btn_start").disabled, DataRegistry.has_errors)
	assert_null(menu.get_viewport().gui_get_focus_owner(), "进入时不取默认焦点")
	_btn(menu, "btn_start").pressed.emit()
	var dlg: ConfirmDialog = menu.find_child("NewGameConfirm", true, false) as ConfirmDialog
	assert_false(dlg.visible, "没有进度时直接开始，不弹确认框")
	assert_true(FileAccess.file_exists(TEST_PATH), "新存档已写盘")


func test_new_game_confirm_cancel_then_ok() -> void:
	_with_progress()
	var menu: Control = _menu()
	await wait_process_frames(2)
	var cont: Button = _btn(menu, "btn_continue")
	assert_eq(cont.disabled, DataRegistry.has_errors, "有进度时「继续游戏」可用")
	assert_false(cont.has_focus(), "有进度时「继续游戏」也不默认选中")
	var dlg: ConfirmDialog = menu.find_child("NewGameConfirm", true, false) as ConfirmDialog
	assert_not_null(dlg)
	assert_false(dlg.visible)
	var saved_motion: bool = UiKit.motion_enabled
	UiKit.motion_enabled = false              # 只查摆放：不要滑入动效的中间位置
	_btn(menu, "btn_start").pressed.emit()
	UiKit.motion_enabled = saved_motion
	assert_true(dlg.visible, "有进度时「新游戏」先弹确认框")
	await wait_process_frames(1)
	assert_eq(dlg.size, menu.size, "确认框铺满界面（遮罩挡住下层）")
	assert_eq((dlg.nodes["btn_ok"] as Button).get_rect(), UiKit.layout_rect("confirm_dialog", "btn_ok", dlg.size), "按钮位置 = 布局")
	assert_eq((dlg.nodes["body"] as Label).get_rect(), UiKit.layout_text_rect("confirm_dialog", "body", dlg.size), "自动换行的正文不被撑高")
	assert_true((dlg.nodes["btn_cancel"] as Button).has_focus(), "确认框默认焦点在「取消」")
	assert_eq((dlg.nodes["title"] as Label).text, DataRegistry.get_string("ui.new_game_confirm_title"))
	(dlg.nodes["btn_cancel"] as Button).pressed.emit()
	assert_false(dlg.visible)
	assert_true(SaveManager.has_progress(), "取消不动存档")
	assert_false(FileAccess.file_exists(TEST_PATH))

	LevelSelectScript.chapter_index = 1
	GameState.current_region_id = "region_withered_farm"
	GameState.fail_counts["level_01"] = 2
	_btn(menu, "btn_start").pressed.emit()
	(dlg.nodes["btn_ok"] as Button).pressed.emit()
	assert_false(dlg.visible)
	assert_false(SaveManager.has_progress(), "确认后清空全部进度")
	assert_eq_deep(SaveManager.data["unlocks"], _fresh()["unlocks"])
	assert_almost_eq(float((SaveManager.data["settings"] as Dictionary)["music"]), 0.35, 0.0001, "设置保留")
	assert_true(GameState.progress == SaveManager.data["progress"] and is_same(GameState.progress, SaveManager.data["progress"]), "GameState 指向新存档")
	assert_false(GameState.is_level_completed("level_01"))
	assert_true(GameState.fail_counts.is_empty(), "本次运行的失败计数清零")
	assert_eq(LevelSelectScript.chapter_index, -1, "章节地图回到默认章节")
	assert_eq(GameState.current_region_id, "", "当前区域清空（一级地图回到默认区域）")
	var on_disk: Dictionary = SaveManager.load_from(TEST_PATH)
	assert_true(((on_disk["progress"] as Dictionary)["completed"] as Array).is_empty(), "写盘的是空进度存档")


func test_esc_cancels_confirm() -> void:
	_with_progress()
	var menu: Control = _menu()
	await wait_process_frames(2)
	var dlg: ConfirmDialog = menu.find_child("NewGameConfirm", true, false) as ConfirmDialog
	_btn(menu, "btn_start").pressed.emit()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	dlg.call("_input", esc)
	assert_false(dlg.visible, "Esc 关闭确认框")
	assert_true(SaveManager.has_progress(), "Esc 等同取消")
