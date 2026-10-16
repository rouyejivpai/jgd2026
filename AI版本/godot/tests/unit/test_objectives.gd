extends GutTest
## 05 §2 test_objectives：胜负判定（01 §6.9）

const ALLY: int = SimTypes.Faction.ALLY
const ENEMY: int = SimTypes.Faction.ENEMY


func _kill(u: SimUnit) -> void:
	u.hp = 0.0
	u.alive = false


func _world(win: Array, lose: Array) -> SimWorld:
	var w: SimWorld = SimFactory.make_empty_world(16, 12)
	for d: Variant in win:
		w.win_objectives.append(SimFactory.objective(d as Dictionary, true))
	for d: Variant in lose:
		w.lose_objectives.append(SimFactory.objective(d as Dictionary, false))
	return w


func _protect_world() -> SimWorld:
	var w: SimWorld = _world(
		[{ "id": "win_survive", "type": "survive", "target": "P", "seconds": 20 }],
		[{ "id": "lose_protect_dead", "type": "unit_dead", "target": "P" }, { "id": "lose_all_dead", "type": "all_allies_dead" }])
	SimFactory.add(w, "transit_node", ALLY, Vector2i(1, 1), [], "P")
	return w


func test_annihilate_ignores_structures_and_flagged() -> void:
	var w: SimWorld = _world([{ "id": "win", "type": "annihilate" }], [{ "id": "lose", "type": "all_allies_dead" }])
	SimFactory.add(w, "striker", ALLY, Vector2i(1, 1))
	var counted: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(10, 10))
	SimFactory.add(w, "echo_pillar", ENEMY, Vector2i(11, 10))                  # 建筑不计
	var flagged: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(12, 10))
	flagged.counts_for_annihilate = false                                      # 不计入全歼
	ObjectiveSystem.evaluate(w)
	assert_eq(w.result, SimTypes.BattleResult.NONE)
	_kill(counted)
	ObjectiveSystem.evaluate(w)
	assert_eq(w.result, SimTypes.BattleResult.WIN)


func test_destroy_targets() -> void:
	var w: SimWorld = _world([{ "id": "win", "type": "destroy", "targets": ["T1", "T2"] }], [{ "id": "lose", "type": "all_allies_dead" }])
	SimFactory.add(w, "striker", ALLY, Vector2i(1, 1))
	var t1: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(10, 10), [], "T1")
	var t2: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(11, 10), [], "T2")
	_kill(t1)
	ObjectiveSystem.evaluate(w)
	assert_eq(w.result, SimTypes.BattleResult.NONE, "未全部死亡")
	_kill(t2)
	ObjectiveSystem.evaluate(w)
	assert_eq(w.result, SimTypes.BattleResult.WIN)
	assert_eq(w.result_objective, "win")


func test_survive_uses_sim_time() -> void:
	var w: SimWorld = _protect_world()
	SimFactory.add(w, "striker", ALLY, Vector2i(2, 1), [SimFactory.r_idle()])
	SimFactory.add(w, "raider", ENEMY, Vector2i(15, 11))   # 视野外，不会接近
	SimFactory.run_steps(w, 599)
	assert_eq(w.result, SimTypes.BattleResult.NONE)
	w.step()
	assert_eq(w.clock.steps, 600)
	assert_almost_eq(w.clock.time, 20.0, 1e-9)
	assert_eq(w.result, SimTypes.BattleResult.WIN, "20 秒 = 600 步")


func test_survive_continues_after_all_enemies_dead() -> void:
	var w: SimWorld = _protect_world()
	SimFactory.add(w, "striker", ALLY, Vector2i(2, 1), [SimFactory.r_idle()])
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(15, 11))
	_kill(e)
	SimFactory.run_steps(w, 300)
	assert_eq(w.result, SimTypes.BattleResult.NONE, "敌人全灭后计时继续")
	assert_true(bool(w.objective_progress["threat_cleared"]))
	SimFactory.run_steps(w, 300)
	assert_eq(w.result, SimTypes.BattleResult.WIN)
	assert_almost_eq(w.clock.time, 20.0, 1e-9)


func test_lose_priority_over_win_same_step() -> void:
	var w: SimWorld = _world([{ "id": "win", "type": "annihilate" }], [{ "id": "lose", "type": "all_allies_dead" }])
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [SimFactory.r_attack_in_range()])
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(3, 2), [SimFactory.r_attack_in_range()])
	a.hp = 5.0
	e.hp = 5.0
	w.step()
	assert_eq(w.result, SimTypes.BattleResult.LOSE, "同一步同时达成 → 失败")


func test_all_allies_dead_ignores_structures() -> void:
	var w: SimWorld = _protect_world()
	var s: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 1))
	SimFactory.add(w, "raider", ENEMY, Vector2i(15, 11))
	_kill(s)
	ObjectiveSystem.evaluate(w)
	assert_eq(w.result, SimTypes.BattleResult.LOSE, "仅建筑存活 = 全灭")
	assert_eq(w.result_objective, "lose_all_dead")


func test_reach_zone() -> void:
	var w: SimWorld = _world([{ "id": "win", "type": "destroy", "targets": ["PR"] }],
		[{ "id": "lose_escaped", "type": "reach_zone", "target": "PR", "cells": [[0, 0], [0, 1]] }])
	SimFactory.add(w, "striker", ALLY, Vector2i(8, 8))
	var pr: SimUnit = SimFactory.add(w, "priest", ENEMY, Vector2i(3, 1), [], "PR")
	ObjectiveSystem.evaluate(w)
	assert_eq(w.result, SimTypes.BattleResult.NONE)
	pr.pos = SimTypes.cell_center(Vector2i(0, 1))
	ObjectiveSystem.evaluate(w)
	assert_eq(w.result, SimTypes.BattleResult.LOSE, "目标进入格集合 → 失败")


func test_sacrificing_normal_unit_not_fail() -> void:
	var w: SimWorld = _protect_world()
	var s1: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 1))
	SimFactory.add(w, "striker", ALLY, Vector2i(3, 1))
	SimFactory.add(w, "raider", ENEMY, Vector2i(15, 11))
	_kill(s1)
	ObjectiveSystem.evaluate(w)
	assert_eq(w.result, SimTypes.BattleResult.NONE, "普通单位阵亡、保护对象存活 → 继续")
