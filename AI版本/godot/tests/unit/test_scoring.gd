extends GutTest
## 结算综合分（Scoring，策划案 3.6；详细设计 08）：公式、最好成绩只留最低、胜利时由 BattleController 统计

const SaveManagerScript: GDScript = preload("res://scripts/autoloads/save_manager.gd")


func test_formula_uses_coefficients() -> void:
	var c: Dictionary = Scoring.coefficients()
	var sc: Dictionary = Scoring.compute(1, 2, 3, 4, 10.0)
	var expect: float = 1.0 * float(c["units"]) + 5.0 * float(c["complexity"]) + 4.0 * float(c["beacons"]) + 10.0 * float(c["time"])
	assert_eq(int(sc["total"]), int(round(expect)), "人数 + （行为 + 条件）+ 信标 + 用时，各乘系数")
	assert_almost_eq(float((sc["parts"] as Dictionary)["complexity"]), 5.0 * float(c["complexity"]), 0.001)
	assert_eq(int(sc["unit_count"]), 1)
	assert_eq(int(sc["beacon_count"]), 4)


func test_best_score_keeps_lowest() -> void:
	var sm: Node = SaveManagerScript.new()
	sm.set("data", SaveManagerScript.call("new_save", DataRegistry.get_initial_unlocks(), DataRegistry.get_initial_levels()))
	assert_eq(int(sm.call("best_score", "level_c01")), -1, "没通关过")
	assert_true(bool(sm.call("record_score", "level_c01", { "total": 90 })), "首次记录")
	assert_false(bool(sm.call("record_score", "level_c01", { "total": 120 })), "更差不刷新")
	assert_eq(int(sm.call("best_score", "level_c01")), 90)
	assert_true(bool(sm.call("record_score", "level_c01", { "total": 70 })), "更低刷新")
	assert_eq(int(sm.call("best_score", "level_c01")), 70)
	sm.free()


func test_controller_scores_win_only() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_c01")
	var saved: Dictionary = GameState.unlocks
	GameState.unlocks = DataRegistry.get_initial_unlocks().duplicate(true)
	var c := BattleController.new()
	c.setup(level)
	assert_true(c.apply_recommended())
	assert_true(c.start())
	for i: int in 600:
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()
	GameState.unlocks = saved
	assert_eq(c.world.result, SimTypes.BattleResult.WIN)
	var sc: Dictionary = c.last_score
	assert_false(sc.is_empty(), "胜利时算综合分")
	assert_eq(int(sc["unit_count"]), c.placements.size(), "所用人数 = 已部署单位")
	var actions: int = 0
	for uid: String in c.uids():
		for r: RuleDef in c.get_rules(uid):
			actions += 1 if r.enabled and r.action != null else 0
	assert_eq(int(sc["action_count"]), actions, "行为数 = 全部已启用指令")
	assert_false(c.last_score_record, "测试不写存档（persist 关闭）")
	c.free()
