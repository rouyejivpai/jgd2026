extends GutTest
## P4（07 §7、§9）：静态关卡加成 modifiers、初始单位 overrides、reach_zone 作为胜利（含 any_ally / count）、escort 护送；
## 机制、校验与面板显示。测试关见 tests/fixtures/level_p4_fixture.json（不进游戏）。

const FIXTURE: String = "res://tests/fixtures/level_p4_fixture.json"


func _raw() -> Dictionary:
	return (JSON.parse_string(FileAccess.get_file_as_string(FIXTURE)) as Dictionary).duplicate(true)


## 构建并校验；返回 [LevelDefinition, 新增错误条目]
func _load(d: Dictionary) -> Array:
	var before: int = DataReader.messages.size()
	var L: LevelDefinition = LevelDefinition.from_dict(d, "fixture")
	DataValidator.validate_level(L, DataRegistry.get_units(), DataRegistry.get_level_list())
	var errs: Array[String] = []
	for i: int in range(before, DataReader.messages.size()):
		errs.append(DataReader.messages[i])
	return [L, errs]


func _handle_errors() -> void:
	for e: Object in get_errors():
		e.set("handled", true)


func _world(L: LevelDefinition, deploy: Array = [[Vector2i(1, 1), []]]) -> SimWorld:
	var config: Dictionary = {}
	for i: int in deploy.size():
		var item: Array = deploy[i] as Array
		config["u%d" % (i + 1)] = { "form": "striker", "index": i, "pos": item[0] as Vector2i, "rules": SimFactory.to_rules(item[1] as Array) }
	return SimWorld.from_level(L, DataRegistry.get_units(), DataRegistry.get_traits(), config)


func test_fixture_is_valid() -> void:
	var r: Array = _load(_raw())
	assert_eq((r[1] as Array).size(), 0, "测试关无数据错误：%s" % str(r[1]))
	var L: LevelDefinition = r[0] as LevelDefinition
	assert_eq(L.modifiers.size(), 3)
	assert_eq(L.win[0].type, SimTypes.ObjectiveType.ESCORT)
	assert_eq(L.get_spawn("R1").overrides.get("vision"), 2.0)


func test_modifiers_and_overrides_applied_once_at_build() -> void:
	var L: LevelDefinition = _load(_raw())[0] as LevelDefinition
	var w: SimWorld = _world(L)
	var striker: SimUnit = w.get_spawn("u1")
	assert_almost_eq(striker.attack, DataRegistry.get_unit("striker").attack * 1.5, 0.001, "form:striker 攻击 ×1.5")
	var raider: SimUnit = w.get_spawn("R1")
	var rdef: UnitDefinition = DataRegistry.get_unit("raider")
	assert_almost_eq(raider.max_hp, rdef.max_hp + 20.0, 0.001, "faction:enemy 生命 +20")
	assert_almost_eq(raider.hp, raider.max_hp, 0.001, "生命同步为新上限")
	assert_almost_eq(raider.vision, 2.0, 0.001, "overrides 覆盖视野（最后应用）")
	assert_almost_eq(w.get_spawn("E1").move_speed, DataRegistry.get_unit("swift").move_speed * 2.0, 0.001, "spawn:E1 移速 ×2")
	assert_almost_eq(raider.attack, rdef.attack, 0.001, "不匹配的属性不变")
	SimFactory.run_steps(w, 30)
	assert_almost_eq(striker.attack, DataRegistry.get_unit("striker").attack * 1.5, 0.001, "无时效：运行中不变")


func test_panel_shows_level_bonus() -> void:
	var L: LevelDefinition = _load(_raw())[0] as LevelDefinition
	var w: SimWorld = _world(L)
	var striker_vals: Array[String] = RuleText.stat_values(w.get_spawn("u1"), DataRegistry.get_unit("striker"))
	assert_eq(striker_vals[1], "18（+6 关卡加成）", "攻击 12 ×1.5")
	var raider_vals: Array[String] = RuleText.stat_values(w.get_spawn("R1"), DataRegistry.get_unit("raider"))
	assert_eq(raider_vals[0], "75/75（+20 关卡加成）")
	assert_eq(raider_vals[4], "2（-10 关卡加成）", "视野覆盖 12 → 2")
	assert_eq(RuleText.stat_values(null, DataRegistry.get_unit("striker"))[1], "12", "无模拟单位时显示基础值")


func test_escort_wins_when_target_reaches_zone() -> void:
	var L: LevelDefinition = _load(_raw())[0] as LevelDefinition
	var w: SimWorld = _world(L)
	assert_eq(SimFactory.run_until_end(w, 10.0), SimTypes.BattleResult.WIN)
	assert_eq(w.result_objective, "win_escort")
	assert_eq(w.get_spawn("E1").cell(), Vector2i(9, 4))


func test_escort_loses_when_target_dies() -> void:
	var L: LevelDefinition = _load(_raw())[0] as LevelDefinition
	var w: SimWorld = _world(L)
	SimFactory.run_steps(w, 5)
	var e: SimUnit = w.get_spawn("E1")
	e.hp = 0.0                                  # 直接置为阵亡（step 开头会清空外部排入的伤害队列）
	e.alive = false
	w.step()
	assert_eq(w.result, SimTypes.BattleResult.LOSE)
	assert_eq(w.result_objective, "lose_escort_dead", "护送对象死亡 → 失败")


func test_reach_zone_win_any_ally_with_count() -> void:
	var d: Dictionary = _raw()
	var obj: Dictionary = d["objectives"] as Dictionary
	obj["win"] = [{ "id": "win_reach", "type": "reach_zone", "target": "any_ally", "cells": [[9, 0], [9, 1]], "count": 2 }]
	obj["lose"] = [{ "id": "lose_all_dead", "type": "all_allies_dead" }]
	((d["initial_units"] as Array)[0] as Dictionary)["rules"] = [SimFactory.r_idle()]    # 伤员不动
	(d["routes"] as Dictionary)["east"] = { "name": "东", "points": [[1, 0], [9, 0]] }
	(d["routes"] as Dictionary)["east2"] = { "name": "东2", "points": [[1, 1], [9, 1]] }
	var r: Array = _load(d)
	assert_eq((r[1] as Array).size(), 0, str(r[1]))
	var L: LevelDefinition = r[0] as LevelDefinition
	assert_eq(RuleText.objective_sentence(L.win[0], L), "2 名己方单位抵达目标区域")
	var go: Dictionary = { "conditions": [], "action": { "type": "follow_route", "route_id": "east", "loop": false } }
	var go2: Dictionary = { "conditions": [], "action": { "type": "follow_route", "route_id": "east2", "loop": false } }
	var one: SimWorld = _world(L, [[Vector2i(1, 0), [go]], [Vector2i(0, 2), [SimFactory.r_idle()]]])
	assert_eq(SimFactory.run_until_end(one, 6.0), SimTypes.BattleResult.NONE, "只到 1 名 < count 2，不胜利")
	var two: SimWorld = _world(L, [[Vector2i(1, 0), [go]], [Vector2i(1, 1), [go2]]])
	assert_eq(SimFactory.run_until_end(two, 6.0), SimTypes.BattleResult.WIN, "两名都到达 → 胜利")
	assert_eq(two.result_objective, "win_reach")


func test_reach_zone_win_specific_unit() -> void:
	var d: Dictionary = _raw()
	(d["objectives"] as Dictionary)["win"] = [{ "id": "win_reach_e1", "type": "reach_zone", "target": "E1", "cells": [[9, 4]] }]
	var L: LevelDefinition = _load(d)[0] as LevelDefinition
	assert_true(L.win[0].is_win)
	assert_eq(RuleText.objective_sentence(L.win[0], L), "伤员抵达目标区域")
	var w: SimWorld = _world(L)
	assert_eq(SimFactory.run_until_end(w, 10.0), SimTypes.BattleResult.WIN)


func test_validation_errors() -> void:
	var d: Dictionary = _raw()
	(d["objectives"] as Dictionary)["lose"] = [{ "id": "lose_all_dead", "type": "all_allies_dead" }]
	assert_true(str(_load(d)[1]).contains("unit_dead"), "escort 关卡缺少护送对象的 unit_dead 失败条件")
	d = _raw()
	((d["initial_units"] as Array)[0] as Dictionary)["faction"] = "enemy"
	assert_true(str(_load(d)[1]).contains("escort 目标"), "escort 目标必须是己方单位")
	d = _raw()
	(d["modifiers"] as Array).append({ "target": "form:dragon", "stat": "attack", "mul": 2 })
	(d["modifiers"] as Array).append({ "target": "spawn:R1", "stat": "armor", "mul": 2 })
	(d["modifiers"] as Array).append({ "target": "team:red", "stat": "attack" })
	var errs: String = str(_load(d)[1])
	assert_true(errs.contains("dragon"), "未知形态")
	assert_true(errs.contains("armor"), "未知属性")
	assert_true(errs.contains("team:red"), "target 格式")
	d = _raw()
	((d["initial_units"] as Array)[1] as Dictionary)["overrides"] = { "luck": 3 }
	assert_true(str(_load(d)[1]).contains("luck"), "overrides 属性非法")
	d = _raw()
	((d["objectives"] as Dictionary)["lose"] as Array).append({ "id": "lose_any", "type": "reach_zone", "target": "any_ally", "cells": [[0, 0]] })
	assert_true(str(_load(d)[1]).contains("any_ally"), "any_ally 只能用于胜利")
	_handle_errors()
