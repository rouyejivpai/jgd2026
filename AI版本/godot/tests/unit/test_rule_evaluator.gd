extends GutTest
## 05 §2 test_rule_evaluator：指令求值（01 §6.6）

const ALLY: int = SimTypes.Faction.ALLY
const ENEMY: int = SimTypes.Faction.ENEMY


func _world() -> SimWorld:
	return SimFactory.make_empty_world(12, 12)


func test_first_matching_rule_wins() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [
		SimFactory.r_attack_in_range(),
		{ "conditions": [], "target": { "selector": "nearest" }, "action": { "type": "attack" } },
	])
	SimFactory.add(w, "raider", ENEMY, Vector2i(4, 2))
	w.step()
	assert_eq(a.current_rule, 0, "两条都成立时只执行第一条")


func test_disabled_rule_skipped() -> void:
	var w: SimWorld = _world()
	var r0: Dictionary = SimFactory.r_attack_in_range()
	r0["enabled"] = false
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [
		r0,
		{ "conditions": [], "target": { "selector": "nearest" }, "action": { "type": "attack" } },
	])
	SimFactory.add(w, "raider", ENEMY, Vector2i(4, 2))
	w.step()
	assert_eq(a.current_rule, 1, "禁用第一条后执行第二条")


func test_no_rule_matched_idles_with_reason() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(0, 0), [SimFactory.r_attack_in_range()])
	SimFactory.add(w, "raider", ENEMY, Vector2i(11, 11))   # 视野 8 之外
	var start: Vector2 = a.pos
	w.step()
	assert_eq(a.current_rule, -1)
	assert_eq(a.current_action, SimTypes.ActionType.IDLE)
	assert_eq(a.reason, SimTypes.ReasonCode.NO_RULE_MATCHED)
	assert_eq(a.pos, start)


func test_condition_fail_reasons_recorded() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [
		{ "conditions": [{ "type": "self_hp_below", "ratio": 0.5 }], "action": { "type": "retreat" } },
		SimFactory.r_attack_in_range(),
		{ "conditions": [{ "type": "target_distance", "op": "<", "value": 2 }], "target": { "selector": "nearest" }, "action": { "type": "idle" } },
		SimFactory.r_idle(),
	])
	SimFactory.add(w, "raider", ENEMY, Vector2i(8, 2))     # 距离 6：可见、不在射程 4 内
	w.step()
	assert_eq(a.current_rule, 3)
	assert_eq(int(a.rule_fail_reasons[0]), SimTypes.ReasonCode.COND_HP_NOT_BELOW)
	assert_eq(int(a.rule_fail_reasons[1]), SimTypes.ReasonCode.COND_NO_ENEMY_IN_RANGE)
	assert_eq(int(a.rule_fail_reasons[2]), SimTypes.ReasonCode.COND_DISTANCE_FAIL)


func test_matched_but_unexecutable_waits_not_fallthrough() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [
		{ "conditions": [{ "type": "enemy_visible" }], "target": { "selector": "nearest" }, "action": { "type": "attack" } },
		SimFactory.r_chase_attack_visible(),
	])
	SimFactory.add(w, "raider", ENEMY, Vector2i(8, 2))     # 视野内、射程外
	var start: Vector2 = a.pos
	SimFactory.run_steps(w, 5)
	assert_eq(a.current_rule, 0, "不回退到第二条")
	assert_eq(a.reason, SimTypes.ReasonCode.TARGET_OUT_OF_RANGE)
	assert_eq(a.pos, start, "原地等待")


func test_empty_conditions_is_always() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [SimFactory.r_idle()])
	w.step()
	assert_eq(a.current_rule, 0)
	assert_eq(a.reason, SimTypes.ReasonCode.OK)


func test_condition_mode_any() -> void:
	var conds: Array = [{ "type": "self_hp_below", "ratio": 0.1 }, { "type": "enemy_visible" }]
	var w: SimWorld = _world()
	var any_unit: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [
		{ "condition_mode": "any", "conditions": conds, "target": { "selector": "nearest" }, "action": { "type": "idle" } },
	])
	var all_unit: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 3), [
		{ "condition_mode": "all", "conditions": conds, "target": { "selector": "nearest" }, "action": { "type": "idle" } },
	])
	SimFactory.add(w, "raider", ENEMY, Vector2i(8, 2))
	w.step()
	assert_eq(any_unit.current_rule, 0, "any：任一成立即成立")
	assert_eq(all_unit.current_rule, -1, "all：需全部成立")


func test_enemy_in_range_restricts_candidates_to_range() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [SimFactory.r_attack_in_range("farthest")])
	var near: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(5, 2))   # 距离 3，射程内
	SimFactory.add(w, "raider", ENEMY, Vector2i(9, 2))                       # 距离 7，可见但射程外（按"最远"本应选它）
	w.step()
	assert_eq(a.current_rule, 0)
	assert_eq(a.current_target, near.id, "选敌只在射程内者中进行")
