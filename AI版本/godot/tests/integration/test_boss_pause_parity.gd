extends GutTest
## 2026-10-21 用户反馈：最后一关（level_c30）转阶段暂停里不能用「推荐阵型」。用户确认：暂停里只有「重置」特殊（整关重来），
## 其余功能与正常部署阶段一致。回归：
## - 提示面板「摆放」在暂停中可用，第一阶段不是用推荐摆的（读档 / 手摆）也能按形态对上存活单位；
## - 暂停中放下的增援可挪位、可收回（移除 / 拖出战场 / 清空），存活单位不能挪；
## - 「继续战斗」同「开始战斗」先校验，有阻塞问题时停在暂停里；暂停中的配置不写进存档。

const HINT_PANEL_SCENE: PackedScene = preload("res://scenes/ui/hint_panel.tscn")
const LEVEL_ID: String = "level_c30"
const SECONDS: float = 180.0

var _saved_data: Dictionary
var _saved_unlocks: Dictionary


func before_each() -> void:
	_saved_data = SaveManager.data.duplicate(true)
	_saved_unlocks = GameState.unlocks
	GameState.unlocks = _unlocks_before(LEVEL_ID)
	SaveManager.set_hints_seen(LEVEL_ID, DataRegistry.get_level(LEVEL_ID).hints.size())
	SaveManager.set_recommend_used(LEVEL_ID, false)


func after_each() -> void:
	SaveManager.data = _saved_data
	GameState.unlocks = _saved_unlocks


func _unlocks_before(level_id: String) -> Dictionary:
	var u: Dictionary = DataRegistry.get_initial_unlocks().duplicate(true)
	for i: int in range(1, 31):
		var lid: String = "level_c%02d" % i
		if lid == level_id:
			break
		var rw: Dictionary = DataRegistry.get_level(lid).rewards
		for k: String in ["forms", "presets", "conditions", "selectors", "actions"]:
			var have: Array = u.get(k, []) as Array
			for v: Variant in rw.get("unlock_" + k, []) as Array:
				if not have.has(v):
					have.append(v)
			u[k] = have
	return u


## 第一阶段按推荐位置摆好，再经存档结构读进一个新控制器（= 读档 / 手摆，没有推荐条目名记录），开打直到换阶段暂停
func _paused_controller() -> BattleController:
	var level: LevelDefinition = DataRegistry.get_level(LEVEL_ID)
	var first := BattleController.new()
	first.setup(level)
	first.apply_recommended()
	var raw: Dictionary = first.config_to_raw()
	first.free()
	var c := BattleController.new()
	add_child_autofree(c)
	c.set_physics_process(false)
	c.setup(level, raw)
	assert_true(c.recommended_uids.is_empty(), "读档后没有推荐条目名记录")
	assert_true(c.start(), "第一阶段通过开始前校验")
	for i: int in int(ceil(SECONDS / SimTypes.SIM_DT)):
		c.advance_tick()
		if c.boss_pending:
			break
	assert_true(c.boss_pending, "Boss 血量过半时暂停")
	return c


func _make_panel(c: BattleController) -> HintPanel:
	var panel: HintPanel = HINT_PANEL_SCENE.instantiate() as HintPanel
	add_child_autofree(panel)
	panel.setup(c.level, c)
	return panel


func _alive_of_form(c: BattleController, form: String) -> String:
	for uid: String in c.uids():
		if c.form_of(uid) == form and c._alive_in_world(uid) and not c.reinforce_uids.has(uid):
			return uid
	return ""


func test_recommend_button_works_in_boss_pause() -> void:
	var c: BattleController = _paused_controller()
	var panel: HintPanel = _make_panel(c)
	assert_true(panel.recommend_available(), "看完提示后为推荐阵型")
	panel.open_recommend()
	var apply: Button = panel.get("_apply_button") as Button
	assert_false(apply.disabled, "暂停中「摆放」可点")
	assert_true(panel.confirm_recommended(), "暂停中可摆放第二阶段推荐")
	var p2: Dictionary = c.level.recommended_phase2
	var rules_map: Dictionary = p2["rules"] as Dictionary
	for ru: RecommendedUnitDef in c.level.recommended_units:
		var uid: String = _alive_of_form(c, ru.form)
		if uid == "" or not rules_map.has(ru.slot_id):
			continue
		assert_eq(RuleDef.to_array(c.get_rules(uid)), RuleDef.to_array(c._rules_from(rules_map[ru.slot_id] as Array)),
			"%s（%s）按形态换上第二阶段推荐指令" % [uid, ru.form])
	assert_eq(c.reinforce_uids.size(), (p2["reinforcements"] as Array).size(), "推荐增援全部放下")
	assert_true(panel.confirm_recommended(), "再摆一次：先收回已放的增援再摆")
	assert_eq(c.reinforce_uids.size(), (p2["reinforcements"] as Array).size(), "重摆后增援人数不变")
	c.resume()
	assert_eq(c.phase, SimTypes.Phase.RUNNING, "推荐配置通过「继续」前校验")
	for i: int in int(ceil(SECONDS / SimTypes.SIM_DT)):
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()
	assert_eq(c.world.result, SimTypes.BattleResult.WIN, "读档进来的第一阶段 + 暂停中推荐 → 胜利")


func test_reinforcements_move_remove_clear() -> void:
	var c: BattleController = _paused_controller()
	var survivor: String = _alive_of_form(c, "bulwark")
	assert_ne(survivor, "", "有存活的盾卫")
	assert_false(c.can_move(survivor), "存活单位不能挪")
	assert_false(c.remove_unit(survivor), "存活单位不能收回")
	var u1: String = c.add_unit("striker", Vector2i(2, 6))
	var u2: String = c.add_unit("bulwark", Vector2i(2, 5))
	assert_ne(u1, "")
	assert_ne(u2, "")
	assert_true(c.can_move(u1), "本次放下的增援可挪")
	assert_eq(c.place_problem(u1, Vector2i(3, 8)), "", "增援区内可挪")
	assert_ne(c.place_problem(u1, Vector2i(2, 5)), "", "不能挪到另一名增援的格上")
	assert_ne(c.place_problem(u1, Vector2i(10, 6)), "", "不能挪出增援区")
	assert_true(c.place_unit(u1, Vector2i(3, 8)))
	assert_eq(c.world.get_unit(c.unit_id_of_slot(u1)).cell(), Vector2i(3, 8), "世界里的增援随之挪位")
	var cost_before: int = c.reinforce_cost()
	assert_true(c.remove_unit(u1), "增援可收回")
	assert_null(c.world.get_unit(c.unit_id_of_slot(u1)), "收回后从战场消失")
	assert_lt(c.reinforce_cost(), cost_before, "收回返还增援预算")
	assert_eq(c.clear_units(), 1, "清空收回剩下的增援")
	assert_true(c.reinforce_uids.is_empty())
	assert_null(c.world.get_unit(c.unit_id_of_slot(u2)))
	assert_true(c._alive_in_world(survivor), "清空不动存活单位")


func test_resume_validates_like_start() -> void:
	var c: BattleController = _paused_controller()
	var survivor: String = _alive_of_form(c, "lancer")
	if survivor == "":
		survivor = _alive_of_form(c, "bulwark")
	var bad: Array[RuleDef] = [RuleDef.from_dict({ "conditions": [{ "type": "at_beacon", "beacon": "9" }], "action": { "type": "attack" },
		"target": { "selector": "nearest", "filter": "unit" } }, "test")]
	assert_true(c.set_rules(survivor, bad))
	watch_signals(EventBus)
	c.resume()
	assert_true(DeploymentValidator.has_blocking(c.last_problems), "引用不存在的信标 = 阻塞问题：%s" % str(c.last_problems))
	assert_signal_emitted(EventBus, "validation_failed")
	assert_true(c.boss_pending, "有阻塞问题时停在暂停里")
	assert_eq(c.phase, SimTypes.Phase.PAUSED)
	assert_true(c.apply_recommended())
	c.resume()
	assert_eq(c.phase, SimTypes.Phase.RUNNING, "改好后可以继续")


func test_pause_config_not_saved() -> void:
	var c: BattleController = _paused_controller()
	c.persist = true
	SaveManager.set_level_config(LEVEL_ID, { "marker": true })
	c.apply_recommended()
	c.save_config()
	assert_true(bool(SaveManager.get_level_config(LEVEL_ID).get("marker", false)), "暂停中不写存档（存档只保存第一阶段）")
	c.persist = false
