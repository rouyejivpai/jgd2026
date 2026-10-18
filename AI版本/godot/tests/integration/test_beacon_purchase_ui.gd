extends GutTest
## 信标购买的界面交互（level_c02：预算 4，基础攻击形态 3，1 Cost 一包 5 个）：
## 信标模式左键放置 → 第 1 个自动买包并提示扣费、预算铭牌与边栏标题即时刷新；放满一包且预算不够时弹「预算不足」气泡、不放置；
## 撤销到整包用不着时提示退回。

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle/battle_root.tscn")
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
var _toasts: Array[String] = []
var _bubbles: Array[String] = []


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	_toasts.clear()
	_bubbles.clear()
	EventBus.toast.connect(_on_toast)
	EventBus.toast_at.connect(_on_bubble)


func after_each() -> void:
	EventBus.toast.disconnect(_on_toast)
	EventBus.toast_at.disconnect(_on_bubble)
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	GameState.unlocks = _saved_unlocks


func _on_toast(text: String) -> void:
	_toasts.append(text)


func _on_bubble(text: String, _anchor: Vector2) -> void:
	_bubbles.append(text)


func _battle(level_id: String) -> Node2D:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	return root


func _cell_screen(root: Node2D, cell: Vector2i) -> Vector2:
	var lv: LevelDefinition = root.get("level") as LevelDefinition
	return (root.get_node("MapLayer") as Node2D).get_global_transform_with_canvas() * SimTypes.sim_to_screen(SimTypes.cell_center(cell), lv.height)


func _click(root: Node2D, cell: Vector2i, button: MouseButton) -> void:
	var mi: Control = root.find_child("MapInput", true, false) as Control
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = pressed
		e.global_position = _cell_screen(root, cell)
		e.position = mi.get_global_transform().affine_inverse() * e.global_position
		mi.call("_gui_input", e)


func _title(hud: Control) -> String:
	var node: Control = (hud.get("_beacon_nodes") as Dictionary)["beacon_bar_title"] as Control
	return (hud.call("_label_of", node) as Label).text


func test_beacon_mode_buys_and_refunds_packs() -> void:
	var root: Node2D = _battle("level_c02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var hud: Control = root.get_node("UI/HUD") as Control
	var uid: String = c.add_unit("striker", Vector2i(1, 5))
	assert_ne(uid, "")
	hud.call("enter_beacon_mode", uid)
	await wait_process_frames(1)
	var budget: Label = hud.find_child("BudgetLabel", true, false) as Label
	assert_eq(budget.text, "3 / 4")
	assert_string_contains(_title(hud), "信标 0/0", "边栏标题显示全场信标池")

	_click(root, Vector2i(7, 3), MOUSE_BUTTON_LEFT)
	assert_eq(c.beacon_total(), 1)
	assert_eq(budget.text, "4 / 4", "放第 1 个信标：自动买一包，预算即时刷新")
	assert_string_contains(_title(hud), "信标 1/5")
	assert_eq(_toasts.size(), 1, "提示已购买")
	assert_string_contains(_toasts[0], "−1 Cost")
	assert_string_contains(budget.tooltip_text, "信标 1 包")

	for x: int in [8, 9, 10, 11]:
		_click(root, Vector2i(x, 3), MOUSE_BUTTON_LEFT)
	assert_eq(c.beacon_total(), 5)
	assert_eq(_toasts.size(), 1, "同一包内不再提示")
	_click(root, Vector2i(12, 3), MOUSE_BUTTON_LEFT)
	assert_eq(c.beacon_total(), 5, "预算不够买第二包：不放置")
	assert_eq(_bubbles.size(), 1, "弹出预算不足气泡")
	assert_string_contains(_bubbles[0], "预算不足")

	for i: int in 4:
		_click(root, Vector2i(1, 1), MOUSE_BUTTON_RIGHT)       # 信标模式右键 = 撤销最后一个
	assert_eq(c.beacon_total(), 1)
	assert_eq(budget.text, "4 / 4", "还剩 1 个：包不退")
	_click(root, Vector2i(1, 1), MOUSE_BUTTON_RIGHT)
	assert_eq(c.beacon_total(), 0)
	assert_eq(budget.text, "3 / 4", "删光：退包")
	assert_string_contains(_toasts.back(), "退回 1 Cost")
