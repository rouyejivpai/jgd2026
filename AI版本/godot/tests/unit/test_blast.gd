extends GutTest
## 05 §2 test_blast：延迟爆炸（01 §6.8、策划 5.4）

const ALLY: int = SimTypes.Faction.ALLY
const ENEMY: int = SimTypes.Faction.ENEMY


func _route(w: SimWorld, route_id: String, points: Array[Vector2i]) -> void:
	var r := RouteDef.new()
	r.id = route_id
	r.points = points
	w.routes[route_id] = r


func _first_event(w: SimWorld, type: int) -> Dictionary:
	var list: Array[Dictionary] = SimFactory.events_of(w, type)
	return list[0] if not list.is_empty() else {}


## 骨喉 + 一名沿路线移动的快速形态
func _moving_target_world() -> SimWorld:
	var w: SimWorld = SimFactory.make_empty_world(16, 12)
	_route(w, "down", [Vector2i(4, 0)])
	var t: SimUnit = SimFactory.add(w, "swift", ALLY, Vector2i(4, 10), [{ "conditions": [], "action": { "type": "follow_route", "route_id": "down" } }])
	t.hp = 10000.0
	t.max_hp = 10000.0
	SimFactory.add(w, "spitter", ENEMY, Vector2i(12, 5))
	return w


func _run_until_event(w: SimWorld, type: int, max_steps: int) -> Dictionary:
	for i: int in max_steps:
		w.step()
		var e: Dictionary = _first_event(w, type)
		if not e.is_empty():
			return e
	return {}


func test_blast_placed_at_target_position_at_lock_time() -> void:
	var w: SimWorld = _moving_target_world()
	var t: SimUnit = w.get_unit(SimTypes.ALLY_ID_BASE)
	var placed: Dictionary = _run_until_event(w, SimTypes.EventType.BLAST_PLACED, 120)
	assert_false(placed.is_empty())
	assert_eq(int(placed["target"]), t.id)
	assert_eq(placed["pos"] as Vector2, t.pos, "落点 = 锁定时目标位置")


func test_blast_does_not_follow_target() -> void:
	var w: SimWorld = _moving_target_world()
	var t: SimUnit = w.get_unit(SimTypes.ALLY_ID_BASE)
	var placed: Dictionary = _run_until_event(w, SimTypes.EventType.BLAST_PLACED, 120)
	var det: Dictionary = _run_until_event(w, SimTypes.EventType.BLAST_DETONATED, 90)
	assert_false(det.is_empty())
	assert_eq(det["pos"] as Vector2, placed["pos"] as Vector2, "落点不随目标移动")
	assert_gt(t.pos.distance_to(placed["pos"] as Vector2), 1.5, "目标已走出半径，不受伤")
	assert_false((det["hits"] as Array).has(t.id))


func test_blast_not_cancelled_on_target_death() -> void:
	var w: SimWorld = _moving_target_world()
	var t: SimUnit = w.get_unit(SimTypes.ALLY_ID_BASE)
	var placed: Dictionary = _run_until_event(w, SimTypes.EventType.BLAST_PLACED, 120)
	assert_false(placed.is_empty())
	t.hp = 0.0
	t.alive = false
	var det: Dictionary = _run_until_event(w, SimTypes.EventType.BLAST_DETONATED, 90)
	assert_false(det.is_empty(), "目标死亡后仍到期爆炸")
	assert_eq(int(det["blast_id"]), int(placed["blast_id"]))


func test_blast_damages_all_opposing_in_radius() -> void:
	var w: SimWorld = SimFactory.make_empty_world(12, 12)
	var source: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(10, 10))
	var inside_a: SimUnit = SimFactory.add(w, "bulwark", ALLY, Vector2i(5, 5))
	var inside_b: SimUnit = SimFactory.add(w, "bulwark", ALLY, Vector2i(6, 5))   # 距离 1
	var outside: SimUnit = SimFactory.add(w, "bulwark", ALLY, Vector2i(8, 5))    # 距离 3
	var same_side: SimUnit = SimFactory.add(w, "raider", ENEMY, Vector2i(5, 6))  # 施放方阵营
	BlastSystem.place(w, source, SimTypes.cell_center(Vector2i(5, 5)), DataRegistry.get_trait("delayed_blast_basic"), inside_a.id)
	SimFactory.run_steps(w, 61)
	assert_eq(inside_a.hp, inside_a.max_hp - 30.0)
	assert_eq(inside_b.hp, inside_b.max_hp - 30.0)
	assert_eq(outside.hp, outside.max_hp, "半径外不受伤")
	assert_eq(same_side.hp, same_side.max_hp, "施放方不受伤")


func test_blast_cooldown_and_first_delay() -> void:
	var w: SimWorld = SimFactory.make_empty_world(16, 12)
	var t: SimUnit = SimFactory.add(w, "bulwark", ALLY, Vector2i(4, 5))
	t.hp = 100000.0
	t.max_hp = 100000.0
	SimFactory.add(w, "spitter", ENEMY, Vector2i(12, 5))
	var tdef: TraitDefinition = DataRegistry.get_trait("delayed_blast_basic")
	SimFactory.run_steps(w, int(15.0 / SimTypes.SIM_DT))
	var placed: Array[Dictionary] = SimFactory.events_of(w, SimTypes.EventType.BLAST_PLACED)
	assert_gt(placed.size(), 2)
	assert_gte(float(placed[0]["time"]), tdef.first_delay - SimTypes.TIME_EPS, "first_delay 前不放置")
	for i: int in range(1, placed.size()):
		assert_gte(float(placed[i]["time"]) - float(placed[i - 1]["time"]), tdef.cooldown - SimTypes.TIME_EPS, "间隔 ≥ cooldown")


func test_blast_selects_farthest_visible() -> void:
	var w: SimWorld = SimFactory.make_empty_world(16, 12)
	SimFactory.add(w, "spitter", ENEMY, Vector2i(14, 5))
	SimFactory.add(w, "bulwark", ALLY, Vector2i(9, 5))               # 距离 5
	var far: SimUnit = SimFactory.add(w, "bulwark", ALLY, Vector2i(5, 5))  # 距离 9
	SimFactory.add(w, "bulwark", ALLY, Vector2i(1, 5))               # 距离 13：视野 12 外
	var placed: Dictionary = _run_until_event(w, SimTypes.EventType.BLAST_PLACED, 120)
	assert_eq(int(placed["target"]), far.id, "选最远可见者")
	assert_eq(placed["pos"] as Vector2, far.pos)
