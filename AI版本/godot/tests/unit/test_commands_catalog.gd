extends GutTest
## 10 §5.1 / §5.5 指令目录与 Cost 框架：数组顺序 = 菜单顺序 = 默认项；解锁键与关卡 allowed 过滤；player:false 不进玩家菜单；
## 指令 Cost 求和；commands.json 全 0 时预算与第二阶段一致；临时把某行为 cost 设为正数时预算计入指令 Cost。

const RULE_EDITOR_SCENE: PackedScene = preload("res://scenes/ui/rule_editor.tscn")
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
}

var _saved_unlocks: Dictionary
var _saved_commands: CommandCatalog


func before_each() -> void:
	_saved_unlocks = GameState.unlocks
	_saved_commands = DataRegistry.get_commands()
	var all: Dictionary = ALL_UNLOCKED.duplicate(true)
	all["presets"] = DataRegistry.get_commands().unlock_keys()
	GameState.unlocks = all


func after_each() -> void:
	GameState.unlocks = _saved_unlocks
	DataRegistry.set("_commands", _saved_commands)


func _raw_commands() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string("res://data/commands.json")) as Dictionary).duplicate(true)


## 把 raw 中 kind/id 条目的 cost 改为 cost，返回新目录
func _catalog_with_cost(kind: String, id: String, cost: int) -> CommandCatalog:
	var raw: Dictionary = _raw_commands()
	for e: Variant in raw[kind] as Array:
		if str((e as Dictionary)["id"]) == id:
			(e as Dictionary)["cost"] = cost
	return CommandCatalog.from_dict(raw, "fixture_commands")


func _editor(level_id: String, form: String, pos: Vector2i) -> RuleEditor:
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(DataRegistry.get_level(level_id))
	var uid: String = c.add_unit(form, pos)
	var e: RuleEditor = RULE_EDITOR_SCENE.instantiate() as RuleEditor
	add_child_autofree(e)
	e.setup(c, DataRegistry.get_level(level_id))
	e.show_slot(uid)
	return e


func test_catalog_loads_and_order_is_default() -> void:
	var cat: CommandCatalog = DataRegistry.get_commands()
	assert_false(DataRegistry.has_errors, "commands.json 加载无错误")
	assert_eq(cat.ids("actions"), ["attack", "hold_fire", "follow_beacons", "chase", "retreat", "idle", "wait", "chase_attack", "follow_route"] as Array[String],
		"第五阶段：攻击组（攻击 / 停火）在前，移动组在后；追击并攻击只留给旧数据")
	assert_false(cat.is_player("chase_attack"))
	assert_eq(cat.group_limit(SimTypes.RuleGroup.ATTACK), 5)
	assert_eq(cat.group_limit(SimTypes.RuleGroup.MOVE), 5)
	assert_eq(cat.ids("selectors").slice(0, 5), ["nearest", "farthest", "highest_hp", "most_damage", "first_in_range"] as Array[String], "玩家目标选项（会议口径）")
	for legacy_sel: String in ["lowest_hp", "first_seen", "highest_max_hp"]:
		assert_false(cat.is_player_selector(legacy_sel), "旧选敌不进玩家菜单：" + legacy_sel)
	var nur: Array[RuleDef] = cat.new_unit_rules()
	assert_eq(nur.size(), 2, "新单位预填两条：攻击组 + 移动组")
	assert_eq(nur[0].action.type, SimTypes.ActionType.ATTACK)
	assert_true(nur[0].conditions.is_empty(), "攻击组默认「始终」")
	assert_eq(nur[1].action.type, SimTypes.ActionType.FOLLOW_BEACONS, "移动组默认「沿信标移动」")
	assert_eq(cat.ids("conditions")[0], "always", "条件默认「始终」")
	assert_eq(cat.ids("selectors")[0], "nearest", "目标选择默认「最近」")
	assert_eq(cat.ids("filters")[0], "any")
	assert_false(cat.is_player("follow_route"))
	assert_true(cat.is_player("attack"))
	assert_eq(cat.unlock_key("actions", "chase"), "preset.chase_nearest_visible", "沿用 preset.* 解锁键")
	assert_false(FileAccess.file_exists("res://data/presets.json"), "presets.json 已删除（P1 末）")
	var e: RuleEditor = _editor("level_08", "striker", Vector2i(1, 4))
	var r: RuleDef = e.new_rule("attack")
	assert_eq(r.target.selector, SimTypes.Selector.NEAREST, "新指令目标选择 = 第一个可用项")
	assert_eq(r.target.filter, SimTypes.TargetFilter.ANY)


func test_unlock_and_allowed_filtering() -> void:
	var e: RuleEditor = _editor("level_03", "striker", Vector2i(2, 1))
	assert_true(e.menu_actions().has("chase"), "第三关 allowed 含追击且已解锁")
	assert_false(e.menu_actions().has("follow_route"), "player:false 的沿路线不进玩家菜单（第三关 allowed 虽含 follow_route）")
	var keys: Array = (GameState.unlocks["presets"] as Array).duplicate()
	keys.erase("preset.chase_nearest_visible")
	GameState.unlocks["presets"] = keys
	assert_false(e.menu_actions().has("chase"), "解锁键未解锁 → 不进菜单")
	assert_true(e.menu_actions().has("follow_beacons"), "unlock_key 为空 = 始终可用")
	var e1: RuleEditor = _editor("level_01", "striker", Vector2i(2, 2))
	assert_false(e1.menu_actions().has("retreat"), "第一关 allowed 不含撤离")
	var sel: Array[String] = []
	for it: Variant in e.selector_items(""):
		sel.append(str((it as Array)[1]))
	assert_eq(sel, ["nearest"] as Array[String], "第三关 allowed 选敌只有最近")
	var fil: Array[String] = []
	for it: Variant in e.filter_items(""):
		fil.append(str((it as Array)[1]))
	assert_eq(fil, ["any", "unit", "structure"] as Array[String], "目标类型按解锁键过滤")
	keys.erase("preset.attack_structure_in_range")
	GameState.unlocks["presets"] = keys
	fil.clear()
	for it: Variant in e.filter_items(""):
		fil.append(str((it as Array)[1]))
	assert_false(fil.has("structure"), "建筑目标类型需要 preset.attack_structure_in_range")


func test_cost_sum() -> void:
	var raw: Dictionary = _raw_commands()
	for e: Variant in raw["actions"] as Array:
		if str((e as Dictionary)["id"]) == "attack":
			(e as Dictionary)["cost"] = 2
	for e: Variant in raw["conditions"] as Array:
		if str((e as Dictionary)["id"]) in ["enemy_in_range", "enemy_visible"]:
			(e as Dictionary)["cost"] = 1
	var cat: CommandCatalog = CommandCatalog.from_dict(raw, "fixture_commands")
	var rules: Array[RuleDef] = SimFactory.to_rules([
		{ "condition_mode": "all", "conditions": [{ "type": "enemy_in_range" }, { "type": "enemy_visible" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "attack" } },
		{ "conditions": [], "action": { "type": "idle" } },
	])
	assert_eq(cat.rule_cost(rules[0]), 2 + 1 + 1, "action.cost + Σ condition.cost")
	assert_eq(cat.rule_cost(rules[1]), 0)
	assert_eq(cat.rules_cost(rules), 4, "指令 Cost = Σ 每条")


func test_all_zero_budget_matches_phase_two() -> void:
	for lid: String in DataRegistry.get_chapter("chapter_01").level_ids():      # 第一章；30 关战役（chapter_02）见 test_campaign_levels.gd
		var level: LevelDefinition = DataRegistry.get_level(lid)
		if not level.is_free():
			continue
		var c := BattleController.new()
		add_child_autofree(c)
		c.setup(level)
		assert_true(c.apply_recommended())
		var form_only: int = 0
		for uid: String in c.uids():
			form_only += c.cost_of(c.form_of(uid))
			assert_eq(c.command_cost(uid), 0, "%s %s 指令 Cost 为 0" % [lid, uid])
		assert_eq(c.budget_used(), form_only, "%s：全 0 时已用 = 形态 Cost 之和（与第二阶段一致）" % lid)
		assert_false(DeploymentValidator.has_blocking(c.last_problems), "%s 推荐阵型仍可开始" % lid)


func test_positive_cost_counts_against_budget() -> void:
	DataRegistry.set("_commands", _catalog_with_cost("actions", "attack", 5))
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(DataRegistry.get_level("level_02"))      # 预算 10
	var uid: String = c.add_unit("bulwark", Vector2i(3, 3))
	c.set_rules(uid, SimFactory.to_rules([SimFactory.r_attack_in_range()]))
	assert_eq(c.command_cost(uid), 5)
	assert_eq(c.budget_used(), 4 + 5, "已用 = 形态 + 指令")
	assert_eq(c.add_unit("striker", Vector2i(1, 2)), "", "9 + 3 > 10：放置新单位时按总 Cost 拒绝")
	assert_eq(c.place_problem("striker", Vector2i(1, 2)), DeploymentValidator.BUDGET_EXCEEDED)
	# 超预算时允许继续编辑，但校验阻塞开始（10 §5.5）
	assert_true(c.set_rules(uid, SimFactory.to_rules([SimFactory.r_attack_in_range(), SimFactory.r_attack_in_range()])), "超预算仍可编辑")
	assert_eq(c.budget_used(), 4 + 10)
	assert_false(c.start(), "超预算不能开始")
	var codes: Array[String] = []
	for p: Dictionary in c.last_problems:
		codes.append("%s:%s" % [p["code"], p["what"]])
	assert_has(codes, "BUDGET_EXCEEDED:14/10")


## Q-059：推荐阵型里 enabled:false 的条目摆放时略去，与保留停用条目的结果完全相同（评估器本就跳过停用规则）
func test_recommended_without_disabled_rules_same_result() -> void:
	for lid: String in ["level_02", "level_06", "level_07"]:
		var level: LevelDefinition = DataRegistry.get_level(lid)
		var hashes: Array[int] = []
		for keep_disabled: bool in [false, true]:
			var c := BattleController.new()
			add_child_autofree(c)
			c.setup(level)
			assert_true(c.apply_recommended())
			if keep_disabled:
				for ru: RecommendedUnitDef in level.recommended_units:
					var uid: String = c.recommended_uid(ru.slot_id) if ru.slot_id != "" else ""
					if uid != "" and c.placements.has(uid):
						c.set_rules(uid, RuleDef.clone_array(ru.rules))
			assert_true(c.start(), lid)
			for i: int in int(60.0 / SimTypes.SIM_DT):
				if c.phase != SimTypes.Phase.RUNNING:
					break
				c.advance_tick()
			hashes.append(c.world.state_hash())
		assert_eq(hashes[0], hashes[1], "%s：略去停用条目后终局哈希不变" % lid)


## P1 完成标准：8 关推荐阵型在新编辑器下可应用、可开始（每名单位的指令行都能建出来）
func test_all_recommended_apply_and_start_in_new_editor() -> void:
	for lid: String in DataRegistry.get_chapter("chapter_01").level_ids():      # 第一章；30 关战役（chapter_02）见 test_campaign_levels.gd
		var level: LevelDefinition = DataRegistry.get_level(lid)
		var c := BattleController.new()
		add_child_autofree(c)
		c.setup(level)
		assert_true(c.apply_recommended(), lid)
		var e: RuleEditor = RULE_EDITOR_SCENE.instantiate() as RuleEditor
		add_child_autofree(e)
		e.setup(c, level)
		for uid: String in c.uids():
			if not c.placements.has(uid):
				continue
			e.show_slot(uid)
			await wait_process_frames(1)
			assert_eq((e.get("_rows") as Array).size(), c.get_rules(uid).size(), "%s %s 指令行全部建出" % [lid, uid])
		assert_true(c.start(), "%s 推荐阵型可开始" % lid)
