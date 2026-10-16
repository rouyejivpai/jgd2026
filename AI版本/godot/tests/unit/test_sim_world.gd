extends GutTest
## 05 §2 test_sim_world：步进顺序、快照、确定性、重置、事件（01 §6.2、§6.11、§7）

const ALLY: int = SimTypes.Faction.ALLY
const ENEMY: int = SimTypes.Faction.ENEMY


func _index_of(events: Array[Dictionary], type: int) -> int:
	for i: int in events.size():
		if int(events[i]["type"]) == type:
			return i
	return -1


func test_step_order_blast_before_decision() -> void:
	var w: SimWorld = SimFactory.make_empty_world(12, 12)
	var source: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(10, 10))
	var a: SimUnit = SimFactory.add(w, "bulwark", ALLY, Vector2i(5, 5), [SimFactory.r_idle()])
	var b: SimBlast = BlastSystem.place(w, source, a.pos, DataRegistry.get_trait("delayed_blast_basic"), a.id)
	b.remaining = SimTypes.SIM_DT   # 下一步到期
	w.take_events()
	w.step()
	var det: int = _index_of(w.events, SimTypes.EventType.BLAST_DETONATED)
	var rule: int = _index_of(w.events, SimTypes.EventType.RULE_CHANGED)
	assert_gte(det, 0)
	assert_gte(rule, 0)
	assert_lt(det, rule, "到期爆炸在决策前结算")
	assert_eq(a.hp, a.max_hp - 30.0)


func test_decisions_use_snapshot() -> void:
	var w: SimWorld = SimFactory.make_empty_world(12, 12)
	# A 追击 B；B 只在射程内攻击。开战时 A 在 B 射程（2）外 0.1 格，本步移动后进入射程。
	var a: SimUnit = SimFactory.add(w, "swift", ALLY, Vector2(3.4, 5.5), [
		{ "conditions": [{ "type": "enemy_visible" }], "target": { "selector": "nearest" }, "action": { "type": "chase" } },
	])
	var b: SimUnit = SimFactory.add(w, "brute", ENEMY, Vector2(5.5, 5.5), [SimFactory.r_attack_in_range(), SimFactory.r_idle()])
	w.step()
	assert_lt(a.pos.distance_to(b.pos), b.attack_range, "A 本步已移动进 B 射程")
	assert_eq(b.current_rule, 1, "B 的决策读取的是本步开始时的位置")
	assert_eq(SimFactory.events_of(w, SimTypes.EventType.ATTACK_FIRED).size(), 0)
	w.step()
	assert_eq(b.current_rule, 0)


func test_state_hash_deterministic() -> void:
	var w1: SimWorld = SimFactory.make_recommended_world("level_07")
	var w2: SimWorld = SimFactory.make_recommended_world("level_07")
	SimFactory.run_steps(w1, 600)
	SimFactory.run_steps(w2, 600)
	assert_eq(w1.state_hash(), w2.state_hash())
	assert_eq(w1.result, w2.result)


func test_speed_2x_equals_two_steps() -> void:
	var w1: SimWorld = SimFactory.make_recommended_world("level_07")
	var w2: SimWorld = SimFactory.make_recommended_world("level_07")
	for tick: int in 300:      # 2 倍速：每 tick 两步
		w1.step()
		w1.step()
	for tick: int in 600:      # 1 倍速：每 tick 一步
		w2.step()
	assert_eq(w1.state_hash(), w2.state_hash())
	assert_eq(w1.result, w2.result)


func test_reset_rebuilds_from_level() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_07")
	var config: Dictionary = SimFactory.make_config(level, level.recommended_deploy)
	var rules_before: Dictionary = {}
	for sid: String in config.keys():
		var rules: Array[RuleDef] = []
		rules.assign((config[sid] as Dictionary)["rules"] as Array)
		rules_before[sid] = RuleDef.to_array(rules)
	var w1: SimWorld = SimWorld.from_level(level, DataRegistry.get_units(), DataRegistry.get_traits(), config)
	var initial_hash: int = w1.state_hash()
	SimFactory.run_steps(w1, 300)
	assert_ne(w1.state_hash(), initial_hash, "战斗已改变状态")
	var w2: SimWorld = SimWorld.from_level(level, DataRegistry.get_units(), DataRegistry.get_traits(), config)
	assert_eq(w2.state_hash(), initial_hash, "重置后生命/位置恢复")
	assert_eq(w2.clock.time, 0.0, "计时恢复")
	assert_eq(w2.blasts.size(), 0)
	for u: SimUnit in w2.units:
		assert_true(u.alive)
		assert_eq(u.hp, u.max_hp)
	for sid: String in config.keys():
		var rules: Array[RuleDef] = []
		rules.assign((config[sid] as Dictionary)["rules"] as Array)
		assert_eq_deep(RuleDef.to_array(rules), rules_before[sid] as Array)


func test_events_emitted() -> void:
	var w: SimWorld = SimFactory.make_recommended_world("level_01")
	var result: int = SimFactory.run_until_end(w, 60.0)
	assert_eq(result, SimTypes.BattleResult.WIN)
	for t: int in [SimTypes.EventType.ATTACK_FIRED, SimTypes.EventType.DAMAGE_APPLIED, SimTypes.EventType.UNIT_DIED,
			SimTypes.EventType.RULE_CHANGED, SimTypes.EventType.TARGET_CHANGED, SimTypes.EventType.BATTLE_ENDED]:
		var list: Array[Dictionary] = SimFactory.events_of(w, t)
		assert_gt(list.size(), 0, "事件 %s 存在" % SimTypes.EventType.keys()[t])
		for e: Dictionary in list:
			assert_true(e.has("time"), "事件含 time")
