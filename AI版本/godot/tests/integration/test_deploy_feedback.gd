extends GutTest
## 10 §4 部署反馈：六种不可放置原因（DeploymentValidator.place_problem，UI 只显示）与放下非法时的原因 toast；
## 「移除」按钮与移除后收起侧栏（unit_selected(-1)）；10 §6.1「清空」：placements 为空、预算归零、toast 人数；拖拽虚影。

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
var _selected: Array[int] = []


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	_toasts.clear()
	_selected.clear()
	EventBus.toast.connect(_on_toast)
	EventBus.unit_selected.connect(_on_selected)


func after_each() -> void:
	EventBus.toast.disconnect(_on_toast)
	EventBus.unit_selected.disconnect(_on_selected)
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	GameState.unlocks = _saved_unlocks


func _on_toast(text: String) -> void:
	_toasts.append(text)


func _on_selected(id: int) -> void:
	_selected.append(id)


func _controller(level_id: String) -> BattleController:
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(DataRegistry.get_level(level_id))
	return c


func _battle(level_id: String) -> Node2D:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	return root


func test_six_cannot_place_reasons() -> void:
	var c: BattleController = _controller("level_02")      # 部署区 x 1–3、y 1–5；预算 10；最多 3 名；形态 bulwark 4 / striker 3
	assert_eq(c.place_problem("striker", Vector2i(2, 2)), "", "合法")
	assert_eq(c.place_problem("striker", Vector2i(6, 3)), DeploymentValidator.OUT_OF_ZONE, "部署区外")
	assert_eq(c.place_problem("striker", Vector2i(10, 1)), DeploymentValidator.CELL_OCCUPIED, "敌方初始单位所在格")
	assert_eq(c.place_problem("lancer", Vector2i(2, 2)), DeploymentValidator.FORM_NOT_AVAILABLE, "形态不在本关 available_forms")
	var u1: String = c.add_unit("bulwark", Vector2i(1, 1))
	assert_eq(c.place_problem("striker", Vector2i(1, 1)), DeploymentValidator.CELL_OCCUPIED, "已有己方单位")
	assert_eq(c.place_problem(u1, Vector2i(1, 1)), "", "单位放回自己所在格合法")
	c.add_unit("bulwark", Vector2i(1, 2))
	assert_eq(c.place_problem("bulwark", Vector2i(2, 2)), DeploymentValidator.BUDGET_EXCEEDED, "4 + 4 + 4 > 10")
	assert_eq(c.place_problem(u1, Vector2i(3, 3)), "", "移动已有单位不再扣费")
	c.clear_units()
	for y: int in [1, 2, 3]:
		c.add_unit("striker", Vector2i(1, y))
	assert_eq(c.place_problem("striker", Vector2i(2, 2)), DeploymentValidator.ROSTER_FULL, "3 名已满（9 ≤ 10 但人数到上限）")
	var c3: BattleController = _controller("level_03")
	assert_eq(c3.place_problem("striker", Vector2i(5, 2)), DeploymentValidator.CELL_BLOCKED, "障碍格")
	# 与控制器原有的放置判断一致
	for x: int in 13:
		for y: int in 7:
			var cell := Vector2i(x, y)
			assert_eq(c.place_problem("u1", cell) == "", c.can_place("u1", cell), "place_problem 与 can_place 一致 %s" % cell)
	# 六种原因都有文案
	for code: String in [DeploymentValidator.OUT_OF_ZONE, DeploymentValidator.CELL_BLOCKED, DeploymentValidator.CELL_OCCUPIED,
			DeploymentValidator.BUDGET_EXCEEDED, DeploymentValidator.ROSTER_FULL, DeploymentValidator.FORM_NOT_AVAILABLE]:
		var text: String = DataRegistry.get_string("validation.cannot_place." + code)
		assert_ne(text, "validation.cannot_place." + code, "%s 有文案" % code)


func test_illegal_drop_toasts_reason_and_keeps_unit() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var map_input: Control = root.find_child("MapInput", true, false) as Control
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	var t: float = float(int(root.get("cell_px")))
	var local := func(cell: Vector2i) -> Vector2:
		return map_input.get_global_transform().affine_inverse() * (rect.position + Vector2((cell.x + 0.5) * t, (7 - cell.y - 0.5) * t))
	var payload: Dictionary = { "form": "striker" }
	assert_true(bool(map_input.call("_can_drop_data", local.call(Vector2i(6, 3)), payload)), "非法格也接收放下（用于提示原因）")
	map_input.call("_drop_data", local.call(Vector2i(6, 3)), payload)
	assert_eq(c.placements.size(), 0, "非法格不放置")
	assert_eq(_toasts.size(), 1)
	assert_string_contains(_toasts[0], DataRegistry.get_string("validation.cannot_place.OUT_OF_ZONE"), "toast 附原因")
	map_input.call("_drop_data", local.call(Vector2i(2, 2)), payload)
	assert_eq(c.placements.size(), 1, "合法格放置")
	var uid: String = c.slot_at(Vector2i(2, 2))
	# 地图上拖起的单位放到战场内的非法格：不动 + 原因；拖出战场：移除
	map_input.call("_drop_data", local.call(Vector2i(10, 1)), { "slot_id": uid, "from_map": true })
	assert_eq(c.placements.get(uid), Vector2i(2, 2), "放到非法格时单位留在原处")
	assert_string_contains(_toasts[_toasts.size() - 1], DataRegistry.get_string("validation.cannot_place.CELL_OCCUPIED"))
	var outside: Vector2 = map_input.get_global_transform().affine_inverse() * (rect.position - Vector2(10.0, -10.0))
	map_input.call("_drop_data", outside, { "slot_id": uid, "from_map": true })
	assert_false(c.placements.has(uid), "拖出战场 = 移除")


func test_drag_preview_uses_form_sprite() -> void:
	var preview: Control = RosterCard.make_preview("striker", 80.0)
	add_child_autofree(preview)
	var body: Control = RosterCard.current_preview()
	assert_true(body is TextureRect, "虚影为形态精灵")
	assert_eq((body as TextureRect).texture, Art.unit_texture("striker"))
	assert_almost_eq(body.size.y, 80.0 * 1.6, 0.01, "高 = cell_px × 1.6")
	assert_almost_eq(body.modulate.a, 0.6, 0.001, "60% 透明")
	assert_almost_eq(body.position.y + body.size.y * 232.0 / 256.0, 0.0, 0.01, "锚点在脚底")
	RosterCard.tint_preview(-1)
	assert_gt(body.modulate.r, body.modulate.g, "非法格叠红")
	RosterCard.tint_preview(1)
	assert_gt(body.modulate.g, body.modulate.b, "合法格叠金")
	assert_not_null(RosterCard.portrait_icon("striker"), "角色卡头像（裁圆）")
	assert_almost_eq(RosterCard.portrait_icon("striker").get_image().get_pixel(0, 0).a, 0.0, 0.01, "圆外透明")


func test_remove_button_hides_side_panel() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	var id: int = c.unit_id_of_slot("u1")
	EventBus.unit_selected.emit(id)
	await wait_process_frames(2)
	var side: Control = root.find_child("SidePanel", true, false) as Control
	var unit_panel: Control = root.find_child("UnitPanel", true, false) as Control
	var remove: Button = unit_panel.get("_remove_button") as Button
	assert_true(side.visible)
	assert_true(remove.visible, "部署阶段已放置单位显示「移除」")
	assert_eq(remove.tooltip_text, DataRegistry.get_string("ui.remove_hint"), "说明改为悬停提示（侧栏头部无空位）")
	_selected.clear()
	remove.pressed.emit()
	assert_false(c.placements.has("u1"), "已移除")
	assert_eq(_selected, [-1] as Array[int], "移除后 unit_selected(-1)")
	assert_false(side.visible, "侧栏收起，不残留详情")
	# 运行中不显示移除
	EventBus.unit_selected.emit(c.unit_id_of_slot("u2"))
	assert_true(c.start())
	await wait_process_frames(1)
	assert_false(remove.visible, "运行中不可移除")


func test_clear_units_empties_and_resets_budget() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	c.add_beacon("u2", Vector2i(5, 3))
	EventBus.unit_selected.emit(c.unit_id_of_slot("u1"))
	await wait_process_frames(1)
	var clear: Button = root.find_child("ClearButton", true, false) as Button
	var budget: Label = root.find_child("BudgetLabel", true, false) as Label
	assert_eq(budget.text, "0 / 10", "倒数显示：用满剩 0")
	assert_false(clear.disabled)
	_selected.clear()
	clear.pressed.emit()
	assert_true(c.placements.is_empty(), "清空后 placements 为空")
	assert_true(c.uids().is_empty(), "free 关单位连同指令与信标一并删除")
	assert_eq(c.budget_used(), 0)
	assert_eq(budget.text, "10 / 10", "清空后储量回满")
	assert_has(_selected, -1, "清空后收起侧栏")
	assert_false((root.find_child("SidePanel", true, false) as Control).visible)
	var toast: Label = root.find_child("Toast", true, false) as Label
	assert_eq(toast.text, DataRegistry.get_string("ui.cleared_toast").format({ "n": 3 }), "toast「已清空 3 名角色」")
	assert_true(clear.disabled, "没有可清空的角色时禁用")


func test_clear_units_on_fixed_level_keeps_slots() -> void:
	var c: BattleController = _controller("level_07")
	assert_true(c.apply_recommended())
	assert_eq(c.clear_units(), 3)
	assert_true(c.placements.is_empty())
	assert_eq(c.uids().size(), 3, "fixed 关槽位保留")
	for uid: String in c.uids():
		assert_eq_deep(RuleDef.to_array(c.get_rules(uid)), RuleDef.to_array(DataRegistry.get_commands().new_unit_rules()))   # 指令一并清空（回到新单位预填指令，第五阶段）
	assert_true(c.start() == false, "清空后不满足出场要求，不能开始")
