extends GutTest
## 05 §2 test_movement：追击、撤离、路线、移速、不堵路（01 §6.7）

const ALLY: int = SimTypes.Faction.ALLY
const ENEMY: int = SimTypes.Faction.ENEMY


func _route(w: SimWorld, route_id: String, points: Array[Vector2i]) -> void:
	var r := RouteDef.new()
	r.id = route_id
	r.display_name = route_id
	r.points = points
	w.routes[route_id] = r


func _retreat_rule(depth: int = 3) -> Dictionary:
	return { "conditions": [], "action": { "type": "retreat", "search_depth": depth } }


func _route_rule(route_id: String, loop: bool = false) -> Dictionary:
	return { "conditions": [], "action": { "type": "follow_route", "route_id": route_id, "loop": loop } }


func test_chase_stops_within_range() -> void:
	var w: SimWorld = SimFactory.make_empty_world(12, 12)
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(1, 5), [
		{ "conditions": [{ "type": "enemy_in_range" }], "target": { "selector": "nearest" }, "action": { "type": "idle" } },
		{ "conditions": [{ "type": "enemy_visible" }], "target": { "selector": "nearest" }, "action": { "type": "chase" } },
	])
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(9, 5))
	SimFactory.run_steps(w, 120)
	assert_lte(a.pos.distance_to(e.pos), a.attack_range, "到达射程内")
	var stopped: Vector2 = a.pos
	SimFactory.run_steps(w, 30)
	assert_eq(a.pos, stopped, "射程内停止移动")


func test_chase_path_avoids_blocked() -> void:
	var wall: Array[Vector2i] = []
	for y: int in range(0, 9):
		wall.append(Vector2i(5, y))
	var w: SimWorld = SimFactory.make_empty_world(10, 10, wall)
	var a: SimUnit = SimFactory.add(w, "swift", ALLY, Vector2i(2, 2), [SimFactory.r_chase_attack_visible()])
	var e: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(8, 2))
	var visited_blocked: bool = false
	for i: int in 300:
		w.step()
		if not w.grid.is_walkable(a.cell()):
			visited_blocked = true
	assert_false(visited_blocked, "路径不穿障碍")
	assert_lte(a.pos.distance_to(e.pos), a.attack_range + 0.01, "绕过墙到达射程内")


func test_unreachable_sets_path_blocked() -> void:
	var cage: Array[Vector2i] = [Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 4), Vector2i(5, 6)]
	var w: SimWorld = SimFactory.make_empty_world(12, 12, cage)
	var a: SimUnit = SimFactory.add(w, "swift", ALLY, Vector2i(1, 5), [SimFactory.r_chase_attack_visible()])
	SimFactory.add(w, "raider", ENEMY, Vector2i(5, 5))
	var start: Vector2 = a.pos
	SimFactory.run_steps(w, 10)
	assert_eq(a.current_rule, 0)
	assert_eq(a.reason, SimTypes.ReasonCode.PATH_BLOCKED)
	assert_eq(a.pos, start, "原地等待")


func test_retreat_maximizes_min_distance() -> void:
	var w: SimWorld = SimFactory.make_empty_world(12, 12)
	var a: SimUnit = SimFactory.add(w, "swift", ALLY, Vector2i(5, 5), [_retreat_rule()])
	SimFactory.add(w, "raider", ENEMY, Vector2i(2, 5))
	w.begin()
	var plan: Dictionary = Movement.plan_retreat(a, a.vision, 3, w.make_snapshot(), w.grid)
	assert_true(bool(plan["found"]))
	assert_eq(plan["cell"] as Vector2i, Vector2i(8, 5), "单威胁：移向最远格")
	w.step()
	assert_gt(a.pos.x, 5.5)
	assert_almost_eq(a.pos.y, 5.5, 1e-6)


func test_retreat_multi_threat_cancellation_stable() -> void:
	var runs: Array[Vector2] = []
	for run: int in 2:
		var w: SimWorld = SimFactory.make_empty_world(12, 12)
		var a: SimUnit = SimFactory.add(w, "swift", ALLY, Vector2i(5, 5), [_retreat_rule()])
		SimFactory.add(w, "raider", ENEMY, Vector2i(2, 5))
		SimFactory.add(w, "raider", ENEMY, Vector2i(8, 5))
		w.begin()
		var plan: Dictionary = Movement.plan_retreat(a, a.vision, 3, w.make_snapshot(), w.grid)
		assert_eq(plan["cell"] as Vector2i, Vector2i(5, 2), "两侧对称：同分取格索引小者（确定的垂直方向）")
		SimFactory.run_steps(w, 10)
		assert_almost_eq(a.pos.x, 5.5, 1e-6, "只做垂直移动")
		runs.append(a.pos)
	assert_eq(runs[0], runs[1], "两次运行结果相同")


func _cornered_world(rules: Array) -> SimWorld:
	# (0,0) 角落，仅能走到 (0,1)，两格都比当前更接近威胁
	var blocked: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 2)]
	var w: SimWorld = SimFactory.make_empty_world(5, 5, blocked)
	SimFactory.add(w, "swift", ALLY, Vector2i(0, 0), rules)
	SimFactory.add(w, "raider", ENEMY, Vector2i(2, 2))
	return w


func test_retreat_cornered_sets_no_direction() -> void:
	var w: SimWorld = _cornered_world([_retreat_rule()])
	var a: SimUnit = w.get_unit(SimTypes.ALLY_ID_BASE)
	var start: Vector2 = a.pos
	w.step()
	assert_eq(a.reason, SimTypes.ReasonCode.FLEE_NO_DIRECTION)
	assert_eq(a.pos, start)


func test_retreat_possible_condition_false_when_cornered() -> void:
	var w: SimWorld = _cornered_world([
		{ "conditions": [{ "type": "retreat_possible", "search_depth": 3 }], "action": { "type": "retreat" } },
		SimFactory.r_idle(),
	])
	var a: SimUnit = w.get_unit(SimTypes.ALLY_ID_BASE)
	w.step()
	assert_eq(int(a.rule_fail_reasons[0]), SimTypes.ReasonCode.COND_NO_ESCAPE)
	assert_eq(a.current_rule, 1, "退路不存在 → 落到下一条")


func test_follow_route_reaches_end_then_finished() -> void:
	var w: SimWorld = SimFactory.make_empty_world(8, 4)
	_route(w, "line", [Vector2i(1, 1), Vector2i(4, 1)])
	_route(w, "loop", [Vector2i(1, 2), Vector2i(4, 2)])
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(1, 1), [_route_rule("line")])
	var b: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(1, 2), [_route_rule("loop", true)])
	var b_returned: bool = false
	var b_max_x: float = 0.0
	for i: int in 150:
		w.step()
		b_max_x = maxf(b_max_x, b.pos.x)
		if b_max_x >= 4.5 - 1e-3 and b.pos.x < 4.0:
			b_returned = true
	assert_eq(a.reason, SimTypes.ReasonCode.ROUTE_FINISHED)
	assert_lt(a.pos.distance_to(SimTypes.cell_center(Vector2i(4, 1))), 1e-3, "停在终点")
	assert_true(b_returned, "loop=true：到终点后回到首路点")


func test_move_speed_per_second() -> void:
	var w: SimWorld = SimFactory.make_empty_world(16, 2)
	_route(w, "far", [Vector2i(15, 0)])
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(0, 0), [_route_rule("far")])
	SimFactory.run_steps(w, 30)
	assert_almost_eq(a.pos.x - 0.5, 3.0, 0.01, "移速 3：30 步移动 3 格")


func test_units_do_not_block_each_other() -> void:
	var w: SimWorld = SimFactory.make_empty_world(8, 3)
	_route(w, "r", [Vector2i(6, 1)])
	var a: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(1, 1), [_route_rule("r")])
	var b: SimUnit = SimFactory.add(w, "striker", ALLY, Vector2i(1, 1), [_route_rule("r")])
	SimFactory.run_steps(w, 90)
	assert_lt(a.pos.distance_to(SimTypes.cell_center(Vector2i(6, 1))), 1e-3)
	assert_eq(b.pos, a.pos, "两单位可重叠同格")
