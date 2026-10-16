class_name Movement
extends RefCounted
## 行为的移动部分（01 §6.7）：chase / chase_attack / retreat / follow_route；07 §3.2 follow_beacons（wait 不移动）。
## 目标位置一律读本步快照；单位之间不堵路，仅障碍格不可走。


static func apply(unit: SimUnit, d: SimDecision, snap: SimSnapshot, world: SimWorld) -> void:
	match d.action_type():
		SimTypes.ActionType.CHASE_ATTACK, SimTypes.ActionType.CHASE:
			_chase(unit, d, snap, world)
		SimTypes.ActionType.RETREAT:
			_retreat(unit, d.action, snap, world)
		SimTypes.ActionType.FOLLOW_ROUTE:
			_follow_route(unit, d.action, world)
		SimTypes.ActionType.FOLLOW_BEACONS:
			follow_beacons(unit, d.action, world)


static func _chase(unit: SimUnit, d: SimDecision, snap: SimSnapshot, world: SimWorld) -> void:
	if d.target < 0:
		return
	var tpos: Vector2 = snap.get_entry(d.target).pos
	if unit.pos.distance_to(tpos) <= unit.attack_range + SimTypes.DIST_EPS:
		return  # 已在射程内：不再移动
	var goal: Vector2i = world.grid.nearest_cell_within(unit.cell(), tpos, unit.attack_range - SimTypes.RANGE_MARGIN)
	if goal.x < 0:
		unit.reason = SimTypes.ReasonCode.PATH_BLOCKED
		unit.path.clear()
		return
	move_toward_cell(unit, goal, world)


## 撤离规划：威胁 = threat_radius 内可见敌人。在 BFS search_depth 步内的可达格中
## 选"到最近威胁距离最大"者，决胜：离当前格更近（步数少）→ 格索引小。
## 返回 { found, cell, gain, has_threat }；gain = 该格得分 - 当前位置得分。
static func plan_retreat(unit: SimUnit, threat_radius: float, search_depth: int, snap: SimSnapshot, grid: SimGrid, flee: String = "max_min") -> Dictionary:
	var result: Dictionary = { "found": false, "cell": Vector2i(-1, -1), "gain": 0.0, "has_threat": false }
	var threats: Array[Vector2] = []
	for oid: int in snap.ids:
		var e: SimSnapshot.Entry = snap.get_entry(oid)
		if not e.alive or not TargetSelector.is_hostile(unit.faction, e.faction):
			continue
		var dist: float = unit.pos.distance_to(e.pos)
		if dist <= threat_radius + SimTypes.DIST_EPS and dist <= unit.vision + SimTypes.DIST_EPS:
			threats.append(e.pos)
	if threats.is_empty():
		return result
	result["has_threat"] = true
	if flee == "vector_sum":
		var vs: Dictionary = _plan_vector_sum(unit, threats, search_depth, grid)
		if not vs.is_empty():
			return vs
	var cur_cell: Vector2i = unit.cell()
	var cur_score: float = _min_dist(unit.pos, threats)
	var best_cell := Vector2i(-1, -1)
	var best_score: float = -INF
	for c: Vector2i in grid.reachable_within(cur_cell, search_depth):
		if c == cur_cell:
			continue
		var s: float = _min_dist(SimTypes.cell_center(c), threats)
		if s > best_score + SimTypes.DIST_EPS:   # 严格更优才替换：同分保留更近/索引更小者
			best_score = s
			best_cell = c
	if best_cell.x < 0 or best_score <= cur_score + SimTypes.DIST_EPS:
		return result
	result["found"] = true
	result["cell"] = best_cell
	result["gain"] = best_score - cur_score
	return result


## 2026-10-12 评审口径「向量之和」：方向 = Σ (自身 - 威胁) / 距离²（近的威胁权重大）。
## 在 search_depth 步内可达格中，取「沿该方向的投影」最大者；不允许比当前更靠近最近的威胁（防止侧向贴脸）。
## 投影同分 → 离最近威胁更远 → 步数少/格索引小。合力为零（被对称包夹）时返回空，退回 max_min 规则。
## 返回格式同 plan_retreat；gain = 投影长度（格）。没有正向可走的格 = 无路可退（found = false）。
static func _plan_vector_sum(unit: SimUnit, threats: Array[Vector2], search_depth: int, grid: SimGrid) -> Dictionary:
	var dir := Vector2.ZERO
	for t: Vector2 in threats:
		var v: Vector2 = unit.pos - t
		dir += v / maxf(v.length_squared(), 0.25)
	if dir.length() < 1e-4:
		return {}
	dir = dir.normalized()
	var result: Dictionary = { "found": false, "cell": Vector2i(-1, -1), "gain": 0.0, "has_threat": true }
	var cur_min: float = _min_dist(unit.pos, threats)
	var cur_cell: Vector2i = unit.cell()
	var best := Vector2i(-1, -1)
	var best_proj: float = 0.0
	var best_md: float = -INF
	for c: Vector2i in grid.reachable_within(cur_cell, search_depth):
		if c == cur_cell:
			continue
		var p: Vector2 = SimTypes.cell_center(c)
		var md: float = _min_dist(p, threats)
		if md < cur_min - SimTypes.DIST_EPS:
			continue
		var proj: float = (p - unit.pos).dot(dir)
		if proj > best_proj + SimTypes.DIST_EPS or (absf(proj - best_proj) <= SimTypes.DIST_EPS and md > best_md + SimTypes.DIST_EPS):
			best = c
			best_proj = proj
			best_md = md
	if best.x < 0 or best_proj < SimTypes.RETREAT_MIN_GAIN - SimTypes.DIST_EPS:
		return result
	result["found"] = true
	result["cell"] = best
	result["gain"] = best_proj
	return result


static func _min_dist(p: Vector2, threats: Array[Vector2]) -> float:
	var m: float = INF
	for t: Vector2 in threats:
		m = minf(m, p.distance_to(t))
	return m


static func _retreat(unit: SimUnit, a: ActionDef, snap: SimSnapshot, world: SimWorld) -> void:
	var radius: float = a.threat_radius if a.threat_radius >= 0.0 else unit.vision
	var plan: Dictionary = plan_retreat(unit, radius, a.search_depth, snap, world.grid, a.flee)
	if not bool(plan["found"]):
		unit.reason = SimTypes.ReasonCode.FLEE_NO_DIRECTION
		unit.path.clear()
		return
	move_toward_cell(unit, plan["cell"] as Vector2i, world)


static func _follow_route(unit: SimUnit, a: ActionDef, world: SimWorld) -> void:
	var route: RouteDef = world.routes.get(a.route_id, null) as RouteDef
	if route == null or route.points.is_empty():
		unit.reason = SimTypes.ReasonCode.PATH_BLOCKED
		return
	var n: int = route.points.size()
	if unit.route_index >= n:
		if a.loop:
			unit.route_index = 0
		else:
			unit.reason = SimTypes.ReasonCode.ROUTE_FINISHED
			return
	# 到达当前路点 → 取下一个（每步最多推进一圈，防止单点循环路线死循环）
	var guard: int = 0
	while guard < n and unit.pos.distance_to(SimTypes.cell_center(route.points[unit.route_index])) < SimTypes.ARRIVE_EPS:
		guard += 1
		unit.route_index += 1
		if unit.route_index >= n:
			if a.loop:
				unit.route_index = 0
			else:
				unit.reason = SimTypes.ReasonCode.ROUTE_FINISHED
				unit.path.clear()
				return
	move_toward_cell(unit, route.points[unit.route_index], world)


## 07 §3.2：沿自己的信标序列移动。游标 beacon_index/beacon_dir 存在单位上，被抢占时保留、恢复后继续前往同一信标。
## once：from→…→末尾，到达后 ROUTE_FINISHED 原地等待（规则仍成立，不回退）；loop：末尾后回到 from；
## pingpong：在 from 与末尾之间往返。没有信标或 from 不存在 → BEACON_MISSING，原地不动。
static func follow_beacons(unit: SimUnit, a: ActionDef, world: SimWorld) -> void:
	var start: int = unit.beacon_slot(a.from)
	if unit.beacons.is_empty() or start < 0:
		unit.reason = SimTypes.ReasonCode.BEACON_MISSING
		return
	var last: int = unit.beacons.size() - 1
	var resuming: bool = unit.beacon_index >= 0 and unit.last_action != SimTypes.ActionType.FOLLOW_BEACONS
	if unit.beacon_index < start or unit.beacon_index > last:
		unit.beacon_index = start
		unit.beacon_dir = 1
		unit.beacon_rejoin = Vector2i(-1, -1)
		resuming = false
	if resuming:
		plan_rejoin(unit, a.mode, start, last, world)
	if unit.beacon_rejoin.x >= 0:
		if unit.pos.distance_to(SimTypes.cell_center(unit.beacon_rejoin)) >= SimTypes.ARRIVE_EPS:
			move_toward_cell(unit, unit.beacon_rejoin, world)
			return
		unit.beacon_rejoin = Vector2i(-1, -1)
	var guard: int = 0
	while guard <= last + 1 and unit.pos.distance_to(SimTypes.cell_center(unit.beacons[unit.beacon_index]["cell"] as Vector2i)) < SimTypes.ARRIVE_EPS:
		guard += 1
		if not _advance_beacon(unit, a.mode, start, last):
			unit.reason = SimTypes.ReasonCode.ROUTE_FINISHED
			unit.path.clear()
			return
	move_toward_cell(unit, unit.beacons[unit.beacon_index]["cell"] as Vector2i, world)


## 第四阶段：恢复沿信标时回到"离路线最近的一点"——在信标折线（loop 含末尾→起点的闭合段）上取离当前位置最近的点，
## 所在格可行走且不是当前格 / 该段终点信标时设为 beacon_rejoin；游标指向该段的下一个信标（pingpong 反向时为段的起点）。
## 同距离取靠前的段（确定性）。
static func plan_rejoin(unit: SimUnit, mode: int, start: int, last: int, world: SimWorld) -> void:
	unit.beacon_rejoin = Vector2i(-1, -1)
	if last <= start:
		return
	var segs: Array[Vector2i] = []
	for i: int in range(start, last):
		segs.append(Vector2i(i, i + 1))
	if mode == SimTypes.BeaconMode.LOOP:
		segs.append(Vector2i(last, start))
	var best_d: float = INF
	var best_q: Vector2 = unit.pos
	var best_seg: Vector2i = segs[0]
	for sg: Vector2i in segs:
		var pa: Vector2 = SimTypes.cell_center(unit.beacons[sg.x]["cell"] as Vector2i)
		var pb: Vector2 = SimTypes.cell_center(unit.beacons[sg.y]["cell"] as Vector2i)
		var ab: Vector2 = pb - pa
		var t: float = 0.0 if ab.length_squared() <= 0.0 else clampf((unit.pos - pa).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var q: Vector2 = pa + ab * t
		var dist: float = unit.pos.distance_to(q)
		if dist < best_d - SimTypes.DIST_EPS:
			best_d = dist
			best_q = q
			best_seg = sg
	var target: int = best_seg.y
	if mode == SimTypes.BeaconMode.PINGPONG and unit.beacon_dir < 0:
		target = best_seg.x
	unit.beacon_index = target
	var c: Vector2i = SimTypes.pos_to_cell(best_q)
	if c != unit.cell() and c != (unit.beacons[target]["cell"] as Vector2i) and world.grid.is_walkable(c):
		unit.beacon_rejoin = c


## 抵达当前信标后推进游标；返回 false 表示 once 已到末尾（或单信标无处可去）
static func _advance_beacon(unit: SimUnit, mode: int, start: int, last: int) -> bool:
	if start == last:
		return false
	match mode:
		SimTypes.BeaconMode.LOOP:
			unit.beacon_index = start if unit.beacon_index >= last else unit.beacon_index + 1
		SimTypes.BeaconMode.PINGPONG:
			if unit.beacon_dir > 0 and unit.beacon_index >= last:
				unit.beacon_dir = -1
			elif unit.beacon_dir < 0 and unit.beacon_index <= start:
				unit.beacon_dir = 1
			unit.beacon_index += unit.beacon_dir
		_:
			if unit.beacon_index >= last:
				return false
			unit.beacon_index += 1
	return true


## 沿四方向路径朝 goal 格中心移动 move_speed * SIM_DT（跨路点保留剩余距离）。
## 路径在目标格变化、每 PATH_REFRESH_STEPS 步或走完时重算。
static func move_toward_cell(unit: SimUnit, goal: Vector2i, world: SimWorld) -> void:
	if unit.move_speed <= 0.0:
		return
	if goal != unit.path_goal or unit.path_age >= SimTypes.PATH_REFRESH_STEPS or unit.path.is_empty():
		var full: Array[Vector2i] = world.grid.find_path(unit.cell(), goal)
		if full.is_empty():
			unit.reason = SimTypes.ReasonCode.PATH_BLOCKED
			unit.path.clear()
			unit.path_goal = Vector2i(-1, -1)
			return
		if full.size() > 1:
			full.remove_at(0)   # 去掉当前格：直接朝下一格中心走（线段只经过当前格与下一格）
		unit.path = full
		unit.path_goal = goal
		unit.path_age = 0
	else:
		unit.path_age += 1
	var remaining: float = unit.move_speed * StatusSystem.speed_mult(world, unit) * SimTypes.SIM_DT
	while remaining > 0.0 and not unit.path.is_empty():
		var wp: Vector2 = SimTypes.cell_center(unit.path[0])
		var dist: float = unit.pos.distance_to(wp)
		if dist <= remaining:
			unit.pos = wp
			remaining -= dist
			unit.path.remove_at(0)
		else:
			unit.pos = unit.pos.move_toward(wp, remaining)
			remaining = 0.0
