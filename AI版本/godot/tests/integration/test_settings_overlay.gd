extends GutTest
## 10 §2 设置浮窗：主界面 / 章节地图 / 局内三处打开（SceneRouter 常驻，层 100 < 黑幕 128）；Esc 与「关闭」关闭；
## 点击遮罩不关闭；局内运行中打开自动暂停、关闭后保持暂停（决策 ⑦）；修改即时生效、关闭时写存档；独立设置界面已删除。

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/screens/main_menu.tscn")
const LEVEL_SELECT_SCENE: PackedScene = preload("res://scenes/screens/level_select.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const TEST_SAVE: String = "user://test_tmp/settings_overlay_save.json"
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
	"presets": [],
}

var _saved_data: Dictionary
var _saved_level_id: String
var _saved_unlocks: Dictionary
var _overlay: SettingsOverlay


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	SaveManager.autosave = false          # 2026-10-20：选关 / 一级地图会记解锁动画的揭开记录，测试里不写盘
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	_overlay = SceneRouter.settings_overlay()
	_overlay.save_path = TEST_SAVE
	_close_silently()


func after_each() -> void:
	_close_silently()
	_overlay.save_path = SaveManager.SAVE_PATH
	SaveManager.data = _saved_data
	GameState.sync_from_save()
	GameState.current_level_id = _saved_level_id
	SaveManager.autosave = true
	GameState.unlocks = _saved_unlocks
	for p: String in [TEST_SAVE, TEST_SAVE + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _close_silently() -> void:
	if SceneRouter.is_settings_open():
		SceneRouter.close_settings()


func _esc() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	_overlay.call("_input", ev)


func test_overlay_is_resident_above_scenes_below_fade() -> void:
	assert_false(ResourceLoader.exists("res://scenes/screens/settings.tscn"), "独立设置界面已删除")
	var layer: CanvasLayer = _overlay.get_parent() as CanvasLayer
	assert_eq(layer.layer, 100, "浮窗层 100")
	assert_lt(layer.layer, (SceneRouter as CanvasLayer).layer, "低于黑幕 128")
	assert_false(SceneRouter.is_settings_open())
	SceneRouter.goto_settings()
	assert_true(SceneRouter.is_settings_open(), "goto_settings 保留签名，改为打开浮窗")
	var mask: Control = _overlay.get_node("Mask") as Control
	assert_eq(mask.mouse_filter, Control.MOUSE_FILTER_STOP, "遮罩挡住下层点击")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	mask.gui_input.emit(click)
	assert_true(SceneRouter.is_settings_open(), "点击遮罩不关闭")
	_esc()
	assert_false(SceneRouter.is_settings_open(), "Esc 关闭")
	SceneRouter.open_settings()
	(_overlay.find_child("CloseButton", true, false) as Button).pressed.emit()
	assert_false(SceneRouter.is_settings_open(), "「关闭」关闭")


func test_open_from_main_menu() -> void:
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	add_child_autofree(menu)
	await wait_process_frames(1)
	(menu.find_child("SettingsButton", true, false) as Button).pressed.emit()
	assert_true(SceneRouter.is_settings_open(), "主界面「设置」打开浮窗（不再切换场景）")
	_esc()
	assert_false(SceneRouter.is_settings_open())


func test_open_from_chapter_map() -> void:
	var select: Control = LEVEL_SELECT_SCENE.instantiate() as Control
	add_child_autofree(select)
	await wait_process_frames(2)
	var btn: Button = select.find_child("SettingsButton", true, false) as Button
	assert_not_null(btn, "章节地图顶栏有「设置」")
	btn.pressed.emit()
	assert_true(SceneRouter.is_settings_open())
	_esc()
	assert_false(SceneRouter.is_settings_open())


func test_battle_open_pauses_and_stays_paused() -> void:
	GameState.current_level_id = "level_02"
	SaveManager.set_level_config("level_02", {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	var c: BattleController = root.get_node("BattleController") as BattleController
	c.persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	await wait_process_frames(2)
	assert_true(c.apply_recommended())
	assert_true(c.start())
	assert_eq(c.phase, SimTypes.Phase.RUNNING)
	var btn: Button = root.find_child("SettingsButton", true, false) as Button
	assert_not_null(btn, "局内右上角「设置」")
	btn.pressed.emit()
	assert_true(SceneRouter.is_settings_open())
	assert_eq(c.phase, SimTypes.Phase.PAUSED, "运行中打开自动暂停")
	var t: float = c.world.clock.time
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	root.call("_input", space)
	assert_eq(c.phase, SimTypes.Phase.PAUSED, "浮窗打开时战斗快捷键无效")
	_esc()
	assert_false(SceneRouter.is_settings_open())
	assert_eq(c.phase, SimTypes.Phase.PAUSED, "关闭后保持暂停，由玩家点继续（决策 ⑦）")
	assert_eq(c.world.clock.time, t, "暂停期间模拟不推进")
	root.call("toggle_pause")
	assert_eq(c.phase, SimTypes.Phase.RUNNING, "玩家点继续后恢复")
	# 部署阶段打开不改变阶段
	c.reset()
	btn.pressed.emit()
	assert_eq(c.phase, SimTypes.Phase.DEPLOY)


func test_changes_apply_immediately_and_close_writes_save() -> void:
	var before: float = GameState.setting_float("master", 1.0)
	var target: float = 0.35 if not is_equal_approx(before, 0.35) else 0.55
	SceneRouter.open_settings()
	var slider: HSlider = _overlay.find_child("Volume_master", true, false) as HSlider
	assert_not_null(slider)
	slider.value = target
	assert_almost_eq(GameState.setting_float("master", 1.0), target, 0.001, "修改即时生效")
	var lines: BaseButton = _overlay.find_child("Toggle_target_lines", true, false) as BaseButton
	var lines_before: bool = GameState.setting_bool("target_lines")
	lines.button_pressed = not lines_before
	assert_eq(GameState.setting_bool("target_lines"), not lines_before)
	assert_false(FileAccess.file_exists(TEST_SAVE))
	SceneRouter.close_settings()
	assert_true(FileAccess.file_exists(TEST_SAVE), "关闭时写存档")
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE)) as Dictionary
	assert_almost_eq(float((written["settings"] as Dictionary)["master"]), target, 0.001)
	assert_eq(bool((written["settings"] as Dictionary)["target_lines"]), not lines_before)
	SceneRouter.open_settings()
	assert_almost_eq((_overlay.find_child("Volume_master", true, false) as HSlider).value, target, 0.001, "再次打开显示当前值")
