extends GutTest
## 10 §5 指令编辑重构：「添加指令」弹出行为列表 → 末尾新增（条件「始终」、目标「最近 / 任意」）；
## 条件一 / 条件二（二默认「无」），加第二条件后「与 / 或」可见并写入 condition_mode；两条件上限；删除（A01）；拖拽排序；
## 无启用勾选（旧配置 enabled:false 读作 true）；敌人只读面板同布局、3 条件全显。
## 第五阶段：攻击 / 移动两组分区、组内拖拽、每组条数上限、行为下拉不跨组、追击不选目标、玩家行无「覆盖」。

const RULE_EDITOR_SCENE: PackedScene = preload("res://scenes/ui/rule_editor.tscn")
const LEVEL_ID: String = "level_01"

var SLOT: String = ""
var _saved_unlocks: Dictionary
var _c: BattleController
var _editor: RuleEditor


func before_each() -> void:
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = {
		"presets": DataRegistry.get_commands().unlock_keys(),
		"conditions": ["always", "enemy_visible", "enemy_in_range"],
		"selectors": ["nearest"],
		"actions": ["idle", "attack", "chase_attack"],
		"forms": ["striker"],
	}
	var level: LevelDefinition = DataRegistry.get_level(LEVEL_ID)
	_c = BattleController.new()
	add_child_autofree(_c)
	_c.setup(level)
	SLOT = _c.add_unit("striker", Vector2i(2, 2))
	_c.set_rules(SLOT, [] as Array[RuleDef])           # 第五阶段：新单位有预填指令，测试从空列表开始
	var other: String = _c.add_unit("striker", Vector2i(2, 4))
	assert_eq([SLOT, other], ["u1", "u2"])
	_c.set_rules(other, level.recommended_rules("slot_striker_b"))
	_editor = RULE_EDITOR_SCENE.instantiate() as RuleEditor
	add_child_autofree(_editor)
	_editor.setup(_c, level)
	_editor.show_slot(SLOT)


func after_each() -> void:
	GameState.unlocks = _saved_unlocks


func _actions() -> Array[String]:
	var out: Array[String] = []
	for r: RuleDef in _c.get_rules(SLOT):
		out.append(SimTypes.action_to_string(r.action.type))
	return out


func _add(action_key: String) -> void:
	var menu: Array[String] = _editor.menu_actions()
	var i: int = menu.find(action_key)
	if i < 0:
		fail_test("行为不在「添加指令」列表中：%s" % action_key)
		return
	_editor.call("_fill_add_menu")
	_editor.call("_on_add_action", i)


func _rows() -> Array[RuleRow]:
	var rows: Array[RuleRow] = []
	rows.assign(_editor.get("_rows") as Array)
	return rows


## 模拟在下拉中选中值为 value 的一项（会发出 item_selected）
func _pick(o: OptionButton, value: String) -> void:
	for i: int in o.item_count:
		if UiKit.option_value(o, i) == value:
			o.select(i)
			o.item_selected.emit(i)
			return
	fail_test("下拉中没有 %s" % value)


## 第五阶段：两组旧行为「追击并攻击」不进菜单，第一关 allowed 的 chase_attack 视为允许 追击 + 攻击
func _dual_rules() -> Array[RuleDef]:
	return SimFactory.to_rules([SimFactory.r_attack_in_range(),
		{ "conditions": [{ "type": "enemy_visible" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "chase" } },
		SimFactory.r_idle()])


func test_add_menu_lists_actions_only() -> void:
	await wait_process_frames(1)
	assert_eq(_editor.menu_actions(), ["attack", "hold_fire", "follow_beacons", "chase", "idle", "wait"] as Array[String],
		"目录顺序（攻击组在前）；第一关 allowed 不含撤离；追击并攻击 / 沿路线 player:false 不进菜单；停火 / 信标 / 停止 / 等待始终可用")
	_editor.toggle_picker()
	assert_true(_editor.picker_open(), "「添加指令」打开行为列表（批准整图 ui_15）")
	var picker: Node = _editor.get("_picker")
	var buttons: Array = picker.get_children().filter(func(n: Node) -> bool: return n is Button)
	assert_eq(buttons.size(), 7, "6 个行为 + 取消")
	assert_eq((buttons[0] as Button).text, RuleText.action_name(SimTypes.ActionType.ATTACK), "列出的是行为名，不是预组合指令")
	assert_false((_editor.get("_list") as Control).visible, "打开时隐藏指令列表")
	(buttons[6] as Button).pressed.emit()
	assert_false(_editor.picker_open(), "「取消」关闭")
	assert_true((_editor.get("_list") as Control).visible)


func test_add_uses_defaults() -> void:
	await wait_process_frames(1)
	_add("attack")
	var r: RuleDef = _c.get_rules(SLOT)[0]
	assert_true(r.conditions.is_empty(), "默认条件「始终」")
	assert_eq(r.condition_mode, SimTypes.ConditionMode.ALL)
	assert_not_null(r.target)
	assert_eq(r.target.selector, SimTypes.Selector.NEAREST, "默认目标最近")
	assert_eq(r.target.filter, SimTypes.TargetFilter.ANY, "默认目标类型 = 列表首项（任意）")
	assert_true(r.enabled)
	_add("wait")
	assert_eq(_c.get_rules(SLOT)[1].action.seconds, SimTypes.WAIT_MIN_SECONDS, "等待秒数取 WAIT_MIN_SECONDS")
	assert_null(_c.get_rules(SLOT)[1].target, "等待无目标")
	_add("follow_beacons")
	assert_eq(_c.get_rules(SLOT)[2].action.mode, SimTypes.BeaconMode.ONCE, "信标模式取列表首项")
	assert_eq(_c.get_rules(SLOT)[2].action.from, "1", "起点 = 第一枚信标（无信标时为 1）")


func test_new_rules_append_to_end() -> void:
	await wait_process_frames(1)
	_add("attack")
	await wait_process_frames(1)
	_add("idle")
	assert_eq(_actions(), ["attack", "idle"] as Array[String], "新指令依次插在末尾")


func test_row_layout_action_first_two_conditions() -> void:
	_add("attack")
	await wait_process_frames(1)
	var row: RuleRow = _rows()[0]
	var conds: Array = row.get("_cond_options") as Array
	assert_eq(conds.size(), 2, "玩家行：条件一、条件二（上限两条）")
	assert_eq(UiKit.option_value(conds[0] as OptionButton, (conds[0] as OptionButton).selected), "always", "条件一默认「始终」")
	assert_eq(UiKit.option_value(conds[1] as OptionButton, (conds[1] as OptionButton).selected), "", "条件二默认「无」")
	assert_true((row.get("_logic") as Button).visible, "条件一、二之间恒显示与 / 或标志")
	assert_true((row.get("_logic") as Button).disabled, "一条件时不可切换与 / 或")
	assert_not_null(row.get("_selector"), "attack 显示目标选择")
	assert_not_null(row.get("_filter"), "attack 显示目标类型")
	assert_eq(row.find_children("*", "CheckBox", true, false).size(), 0, "无启用勾选")


func test_second_condition_shows_logic_and_writes_mode() -> void:
	_add("attack")
	await wait_process_frames(1)
	_pick((_rows()[0].get("_cond_options") as Array)[0] as OptionButton, "enemy_in_range")
	assert_eq(_c.get_rules(SLOT)[0].conditions.size(), 1)
	await wait_process_frames(1)
	_pick((_rows()[0].get("_cond_options") as Array)[1] as OptionButton, "enemy_visible")
	var r: RuleDef = _c.get_rules(SLOT)[0]
	assert_eq(r.conditions.size(), 2, "选了条件二才存在")
	assert_eq(r.conditions[1].type, SimTypes.ConditionType.ENEMY_VISIBLE)
	assert_eq(r.condition_mode, SimTypes.ConditionMode.ALL)
	await wait_process_frames(1)
	var logic: Button = _rows()[0].get("_logic") as Button
	assert_true(logic.visible, "两条件时显示与 / 或")
	assert_eq(logic.icon, RuleRow.LOGIC_AND, "与标志")
	logic.pressed.emit()
	assert_eq(_c.get_rules(SLOT)[0].condition_mode, SimTypes.ConditionMode.ANY, "切到「或」写入 condition_mode = any")
	await wait_process_frames(1)
	assert_eq((_rows()[0].get("_logic") as Button).icon, RuleRow.LOGIC_OR)
	assert_string_contains((_rows()[0].get("_sentence") as Label).text, DataRegistry.get_string("ui.sentence_or"))
	_pick((_rows()[0].get("_cond_options") as Array)[1] as OptionButton, "")
	r = _c.get_rules(SLOT)[0]
	assert_eq(r.conditions.size(), 1, "条件二改回「无」即删除")
	assert_eq(r.condition_mode, SimTypes.ConditionMode.ALL, "少于两条件时写 all")


func test_second_condition_on_always_keeps_first_slot() -> void:
	_add("idle")
	await wait_process_frames(1)
	_pick((_rows()[0].get("_cond_options") as Array)[1] as OptionButton, "enemy_visible")
	var r: RuleDef = _c.get_rules(SLOT)[0]
	assert_eq(r.conditions.size(), 2, "条件一「始终」+ 条件二")
	assert_eq(r.conditions[0].type, SimTypes.ConditionType.ALWAYS)
	await wait_process_frames(1)
	_pick((_rows()[0].get("_cond_options") as Array)[1] as OptionButton, "")
	assert_true(_c.get_rules(SLOT)[0].conditions.is_empty(), "去掉条件二后回到无条件")


func test_delete_button_removes_row() -> void:
	_c.set_rules(SLOT, _dual_rules())
	await wait_process_frames(1)
	var rows: Array[RuleRow] = _rows()
	assert_eq(rows.size(), 3)
	assert_eq(rows.map(func(r: RuleRow) -> int: return r.index), [0, 1, 2], "攻击组分区在上：行 = 攻击(0)、追击(1)、停止(2)")
	var del: Button = rows[1].get("_delete") as Button
	assert_false(del.disabled, "部署阶段可删除")
	del.pressed.emit()
	assert_eq(_actions(), ["attack", "idle"] as Array[String], "删除追击")
	await wait_process_frames(1)
	assert_eq(_rows().size(), 2, "行列表随之重建")


## 第五阶段：组内拖拽排序；跨组不可放下
func test_drag_reorder() -> void:
	_c.set_rules(SLOT, _dual_rules())
	await wait_process_frames(1)
	var rows: Array[RuleRow] = _rows()
	var data: Dictionary = rows[2].call("_drag_payload") as Dictionary      # 停止（移动组第 2 条）
	assert_true(bool(rows[1].call("_can_drop_data", Vector2.ZERO, data)), "同组可放下")
	assert_false(bool(rows[0].call("_can_drop_data", Vector2.ZERO, data)), "不能拖进攻击组")
	rows[1].call("_drop_data", Vector2.ZERO, data)
	assert_eq(_actions(), ["attack", "idle", "chase"] as Array[String], "停止拖到追击之上（移动组内优先级互换）")


func test_delete_to_empty_allows_start_with_warning() -> void:
	_c.set_rules(SLOT, _dual_rules())
	for i: int in 3:
		_editor.delete_rule(0)
	assert_eq(_c.get_rules(SLOT).size(), 0)
	assert_true(_c.start(), "空指令列表允许开始")
	var codes: Array[String] = []
	for p: Dictionary in _c.last_problems:
		codes.append("%s:%s:%s" % [p["code"], p["slot"], str(p["blocking"])])
	assert_has(codes, "EMPTY_RULES:%s:false" % SLOT, "保留 EMPTY_RULES 提醒（非阻塞）")


func test_delete_disabled_while_running() -> void:
	_c.set_rules(SLOT, _dual_rules())
	assert_true(_c.start())
	await wait_process_frames(2)
	var rows: Array[RuleRow] = _rows()
	assert_gt(rows.size(), 0)
	assert_true((rows[0].get("_delete") as Button).disabled, "运行中删除按钮禁用")
	assert_true((rows[0].get("_action") as OptionButton).disabled, "运行中行为下拉禁用")
	_editor.delete_rule(0)
	assert_eq(_c.get_rules(SLOT).size(), 3, "运行中删除无效")


func test_enemy_three_conditions_read_only() -> void:
	var enemy: SimUnit = null
	for u: SimUnit in _c.world.units:
		if u.faction == SimTypes.Faction.ENEMY:
			enemy = u
			break
	enemy.rules = SimFactory.to_rules([{ "condition_mode": "any",
		"conditions": [{ "type": "enemy_in_range" }, { "type": "enemy_visible" }, { "type": "self_hp_below", "ratio": 0.5 }],
		"target": { "selector": "nearest", "filter": "any" }, "action": { "type": "attack" } }])
	var ro: RuleEditor = RULE_EDITOR_SCENE.instantiate() as RuleEditor
	add_child_autofree(ro)
	ro.setup(_c, DataRegistry.get_level(LEVEL_ID))
	ro.show_enemy(enemy.id)
	await wait_process_frames(1)
	var rows: Array[RuleRow] = []
	rows.assign(ro.get("_rows") as Array)
	assert_eq(rows.size(), 1)
	var conds: Array = rows[0].get("_cond_options") as Array
	assert_eq(conds.size(), 3, "敌人数据 3 条件全部显示")
	for o: Variant in conds:
		assert_true((o as OptionButton).disabled, "只读")
	assert_false((rows[0].get("_delete") as Button).visible, "只读面板无删除")
	assert_false((ro.get("_add") as Button).visible, "只读面板无添加")


func test_disabled_rules_from_old_save_read_as_enabled() -> void:
	var raw: Dictionary = { "units": [{ "uid": "u1", "form": "striker", "pos": [2, 2], "rules": [
		{ "enabled": false, "condition_mode": "all", "conditions": [{ "type": "enemy_in_range" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "attack" } },
	] }], "next_uid": 2 }
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(DataRegistry.get_level(LEVEL_ID), raw)
	assert_true(c.get_rules("u1")[0].enabled, "旧配置 enabled:false 视为 true（10 §5.2）")
	var saved: Dictionary = c.config_to_raw()
	var rule0: Dictionary = ((((saved["units"] as Array)[0] as Dictionary)["rules"] as Array)[0]) as Dictionary
	assert_true(bool(rule0["enabled"]), "下次保存写回 true")


## 第五阶段：「覆盖」= 组内优先级（高覆盖低），玩家行不再显示覆盖勾选
func test_override_toggle_hidden_for_player() -> void:
	_add("attack")
	await wait_process_frames(1)
	var toggle: TextureButton = _rows()[0].get("_override") as TextureButton
	assert_not_null(toggle)
	assert_false(toggle.visible, "玩家行无覆盖勾选")


## 第五阶段：两组标题带条数；每组上限（commands.json group_limits）满后本组添加按钮禁用、再加无效
func test_group_sections_and_limit() -> void:
	var limit: int = DataRegistry.get_commands().group_limit(SimTypes.RuleGroup.ATTACK)
	for i: int in limit:
		_add("attack")
	_add("idle")
	await wait_process_frames(1)
	var sections: Dictionary = _editor.get("_sections") as Dictionary
	var atk: Dictionary = sections[SimTypes.RuleGroup.ATTACK] as Dictionary
	var mv: Dictionary = sections[SimTypes.RuleGroup.MOVE] as Dictionary
	assert_string_contains((atk["title"] as Label).text, "%d/%d" % [limit, limit])
	assert_string_contains((mv["title"] as Label).text, "1/%d" % DataRegistry.get_commands().group_limit(SimTypes.RuleGroup.MOVE))
	assert_true((atk["add"] as Button).disabled, "攻击组已满：添加按钮禁用")
	assert_false((mv["add"] as Button).disabled)
	assert_true(_editor.group_full(SimTypes.RuleGroup.ATTACK))
	_editor.open_picker(SimTypes.RuleGroup.ATTACK)
	assert_eq(_editor.menu_actions(), ["attack", "hold_fire"] as Array[String], "按组打开只列本组行为")
	_editor.call("_on_add_action", 0)
	assert_eq(RuleDef.group_indices(_c.get_rules(SLOT), SimTypes.RuleGroup.ATTACK).size(), limit, "满了不再添加")
	assert_eq((_rows()[limit].get("_action") as OptionButton).item_count, 4, "移动行的行为下拉只列移动组（沿信标 / 追击 / 停止 / 等待）")


## 2026-10-18：追击像攻击一样可选目标——默认最近 / 任意，改选后写回并保留
func test_chase_target_choice_defaults_nearest() -> void:
	(GameState.unlocks["selectors"] as Array).append("farthest")
	var lv: LevelDefinition = DataRegistry.get_level(LEVEL_ID)          # 本关只允许「最近」：临时放开「最远」，测完恢复
	lv.allowed_selectors.append(SimTypes.Selector.FARTHEST)
	_add("chase")
	await wait_process_frames(1)
	var r: RuleDef = _c.get_rules(SLOT)[0]
	assert_eq(r.target.selector, SimTypes.Selector.NEAREST, "默认追最近")
	assert_eq(r.target.filter, SimTypes.TargetFilter.ANY)
	var sel: OptionButton = _rows()[0].get("_selector") as OptionButton
	assert_not_null(sel, "追击行有目标选择下拉")
	_pick(sel, "farthest")
	assert_eq(_c.get_rules(SLOT)[0].target.selector, SimTypes.Selector.FARTHEST, "改选最远后写回")
	assert_eq(_c.get_rules(SLOT)[0].action.type, SimTypes.ActionType.CHASE, "仍是追击")
	lv.allowed_selectors.erase(SimTypes.Selector.FARTHEST)


## 第四阶段：目标距离为一个「< N」下拉（比较与距离合成），选中写回 op 与 value
func test_distance_dropdown_writes_op_and_value() -> void:
	_add("attack")
	await wait_process_frames(1)
	var r: RuleDef = _c.get_rules(SLOT)[0].clone()
	r.conditions.append(ConditionDef.from_dict({ "type": "target_distance", "op": "<", "value": 3.0 }, "test"))
	r.target = TargetDef.create(SimTypes.Selector.NEAREST, SimTypes.TargetFilter.ANY)
	var rules: Array[RuleDef] = [r]
	_c.set_rules(SLOT, rules)
	await wait_process_frames(1)
	var dist: OptionButton = null
	for o: Node in _rows()[0].find_children("*", "OptionButton", true, false):
		if UiKit.option_value(o as OptionButton, (o as OptionButton).selected) == RuleEditor.distance_key("<", 3.0):
			dist = o as OptionButton
	assert_not_null(dist, "当前值「< 3」被选中")
	_pick(dist, RuleEditor.distance_key(">", 5.0))
	assert_eq(_c.get_rules(SLOT)[0].conditions[0].op, ">")
	assert_eq(_c.get_rules(SLOT)[0].conditions[0].value, 5.0)
