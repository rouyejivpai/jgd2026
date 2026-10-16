extends GutTest
## 07 §5 / 08 ⑥ UI 走查：对侧面板切侧、不挡选中单位、点击空地 / Esc 隐藏、运行中只读；
## 底栏出场卡与预算（free）、槽位卡（fixed）；敌人面板为只读 RuleEditor。
## 10 §6.1（第三阶段 P0）：无导出按钮、有「清空」、「重置」更名「重试」。
## 10 §6.1（P2）：右上角功能组（重试 速度 暂停 设置 退出）与其下「任务」「机制说明」；底栏开始左 / 卡居中 / 清空 / 提示 / 预算最右；任务弹窗开合。

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


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_level_id = GameState.current_level_id
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.current_level_id = _saved_level_id
	GameState.unlocks = _saved_unlocks


func _battle(level_id: String) -> Node2D:
	GameState.current_level_id = level_id
	SaveManager.set_level_config(level_id, {})
	var root: Node2D = BATTLE_SCENE.instantiate() as Node2D
	add_child_autofree(root)
	(root.get_node("BattleController") as BattleController).persist = false
	(root.find_child("DialogueOverlay", true, false) as CanvasItem).visible = false
	return root


func _settle() -> void:
	for i: int in 30:
		await wait_process_frames(1)


## 第四阶段：详情为停靠屏幕一侧、上下铺满的侧栏（批准整图 side_detail/design.png）：单位在左半屏 → 侧栏贴右边，反之贴左边；
## 没有遮罩（侧栏以外的战场照常可点）；「关闭」只收起（保留选中）；点击空地 = 取消选中并收起
func test_detail_modal_follows_reference() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	await wait_process_frames(1)
	var hud: Control = root.find_child("HUD", true, false) as Control
	var side: Control = root.find_child("SidePanel", true, false) as Control
	var ally: int = c.unit_id_of_slot("u1")
	EventBus.unit_selected.emit(ally)
	await _settle()
	assert_true(side.visible)
	var vp: Vector2 = hud.get_viewport_rect().size
	var frame: Control = side.get_node("Frame") as Control
	var design: Rect2 = UiKit.layout_rect(DetailKit.SKIN, "det_panel", UiKit.design_size(DetailKit.SKIN))
	var unit_x: float = (root.call("unit_screen_pos", ally) as Vector2).x
	var fr: Rect2 = frame.get_global_rect()
	assert_eq(bool(hud.call("side_on_right")), unit_x < vp.x * 0.5, "侧栏在单位的对侧")
	if bool(hud.call("side_on_right")):
		assert_lt(unit_x, fr.position.x, "侧栏不遮挡该单位")
	else:
		assert_gt(unit_x, fr.end.x, "侧栏不遮挡该单位")
	assert_eq(fr.size.x, design.size.x, "宽 = 布局")
	assert_eq(fr.position.y, design.position.y, "上沿 = 布局")
	assert_almost_eq(vp.y - fr.end.y, UiKit.design_size(DetailKit.SKIN).y - design.end.y, 0.5, "上下铺满（下边距 = 布局）")
	assert_eq(side.mouse_filter, Control.MOUSE_FILTER_IGNORE, "没有遮罩")
	assert_null(side.get_node_or_null("Skin_det_scrim"))
	(side.find_child("DetailClose", true, false) as Button).pressed.emit()
	assert_false(side.visible, "「关闭」收起侧栏")
	assert_eq(int(root.get("selected_id")), ally, "但保留选中")
	EventBus.unit_selected.emit(ally)
	await _settle()
	EventBus.unit_selected.emit(-1)
	assert_false(side.visible, "点击空地收起")
	assert_eq(int(root.get("selected_id")), -1, "并取消选中")
	var enemy: int = -1
	for u: SimUnit in c.world.units:
		if u.faction == SimTypes.Faction.ENEMY:
			enemy = u.id
	EventBus.unit_selected.emit(enemy)
	await _settle()
	var enemy_panel: Control = root.find_child("EnemyPanel", true, false) as Control
	assert_true(enemy_panel.visible)
	var editor: RuleEditor = enemy_panel.find_children("*", "RuleEditor", true, false)[0] as RuleEditor
	assert_true(editor.read_only, "敌人面板为只读 RuleEditor")
	await wait_process_frames(1)
	assert_gt((editor.get("_rows") as Array).size(), 0, "敌人规则逐行显示")
	assert_false(editor.editable())
	# 点击空地 / Esc 隐藏
	EventBus.unit_selected.emit(-1)
	assert_false(side.visible, "点击空地隐藏")
	EventBus.unit_selected.emit(ally)
	await _settle()
	var esc := InputEventAction.new()
	esc.action = "ui_cancel"
	esc.pressed = true
	hud.call("_unhandled_input", esc)
	assert_false(side.visible, "Esc 隐藏")


func test_running_is_viewable_but_read_only() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_true(c.apply_recommended())
	assert_true(c.start())
	EventBus.unit_selected.emit(c.unit_id_of_slot("u1"))
	await _settle()
	var side: Control = root.find_child("SidePanel", true, false) as Control
	assert_true(side.visible, "运行中可查看")
	var unit_panel: Control = root.find_child("UnitPanel", true, false) as Control
	var editor: RuleEditor = unit_panel.find_children("*", "RuleEditor", true, false)[0] as RuleEditor
	assert_false(editor.editable(), "运行中不可编辑")
	var rows: Array = editor.get("_rows") as Array
	assert_gt(rows.size(), 0)
	assert_true(((rows[0] as RuleRow).get("_delete") as Button).disabled)


func test_free_cards_and_budget() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	var cards: Array[Node] = _roster_cards(root)
	assert_eq(cards.size(), 2, "第二关两种形态卡")
	assert_eq(root.find_children("*", "RosterCard", true, false).filter(func(n: Node) -> bool: return (n as RosterCard).locked).size(), 3,
		"其余三个卡位为「未解锁」卡（P6：五个卡位）")
	var budget: Label = root.find_child("BudgetLabel", true, false) as Label
	assert_eq(budget.text, "0 / 10")
	var bulwark_card: RosterCard = null
	for n: Node in cards:
		if (n as RosterCard).form == "bulwark":
			bulwark_card = n as RosterCard
	var map_input: Control = root.find_child("MapInput", true, false) as Control
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	var t: float = float(int(root.get("cell_px")))
	var at: Vector2 = map_input.get_global_transform().affine_inverse() * (rect.position + Vector2(3.5 * t, (7 - 3.5) * t))
	var payload: Dictionary = bulwark_card.drag_payload()
	assert_true(bool(map_input.call("_can_drop_data", at, payload)), "出场卡可拖到部署区")
	map_input.call("_drop_data", at, payload)
	assert_eq(c.placements.size(), 1)
	assert_eq(budget.text, "4 / 10", "放置扣费")
	c.add_unit("bulwark", Vector2i(3, 2))
	await wait_process_frames(1)
	assert_true(bulwark_card.disabled, "8 + 4 > 10：预算不足时卡片禁用")
	c.remove_unit("u2")
	await wait_process_frames(1)
	assert_false(bulwark_card.disabled, "收回返还 Cost")
	assert_eq(budget.text, "4 / 10")


func test_fixed_level_shows_slot_cards_without_budget() -> void:
	var root: Node2D = _battle("level_07")
	await wait_process_frames(2)
	var cards: Array[Node] = _roster_cards(root)
	assert_eq(cards.size(), 3, "第七关三个固定槽位卡")
	assert_eq((cards[0] as RosterCard).slot_id, "slot_bulwark")
	assert_false((root.find_child("BudgetLabel", true, false) as Control).is_visible_in_tree(), "fixed 关不显示预算数值")
	var fixed: Label = root.find_child("BudgetFixedLabel", true, false) as Label
	assert_true(fixed.is_visible_in_tree(), "fixed 关预算铭牌显示「固定出场」（批准整图 ui_04）")
	assert_eq(fixed.text, DataRegistry.get_string("ui.roster_fixed"))


func test_no_export_has_clear_and_retry() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	var c: BattleController = root.get_node("BattleController") as BattleController
	assert_null(root.find_child("ExportButton", true, false), "HUD 导出按钮已删除")
	assert_null(root.find_child("ResetButton", true, false))
	var result_panel: Control = root.find_child("ResultPanel", true, false) as Control
	assert_false(result_panel.has_method("export_record"), "结算面板导出已删除")
	for b: Node in result_panel.find_children("*", "Button", true, false):
		assert_ne((b as Button).text, "导出本局记录", "结算面板无导出按钮")
	var clear: Button = root.find_child("ClearButton", true, false) as Button
	var retry: Button = root.find_child("RetryButton", true, false) as Button
	assert_not_null(clear, "有「清空」")
	assert_eq(clear.text, DataRegistry.get_string("ui.clear_units"))
	assert_eq(clear.text, "清空")
	assert_eq(retry.text, "重试", "「重置」更名「重试」（决策 ①）")
	assert_true(retry.disabled, "部署阶段不可重试")
	assert_true(clear.disabled, "无已放置角色时清空禁用")
	assert_true(c.apply_recommended())
	await wait_process_frames(1)
	assert_false(clear.disabled, "部署阶段有角色时可清空")
	assert_true(c.start())
	assert_false(retry.disabled, "运行中可重试")
	assert_true(clear.disabled, "运行中不可清空")
	retry.pressed.emit()
	assert_eq(c.phase, SimTypes.Phase.DEPLOY, "重试 = 回到部署阶段")
	assert_eq(c.placements.size(), 3, "并保留配置")


## 出场卡（不含补位的「未解锁」卡）
func _roster_cards(root: Node) -> Array[Node]:
	return root.find_children("*", "RosterCard", true, false).filter(func(n: Node) -> bool: return not (n as RosterCard).locked)


## P6：按批准整图 ui_01 换皮后，每个控件的位置与大小 = 布局（data/ui_layout/battle_hud.json）
func test_top_right_group_and_bottom_follow_layout() -> void:
	var root: Node2D = _battle("level_02")
	await wait_process_frames(2)
	await _settle()
	var group: Control = root.find_child("ControlGroup", true, false) as Control
	assert_not_null(group, "右上角功能组")
	var names: Array[String] = []
	for ch: Node in group.get_children():
		names.append(String(ch.name))
	assert_eq(names, ["RetryButton", "Speed1Button", "Speed2Button", "PauseButton", "SettingsButton", "ExitButton"] as Array[String], "速度、暂停 / 继续、设置、退出集中在右上角")
	var vp: Vector2 = (group as Control).get_viewport_rect().size
	var ids: Dictionary = {
		"btn_retry": "RetryButton", "btn_speed1": "Speed1Button", "btn_speed2": "Speed2Button", "btn_pause": "PauseButton",
		"btn_settings": "SettingsButton", "btn_exit": "ExitButton", "btn_task": "ObjectivesButton", "btn_mechanics": "MechanicsButton",
		"btn_clear": "ClearButton", "btn_hint": "HintButton", "btn_start": "StartButton",
	}
	for id: String in ids.keys():
		var c: Control = root.find_child(str(ids[id]), true, false) as Control
		assert_eq(c.get_global_rect(), UiKit.layout_rect("battle_hud", id, vp), "%s 位置 = 布局" % ids[id])
	assert_eq((root.find_child("ObjectivesButton", true, false) as Button).text, "任务")
	var cards: Array[Node] = root.find_children("*", "RosterCard", true, false)
	assert_eq(cards.size(), 5, "五个卡位")
	for i: int in cards.size():
		assert_eq((cards[i] as Control).get_global_rect(), UiKit.layout_rect("battle_hud", "card_%d" % (i + 1), vp), "卡位 %d = 布局" % (i + 1))
	var bands: Vector2 = Playfield.bands()
	var rect: Rect2 = root.get("playfield_rect") as Rect2
	assert_true(rect.position.y >= bands.x and rect.end.y <= vp.y - bands.y, "战场在 HUD 让出的上下带之间，不被 HUD 遮挡")


func test_objectives_popup_opens_and_closes() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var hud: Control = root.find_child("HUD", true, false) as Control
	var popup: Control = root.find_child("ObjectivePopup", true, false) as Control
	var tasks: Button = root.find_child("ObjectivesButton", true, false) as Button
	var panel: Control = root.find_child("ObjectivePanel", true, false) as Control
	assert_false(popup.visible)
	assert_true(popup.is_ancestor_of(panel), "ObjectivePanel 内容不变，在悬浮弹窗里（P6：正文区可上下滚动）")
	assert_not_null(root.find_child("Scroll_PopupColumn", true, false), "弹窗正文超出时滚轮 / 拖动滚动")
	tasks.pressed.emit()
	assert_true(popup.visible, "「任务」打开弹窗")
	assert_true(bool(hud.call("is_objectives_open")))
	var mech_btn: Button = root.find_child("MechanicsButton", true, false) as Button
	mech_btn.pressed.emit()
	assert_false(popup.visible, "与机制说明互斥")
	tasks.pressed.emit()
	assert_false((root.find_child("MechanicsPopup", true, false) as Control).visible)
	tasks.pressed.emit()
	assert_false(popup.visible, "再点收起")
	var objective: ScrollText = root.find_child("Scroll_ObjectiveLabel", true, false) as ScrollText
	assert_not_null(objective, "任务句在铭牌内遮罩 + 滚动（长文本：滚轮 / 拖动）")
	assert_eq(objective.mode, ScrollText.Mode.MANUAL)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	objective.call("_gui_input", click)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	objective.call("_gui_input", release)
	assert_true(popup.visible, "点击任务句同样打开弹窗（并让特殊目标闪烁）")
	var close: Button = null
	for b: Node in popup.find_children("*", "Button", true, false):
		if (b as Button).text == DataRegistry.get_string("ui.close"):
			close = b as Button
	assert_not_null(close)
	close.pressed.emit()
	assert_false(popup.visible, "弹窗「关闭」")


## P6 ui_05：开始校验问题面板按批准整图摆放——两行时与整图同高、下沿固定；标题与各行在面板内；行多时向上长、超出可用高度时列表滚动
func test_problems_panel_follows_reference() -> void:
	var root: Node2D = _battle("level_03")
	await wait_process_frames(2)
	var hud: Node = root.find_child("HUD", true, false)
	var vp: Vector2 = (hud as Control).get_viewport_rect().size
	var two: Array[Dictionary] = [DeploymentValidator._problem("BUDGET_EXCEEDED", "", 0, "12/8"), DeploymentValidator._problem("EMPTY_RULES", "u1", 0, "", false)]
	hud.call("_show_problems", DataRegistry.get_string("ui.problems_title"), two)
	await wait_process_frames(2)
	var panel: Control = root.find_child("ProblemsPanel", true, false) as Control
	var ref: Rect2 = UiKit.layout_rect("battle_hud", "problems_panel", vp)
	assert_true(panel.visible)
	assert_almost_eq(panel.get_global_rect().end.y, ref.end.y, 1.0, "下沿 = 整图")
	assert_almost_eq(panel.get_global_rect().size.y, ref.size.y, 3.0, "两行时与整图同高")
	var title: Label = root.find_child("ProblemsTitle", true, false) as Label
	assert_true(title.is_visible_in_tree())
	assert_true(panel.get_global_rect().encloses(title.get_global_rect().grow(-1.0)) or panel.get_global_rect().intersects(title.get_global_rect()), "标题在面板内")
	assert_almost_eq(title.get_parent().get("position").y + panel.get_global_rect().position.y, UiKit.layout_text_rect("battle_hud", "problems_title", vp).position.y, 1.0, "标题位置 = 整图")
	var many: Array[Dictionary] = []
	for i: int in 40:
		many.append(DeploymentValidator._problem("EMPTY_RULES", "u1", 0, "", false))
	hud.call("_show_problems", "x", many)
	await wait_process_frames(2)
	assert_almost_eq(panel.get_global_rect().end.y, ref.end.y, 1.0, "行多时下沿仍固定")
	assert_gte(panel.get_global_rect().position.y, Playfield.bands().x - 1.0, "不超过 HUD 上带")
	var scroll: ScrollText = root.find_child("Scroll_ProblemsList", true, false) as ScrollText
	assert_gt(scroll.overflow(), 0.0, "超出可用高度时列表可滚动（滚轮 / 拖动）")
	assert_eq(scroll.mode, ScrollText.Mode.MANUAL)
