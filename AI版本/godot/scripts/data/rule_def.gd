class_name RuleDef
extends RefCounted
## 一条指令（02 §3 RuleDef）——敌我、默认、玩家配置、预设共用。

var enabled: bool = true
## 第四阶段「覆盖」：条件成立时无视上方非覆盖指令的优先级、直接接管（覆盖指令之间仍按列表顺序）。
## 例：1 始终→沿信标；2 射程内敌人→撤离（覆盖）= 平时沿信标走，有敌人时撤离，敌人离开后回到路线继续。
## 第五阶段起只对旧口径（单列表）单位生效；双组口径下"覆盖" = 同组内优先级高的覆盖低的，本字段由 migrate_legacy() 折算成顺序后清除。
var override: bool = false
var condition_mode: int = SimTypes.ConditionMode.ALL
var conditions: Array[ConditionDef] = []
var target: TargetDef = null            ## idle / retreat / follow_route 可为空
var action: ActionDef = null


static func from_dict(d: Dictionary, ctx: String) -> RuleDef:
	var r := RuleDef.new()
	r.enabled = DataReader.opt_bool(d, "enabled", true, ctx)
	r.override = DataReader.opt_bool(d, "override", false, ctx)
	var raw_mode: String = DataReader.opt_str(d, "condition_mode", "all", ctx)
	r.condition_mode = DataReader.enum_value(SimTypes.parse_mode(raw_mode), raw_mode, "条件模式", ctx)
	var conds: Array = DataReader.req_array(d, "conditions", ctx)
	for i: int in conds.size():
		var cctx: String = "%s.conditions[%d]" % [ctx, i]
		r.conditions.append(ConditionDef.from_dict(DataReader.as_dict(conds[i], cctx), cctx))
	if d.has("target"):
		r.target = TargetDef.from_dict(DataReader.as_dict(d["target"], ctx + ".target"), ctx + ".target")
	r.action = ActionDef.from_dict(DataReader.req_dict(d, "action", ctx), ctx + ".action")
	if r.target == null and (r.action.needs_target() or r.has_condition(SimTypes.ConditionType.TARGET_DISTANCE)):
		DataReader.report(ctx, "行为或条件需要 target 但缺失")
	return r


static func from_array(arr: Array, ctx: String) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	for i: int in arr.size():
		var rctx: String = "%s[%d]" % [ctx, i]
		out.append(RuleDef.from_dict(DataReader.as_dict(arr[i], rctx), rctx))
	return out


static func to_array(rules: Array[RuleDef]) -> Array:
	var out: Array = []
	for r: RuleDef in rules:
		out.append(r.to_dict())
	return out


static func clone_array(rules: Array[RuleDef]) -> Array[RuleDef]:
	var out: Array[RuleDef] = []
	for r: RuleDef in rules:
		out.append(r.clone())
	return out


## 第五阶段：本条属于哪个指令组（CHASE_ATTACK 两组都算）
func in_group(group: int) -> bool:
	return action != null and SimTypes.action_in_group(action.type, group)


## 某组指令在列表中的下标（列表顺序 = 组内优先级）
static func group_indices(rules: Array[RuleDef], group: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in rules.size():
		if rules[i].in_group(group):
			out.append(i)
	return out


## 第五阶段：旧口径（单列表、第一条成立者独占）→ 双组口径的等价指令列表。
## 先按旧求值顺序（覆盖指令在前）排好，再逐条展开，组内相对顺序不变：
##   攻击 → 攻击（攻击组）+ 同条件的「停止」（移动组）：旧口径攻击时原地不动
##   追击并攻击 → 追击（移动组）+ 攻击（攻击组）
##   移动类（沿信标 / 沿路线 / 追击 / 撤离 / 待机）→ 原样（移动组）+ 同条件的「停火」（攻击组）：旧口径移动时不开火
##   等待 → 原样（不加停火：等待结束后旧口径会继续向下，停火镜像无法跟随，见 docs/14 §2.4）
## 镜像指令保留原条件与目标（条件的候选口径依赖目标），因此两组的"第一条成立"与旧口径落在同一位置。
static func migrate_legacy(rules: Array[RuleDef]) -> Array[RuleDef]:
	var ordered: Array[RuleDef] = []
	for r: RuleDef in rules:
		if r.override:
			ordered.append(r)
	for r: RuleDef in rules:
		if not r.override:
			ordered.append(r)
	var out: Array[RuleDef] = []
	for src: RuleDef in ordered:
		var r: RuleDef = src.clone()
		r.override = false
		if r.action == null:
			out.append(r)
			continue
		match r.action.type:
			SimTypes.ActionType.ATTACK:
				out.append(r)
				out.append(_mirror(r, SimTypes.ActionType.IDLE))
			SimTypes.ActionType.CHASE_ATTACK:
				var chase: RuleDef = r.clone()
				chase.action = ActionDef.create(SimTypes.ActionType.CHASE)
				out.append(chase)
				out.append(_mirror(r, SimTypes.ActionType.ATTACK))
			SimTypes.ActionType.WAIT, SimTypes.ActionType.HOLD_FIRE:
				out.append(r)
			_:
				out.append(r)
				out.append(_mirror(r, SimTypes.ActionType.HOLD_FIRE))
	return out


## 同条件、同目标、换成另一种无参数行为的副本
static func _mirror(r: RuleDef, action_type: int) -> RuleDef:
	var m: RuleDef = r.clone()
	m.override = false
	m.action = ActionDef.create(action_type)
	return m


func has_condition(t: int) -> bool:
	for c: ConditionDef in conditions:
		if c.type == t:
			return true
	return false


func to_dict() -> Dictionary:
	var conds: Array = []
	for c: ConditionDef in conditions:
		conds.append(c.to_dict())
	var d: Dictionary = {
		"enabled": enabled,
		"condition_mode": "any" if condition_mode == SimTypes.ConditionMode.ANY else "all",
		"conditions": conds,
		"action": action.to_dict() if action != null else {},
	}
	if target != null:
		d["target"] = target.to_dict()
	if override:
		d["override"] = true          # 缺省不写（旧存档 / 关卡数据不变）
	return d


func clone() -> RuleDef:
	return RuleDef.from_dict(to_dict(), "clone")
