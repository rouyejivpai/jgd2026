extends GutTest
## A02「反复点击提示出现异常」复现与回归：连点、点到第 4 层、关闭再打开、运行中点击、结算后点击；
## 根因之一：提示按钮点击后持有键盘焦点，空格（开始快捷键 = ui_accept）会再次按下它而多揭示一层。
## 机制说明任何阶段可打开。

const HINT_PANEL_SCENE: PackedScene = preload("res://scenes/ui/hint_panel.tscn")
const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
const LEVEL_ID: String = "level_01"
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
}

var _saved_data: Dictionary
var _saved_unlocks: Dictionary
var _saved_level_id: String


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_unlocks = GameState.unlocks
	_saved_level_id = GameState.current_level_id
	GameState.unlocks = ALL_UNLOCKED
	SaveManager.set_hints_seen(LEVEL_ID, 0)
	SaveManager.set_recommend_used(LEVEL_ID, false)
	SaveManager.set_level_config(LEVEL_ID, {})


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.unlocks = _saved_unlocks
	GameState.current_level_id = _saved_level_id


func _make_panel() -> Array:
	var level: LevelDefinition = DataRegistry.get_level(LEVEL_ID)
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(level)
	var panel: HintPanel = HINT_PANEL_SCENE.instantiate() as HintPanel
	add_child_autofree(panel)
	panel.setup(level, c)
	return [panel, c]


func _items(panel: HintPanel) -> int:
	return (panel.get("_list") as Node).get_child_count()


func test_rapid_double_click_reveals_one_tier() -> void:
	var panel: HintPanel = _make_panel()[0] as HintPanel
	panel.press()
	panel.press()
	panel.press()
	assert_eq(panel.seen(), 1, "同一时间窗内连点只揭示一层")
	assert_eq(_items(panel), 1)
	panel.set("_last_reveal_ms", -100000)
	panel.press()
	assert_eq(panel.seen(), 2, "间隔足够后再揭示下一层")
	assert_eq(_items(panel), 2)


func test_click_through_tier_4_never_exceeds() -> void:
	var panel: HintPanel = _make_panel()[0] as HintPanel
	for i: int in 10:
		panel.set("_last_reveal_ms", -100000)
		panel.press()
	assert_eq(panel.seen(), 4)
	assert_eq(_items(panel), 4, "列表条数与层数一致，没有残留旧条目")
	assert_true(panel.visible)


func test_close_and_reopen_keeps_state() -> void:
	var panel: HintPanel = _make_panel()[0] as HintPanel
	panel.press()
	panel.close_panel()
	assert_false(panel.visible)
	panel.show_tier(panel.seen())
	assert_true(panel.visible)
	assert_eq(panel.seen(), 1, "重新打开不改变已看层数")
	assert_eq(_items(panel), 1)


func test_press_while_running_and_after_end() -> void:
	var pair: Array = _make_panel()
	var panel: HintPanel = pair[0] as HintPanel
	var c: BattleController = pair[1] as BattleController
	SaveManager.set_hints_seen(LEVEL_ID, 4)
	assert_true(c.apply_recommended())
	assert_true(c.start())
	panel.press()
	assert_true(panel.visible, "运行中可以查看提示")
	assert_eq(_items(panel), 4)
	assert_true((panel.get("_apply_button") as Button).disabled, "运行中不能摆放推荐阵型")
	while c.phase == SimTypes.Phase.RUNNING:
		c.advance_tick()
	assert_eq(c.phase, SimTypes.Phase.ENDED)
	panel.close_panel()
	panel.press()
	assert_true(panel.visible, "结算后可以查看提示")
	assert_true((panel.get("_apply_button") as Button).disabled)
	assert_false(panel.confirm_recommended())


## 场景级：经真实输入管线发空格，焦点在提示按钮上时也只开始战斗、不多揭示一层
func _make_battle() -> Node2D:
	GameState.current_level_id = LEVEL_ID
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	var c: BattleController = root.get_node("BattleController") as BattleController
	c.persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	return root


func _space() -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = KEY_SPACE
		e.keycode = KEY_SPACE
		e.unicode = 32
		e.pressed = pressed
		Input.parse_input_event(e)
		await wait_process_frames(2)


func test_space_with_focused_hint_button_starts_battle_only() -> void:
	var root: Node2D = _make_battle()
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	var hint_button: Button = root.find_child("HintButton", true, false) as Button
	assert_eq(hint_button.focus_mode, Control.FOCUS_NONE, "底栏按钮不取键盘焦点")
	hint_button.pressed.emit()
	assert_eq(SaveManager.get_hints_seen(LEVEL_ID), 1)
	hint_button.focus_mode = Control.FOCUS_ALL      # 最坏情况：按钮仍持有焦点
	hint_button.grab_focus()
	await wait_process_frames(1)
	await _space()
	assert_eq(c.phase, SimTypes.Phase.RUNNING, "空格开始战斗")
	assert_eq(SaveManager.get_hints_seen(LEVEL_ID), 1, "空格没有再按下提示按钮")
	await _space()
	assert_eq(SaveManager.get_hints_seen(LEVEL_ID), 1)


func test_mechanics_popup_opens_in_every_phase() -> void:
	var root: Node2D = _make_battle()
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var mech_button: Button = root.find_child("MechanicsButton", true, false) as Button
	var popup: Control = root.find_child("MechanicsPopup", true, false) as Control
	var hint_panel: HintPanel = root.find_child("HintPanel", true, false) as HintPanel
	var hint_button: Button = root.find_child("HintButton", true, false) as Button

	hint_button.pressed.emit()
	assert_true(hint_panel.visible)
	mech_button.pressed.emit()
	assert_true(popup.visible, "部署阶段可打开")
	assert_false(hint_panel.visible, "两个浮层互斥，不再叠压")
	mech_button.pressed.emit()
	assert_false(popup.visible)

	assert_true(c.apply_recommended())
	assert_true(c.start())
	mech_button.pressed.emit()
	assert_true(popup.visible, "运行中可打开")
	mech_button.pressed.emit()
	c.pause()
	mech_button.pressed.emit()
	assert_true(popup.visible, "暂停中可打开")
	mech_button.pressed.emit()
	c.resume()
	while c.phase == SimTypes.Phase.RUNNING:
		c.advance_tick()
	await wait_process_frames(2)
	mech_button.pressed.emit()
	assert_true(popup.visible, "结算后可打开")
	assert_true(popup.is_visible_in_tree())
