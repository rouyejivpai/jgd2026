extends GutTest
## 05 §2 test_combat：普通攻击（01 §6.7、策划 5.1）

const ALLY: int = SimTypes.Faction.ALLY
const ENEMY: int = SimTypes.Faction.ENEMY


func _world() -> SimWorld:
	return SimFactory.make_empty_world(12, 12)


func _attacks_by(w: SimWorld, source: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in SimFactory.events_of(w, SimTypes.EventType.ATTACK_FIRED):
		if int(e["source"]) == source:
			out.append(e)
	return out


func test_attack_resolves_without_projectile() -> void:
	var w: SimWorld = _world()
	SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [SimFactory.r_attack_in_range()])
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(4, 2))
	w.step()
	assert_eq(e.hp, e.max_hp - 12.0, "同一步内结算，生命立即减少")


func test_cooldown_equals_inverse_aps() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [SimFactory.r_attack_in_range()])
	a.attack_speed = 0.5
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(4, 2))
	e.hp = 10000.0
	e.max_hp = 10000.0
	var fired_steps: Array[int] = []
	for i: int in 200:
		var before: int = _attacks_by(w, a.id).size()
		w.step()
		if _attacks_by(w, a.id).size() > before:
			fired_steps.append(w.clock.steps)
	assert_gt(fired_steps.size(), 2)
	for i: int in range(1, fired_steps.size()):
		assert_eq(fired_steps[i] - fired_steps[i - 1], 60, "攻速 0.5 → 间隔 2.0 秒 = 60 步")


func test_cooldown_not_reset_on_rule_switch() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [
		{ "conditions": [{ "type": "self_hp_below", "ratio": 0.5 }], "target": { "selector": "nearest" }, "action": { "type": "attack" } },
		SimFactory.r_attack_in_range(),
	])
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(4, 2))
	e.hp = 10000.0
	e.max_hp = 10000.0
	w.step()
	assert_eq(a.current_rule, 1)
	assert_eq(_attacks_by(w, a.id).size(), 1)
	a.hp = 10.0
	w.step()
	assert_eq(a.current_rule, 0, "已切换到第一条")
	assert_almost_eq(a.cooldown, 1.0 - SimTypes.SIM_DT, 1e-6, "冷却未被重置")
	assert_eq(_attacks_by(w, a.id).size(), 1, "冷却中不攻击")


func test_zero_aps_never_attacks() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [SimFactory.r_attack_in_range()])
	a.attack_speed = 0.0
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(4, 2))
	SimFactory.run_steps(w, 90)
	assert_eq(_attacks_by(w, a.id).size(), 0)
	assert_eq(e.hp, e.max_hp)


func test_simultaneous_kill_both_die() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [SimFactory.r_attack_in_range()])
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(3, 2), [SimFactory.r_attack_in_range()])
	a.hp = 5.0
	e.hp = 5.0
	w.step()
	assert_false(a.alive, "同步结算允许互杀")
	assert_false(e.alive)
	assert_eq(SimFactory.events_of(w, SimTypes.EventType.UNIT_DIED).size(), 2)


func test_dead_unit_removed_from_candidates() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(2, 2), [SimFactory.r_attack_in_range()])
	var e1: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(3, 2), [SimFactory.r_attack_in_range()])
	var e2: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(5, 2))
	e1.hp = 5.0
	w.step()
	assert_false(e1.alive)
	var e1_attacks: int = _attacks_by(w, e1.id).size()
	SimFactory.run_steps(w, 60)
	assert_eq(a.current_target, e2.id, "死亡单位不再被选中")
	assert_eq(_attacks_by(w, e1.id).size(), e1_attacks, "死亡单位不再攻击")
	for ev: Dictionary in _attacks_by(w, a.id):
		if float(ev["time"]) > SimTypes.SIM_DT + SimTypes.TIME_EPS:
			assert_ne(int(ev["target"]), e1.id)


func test_damage_is_flat_attack_value() -> void:
	var w: SimWorld = _world()
	var a: SimUnit = SimFactory.add(w, "lancer", ALLY, Vector2i(2, 2), [SimFactory.r_attack_in_range()])
	var e: SimUnit = SimFactory.add(w, "brute", ENEMY, Vector2i(6, 2))
	SimFactory.run_steps(w, 61)   # 攻速 0.5：第 1 步与第 61 步各一次
	assert_eq(_attacks_by(w, a.id).size(), 2)
	assert_eq(e.hp, e.max_hp - 2.0 * a.attack, "伤害 = attack，无防御/闪避")
