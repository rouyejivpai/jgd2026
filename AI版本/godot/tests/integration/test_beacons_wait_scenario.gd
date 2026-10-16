extends GutTest
## 07 §3.7 验收小场景（10 §6.3 起信标编号为数字：A/B/C 位置的信标编号 1/2/3）：一名单位、三枚信标——走到 A、等 2 秒、走到 B、再到 C 停下；loop / pingpong 顺序；
## 删除 B 后引用 B 的条件在校验中被指出（不静默改指）；更高优先级规则抢占取消等待；
## 第三关用信标替代预设路线完成绕后，1×/2× 一致。

const A := Vector2i(4, 2)
const B := Vector2i(8, 2)
const C := Vector2i(8, 4)
const WAIT_SECONDS: float = 2.0
const ALL_UNLOCKED: Dictionary = {
	"conditions": ["always", "self_hp_below", "enemy_visible", "enemy_in_range", "target_distance", "retreat_possible"],
	"selectors": ["nearest", "farthest", "lowest_hp", "first_seen"],
	"actions": ["idle", "attack", "chase_attack", "chase", "retreat", "follow_route"],
	"forms": ["striker", "bulwark", "swift", "lancer"],
}


static func r_at_wait(beacon: String, seconds: float) -> Dictionary:
	return { "conditions": [{ "type": "at_beacon", "beacon": beacon }], "action": { "type": "wait", "seconds": seconds } }


static func r_follow(mode: String, from: String = "1") -> Dictionary:
	return { "conditions": [], "action": { "type": "follow_beacons", "mode": mode, "from": from } }


func _beacons(cells: Array[Vector2i], ids: String = "123") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in cells.size():
		out.append({ "id": ids[i], "cell": cells[i] })
	return out


func _world(rules: Array, beacon_cells: Array[Vector2i] = [A, B, C]) -> Array:
	var w: SimWorld = SimFactory.make_empty_world(12, 6)
	var u: SimUnit = SimFactory.add(w, "striker", SimTypes.Faction.ALLY, Vector2i(1, 2), rules)
	u.beacons = _beacons(beacon_cells)
	return [w, u]


func test_walk_wait_walk_stop() -> void:
	var pair: Array = _world([r_at_wait("1", WAIT_SECONDS), r_follow("once")])
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	var wait_start: float = -1.0
	var wait_end: float = -1.0
	var wait_pos: Vector2 = Vector2.ZERO
	var reached_b: float = -1.0
	var max_drift: float = 0.0
	for i: int in int(20.0 / SimTypes.SIM_DT):
		w.step()
		if u.current_action == SimTypes.ActionType.WAIT:
			if wait_start < 0.0:
				wait_start = w.clock.time
				wait_pos = u.pos
			max_drift = maxf(max_drift, u.pos.distance_to(wait_pos))
			assert_eq(u.reason, SimTypes.ReasonCode.WAITING)
		elif wait_start >= 0.0 and wait_end < 0.0:
			wait_end = w.clock.time
		if reached_b < 0.0 and u.pos.distance_to(SimTypes.cell_center(B)) < SimTypes.ARRIVE_EPS:
			reached_b = w.clock.time
	assert_gt(wait_start, 0.0, "到达 A 时开始等待")
	assert_lte(wait_pos.distance_to(SimTypes.cell_center(A)), SimTypes.AT_BEACON_RADIUS + 0.001, "等待发生在 A 处（≤ 0.35 格）")
	assert_almost_eq(wait_end - wait_start, WAIT_SECONDS, SimTypes.SIM_DT * 1.5, "等待约 2 秒")
	assert_eq(max_drift, 0.0, "等待期间不移动")
	assert_gt(reached_b, wait_end, "等待结束后前往 B")
	assert_almost_eq(u.pos.x, SimTypes.cell_center(C).x, 0.001, "最终停在 C")
	assert_almost_eq(u.pos.y, SimTypes.cell_center(C).y, 0.001)
	assert_eq(u.reason, SimTypes.ReasonCode.ROUTE_FINISHED, "once 到末尾：已到达终点，规则仍成立")
	assert_eq(u.current_rule, 1, "停下后仍是 follow_beacons 这条（不回退）")
	assert_true(bool((u.wait_state[0] as Dictionary)["armed"]), "离开 A 后 wait 重新 armed")
	gut.p("07 §3.7：等待 %.2f–%.2f s，到达 B %.2f s，停在 C" % [wait_start, wait_end, reached_b])


func _visit_order(mode: String, seconds: float) -> PackedStringArray:
	var pair: Array = _world([r_follow(mode)])
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	var order: PackedStringArray = PackedStringArray()
	var last: int = -2
	for i: int in int(seconds / SimTypes.SIM_DT):
		w.step()
		if u.beacon_index != last:
			last = u.beacon_index
			order.append(str(u.beacons[last]["id"]))
	return order


func test_loop_order() -> void:
	var order: PackedStringArray = _visit_order("loop", 16.0)
	assert_eq(" ".join(order.slice(0, 7)), "1 2 3 1 2 3 1", "loop：末尾后回到 from")


func test_pingpong_order() -> void:
	var order: PackedStringArray = _visit_order("pingpong", 16.0)
	assert_eq(" ".join(order.slice(0, 7)), "1 2 3 2 1 2 3", "pingpong：末尾后反向，到 from 后再正向")


func test_follow_from_middle_beacon() -> void:
	var pair: Array = _world([r_follow("loop", "2")])
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	var seen: Dictionary = {}
	for i: int in int(16.0 / SimTypes.SIM_DT):
		w.step()
		seen[str(u.beacons[u.beacon_index]["id"])] = true
	assert_false(seen.has("1"), "from = B 时 loop 只在 B…C 之间")
	assert_true(seen.has("2") and seen.has("3"))


func test_deleted_beacon_reported_by_validation() -> void:
	var level: LevelDefinition = DataRegistry.get_level("level_03")
	var rules: Array[RuleDef] = SimFactory.to_rules([r_at_wait("2", WAIT_SECONDS), r_follow("once", "2"), r_follow("once", "1")])
	var config: Dictionary = {
		"slot_swift": { "pos": Vector2i(2, 5), "rules": SimFactory.to_rules([SimFactory.r_idle()]) },
		"slot_striker": { "pos": Vector2i(2, 1), "rules": rules, "beacons": _beacons([Vector2i(3, 1), Vector2i(10, 1)], "13") },
	}
	var problems: Array[Dictionary] = DeploymentValidator.validate(level, config, ALL_UNLOCKED, DataRegistry.get_units())
	var found: PackedStringArray = PackedStringArray()
	for p: Dictionary in problems:
		if str(p["code"]).begins_with("BEACON"):
			found.append("%s:%d:%s:%s" % [p["code"], int(p["index"]), p["what"], str(p["blocking"])])
	assert_eq(" ".join(found), "BEACON_MISSING:1:2:true BEACON_MISSING:2:2:true", "删除 B 后引用 B 的条件与行为被指出且阻止开始，未引用 B 的第 3 条不报")
	# 没有信标 / 信标在障碍上
	(config["slot_striker"] as Dictionary)["rules"] = SimFactory.to_rules([r_follow("once")])
	(config["slot_striker"] as Dictionary)["beacons"] = [] as Array[Dictionary]
	problems = DeploymentValidator.validate(level, config, ALL_UNLOCKED, DataRegistry.get_units())
	assert_true(_has_code(problems, "BEACONS_EMPTY"))
	(config["slot_striker"] as Dictionary)["beacons"] = _beacons([Vector2i(5, 2)], "1")    # (5,2) 是哭墙
	problems = DeploymentValidator.validate(level, config, ALL_UNLOCKED, DataRegistry.get_units())
	assert_true(_has_code(problems, "BEACON_ON_BLOCKED"))
	assert_false(_has_code(problems, "RULE_NOT_ALLOWED"), "信标/等待是通用工具，不受关卡 allowed 限制（Q-047）")


func _has_code(problems: Array[Dictionary], code: String) -> bool:
	for p: Dictionary in problems:
		if str(p["code"]) == code:
			return true
	return false


func test_missing_beacon_at_runtime_idles_with_reason() -> void:
	var pair: Array = _world([r_follow("once", "4")])
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	var start: Vector2 = u.pos
	SimFactory.run_steps(w, 10)
	assert_eq(u.pos, start, "from 不存在时原地不动")
	assert_eq(u.reason, SimTypes.ReasonCode.BEACON_MISSING)


func test_preemption_cancels_wait_without_restart() -> void:
	var pair: Array = _world([SimFactory.r_attack_in_range(), r_at_wait("1", 3.0), r_follow("once")])
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	var foe: SimUnit = SimFactory.add(w, "raider", SimTypes.Faction.ENEMY, Vector2i(11, 5), [SimFactory.r_idle()])
	foe.hp = 1.0
	while u.current_action != SimTypes.ActionType.WAIT and w.clock.time < 10.0:
		w.step()
	assert_eq(u.current_action, SimTypes.ActionType.WAIT, "到 A 开始等待")
	SimFactory.run_steps(w, 15)                             # 等了 0.5 秒
	foe.pos = u.pos + Vector2(1.0, 0.0)                    # 敌人进入射程 → 攻击条抢占
	w.step()
	assert_eq(u.current_rule, 0, "更高优先级的攻击抢占等待")
	var st: Dictionary = u.wait_state[1] as Dictionary
	assert_false(bool(st["armed"]), "被抢占：armed = false")
	assert_lt(float(st["remaining"]), 0.0, "计时取消")
	SimFactory.run_steps(w, 40)                            # 敌人被击杀
	assert_false(foe.alive)
	var before: Vector2 = u.pos
	w.step()
	assert_eq(u.current_rule, 2, "仍在 A 上但不重新计时，继续沿信标前进")
	assert_ne(u.pos, before)


func test_wait_disarms_then_rearms_after_leaving() -> void:
	# A → B → 回到 A（loop），第二次到达 A 会再次等待
	var pair: Array = _world([r_at_wait("1", 0.5), r_follow("loop")], [A, B] as Array[Vector2i])
	var w: SimWorld = pair[0] as SimWorld
	var u: SimUnit = pair[1] as SimUnit
	var waits: int = 0
	var waiting: bool = false
	for i: int in int(14.0 / SimTypes.SIM_DT):
		w.step()
		var now: bool = u.current_action == SimTypes.ActionType.WAIT
		if now and not waiting:
			waits += 1
		waiting = now
	assert_gte(waits, 2, "每次重新到达 A 都会等待一次（边沿触发）")


# ---- 第三关：信标替代预设路线（07 / 程序任务包 P2 完成标准）----
func _run_level_03_beacons(speed: int) -> BattleController:
	var level: LevelDefinition = DataRegistry.get_level("level_03")
	var saved_unlocks: Dictionary = GameState.unlocks
	GameState.unlocks = ALL_UNLOCKED
	var c := BattleController.new()
	add_child_autofree(c)
	c.setup(level)
	assert_true(c.apply_recommended())
	var striker: String = c.recommended_uid("slot_striker")
	assert_true(c.copy_route_to_beacons(striker, "corridor"), "复制预设路线为我的信标")
	var rules: Array[RuleDef] = c.get_rules(striker)
	rules[1] = SimFactory.rule(r_follow("once"))               # 原 follow_route corridor → 沿我的信标
	assert_true(c.set_rules(striker, rules))
	c.set_speed(speed)
	assert_true(c.start(), "信标配置通过校验")
	GameState.unlocks = saved_unlocks
	for i: int in int(ceil(60.0 / SimTypes.SIM_DT)):
		if c.phase != SimTypes.Phase.RUNNING:
			break
		c.advance_tick()
	return c


func test_level_03_beacons_replace_route_and_speed_consistent() -> void:
	var c1: BattleController = _run_level_03_beacons(1)
	var c2: BattleController = _run_level_03_beacons(2)
	assert_eq(c1.world.result, SimTypes.BattleResult.WIN, "沿信标绕后摧毁骸柱")
	assert_eq(c1.get_beacons(c1.recommended_uid("slot_striker")).size(), 3)
	assert_eq(c1.world.result, c2.world.result)
	assert_almost_eq(c1.world.clock.time, c2.world.clock.time, 0.0001, "1×/2× 时长一致")
	assert_eq(c1.world.state_hash(), c2.world.state_hash(), "1×/2× 终局哈希一致")
	gut.p("level_03 信标替代墙下通道：%s @ %.2fs hash=%d" % [SimTypes.BattleResult.keys()[c1.world.result], c1.world.clock.time, c1.world.state_hash()])
