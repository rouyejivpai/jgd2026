extends GutTest
## 第四阶段「覆盖」指令与沿信标恢复（用户 2026-10-08 修改意见 3）：
## 1 始终 → 沿我的信标；2 有敌人 → 撤离（覆盖）= 先沿路线走，发现敌人后撤离，敌人消失后回到离路线最近的一点继续。

const A := Vector2i(2, 2)
const B := Vector2i(10, 2)


static func r_follow(mode: String = "once") -> Dictionary:
	return { "conditions": [], "action": { "type": "follow_beacons", "mode": mode, "from": "1" } }


static func r_retreat(override: bool) -> Dictionary:
	return { "conditions": [{ "type": "enemy_visible" }], "action": { "type": "retreat" }, "override": override }


func _world(rules: Array, enemy_cell: Vector2i = Vector2i(-1, -1)) -> Array:
	var w: SimWorld = SimFactory.make_empty_world(14, 8)
	var u: SimUnit = SimFactory.add(w, "striker", SimTypes.Faction.ALLY, Vector2i(1, 2), rules)
	u.beacons.assign([{ "id": "1", "cell": A }, { "id": "2", "cell": B }])
	if enemy_cell.x >= 0:
		SimFactory.add(w, "hound", SimTypes.Faction.ENEMY, enemy_cell, [])
	return [w, u]


func test_eval_order_without_override_is_list_order() -> void:
	var rules: Array[RuleDef] = SimFactory.to_rules([r_follow(), r_retreat(false), r_follow()])
	assert_eq(RuleEvaluator.eval_order(rules), [0, 1, 2] as Array[int])


func test_eval_order_puts_override_rules_first_keeping_their_order() -> void:
	var rules: Array[RuleDef] = SimFactory.to_rules([r_follow(), r_retreat(true), r_follow(), r_retreat(true)])
	assert_eq(RuleEvaluator.eval_order(rules), [1, 3, 0, 2] as Array[int])


func test_override_round_trips_and_is_omitted_when_false() -> void:
	var on: RuleDef = SimFactory.rule(r_retreat(true))
	var off: RuleDef = SimFactory.rule(r_retreat(false))
	assert_true(on.override)
	assert_true(on.clone().override, "clone 保留覆盖")
	assert_false(off.to_dict().has("override"), "未勾选时不写字段（旧存档 / 关卡数据不变）")


func test_without_override_first_rule_blocks_retreat() -> void:
	var pair: Array = _world([r_follow(), r_retreat(false)], Vector2i(13, 7))
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	for i: int in int(8.0 / SimTypes.SIM_DT):
		w.step()
		assert_ne(u.current_action, SimTypes.ActionType.RETREAT, "无覆盖：始终成立的第一条一直生效")


func test_override_retreat_takes_over_when_enemy_seen() -> void:
	var pair: Array = _world([r_follow(), r_retreat(true)], Vector2i(13, 7))
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	var followed_first: bool = false
	var retreated: bool = false
	for i: int in int(8.0 / SimTypes.SIM_DT):
		w.step()
		if not retreated and u.current_action == SimTypes.ActionType.FOLLOW_BEACONS:
			followed_first = true
		if u.current_action == SimTypes.ActionType.RETREAT:
			retreated = true
			assert_eq(u.current_rule, 1, "生效的是覆盖的第 2 条")
	assert_true(followed_first, "看到敌人之前沿信标走")
	assert_true(retreated, "看到敌人后撤离接管")


func test_resume_goes_to_nearest_point_on_path_then_continues() -> void:
	var pair: Array = _world([r_follow()])
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	# 模拟"撤离把单位带离路线"：已在前往第 2 个信标途中、上一步是撤离、人在路线 (5,2) 正上方 3 格
	u.beacon_index = 1
	u.pos = SimTypes.cell_center(Vector2i(5, 5))
	u.current_action = SimTypes.ActionType.RETREAT
	w.step()
	assert_eq(u.beacon_rejoin, Vector2i(5, 2), "恢复时先回到离路线最近的一点")
	assert_eq(u.beacon_index, 1, "之后继续前往该段终点")
	var reached_rejoin: bool = false
	for i: int in int(8.0 / SimTypes.SIM_DT):
		w.step()
		if u.pos.distance_to(SimTypes.cell_center(Vector2i(5, 2))) < SimTypes.ARRIVE_EPS:
			reached_rejoin = true
	assert_true(reached_rejoin, "经过回归点")
	assert_almost_eq(u.pos.distance_to(SimTypes.cell_center(B)), 0.0, 0.001, "最终到达第 2 个信标")
	assert_eq(u.beacon_rejoin, Vector2i(-1, -1))


func test_uninterrupted_follow_never_sets_rejoin() -> void:
	var pair: Array = _world([r_follow("loop")])
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	for i: int in int(10.0 / SimTypes.SIM_DT):
		w.step()
		assert_eq(u.beacon_rejoin, Vector2i(-1, -1), "未被打断时行为与原来一致")


func test_loop_rejoin_considers_closing_segment() -> void:
	var w: SimWorld = SimFactory.make_empty_world(14, 8)
	var u: SimUnit = SimFactory.add(w, "striker", SimTypes.Faction.ALLY, Vector2i(1, 2), [r_follow("loop")])
	u.beacons.assign([{ "id": "1", "cell": Vector2i(2, 2) }, { "id": "2", "cell": Vector2i(10, 2) }, { "id": "3", "cell": Vector2i(10, 6) }])
	u.pos = SimTypes.cell_center(Vector2i(6, 5))        # 离闭合段 3→1（(10,6)→(2,2)）最近
	Movement.plan_rejoin(u, SimTypes.BeaconMode.LOOP, 0, 2, w)
	assert_eq(u.beacon_index, 0, "闭合段的终点是第 1 个信标")
	assert_ne(u.beacon_rejoin, Vector2i(-1, -1))
