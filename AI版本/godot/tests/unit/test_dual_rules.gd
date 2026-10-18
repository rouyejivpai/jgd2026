extends GutTest
## 第五阶段（2026-10-17 会议）：攻击 / 移动两组指令独立求值、同时执行；组内优先级高的覆盖低的；
## 停火、追击（可选目标、不攻击）；攻击目标 最近 / 最远 / HP最高 / 造成伤害最高 / 第一个进入射程；旧单列表 → 双组折算。

const ATK_ALWAYS: Dictionary = { "conditions": [], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "attack" } }
const FOLLOW: Dictionary = { "conditions": [], "action": { "type": "follow_beacons", "mode": "once", "from": "1" } }
const HOLD_FIRE: Dictionary = { "conditions": [], "action": { "type": "hold_fire" } }
const CHASE: Dictionary = { "conditions": [{ "type": "enemy_visible" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "chase" } }


static func atk(selector: String) -> Dictionary:
	return { "conditions": [], "target": { "selector": selector, "filter": "any" }, "action": { "type": "attack" } }


func _ally(w: SimWorld, cell: Vector2i, rules: Array, def_id: String = "striker") -> SimUnit:
	var u: SimUnit = SimFactory.add(w, def_id, SimTypes.Faction.ALLY, cell, rules)
	u.dual_rules = true
	return u


func _dummy(w: SimWorld, cell: Vector2i, def_id: String = "dummy") -> SimUnit:
	return SimFactory.add(w, def_id, SimTypes.Faction.ENEMY, cell, [])


func test_group_of_actions() -> void:
	assert_eq(SimTypes.action_group(SimTypes.ActionType.ATTACK), SimTypes.RuleGroup.ATTACK)
	assert_eq(SimTypes.action_group(SimTypes.ActionType.HOLD_FIRE), SimTypes.RuleGroup.ATTACK)
	for t: int in [SimTypes.ActionType.FOLLOW_BEACONS, SimTypes.ActionType.CHASE, SimTypes.ActionType.RETREAT, SimTypes.ActionType.IDLE, SimTypes.ActionType.WAIT, SimTypes.ActionType.FOLLOW_ROUTE]:
		assert_eq(SimTypes.action_group(t), SimTypes.RuleGroup.MOVE, "移动组：%s" % SimTypes.action_to_string(t))
	assert_true(SimTypes.action_in_group(SimTypes.ActionType.CHASE_ATTACK, SimTypes.RuleGroup.MOVE), "旧数据追击并攻击两组都算")
	assert_true(SimTypes.action_in_group(SimTypes.ActionType.CHASE_ATTACK, SimTypes.RuleGroup.ATTACK))


## 会议："移动中的单位可以同时执行符合条件的攻击策略"
func test_moves_and_attacks_at_the_same_time() -> void:
	var w: SimWorld = SimFactory.make_empty_world(14, 6)
	var u: SimUnit = _ally(w, Vector2i(1, 2), [ATK_ALWAYS, FOLLOW])
	u.beacons.assign([{ "id": "1", "cell": Vector2i(12, 2) }])
	var d: SimUnit = _dummy(w, Vector2i(4, 4))
	var x0: float = u.pos.x
	SimFactory.run_steps(w, 30)
	assert_gt(u.pos.x, x0 + 1.0, "沿信标前进")
	assert_lt(d.hp, d.max_hp, "前进途中开火")
	assert_eq(u.current_action, SimTypes.ActionType.FOLLOW_BEACONS, "移动组：沿信标")
	assert_eq(u.current_attack_rule, 0, "攻击组：第 1 条攻击")
	assert_eq(u.display_target(), d.id, "目标连线显示攻击目标")


## 旧单列表口径：第一条（攻击）成立就独占，单位停下打——对照
func test_legacy_unit_stops_to_attack() -> void:
	var w: SimWorld = SimFactory.make_empty_world(14, 6)
	var u: SimUnit = SimFactory.add(w, "striker", SimTypes.Faction.ALLY, Vector2i(1, 2), [ATK_ALWAYS, FOLLOW])
	u.beacons.assign([{ "id": "1", "cell": Vector2i(12, 2) }])
	_dummy(w, Vector2i(4, 4))
	var x0: float = u.pos.x
	SimFactory.run_steps(w, 30)
	assert_almost_eq(u.pos.x, x0, 0.001, "旧口径：攻击指令成立时不移动")


## 组内优先级：上面的覆盖下面的（移动覆盖移动、攻击覆盖攻击）
func test_priority_within_each_group() -> void:
	var w: SimWorld = SimFactory.make_empty_world(14, 6)
	var stop_when_in_range: Dictionary = { "conditions": [{ "type": "enemy_in_range" }], "target": { "selector": "nearest", "filter": "any" }, "action": { "type": "idle" } }
	var u: SimUnit = _ally(w, Vector2i(1, 2), [stop_when_in_range, FOLLOW, HOLD_FIRE, ATK_ALWAYS])
	u.beacons.assign([{ "id": "1", "cell": Vector2i(12, 2) }])
	var d: SimUnit = _dummy(w, Vector2i(4, 2))
	SimFactory.run_steps(w, 60)
	assert_eq(u.current_action, SimTypes.ActionType.IDLE, "移动组第 1 条（射程内停止）覆盖沿信标")
	assert_eq(u.current_attack_rule, 2, "攻击组第 1 条（停火）覆盖攻击")
	assert_eq(u.attack_reason, SimTypes.ReasonCode.HOLDING_FIRE)
	assert_eq(d.hp, d.max_hp, "停火：不出手")
	assert_lt(u.pos.x, 4.5 - 0.5, "进入射程后停下")


## 追击本身不攻击；配合攻击组才开火
func test_chase_does_not_attack_by_itself() -> void:
	var w: SimWorld = SimFactory.make_empty_world(14, 6)
	var u: SimUnit = _ally(w, Vector2i(1, 2), [CHASE])
	var d: SimUnit = _dummy(w, Vector2i(9, 2))
	SimFactory.run_steps(w, 90)
	assert_lte(u.pos.distance_to(d.pos), u.attack_range + SimTypes.DIST_EPS + 0.2, "追到射程内")
	assert_eq(d.hp, d.max_hp, "只有追击：不开火")
	assert_eq(u.current_attack_rule, -1)
	assert_eq(u.attack_reason, SimTypes.ReasonCode.NO_RULE_MATCHED, "攻击组没有成立的指令")
	var w2: SimWorld = SimFactory.make_empty_world(14, 6)
	_ally(w2, Vector2i(1, 2), [CHASE, ATK_ALWAYS])
	var d2: SimUnit = _dummy(w2, Vector2i(9, 2))
	SimFactory.run_steps(w2, 90)
	assert_lt(d2.hp, d2.max_hp, "追击 + 攻击：追上就打")


## 攻击目标：在射程内按目标选择挑
func test_attack_selectors_pick_within_range() -> void:
	# 射程 4：近 (3,2) 距 2、远 (5,2) 距 4 都在射程内；(9,2) 距 8 在视野内但射程外
	var cells: Array[Vector2i] = [Vector2i(3, 2), Vector2i(5, 2), Vector2i(9, 2)]
	var expect: Dictionary = { "nearest": 0, "farthest": 1 }
	for sel: String in expect.keys():
		var w: SimWorld = SimFactory.make_empty_world(14, 6)
		var u: SimUnit = _ally(w, Vector2i(1, 2), [atk(sel)])
		var ds: Array[SimUnit] = []
		for c: Vector2i in cells:
			ds.append(_dummy(w, c))
		w.step()
		assert_eq(u.current_attack_target, ds[int(expect[sel])].id, "%s：射程内挑选（最远 = 射程内最远，不是视野里最远）" % sel)


func test_highest_hp_selector() -> void:
	var w: SimWorld = SimFactory.make_empty_world(14, 6)
	var u: SimUnit = _ally(w, Vector2i(1, 2), [atk("highest_hp")])
	var a: SimUnit = _dummy(w, Vector2i(3, 2))
	var b: SimUnit = _dummy(w, Vector2i(4, 3))
	a.hp = 50.0
	b.hp = 120.0
	w.step()
	assert_eq(u.current_attack_target, b.id, "当前生命最高")


func test_most_damage_selector_prefers_damage_dealer_then_nearest() -> void:
	var w: SimWorld = SimFactory.make_empty_world(14, 6)
	var u: SimUnit = _ally(w, Vector2i(1, 2), [atk("most_damage")])
	var near: SimUnit = _dummy(w, Vector2i(2, 2))
	var far: SimUnit = _dummy(w, Vector2i(4, 2))
	w.step()
	assert_eq(u.current_attack_target, near.id, "都没造成伤害：取最近")
	far.damage_dealt = 15.0
	w.step()
	assert_eq(u.current_attack_target, far.id, "累计造成伤害最高者优先")


func test_damage_dealt_accumulates() -> void:
	var w: SimWorld = SimFactory.make_empty_world(10, 6)
	var u: SimUnit = _ally(w, Vector2i(1, 2), [ATK_ALWAYS])
	_dummy(w, Vector2i(3, 2))
	SimFactory.run_steps(w, 3)
	assert_almost_eq(u.damage_dealt, u.attack, 0.001, "出手一次累计一次伤害")


func test_first_in_range_selector_keeps_earliest() -> void:
	var w: SimWorld = SimFactory.make_empty_world(16, 6)
	var u: SimUnit = _ally(w, Vector2i(1, 2), [atk("first_in_range")])
	var early: SimUnit = _dummy(w, Vector2i(5, 2))     # 距 4：开战即在射程内
	var late: SimUnit = _dummy(w, Vector2i(9, 2))      # 射程外
	w.step()
	assert_eq(u.current_attack_target, early.id)
	late.pos = SimTypes.cell_center(Vector2i(2, 2))    # 后来者贴到更近处
	w.step()
	w.step()
	assert_true(u.range_order.has(late.id), "后来者也已进入射程")
	assert_eq(u.current_attack_target, early.id, "仍打最先进入射程的目标（最近的是后来者）")
	early.pos = SimTypes.cell_center(Vector2i(14, 2))  # 先来者离开射程
	w.step()
	w.step()
	assert_false(u.range_order.has(early.id), "离开射程即移除")
	assert_eq(u.current_attack_target, late.id, "改打现存最早进入射程者")


## 旧单列表 → 双组：攻击加停止镜像、移动加停火镜像、追击并攻击拆开、覆盖折算成顺序
func test_migrate_legacy_expands_rules() -> void:
	var legacy: Array[RuleDef] = SimFactory.to_rules([
		SimFactory.r_attack_in_range(), SimFactory.r_chase_attack_visible(), SimFactory.r_idle(),
		{ "conditions": [{ "type": "enemy_visible" }], "action": { "type": "retreat" }, "override": true },
	])
	var out: Array[RuleDef] = RuleDef.migrate_legacy(legacy)
	assert_eq(out.map(func(r: RuleDef) -> String: return SimTypes.action_to_string(r.action.type)),
		["retreat", "hold_fire", "attack", "idle", "chase", "attack", "idle", "hold_fire"])
	for r: RuleDef in out:
		assert_false(r.override)
	assert_eq(out[3].conditions[0].type, SimTypes.ConditionType.ENEMY_IN_RANGE, "镜像保留原条件")
	assert_not_null(out[3].target, "镜像保留原目标（条件的候选口径）")


## 折算后的双组结果与旧口径逐步一致（推荐解覆盖的面更全，见 run_playtests --check）
func test_migrated_dual_matches_legacy_step_by_step() -> void:
	var rules: Array = [SimFactory.r_attack_in_range(), SimFactory.r_chase_attack_visible(), SimFactory.r_idle()]
	var worlds: Array[SimWorld] = []
	for dual: bool in [false, true]:
		var w: SimWorld = SimFactory.make_empty_world(14, 8)
		var rs: Array[RuleDef] = SimFactory.to_rules(rules)
		var u: SimUnit = SimFactory.add(w, "striker", SimTypes.Faction.ALLY, Vector2i(1, 3), RuleDef.migrate_legacy(rs) if dual else rs)
		u.dual_rules = dual
		SimFactory.add(w, "raider", SimTypes.Faction.ENEMY, Vector2i(11, 3), [SimFactory.r_attack_in_range(), SimFactory.r_chase_attack_visible()])
		SimFactory.add(w, "raider", SimTypes.Faction.ENEMY, Vector2i(12, 6), [SimFactory.r_attack_in_range(), SimFactory.r_chase_attack_visible()])
		worlds.append(w)
	for i: int in 300:
		worlds[0].step()
		worlds[1].step()
		if worlds[0].state_hash() != worlds[1].state_hash():
			fail_test("第 %d 步出现差异" % i)
			return
	pass_test("300 步逐步一致")


func test_no_target_reason_in_attack_group() -> void:
	var w: SimWorld = SimFactory.make_empty_world(10, 6)
	var u: SimUnit = _ally(w, Vector2i(1, 2), [ATK_ALWAYS])
	w.step()
	assert_eq(u.current_attack_rule, 0, "始终 → 攻击：成立")
	assert_eq(u.attack_reason, SimTypes.ReasonCode.NO_TARGET_IN_RANGE, "没有目标：原地等待原因")
