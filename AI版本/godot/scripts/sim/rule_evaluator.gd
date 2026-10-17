class_name RuleEvaluator
extends RefCounted
## 指令求值（01 §6.6）：从上到下，第一条已启用且条件成立的指令生效；
## 成立但暂时无法执行时不回退到下一条（原地等待并给出原因）。
## 07 §3.4 定时等待 wait 的兼容规则（边沿触发）：每条含 wait 的规则维护 armed（初始 true）。
##   条件成立且 armed → 选中并计时（模拟时间），原地不动不攻击；计时结束 → armed = false，本步起视为不成立、继续向下；
##   条件不成立 → armed = true；被更高优先级规则抢占 → 计时取消且 armed = false（直到条件再次由假变真）。
##   注：未被求值到的低优先级规则不检查条件，因此"由假变真"以该规则下次被求值时看到"假"为准（Q-048）。
## 第四阶段「覆盖」（RuleDef.override）：求值顺序 = 覆盖指令（按列表顺序）在前，其余按列表顺序在后；
## 没有覆盖指令时与原顺序完全相同。wait 的"被更高优先级抢占"按求值顺序判断。
## 第五阶段（2026-10-17 会议）：SimUnit.dual_rules = true 的单位（玩家单位）按两组求值——移动组与攻击组各自从上到下取第一条成立者，
## 同时执行（边走边打）；组内优先级高的覆盖低的，override 字段不再使用。敌人与关卡预置单位仍按上面的旧单列表口径。

static var _default_target: TargetDef = null


## 规则未指定 target 时，条件（可见/射程）使用的候选口径：最近、任意。
static func default_target() -> TargetDef:
	if _default_target == null:
		_default_target = TargetDef.create(SimTypes.Selector.NEAREST, SimTypes.TargetFilter.ANY)
	return _default_target


static func evaluate(unit: SimUnit, snap: SimSnapshot, world: SimWorld) -> SimDecision:
	unit.rule_fail_reasons.clear()
	if not unit.dual_rules:
		var legacy: SimDecision = _evaluate_order(unit, snap, world, eval_order(unit.rules), false)
		legacy.mirror_attack_part()
		return legacy
	# 第五阶段双组口径：移动组与攻击组各自"第一条成立者生效"，结果合并为一个决策（移动部分 + 攻击部分）
	var d: SimDecision = _evaluate_order(unit, snap, world, RuleDef.group_indices(unit.rules, SimTypes.RuleGroup.MOVE), false)
	var at: SimDecision = _evaluate_order(unit, snap, world, RuleDef.group_indices(unit.rules, SimTypes.RuleGroup.ATTACK), true)
	d.attack_rule_index = at.rule_index
	d.attack_target = at.target
	d.attack_action = at.action
	d.attack_reason = at.reason
	return d


## 按 order 依次求值，返回第一条成立的指令。attack_group = true（双组口径的攻击组）时，目标优先在射程内选：
## 目标 = 按目标选择排序后第一个在射程内的候选，射程内没有则取排序第一的可见候选（本步移动后进入射程即开火）；
## 成立但没有任何候选 → NO_TARGET_IN_RANGE（不回退）。条件（目标距离等）的候选口径与旧口径相同。
static func _evaluate_order(unit: SimUnit, snap: SimSnapshot, world: SimWorld, order: Array[int], attack_group: bool) -> SimDecision:
	for i: int in order:
		var rule: RuleDef = unit.rules[i]
		if not rule.enabled:
			continue
		var tdef: TargetDef = rule.target if rule.target != null else default_target()
		var cands: Array[int] = TargetSelector.resolve(unit, tdef, snap)
		var in_range: Array[int] = []
		for cid: int in cands:
			if unit.pos.distance_to(snap.get_entry(cid).pos) <= unit.attack_range + SimTypes.DIST_EPS:
				in_range.append(cid)
		# enemy_in_range 成立时，选敌只在射程内者中进行
		var restrict: bool = false
		for c: ConditionDef in rule.conditions:
			if c.type == SimTypes.ConditionType.ENEMY_IN_RANGE and not in_range.is_empty():
				restrict = true
		var pool: Array[int] = in_range if restrict else cands
		var chosen: int = pool[0] if not pool.is_empty() else -1     # 条件（目标距离）按此口径判断（两种口径一致）
		if attack_group and not in_range.is_empty():   # 攻击组的目标：排序后第一个在射程内的候选；射程内没有时取排序第一的可见候选
			pool = in_range                              # （本步移动后进入射程即可开火，与旧口径「追击并攻击」一致；是否在射程内由 Combat 判断）

		var ok: bool = rule.conditions.is_empty() or rule.condition_mode == SimTypes.ConditionMode.ALL
		var first_fail: int = SimTypes.ReasonCode.OK
		for c: ConditionDef in rule.conditions:
			var r: int = _check(c, unit, cands, in_range, chosen, snap, world)
			var passed: bool = r == SimTypes.ReasonCode.OK
			if not passed and first_fail == SimTypes.ReasonCode.OK:
				first_fail = r
			if rule.condition_mode == SimTypes.ConditionMode.ANY:
				ok = ok or passed
			else:
				ok = ok and passed
		if rule.action != null and rule.action.type == SimTypes.ActionType.WAIT:
			var st: Dictionary = _wait_state(unit, i)
			if not ok:
				st["armed"] = true
				st["remaining"] = -1.0
				unit.rule_fail_reasons[i] = first_fail
				continue
			if not bool(st["armed"]):
				unit.rule_fail_reasons[i] = SimTypes.ReasonCode.WAIT_DONE
				continue
			var rem: float = float(st["remaining"])
			rem = rule.action.seconds if rem < 0.0 else rem - SimTypes.SIM_DT
			if rem <= SimTypes.TIME_EPS:
				st["armed"] = false
				st["remaining"] = -1.0
				unit.rule_fail_reasons[i] = SimTypes.ReasonCode.WAIT_DONE
				continue
			st["remaining"] = rem
			var dw := SimDecision.new()
			dw.rule_index = i
			dw.action = rule.action
			dw.reason = SimTypes.ReasonCode.WAITING
			_preempt_waits(unit, i, order)
			return dw
		if not ok:
			unit.rule_fail_reasons[i] = first_fail
			continue

		var d := SimDecision.new()
		d.rule_index = i
		d.action = rule.action
		var tid: int = pool[0] if not pool.is_empty() else -1
		d.target = tid if rule.target != null else -1
		if attack_group and rule.action.type == SimTypes.ActionType.HOLD_FIRE:
			d.target = -1
			d.reason = SimTypes.ReasonCode.HOLDING_FIRE
		elif rule.action.needs_target():
			if tid < 0:
				d.reason = SimTypes.ReasonCode.NO_TARGET_IN_RANGE if attack_group else SimTypes.ReasonCode.NO_TARGET_CANDIDATE
			elif rule.action.type == SimTypes.ActionType.ATTACK \
					and unit.pos.distance_to(snap.get_entry(tid).pos) > unit.attack_range + SimTypes.DIST_EPS:
				d.reason = SimTypes.ReasonCode.TARGET_OUT_OF_RANGE
		_preempt_waits(unit, i, order)
		return d

	var none := SimDecision.new()
	none.reason = SimTypes.ReasonCode.NO_RULE_MATCHED
	return none


static func _wait_state(unit: SimUnit, rule_index: int) -> Dictionary:
	if not unit.wait_state.has(rule_index):
		unit.wait_state[rule_index] = { "armed": true, "remaining": -1.0 }
	return unit.wait_state[rule_index] as Dictionary


## 求值顺序：覆盖指令在前（保持列表顺序），其余在后
static func eval_order(rules: Array[RuleDef]) -> Array[int]:
	var first: Array[int] = []
	var rest: Array[int] = []
	for i: int in rules.size():
		if rules[i].override:
			first.append(i)
		else:
			rest.append(i)
	first.append_array(rest)
	return first


## 选中第 chosen 条：求值顺序在其后、正在计时的 wait 被抢占 → 取消且 armed = false
static func _preempt_waits(unit: SimUnit, chosen: int, order: Array[int]) -> void:
	var rank: int = order.find(chosen)
	for k: Variant in unit.wait_state.keys():
		var st: Dictionary = unit.wait_state[k] as Dictionary
		if order.find(int(k)) > rank and float(st["remaining"]) >= 0.0:
			st["remaining"] = -1.0
			st["armed"] = false


## 返回 OK 表示成立，否则为失败原因码
static func _check(c: ConditionDef, unit: SimUnit, cands: Array[int], in_range: Array[int], chosen: int, snap: SimSnapshot, world: SimWorld) -> int:
	match c.type:
		SimTypes.ConditionType.ALWAYS:
			return SimTypes.ReasonCode.OK
		SimTypes.ConditionType.SELF_HP_BELOW:
			return SimTypes.ReasonCode.OK if unit.hp / unit.max_hp < c.ratio else SimTypes.ReasonCode.COND_HP_NOT_BELOW
		SimTypes.ConditionType.ENEMY_VISIBLE:
			return SimTypes.ReasonCode.OK if not cands.is_empty() else SimTypes.ReasonCode.COND_NO_VISIBLE_ENEMY
		SimTypes.ConditionType.ENEMY_IN_RANGE:
			return SimTypes.ReasonCode.OK if not in_range.is_empty() else SimTypes.ReasonCode.COND_NO_ENEMY_IN_RANGE
		SimTypes.ConditionType.TARGET_DISTANCE:
			if chosen < 0:
				return SimTypes.ReasonCode.NO_TARGET_CANDIDATE
			var dist: float = unit.pos.distance_to(snap.get_entry(chosen).pos)
			var passed: bool = dist < c.value if c.op == "<" else dist > c.value
			return SimTypes.ReasonCode.OK if passed else SimTypes.ReasonCode.COND_DISTANCE_FAIL
		SimTypes.ConditionType.RETREAT_POSSIBLE:
			var radius: float = c.threat_radius if c.threat_radius >= 0.0 else unit.vision
			var plan: Dictionary = Movement.plan_retreat(unit, radius, c.search_depth, snap, world.grid, c.flee)
			if bool(plan["found"]) and float(plan["gain"]) >= SimTypes.RETREAT_MIN_GAIN - SimTypes.DIST_EPS:
				return SimTypes.ReasonCode.OK
			return SimTypes.ReasonCode.COND_NO_ESCAPE
		SimTypes.ConditionType.AT_BEACON:
			var bi: int = unit.beacon_slot(c.beacon)
			if bi < 0:
				return SimTypes.ReasonCode.BEACON_MISSING
			var center: Vector2 = SimTypes.cell_center(unit.beacons[bi]["cell"] as Vector2i)
			return SimTypes.ReasonCode.OK if unit.pos.distance_to(center) <= SimTypes.AT_BEACON_RADIUS + SimTypes.DIST_EPS else SimTypes.ReasonCode.COND_NOT_AT_BEACON
		SimTypes.ConditionType.SIGNAL_IS:
			return SimTypes.ReasonCode.OK if world.boss_signal == c.sig else SimTypes.ReasonCode.COND_SIGNAL_OFF
	return SimTypes.ReasonCode.NO_RULE_MATCHED
