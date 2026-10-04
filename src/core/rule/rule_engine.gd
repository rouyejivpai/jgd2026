class_name RuleEngine
extends RefCounted
## 详细设计：[docs/design/02-规则引擎.md](../../docs/design/02-规则引擎.md) 4.2-4.4
##
## 把「玩家写的规则表」在**每个逻辑 tick** 翻译成一组**本 tick 生效的意图**，
## 并对冲突与持续状态给出确定结果。**全项目最高风险的系统。**
##
## 【核心语义，逐条对应详设 02】
## 1. 每 tick 从第 1 条向下逐条求值，收集**所有**条件成立的指令
## 2. 同类行为按冲突键分组，**顺序最靠后**的生效（后覆盖前）
## 3. 条件转假**不清空**持续型意图 —— 由 UnitActor 负责保持（本引擎只产出意图）
## 4. 本 tick 写入的信号**下一 tick** 才被条件读到（由 SignalStore 保证）
## 5. 延迟是阻塞型计时器，**不占冲突键**；阻塞期间**不评估任何条件**
## 6. 引用不存在的信标/信号 → **整条跳过**，并写 invalid_reason
##
## 【本类是纯逻辑】不持有单位、不读 tick；所有外部依赖经参数传入，
## 因此可以在冒烟测试里脱离场景单独验收。

const RuleConditionScript := preload("res://src/core/rule/condition.gd")
const RuleActionScript := preload("res://src/core/rule/action.gd")
const IntentScript := preload("res://src/core/rule/intent.gd")
const RuleScript := preload("res://src/core/rule/rule.gd")

## 阵营
const TEAM_ALLY := 0
const TEAM_ENEMY := 1


## 求值单个单位，产出 Intent。
##
## unit         UnitActor（读 rules / is_dead / delay_remaining / hp / team / position_logic）
## battle_state BattleState（查敌人）
## map          BattleMap（查信标位置与存在性）
## signals      SignalStore（读本 tick 生效值、写暂存区）
##
## **纯函数**：除写 signals 暂存区与 rule.invalid_reason 外不改任何状态
## （详设 02 的 4.4 决策 1）。
func evaluate_unit(unit, battle_state, map, signals) -> RefCounted:
	var intent := IntentScript.new()
	if unit == null:
		return intent
	if bool(unit.get("is_dead")):
		return intent

	# 1. 延迟阻塞：本 tick **不评估任何条件**（详设 02 的 6.3）。
	#    理由：若延迟期间继续求值，计时结束那一刻生效的可能是延迟期间被刷新的
	#    意图，玩家难以预期。跳过求值让「停止 N 秒」成为一个干净的时间窗。
	if float(unit.get("delay_remaining")) > 0.0:
		return intent

	var rules: Array = unit.get("rules")
	if rules.is_empty():
		return intent

	# 2. 收集命中指令：冲突键 → 行为（后写覆盖先写）
	var table: Dictionary = {}
	for i in rules.size():
		var rule = rules[i]
		if rule == null:
			continue
		# 2a. 禁用 → 跳过
		if not bool(rule.get("enabled")):
			continue
		# 2b. 引用缺失 → 整条跳过 + 标黄
		var bad := _check_references(rule, map, signals)
		rule.set("invalid_reason", bad)
		if not bad.is_empty():
			continue
		# 2c. 条件求值
		if not _conditions_hold(rule, unit, battle_state, map, signals):
			continue
		intent.matched_rule_indices.append(i)
		# 2d. 记账：同键后者覆盖前者；阻塞型单独收集（不占键）
		for a in (rule.get("actions") as Array):
			if a == null:
				continue
			var key := str(a.call("conflict_key"))
			if key.is_empty():
				if bool(a.call("is_blocking")):
					intent.delay_request = _max_delay(intent.delay_request, float(a.get("seconds")))
				continue
			table[key] = a

	# 3. 从 table 生成 Intent
	for key in table.keys():
		var a = table[key]
		match str(a.get("type")):
			RuleActionScript.T_SET_FIRE_MODE:
				intent.fire_intent = bool(a.get("fire"))
			RuleActionScript.T_MOVE_ALONG_BEACONS:
				var seq: Array = []
				for x in (a.get("beacon_indices") as Array):
					seq.append(int(x))
				intent.move_intent = seq
			RuleActionScript.T_SET_SIGNAL:
				intent.signal_writes.append([int(a.get("signal_index")), bool(a.get("value"))])
			_:
				pass  # INTERACT_DEVICE：MVP 不实现，跳过

	# 4. 持续型意图的保持与重置**不在这里做** —— 由 UnitActor.apply_intents 落地。
	#    （详设 02 的 4.3 与详设 04 的 4.1 必须一致，改一处要改另一处。）
	return intent


func _max_delay(current, new_seconds: float):
	if current == null:
		return new_seconds
	return maxf(float(current), new_seconds)


# ---------------------------------------------------------------------------
# 引用检查与条件求值
# ---------------------------------------------------------------------------

## **公开的引用校验**（详设 09 §4.5 的 `validate_rule`）。
##
## 与 `_check_references` 是同一份实现 —— 只是暴露出来给**编制期**用：
## 玩家增删信标、复制指令之后，UI 要立刻把引用了不存在信标/信号的指令标黄，
## 而不是等到按了「开始」、在推演期求值时才知道。
func validate_rule(rule, map, signals) -> String:
	if rule == null:
		return ""
	return _check_references(rule, map, signals)


## 检查一条指令引用的信标/信号是否都存在。
## 返回空串表示合法，否则返回给 UI 看的说明（详设 02 的 4.4 决策 5：整条跳过）。
func _check_references(rule, map, signals) -> String:
	for c in (rule.get("conditions") as Array):
		if c == null:
			continue
		var ref: Array = c.call("reference_of")
		if not ref.is_empty():
			var msg := _check_one_ref(ref, map, signals)
			if not msg.is_empty():
				return msg
	for a in (rule.get("actions") as Array):
		if a == null:
			continue
		for ref2 in (a.call("references") as Array):
			var msg2 := _check_one_ref(ref2, map, signals)
			if not msg2.is_empty():
				return msg2
	return ""


func _check_one_ref(ref: Array, map, signals) -> String:
	var kind := str(ref[0])
	var idx := int(ref[1])
	if kind == "beacon":
		if map == null or not bool(map.call("has_beacon", idx)):
			return "引用了不存在的信标 %d" % idx
	elif kind == "signal":
		if signals == null or not bool(signals.call("has_signal_index", idx)):
			return "引用了不存在的信号 %d" % idx
	return ""


## 条件组求值：AND 全真 / OR 任一真；**0 个条件视为真**（详设 02 的 4.2）
func _conditions_hold(rule, unit, battle_state, map, signals) -> bool:
	var conds: Array = rule.get("conditions")
	if conds.is_empty():
		return true
	if int(rule.get("condition_logic")) == 0:      # RuleEnums.Logic.AND == 0
		for c in conds:
			if not evaluate_condition(c, unit, battle_state, map, signals):
				return false
		return true
	for c in conds:
		if evaluate_condition(c, unit, battle_state, map, signals):
			return true
	return false


## 求值单个条件。**纯函数，不得修改任何状态。**
func evaluate_condition(c, unit, battle_state, map, signals) -> bool:
	if c == null:
		return false
	match str(c.get("type")):
		RuleConditionScript.T_ENEMY_IN_VISION:
			var radius := float(c.get("radius"))
			if radius <= 0.0:
				radius = float(unit.call("effective_range"))
			return bool(battle_state.call("has_enemy_in_radius", unit, radius))

		RuleConditionScript.T_SIGNAL_STATE:
			return bool(signals.call("is_on", int(c.get("signal_index")))) == bool(c.get("want"))

		RuleConditionScript.T_BEACON_DISTANCE:
			if map == null:
				return false
			var bp = map.call("beacon_logic_position", int(c.get("beacon_index")))
			if bp == null:
				return false
			var d: float = (unit.get("position_logic") as Vector2).distance_to(bp as Vector2)
			return _compare(d, str(c.get("op")), float(c.get("value")))

		RuleConditionScript.T_SELF_HP:
			var max_hp := float(unit.get("max_hp"))
			if max_hp <= 0.0:
				return false
			var pct: float = float(unit.get("hp")) / max_hp * 100.0
			return _compare(pct, str(c.get("op")), float(c.get("percent")))

		RuleConditionScript.T_ENEMY_HAS_STATUS:
			return bool(battle_state.call("query_any_enemy_with_status",
				unit, str(c.get("status")), bool(c.get("want")),
				float(unit.call("effective_range"))))

		_:
			return false


func _compare(lhs: float, op: String, rhs: float) -> bool:
	match op:
		RuleConditionScript.OP_LT: return lhs < rhs
		RuleConditionScript.OP_LE: return lhs <= rhs
		RuleConditionScript.OP_EQ: return is_equal_approx(lhs, rhs)
		RuleConditionScript.OP_GE: return lhs >= rhs
		RuleConditionScript.OP_GT: return lhs > rhs
		_: return false


# ---------------------------------------------------------------------------
# 便捷构造（UI 与测试都用它，保证默认值一致）
# ---------------------------------------------------------------------------

static func make_rule(conditions: Array, actions: Array, logic: int = 0) -> RefCounted:
	var r = RuleScript.new()
	r.conditions = conditions
	r.actions = actions
	r.condition_logic = logic
	return r
