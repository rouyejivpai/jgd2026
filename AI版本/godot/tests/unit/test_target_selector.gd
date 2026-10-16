extends GutTest
## 05 §2 test_target_selector：候选、排序、决胜、first_seen 锁定（01 §6.5）

const ALLY: int = SimTypes.Faction.ALLY
const ENEMY: int = SimTypes.Faction.ENEMY


func _world() -> SimWorld:
	return SimFactory.make_empty_world(16, 16)


func _lock_rules() -> Array:
	return [{ "conditions": [{ "type": "enemy_visible" }], "target": { "selector": "first_seen", "filter": "any" }, "action": { "type": "idle" } }]


func _resolve(w: SimWorld, u: SimUnit, selector: String, filter: String = "any") -> Array[int]:
	var t: TargetDef = TargetDef.from_dict({ "selector": selector, "filter": filter }, "test")
	return TargetSelector.resolve(u, t, w.make_snapshot())


func test_nearest_farthest_lowest_hp() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(1, 1))
	var e1: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(3, 1))   # 距离 2
	var e2: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(5, 1))   # 距离 4
	e2.hp = 30.0
	w.begin()
	assert_eq(str(_resolve(w, o, "nearest")), str([e1.id, e2.id]))
	assert_eq(str(_resolve(w, o, "farthest")), str([e2.id, e1.id]))
	assert_eq(str(_resolve(w, o, "lowest_hp")), str([e2.id, e1.id]))


func test_tie_break_seen_order_then_id() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(8, 8), [SimFactory.r_idle()])
	var e1: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(15, 15))  # 开战时不可见
	var e2: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(5, 8))    # 距离 3，先进入视野
	w.step()
	e1.pos = SimTypes.cell_center(Vector2i(11, 8))                          # 同距 3，后进入视野
	w.step()
	assert_true(int(o.seen_order[e2.id]) < int(o.seen_order[e1.id]))
	assert_eq(str(_resolve(w, o, "nearest")), str([e2.id, e1.id]), "同距：先按进入视野序号")
	o.seen_order.clear()
	assert_eq(str(_resolve(w, o, "nearest")), str([e1.id, e2.id]), "序号相同：再按 id")


func test_initial_visible_assigned_by_id_order() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(5, 5))
	var ids: Array[int] = [103, 101, 102]
	for i: int in ids.size():
		var u: SimUnit = SimFactory.make_unit("raider", ENEMY, Vector2i(6 + i, 5))
		u.id = ids[i]
		w.add_unit(u)
	w.begin()
	assert_true(int(o.seen_order[101]) < int(o.seen_order[102]))
	assert_true(int(o.seen_order[102]) < int(o.seen_order[103]))


func test_filter_unit_structure_any() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(1, 1))
	var unit_e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(3, 1))
	var struct_e: SimUnit = SimFactory.add(w, "echo_pillar", ENEMY, Vector2i(4, 1))
	w.begin()
	assert_eq(str(_resolve(w, o, "nearest", "unit")), str([unit_e.id]))
	assert_eq(str(_resolve(w, o, "nearest", "structure")), str([struct_e.id]))
	assert_eq(str(_resolve(w, o, "nearest", "any")), str([unit_e.id, struct_e.id]))


func test_first_seen_locks_and_does_not_switch() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(5, 5), _lock_rules())
	var a: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(10, 5))   # 距离 5，可见
	var b: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(15, 15))  # 不可见
	w.step()
	assert_eq(o.lock_target, a.id)
	b.pos = SimTypes.cell_center(Vector2i(6, 5))                           # B 更近
	SimFactory.run_steps(w, 3)
	assert_eq(o.current_target, a.id, "锁定 A 后 B 更近仍返回 A")
	assert_eq(o.lock_target, a.id)


func test_first_seen_lock_cleared_on_death() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(5, 5), _lock_rules())
	var a: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(10, 5))
	var b: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(6, 5))
	w.step()
	assert_eq(o.lock_target, a.id, "开战同时可见：按 id 升序，A 序号更早")
	a.hp = 0.0
	a.alive = false
	w.step()
	assert_eq(o.lock_target, b.id, "A 死亡 → 下一次决策锁定 B")
	assert_eq(o.current_target, b.id)


func test_first_seen_lock_cleared_on_leaving_vision() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(5, 5), _lock_rules())
	var a: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(8, 5))
	var b: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(15, 15))
	w.step()
	assert_eq(o.lock_target, a.id)
	b.pos = SimTypes.cell_center(Vector2i(5, 9))     # B 进入视野（序号晚于 A）
	w.step()
	assert_eq(o.lock_target, a.id)
	a.pos = SimTypes.cell_center(Vector2i(15, 5))    # A 离开视野（距离 10 > 8）
	w.step()
	assert_ne(o.lock_target, a.id, "A 离开视野 → 锁定清除")
	assert_false(o.seen_order.has(a.id))
	a.pos = SimTypes.cell_center(Vector2i(8, 5))     # A 回来，B 仍在
	SimFactory.run_steps(w, 2)
	assert_eq(o.lock_target, b.id, "A 回来而 B 仍在 → 锁定 B（B 序号更早）")


func test_first_seen_with_in_range_condition_uses_locked_target() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(5, 5), [
		{ "conditions": [{ "type": "enemy_in_range" }], "target": { "selector": "first_seen" }, "action": { "type": "attack" } },
		{ "conditions": [{ "type": "enemy_visible" }], "target": { "selector": "first_seen" }, "action": { "type": "idle" } },
	])
	var a: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(11, 5))   # 距离 6：可见、射程 4 外
	var b: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(15, 15))
	w.step()
	assert_eq(o.lock_target, a.id)
	b.pos = SimTypes.cell_center(Vector2i(6, 5))                           # B 进入射程
	w.step()
	assert_eq(int(o.rule_fail_reasons[0]), SimTypes.ReasonCode.COND_NO_ENEMY_IN_RANGE, "不改打射程内的 B")
	assert_eq(o.current_rule, 1)
	assert_eq(o.current_target, a.id)
	assert_eq(SimFactory.events_of(w, SimTypes.EventType.ATTACK_FIRED).size(), 0)


func test_seen_order_removed_when_not_visible() -> void:
	var w: SimWorld = _world()
	var o: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(5, 5), [SimFactory.r_idle()])
	var a: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(8, 5))
	w.step()
	var first: int = int(o.seen_order[a.id])
	a.pos = SimTypes.cell_center(Vector2i(15, 15))
	w.step()
	assert_false(o.seen_order.has(a.id), "离开视野后删除")
	a.pos = SimTypes.cell_center(Vector2i(8, 5))
	w.step()
	assert_true(o.seen_order.has(a.id))
	assert_gt(int(o.seen_order[a.id]), first, "重新进入得到新序号")
